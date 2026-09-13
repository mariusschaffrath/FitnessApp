import WidgetKit
import SwiftUI
import HealthKit

struct FitnessWidgetEntry: TimelineEntry {
    let date: Date
    let calories: Double
    let caloriesGoal: Double
    let exercise: Double
    let exerciseGoal: Double
    let stand: Double
    let standGoal: Double
    let isAuthorized: Bool
}

struct FitnessWidgetView : View {
    var entry: FitnessWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if !entry.isAuthorized {
                Text("Bitte App öffnen & Zugriff erlauben")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                switch family {
                case .systemSmall:
                    smallWidget
                case .systemMedium:
                    mediumWidget
                case .accessoryCircular:
                    lockScreenWidget
                default:
                    smallWidget
                }
            }
        }
    }
    
    var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    ActivityRingVisual(
                        calories: entry.calories, calGoal: entry.caloriesGoal,
                        exercise: entry.exercise, exGoal: entry.exerciseGoal,
                        stand: entry.stand, standGoal: entry.standGoal,
                        size: 50
                    )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    WidgetMetricRow(label: "Bewegen", value: entry.calories, unit: "kcal", color: .red)
                    WidgetMetricRow(label: "Training", value: entry.exercise, unit: "min", color: .green)
                    WidgetMetricRow(label: "Stehen", value: entry.stand, unit: "std", color: .blue)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    var mediumWidget: some View {
        HStack {
            ActivityRingVisual(
                calories: entry.calories, calGoal: entry.caloriesGoal,
                exercise: entry.exercise, exGoal: entry.exerciseGoal,
                stand: entry.stand, standGoal: entry.standGoal,
                size: 80
            )
            .padding(.trailing, 20)
            
            VStack(alignment: .leading, spacing: 6) {
                WidgetMetricRow(label: "Bewegen", value: entry.calories, unit: "kcal / \(Int(entry.caloriesGoal))", color: .red)
                WidgetMetricRow(label: "Training", value: entry.exercise, unit: "min / \(Int(entry.exerciseGoal))", color: .green)
                WidgetMetricRow(label: "Stehen", value: entry.stand, unit: "std / \(Int(entry.standGoal))", color: .blue)
            }
            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    var lockScreenWidget: some View {
        ZStack {
            ActivityRingVisual(
                calories: entry.calories, calGoal: entry.caloriesGoal,
                exercise: entry.exercise, exGoal: entry.exerciseGoal,
                stand: entry.stand, standGoal: entry.standGoal,
                size: 44
            )
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct WidgetMetricRow: View {
    let label: String; let value: Double; let unit: String; let color: Color
    var body: some View {
        HStack(spacing: 2) {
            Text("\(Int(value))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }
}
