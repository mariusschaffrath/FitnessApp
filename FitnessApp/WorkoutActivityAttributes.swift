import Foundation
import ActivityKit

/// Attributes and dynamic state definition for Workout & Recovery Live Activities.
nonisolated public struct WorkoutActivityAttributes: ActivityAttributes, Sendable {
    
    /// Dynamic state updated in real-time during an active workout or recovery window.
    public struct ContentState: Codable, Hashable, Sendable {
        public var heartRate: Double
        public var activeCalories: Double
        public var durationSeconds: TimeInterval
        public var trimpStrain: Double
        public var currentZoneName: String
        public var isPaused: Bool
        public var startDate: Date
        
        public init(
            heartRate: Double = 142.0,
            activeCalories: Double = 320.0,
            durationSeconds: TimeInterval = 1440.0,
            trimpStrain: Double = 12.4,
            currentZoneName: String = "Z4 Schwelle",
            isPaused: Bool = false,
            startDate: Date = Date()
        ) {
            self.heartRate = heartRate
            self.activeCalories = activeCalories
            self.durationSeconds = durationSeconds
            self.trimpStrain = trimpStrain
            self.currentZoneName = currentZoneName
            self.isPaused = isPaused
            self.startDate = startDate
        }
    }
    
    // Fixed static attributes set when starting the Live Activity session
    public var workoutName: String
    public var workoutIcon: String
    
    public init(workoutName: String = "Laufen", workoutIcon: String = "figure.run") {
        self.workoutName = workoutName
        self.workoutIcon = workoutIcon
    }
}
