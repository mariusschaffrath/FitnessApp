import Foundation
import SwiftData

/// SwiftData Entity storing daily biometric and activity snapshots for historical persistence and trend analysis.
@Model
public final class BioMetricsSnapshotEntity {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var recoveryScore: Double
    public var strainScore: Double
    public var sleepScore: Double
    public var hrvValue: Double
    public var rhrValue: Double
    public var steps: Double
    public var calories: Double
    public var exerciseMinutes: Double
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        recoveryScore: Double = 0.0,
        strainScore: Double = 0.0,
        sleepScore: Double = 0.0,
        hrvValue: Double = 0.0,
        rhrValue: Double = 0.0,
        steps: Double = 0.0,
        calories: Double = 0.0,
        exerciseMinutes: Double = 0.0
    ) {
        self.id = id
        self.date = date
        self.recoveryScore = recoveryScore
        self.strainScore = strainScore
        self.sleepScore = sleepScore
        self.hrvValue = hrvValue
        self.rhrValue = rhrValue
        self.steps = steps
        self.calories = calories
        self.exerciseMinutes = exerciseMinutes
    }
}
