import Foundation
import SwiftUI
import SwiftData
import WidgetKit

/// SwiftData Persistence Manager for managing `BioMetricsSnapshotEntity` persistence,
/// daily auto-saving, historical queries (7-day, 30-day, 90-day), and mock data initialization.
@MainActor
public final class PersistenceManager: ObservableObject {
    public static let shared = PersistenceManager()
    
    public let container: ModelContainer
    
    public var mainContext: ModelContext {
        container.mainContext
    }
    
    public init(inMemory: Bool = false) {
        do {
            let schema = Schema([BioMetricsSnapshotEntity.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }
    
    /// Saves or updates the daily snapshot for the specified date (defaults to today).
    public func saveDailySnapshot(
        date: Date = Date(),
        recoveryScore: Double,
        strainScore: Double,
        sleepScore: Double,
        hrvValue: Double,
        rhrValue: Double,
        steps: Double,
        calories: Double,
        exerciseMinutes: Double
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let descriptor = FetchDescriptor<BioMetricsSnapshotEntity>(
            sortBy: [SortDescriptor(\BioMetricsSnapshotEntity.date, order: .reverse)]
        )
        
        do {
            let allSnapshots: [BioMetricsSnapshotEntity] = try mainContext.fetch(descriptor)
            if let existing = allSnapshots.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
                existing.recoveryScore = recoveryScore
                existing.strainScore = strainScore
                existing.sleepScore = sleepScore
                existing.hrvValue = hrvValue
                existing.rhrValue = rhrValue
                existing.steps = steps
                existing.calories = calories
                existing.exerciseMinutes = exerciseMinutes
            } else {
                let newEntity = BioMetricsSnapshotEntity(
                    date: startOfDay,
                    recoveryScore: recoveryScore,
                    strainScore: strainScore,
                    sleepScore: sleepScore,
                    hrvValue: hrvValue,
                    rhrValue: rhrValue,
                    steps: steps,
                    calories: calories,
                    exerciseMinutes: exerciseMinutes
                )
                mainContext.insert(newEntity)
            }
            try mainContext.save()
            
            // Sync with WidgetKit & UserDefaults
            let defaults = UserDefaults.standard
            defaults.set(recoveryScore, forKey: "widget_recovery_score")
            defaults.set(strainScore, forKey: "widget_strain_score")
            
            let targetStrain: Double
            if recoveryScore >= 80 { targetStrain = 16.0 }
            else if recoveryScore >= 66 { targetStrain = 14.0 }
            else if recoveryScore >= 45 { targetStrain = 10.0 }
            else if recoveryScore >= 30 { targetStrain = 7.0 }
            else { targetStrain = 4.0 }
            
            defaults.set(targetStrain, forKey: "widget_target_strain")
            defaults.set(sleepScore, forKey: "widget_sleep_score")
            defaults.set(hrvValue, forKey: "widget_hrv_value")
            defaults.set(rhrValue, forKey: "widget_rhr_value")
            
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("PersistenceManager Error saving snapshot: \(error.localizedDescription)")
        }
    }
    
    /// Convenience method to save snapshot from a `BioMetricsSnapshot` and `ActivityData`
    public func saveSnapshot(biometrics: BioMetricsSnapshot, steps: Double, calories: Double, exerciseMinutes: Double) {
        saveDailySnapshot(
            date: biometrics.timestamp,
            recoveryScore: biometrics.recovery.score,
            strainScore: biometrics.strain.strainScale,
            sleepScore: biometrics.sleep.score,
            hrvValue: biometrics.recovery.hrvMs,
            rhrValue: biometrics.recovery.rhrBpm,
            steps: steps,
            calories: calories,
            exerciseMinutes: exerciseMinutes
        )
    }
    
    /// Fetches historical snapshots for the specified past number of days (e.g. 7, 30, 90).
    public func fetchSnapshots(days: Int) -> [BioMetricsSnapshotEntity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return []
        }
        
        let descriptor = FetchDescriptor<BioMetricsSnapshotEntity>(
            predicate: #Predicate<BioMetricsSnapshotEntity> { snapshot in
                snapshot.date >= startDate
            },
            sortBy: [SortDescriptor(\BioMetricsSnapshotEntity.date, order: .forward)]
        )
        
        do {
            return try mainContext.fetch(descriptor)
        } catch {
            print("PersistenceManager Error fetching snapshots: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Data verification and repair method to sanitize any corrupted or NaN records in SwiftData.
    public func verifyAndRepairData() {
        let descriptor = FetchDescriptor<BioMetricsSnapshotEntity>()
        do {
            let allEntities = try mainContext.fetch(descriptor)
            var hasChanges = false
            for entity in allEntities {
                if entity.recoveryScore.isNaN || !entity.recoveryScore.isFinite || entity.recoveryScore < 0 || entity.recoveryScore > 100 {
                    entity.recoveryScore = min(100.0, max(0.0, entity.recoveryScore.isFinite && !entity.recoveryScore.isNaN ? entity.recoveryScore : 65.0))
                    hasChanges = true
                }
                if entity.strainScore.isNaN || !entity.strainScore.isFinite || entity.strainScore < 0 || entity.strainScore > 21 {
                    entity.strainScore = min(21.0, max(0.0, entity.strainScore.isFinite && !entity.strainScore.isNaN ? entity.strainScore : 10.0))
                    hasChanges = true
                }
                if entity.sleepScore.isNaN || !entity.sleepScore.isFinite || entity.sleepScore < 0 || entity.sleepScore > 100 {
                    entity.sleepScore = min(100.0, max(0.0, entity.sleepScore.isFinite && !entity.sleepScore.isNaN ? entity.sleepScore : 75.0))
                    hasChanges = true
                }
                if entity.hrvValue.isNaN || !entity.hrvValue.isFinite || entity.hrvValue <= 0 {
                    entity.hrvValue = 58.0
                    hasChanges = true
                }
                if entity.rhrValue.isNaN || !entity.rhrValue.isFinite || entity.rhrValue <= 0 {
                    entity.rhrValue = 56.0
                    hasChanges = true
                }
                if entity.steps.isNaN || !entity.steps.isFinite || entity.steps < 0 {
                    entity.steps = 8000.0
                    hasChanges = true
                }
                if entity.calories.isNaN || !entity.calories.isFinite || entity.calories < 0 {
                    entity.calories = 400.0
                    hasChanges = true
                }
                if entity.exerciseMinutes.isNaN || !entity.exerciseMinutes.isFinite || entity.exerciseMinutes < 0 {
                    entity.exerciseMinutes = 30.0
                    hasChanges = true
                }
            }
            if hasChanges {
                try mainContext.save()
                print("PersistenceManager: Repaired corrupt data entries.")
            }
        } catch {
            print("PersistenceManager Data Repair Error: \(error.localizedDescription)")
        }
    }

    /// Seeds historical snapshot data for seamless offline/simulator testing and trend visualisations.
    public func seedHistoricalData(days: Int = 90, overwrite: Bool = false) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if overwrite {
            let descriptor = FetchDescriptor<BioMetricsSnapshotEntity>()
            if let existing = try? mainContext.fetch(descriptor) {
                for entity in existing {
                    mainContext.delete(entity)
                }
                try? mainContext.save()
            }
        }
        
        let existingSnapshots = fetchSnapshots(days: days)
        let existingDates = Set(existingSnapshots.map { calendar.startOfDay(for: $0.date) })
        
        var addedCount = 0
        for daysAgo in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            
            if existingDates.contains(dayStart) && !overwrite { continue }
            
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            let progressFactor = Double(days - daysAgo) / Double(days)
            
            // Weekly periodicity: higher strain on Tue/Thu/Sat, active recovery on Sun/Mon
            let dayStrainBase: Double
            switch weekday {
            case 3, 5, 7: dayStrainBase = 14.5
            case 2, 4, 6: dayStrainBase = 10.5
            default: dayStrainBase = 6.0
            }
            
            let strain = min(21.0, max(3.0, dayStrainBase + Double.random(in: -2.0...2.5)))
            
            // HRV & RHR inversely correlated with strain & progressive adaptation
            let baseHrv = 55.0 + (progressFactor * 10.0) + (isWeekend ? 4.0 : -2.0) + Double.random(in: -5.0...6.0)
            let baseRhr = 62.0 - (progressFactor * 4.0) + (isWeekend ? -2.0 : 1.0) + Double.random(in: -2.0...2.5)
            
            let recovery = min(100.0, max(25.0, 60.0 + (progressFactor * 12.0) - (strain * 1.5) + Double.random(in: -10.0...15.0)))
            let sleep = min(100.0, max(45.0, 70.0 + (progressFactor * 8.0) + Double.random(in: -12.0...12.0)))
            
            let steps = min(22000.0, max(3000.0, (dayStrainBase * 750.0) + Double.random(in: -1500.0...2500.0)))
            let calories = min(1200.0, max(200.0, (dayStrainBase * 38.0) + Double.random(in: -60.0...100.0)))
            let exercise = min(150.0, max(15.0, (dayStrainBase * 3.5) + Double.random(in: -10.0...20.0)))
            
            let entity = BioMetricsSnapshotEntity(
                date: dayStart,
                recoveryScore: recovery,
                strainScore: strain,
                sleepScore: sleep,
                hrvValue: baseHrv,
                rhrValue: baseRhr,
                steps: steps,
                calories: calories,
                exerciseMinutes: exercise
            )
            mainContext.insert(entity)
            addedCount += 1
        }
        
        if addedCount > 0 {
            do {
                try mainContext.save()
                print("PersistenceManager: Successfully seeded \(addedCount) historical snapshots.")
            } catch {
                print("PersistenceManager Error seeding snapshots: \(error.localizedDescription)")
            }
        }
        
        verifyAndRepairData()
    }
    
    /// Populates synthetic mock data for 90 days if database is empty to allow immediate trend visualisations.
    public func populateMockDataIfNeeded() {
        seedHistoricalData(days: 90, overwrite: false)
    }
}
