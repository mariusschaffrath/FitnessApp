import Foundation
import HealthKit

struct Workout: Identifiable, Equatable {
    let id: UUID
    let type: HKWorkoutActivityType
    let duration: TimeInterval
    let calories: Double
    let distance: Double
    let date: Date
    let isIndoor: Bool
    var steps: Double? // Optionale Schritte für das Training
    
    var activityName: String {
        let name: String
        switch type {
        case .running: name = "Laufen"
        case .cycling: name = "Radfahren"
        case .walking: name = "Gehen"
        case .swimming: name = "Schwimmen"
        case .functionalStrengthTraining, .traditionalStrengthTraining: name = "Krafttraining"
        case .yoga: name = "Yoga"
        case .highIntensityIntervalTraining: name = "HIIT"
        case .hiking: name = "Wandern"
        case .climbing: name = "Klettern"
        case .rowing: name = "Rudern"
        case .soccer: name = "Fußball"
        case .basketball: name = "Basketball"
        case .tennis: name = "Tennis"
        case .elliptical: name = "Crosstrainer"
        case .stairClimbing: name = "Stepper"
        case .badminton: name = "Badminton"
        case .golf: name = "Golf"
        case .hockey: name = "Hockey"
        case .tableTennis: name = "Tischtennis"
        case .boxing: name = "Boxen"
        case .martialArts: name = "Kampfsport"
        case .pilates: name = "Pilates"
        case .dance, .socialDance: name = "Tanzen"
        case .coreTraining: name = "Core"
        case .flexibility: name = "Flexibilität"
        case .crossTraining: name = "Cross Training"
        case .barre: name = "Barre"
        case .handCycling: name = "Handbike"
        case .mindAndBody: name = "Geist & Körper"
        case .pickleball: name = "Pickleball"
        case .handball: name = "Handball"
        case .squash: name = "Squash"
        case .gymnastics: name = "Gymnastik"
        case .surfingSports: name = "Surfen"
        case .sailing: name = "Segeln"
        case .skatingSports: name = "Skaten"
        case .snowSports: name = "Wintersport"
        case .paddleSports: name = "Paddeln"
        default: name = "Workout"
        }
        return name + (isIndoor ? " (Indoor)" : " (Outdoor)")
    }
    
    var icon: String {
        switch type {
        case .running: return isIndoor ? "figure.run" : "figure.run.circle"
        case .cycling: return isIndoor ? "figure.indoor.cycle" : "figure.outdoor.cycle"
        case .walking: return isIndoor ? "figure.walk.circle" : "figure.walk"
        case .swimming: return "figure.pool.swim"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "figure.strengthtraining.functional"
        case .yoga: return "figure.yoga"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .hiking: return "figure.hiking"
        case .climbing: return "figure.climbing"
        case .rowing: return "figure.rower"
        case .soccer: return "figure.soccer"
        case .basketball: return "figure.basketball"
        case .tennis: return "figure.tennis"
        case .elliptical: return "figure.elliptical"
        case .stairClimbing: return "figure.stairs"
        case .golf: return "figure.golf"
        case .hockey: return "figure.hockey"
        case .boxing: return "figure.boxing"
        case .martialArts: return "figure.martial.arts"
        case .pilates: return "figure.pilates"
        case .dance, .socialDance: return "figure.dance"
        case .coreTraining: return "figure.core.training"
        case .flexibility: return "figure.flexibility"
        case .crossTraining: return "figure.cross.training"
        case .barre: return "figure.barre"
        case .handCycling: return "figure.hand.cycling"
        case .mindAndBody: return "figure.mind.and.body"
        case .pickleball: return "figure.pickleball"
        case .handball: return "figure.handball"
        case .squash: return "figure.squash"
        case .gymnastics: return "figure.gymnastics"
        case .surfingSports: return "figure.surfing"
        case .sailing: return "figure.sailing"
        case .skatingSports: return "figure.skating"
        case .snowSports: return "figure.skiing.downhill"
        case .paddleSports: return "figure.rower"
        default: return "figure.mixed.cardio"
        }
    }
}

extension HealthKitManager {
    func fetchRecentWorkouts(limit: Int = 25, completion: @escaping ([Workout]) -> Void) {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: limit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let samples = samples as? [HKWorkout], error == nil else { completion([]); return }
            let workouts = samples.map { hkWorkout in
                let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let calories = hkWorkout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                
                // --- VERBESSERTE INDOOR/OUTDOOR ERKENNUNG ---
                // Verwende String Literal für maximale Kompatibilität
                var isIndoor = (hkWorkout.metadata?["HKWorkoutIndoor"] as? Bool)
                
                if isIndoor == nil {
                    switch hkWorkout.workoutActivityType {
                    case .hiking, .snowSports, .sailing, .surfingSports: isIndoor = false
                    case .elliptical, .stairClimbing, .yoga, .pilates, .functionalStrengthTraining: isIndoor = true
                    default: isIndoor = false
                    }
                }

                return Workout(
                    id: hkWorkout.uuid,
                    type: hkWorkout.workoutActivityType,
                    duration: hkWorkout.duration,
                    calories: calories,
                    distance: hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                    date: hkWorkout.startDate,
                    isIndoor: isIndoor ?? false,
                    steps: nil
                )
            }
            DispatchQueue.main.async { completion(workouts) }
        }
        healthStore.execute(query)
    }
}
