import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var errorMessage: String?
    
    func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKCategoryType.categoryType(forIdentifier: .appleStandHour)!,
            HKObjectType.workoutType()
        ]
        
        let typesToShare: Set = [
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                self.startBackgroundMonitoring()
            }
            DispatchQueue.main.async {
                self.isAuthorized = success
                completion(success)
            }
        }
    }
    
    // MARK: - Background Monitoring
    
    private func startBackgroundMonitoring() {
        let workoutType = HKObjectType.workoutType()
        
        // 1. Enable Background Delivery
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
            if success { print("Background delivery enabled for workouts") }
        }
        
        // 2. Observer Query for new workouts
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            if error == nil {
                self?.fetchLatestWorkoutAndNotify()
            }
            completionHandler()
        }
        healthStore.execute(query)
    }
    
    private func fetchLatestWorkoutAndNotify() {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let lastWorkout = samples?.first as? HKWorkout else { return }
            
            // Verhindere Mehrfach-Benachrichtigung für dasselbe Workout (einfaches Date-Check)
            let lastNotify = UserDefaults.standard.object(forKey: "lastWorkoutNotify") as? Date ?? Date.distantPast
            if lastWorkout.startDate > lastNotify {
                let workout = Workout(
                    id: lastWorkout.uuid,
                    type: lastWorkout.workoutActivityType,
                    duration: lastWorkout.duration,
                    calories: lastWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                    distance: lastWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                    date: lastWorkout.startDate
                )
                
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute]
                formatter.unitsStyle = .abbreviated
                let durationStr = formatter.string(from: workout.duration) ?? ""
                
                NotificationManager.shared.sendWorkoutSummary(
                    activityName: workout.activityName,
                    duration: durationStr,
                    calories: Int(workout.calories)
                )
                
                UserDefaults.standard.set(lastWorkout.startDate, forKey: "lastWorkoutNotify")
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - Data Fetching
    
    func saveWater(ml: Double, completion: @escaping (Bool, Error?) -> Void) {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let unit = HKUnit.literUnit(with: .milli)
        let quantity = HKQuantity(unit: unit, doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }
    
    func fetchTodayActivity(completion: @escaping (Double, Double, Double, Double) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        var steps: Double = 0; var calories: Double = 0; var exercise: Double = 0; var stand: Double = 0
        let group = DispatchGroup()
        
        group.enter()
        let stepsQuery = HKStatisticsQuery(quantityType: HKQuantityType.quantityType(forIdentifier: .stepCount)!, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            group.leave()
        }
        healthStore.execute(stepsQuery)
        
        group.enter()
        let caloriesQuery = HKStatisticsQuery(quantityType: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
            group.leave()
        }
        healthStore.execute(caloriesQuery)
        
        group.enter()
        let exerciseQuery = HKStatisticsQuery(quantityType: HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            exercise = result?.sumQuantity()?.doubleValue(for: HKUnit.minute()) ?? 0
            group.leave()
        }
        healthStore.execute(exerciseQuery)
        
        group.enter()
        let standQuery = HKSampleQuery(sampleType: HKCategoryType.categoryType(forIdentifier: .appleStandHour)!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            if let standSamples = samples as? [HKCategorySample] {
                stand = Double(standSamples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count)
            }
            group.leave()
        }
        healthStore.execute(standQuery)
        
        group.notify(queue: .main) {
            self.checkGoalCompletion(steps: steps, calories: calories)
            completion(steps, calories, exercise, stand)
        }
    }
    
    private func checkGoalCompletion(steps: Double, calories: Double) {
        let stepGoal = UserDefaults.standard.double(forKey: "stepsGoal")
        let caloriesGoal = UserDefaults.standard.double(forKey: "caloriesGoal")
        
        let lastStepGoalNotify = UserDefaults.standard.object(forKey: "lastStepGoalNotify") as? Date ?? Date.distantPast
        if steps >= stepGoal && !Calendar.current.isDateInToday(lastStepGoalNotify) && stepGoal > 0 {
            NotificationManager.shared.sendGoalReachedNotification(goalType: "Schritte")
            UserDefaults.standard.set(Date(), forKey: "lastStepGoalNotify")
        }
        
        let lastMoveGoalNotify = UserDefaults.standard.object(forKey: "lastMoveGoalNotify") as? Date ?? Date.distantPast
        if calories >= caloriesGoal && !Calendar.current.isDateInToday(lastMoveGoalNotify) && caloriesGoal > 0 {
            NotificationManager.shared.sendGoalReachedNotification(goalType: "Kalorien")
            UserDefaults.standard.set(Date(), forKey: "lastMoveGoalNotify")
        }
    }
}
