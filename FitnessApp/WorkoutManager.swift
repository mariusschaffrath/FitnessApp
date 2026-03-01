import Foundation
import HealthKit

struct Workout: Identifiable {
    let id: UUID
    let type: HKWorkoutActivityType
    let duration: TimeInterval
    let calories: Double
    let distance: Double
    let date: Date
    
    var activityName: String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Traditional Strength"
        case .yoga: return "Yoga"
        case .highIntensityIntervalTraining: return "HIIT"
        case .hiking: return "Hiking"
        case .climbing: return "Climbing"
        case .rowing: return "Rowing"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Stepper"
        case .badminton: return "Tennis"
        case .golf: return "Golf"
        case .hockey: return "Hockey"
        case .tableTennis: return "Table Tennis"
        case .boxing: return "Boxing"
        case .martialArts: return "Martial Arts"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        case .coreTraining: return "Core"
        case .flexibility: return "Flexibility"
        case .crossTraining: return "Cross Training"
        case .barre: return "Barre"
        case .handCycling: return "Hand Cycling"
        case .mindAndBody: return "Mind & Body"
        case .pickleball: return "Pickleball"
        case .socialDance: return "Social Dance"
        case .handball: return "Handball"
        case .squash: return "Squash"
        case .gymnastics: return "Gymnastics"
        case .surfingSports: return "Surfing"
        case .sailing: return "Sailing"
        case .skatingSports: return "Skating"
        case .snowSports: return "Skiing/Snowboard"
        case .paddleSports: return "Paddling"
        default: return "Workout"
        }
    }
    
    var icon: String {
        switch type {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .walking: return "figure.walk"
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
    func fetchRecentWorkouts(completion: @escaping ([Workout]) -> Void) {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: 25, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let samples = samples as? [HKWorkout], error == nil else {
                completion([])
                return
            }
            let workouts = samples.map { hkWorkout in
                let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let calories = hkWorkout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                return Workout(
                    id: hkWorkout.uuid,
                    type: hkWorkout.workoutActivityType,
                    duration: hkWorkout.duration,
                    calories: calories,
                    distance: hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                    date: hkWorkout.startDate
                )
            }
            DispatchQueue.main.async { completion(workouts) }
        }
        healthStore.execute(query)
    }
}
