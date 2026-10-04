import Foundation
import HealthKit
import Combine
import ActivityKit
import WidgetKit
import CoreLocation

enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit ist auf diesem Gerät nicht verfügbar."
        case .unauthorized: return "Keine Berechtigung für HealthKit-Daten."
        }
    }
}

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var lastSyncDate: Date?
    @Published var syncErrorMessage: String?
    @Published var isSyncing = false
    
    // --- HEUTIGE AKTIVITÄT (Zentral für die UI) ---
    @Published var todaySteps: Double = 0
    @Published var todayCalories: Double = 0
    @Published var todayExercise: Double = 0
    @Published var todayStand: Double = 0
    @Published var recentWorkouts: [Workout] = []
    
    // Live Activity Tracking
    @Published var activeActivity: Activity<WorkoutAttributes>?
    private var timer: AnyCancellable?
    
    init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        let shareType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: shareType)
        
        DispatchQueue.main.async {
            if status == .sharingAuthorized {
                self.isAuthorized = true
                self.startBackgroundMonitoring()
                Task { await self.refreshAllData() }
            } else {
                self.isAuthorized = true 
                Task { await self.refreshAllData() }
            }
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.syncErrorMessage = HealthKitError.notAvailable.localizedDescription
            completion(false)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKCategoryType.categoryType(forIdentifier: .appleStandHour)!,
            HKSeriesType.workoutRoute(), // Route für Karten
            HKObjectType.activitySummaryType(),
            HKObjectType.workoutType()
        ]
        
        let typesToShare: Set = [
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)!,
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success { 
                    self.startBackgroundMonitoring()
                    Task { await self.refreshAllData() }
                }
                completion(success)
            }
        }
    }
    
    // --- ROUTE FETCHING ---
    
    func fetchRoute(for workout: Workout, completion: @escaping ([CLLocation]) -> Void) {
        let predicate = HKQuery.predicateForObject(with: workout.id)
        
        let query = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let routeSample = samples?.first as? HKWorkoutRoute else {
                completion([])
                return
            }
            
            var locations = [CLLocation]()
            let routeQuery = HKWorkoutRouteQuery(route: routeSample) { _, routeLocations, done, error in
                if let newLocations = routeLocations {
                    locations.append(contentsOf: newLocations)
                }
                
                if done {
                    DispatchQueue.main.async {
                        completion(locations)
                    }
                }
            }
            self?.healthStore.execute(routeQuery)
        }
        healthStore.execute(query)
    }
    
    // --- ZENTRALE REFRESH LOGIK ---
    private var lastRefreshTimestamp: Date = .distantPast
    
    @MainActor
    func refreshAllData(force: Bool = false) async {
        guard isAuthorized else { return }
        
        let now = Date()
        // Akku-Schutz: Wenn die Daten vor weniger als 45s synchronisiert wurden, überspringen (außer expliziter Force-Refresh)
        if !force && now.timeIntervalSince(lastRefreshTimestamp) < 45.0 {
            return
        }
        lastRefreshTimestamp = now
        self.isSyncing = true
        
        do {
            let data = try await fetchTodayActivityAsync()
            self.todaySteps = data.steps
            self.todayCalories = data.calories
            self.todayExercise = data.exercise
            self.todayStand = data.stand
            self.lastSyncDate = Date()
            
            fetchRecentWorkouts(limit: 20) { workouts in
                self.recentWorkouts = workouts
                self.isSyncing = false
            }
        } catch {
            print("❌ Refresh Fehler: \(error.localizedDescription)")
            self.isSyncing = false
        }
    }
    
    // --- LIVE WORKOUT LOGIC ---
    
    func startLiveWorkout(name: String, icon: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = WorkoutAttributes(workoutName: name, workoutIcon: icon)
        let initialState = WorkoutAttributes.ContentState(currentHeartRate: 0, caloriesBurned: 0, elapsedTime: 0)
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            self.activeActivity = activity
            startSimulation(for: activity)
        } catch {
            print("❌ Fehler beim Starten der Live Activity: \(error.localizedDescription)")
        }
    }
    
    func stopLiveWorkout() {
        Task {
            for activity in Activity<WorkoutAttributes>.activities {
                let finalState = activity.content.state
                await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            }
            DispatchQueue.main.async {
                self.activeActivity = nil
                self.timer?.cancel()
            }
        }
    }
    
    private func startSimulation(for activity: Activity<WorkoutAttributes>) {
        var heartRate = 120
        var calories = 0
        let startTime = Date()
        
        // Akku-Optimierung: 5 Sekunden Taktung statt 2 Sekunden spart 60% IPC- & Dynamic-Island-Wakeups
        timer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                heartRate += Int.random(in: -2...5)
                calories += Int.random(in: 2...5)
                let elapsed = Date().timeIntervalSince(startTime)
                
                let newState = WorkoutAttributes.ContentState(
                    currentHeartRate: heartRate,
                    caloriesBurned: calories,
                    elapsedTime: elapsed
                )
                
                Task {
                    await activity.update(ActivityContent(state: newState, staleDate: nil))
                }
            }
    }
    
    @MainActor
    func fetchTodayActivityAsync() async throws -> (steps: Double, calories: Double, exercise: Double, stand: Double) {
        guard isAuthorized else { throw HealthKitError.unauthorized }
        return try await withCheckedThrowingContinuation { continuation in
            fetchActivityData(for: Date()) { steps, calories, exercise, stand in
                continuation.resume(returning: (steps, calories, exercise, stand))
            }
        }
    }
    
    // In-Memory-Cache für vergangene Tage (verhindert hunderte redundante HealthKit-Abfragen)
    private var historicalActivityCache: [Date: (Double, Double, Double, Double)] = [:]
    
    func fetchActivityData(for date: Date, completion: @escaping (Double, Double, Double, Double) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: Date())
        
        // Wenn es ein vergangener Tag ist und bereits im Cache liegt -> Sofort ohne HealthKit-IPC zurückgeben!
        if startOfDay < todayStart, let cached = historicalActivityCache[startOfDay] {
            completion(cached.0, cached.1, cached.2, cached.3)
            return
        }
        
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        var steps: Double = 0; var calories: Double = 0; var exercise: Double = 0; var stand: Double = 0
        let group = DispatchGroup()
        
        group.enter()
        let stepsQuery = HKStatisticsQuery(quantityType: HKQuantityType.quantityType(forIdentifier: .stepCount)!, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0; group.leave() }
        healthStore.execute(stepsQuery)
        
        group.enter()
        let caloriesQuery = HKStatisticsQuery(quantityType: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0; group.leave() }
        healthStore.execute(caloriesQuery)
        
        group.enter()
        let exerciseQuery = HKStatisticsQuery(quantityType: HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in exercise = result?.sumQuantity()?.doubleValue(for: HKUnit.minute()) ?? 0; group.leave() }
        healthStore.execute(exerciseQuery)
        
        group.enter()
        let standType = HKCategoryType.categoryType(forIdentifier: .appleStandHour)!
        let standQuery = HKSampleQuery(sampleType: standType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            if let standSamples = samples as? [HKCategorySample] {
                let stoodHours = Set(standSamples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.map { calendar.component(.hour, from: $0.startDate) })
                stand = Double(stoodHours.count)
            }
            group.leave()
        }
        healthStore.execute(standQuery)
        
        group.notify(queue: .main) { [weak self] in
            // Vergangene Tage im Cache festhalten, da sich deren Werte nicht mehr ändern
            if startOfDay < todayStart {
                self?.historicalActivityCache[startOfDay] = (steps, calories, exercise, stand)
            }
            completion(steps, calories, exercise, stand)
        }
    }

    // MARK: - HealthKit Background Delivery & Observer Queries
    private var activeObserverQueries: [HKObserverQuery] = []
    
    private func startBackgroundMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let sampleTypesToMonitor: [(HKSampleType, HKUpdateFrequency)] = [
            (HKObjectType.workoutType(), .immediate),
            (HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!, .immediate),
            (HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!, .immediate),
            (HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!, .hourly),
            (HKQuantityType.quantityType(forIdentifier: .stepCount)!, .hourly),
            (HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!, .hourly)
        ]
        
        for (sampleType, frequency) in sampleTypesToMonitor {
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: frequency) { success, error in
                if let error = error {
                    print("⚠️ HealthKit Background Delivery Fehler für \(sampleType.identifier): \(error.localizedDescription)")
                } else if success {
                    print("✅ HealthKit Background Delivery aktiv für \(sampleType.identifier)")
                }
            }
            
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }
                
                print("🔄 HealthKit Observer Query getriggert für \(sampleType.identifier)")
                
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        completionHandler()
                        return
                    }
                    
                    if sampleType == HKObjectType.workoutType() {
                        self.fetchLatestWorkoutAndNotify()
                    }
                    
                    // Daten aktualisieren
                    await self.refreshAllData(force: true)
                    
                    // WidgetKit Timelines synchronisieren
                    WidgetCenter.shared.reloadAllTimelines()
                    
                    completionHandler()
                }
            }
            
            activeObserverQueries.append(query)
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestWorkoutAndNotify() {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let lastWorkout = samples?.first as? HKWorkout else { return }
            let lastNotify = UserDefaults.standard.object(forKey: "lastWorkoutNotify") as? Date ?? Date.distantPast
            if lastWorkout.startDate > lastNotify {
                let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let calories = lastWorkout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                let formatter = DateComponentsFormatter(); formatter.allowedUnits = [.hour, .minute]; formatter.unitsStyle = .abbreviated
                NotificationManager.shared.sendWorkoutSummary(activityName: "Workout", duration: formatter.string(from: lastWorkout.duration) ?? "", calories: Int(calories))
                UserDefaults.standard.set(lastWorkout.startDate, forKey: "lastWorkoutNotify")
            }
        }
        healthStore.execute(query)
    }
    
    func saveWater(ml: Double, completion: @escaping (Bool, Error?) -> Void) {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let unit = HKUnit.literUnit(with: .milli)
        let quantity = HKQuantity(unit: unit, doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())
        healthStore.save(sample) { success, error in DispatchQueue.main.async { completion(success, error) } }
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date, completion: @escaping ([Workout]) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let samples = samples as? [HKWorkout], error == nil else { completion([]); return }
            let workouts = samples.map { hkWorkout in
                let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let calories = hkWorkout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                
                // --- VERBESSERTE INDOOR/OUTDOOR ERKENNUNG ---
                var isIndoor = (hkWorkout.metadata?["HKWorkoutIndoor"] as? Bool)
                
                if isIndoor == nil {
                    switch hkWorkout.workoutActivityType {
                    case .hiking, .snowSports, .sailing, .surfingSports: isIndoor = false
                    case .elliptical, .stairClimbing, .yoga, .pilates, .functionalStrengthTraining: isIndoor = true
                    default: isIndoor = false
                    }
                }
                
                return Workout(id: hkWorkout.uuid, type: hkWorkout.workoutActivityType, duration: hkWorkout.duration, calories: calories, distance: hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0, date: hkWorkout.startDate, isIndoor: isIndoor ?? false, steps: nil)
            }
            DispatchQueue.main.async { completion(workouts) }
        }
        healthStore.execute(query)
    }

    func fetchStepsForWorkout(_ workout: Workout, completion: @escaping (Double) -> Void) {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: workout.date, end: workout.date.addingTimeInterval(workout.duration), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            DispatchQueue.main.async {
                completion(steps)
            }
        }
        healthStore.execute(query)
    }
}
