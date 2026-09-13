import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamische Daten, die sich während des Workouts ändern
        var currentHeartRate: Int
        var caloriesBurned: Int
        var elapsedTime: TimeInterval
    }

    // Statische Daten, die beim Start festgelegt werden
    var workoutName: String
    var workoutIcon: String
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            // --- LOCKSCREEN / BANNER UI ---
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(AppleColors.ultraOrange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: context.attributes.workoutIcon)
                        .font(.title2)
                        .foregroundColor(AppleColors.ultraOrange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.workoutName)
                        .font(.headline)
                        .bold()
                    Text("Aktiv")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("\(context.state.currentHeartRate)")
                            .font(.system(.body, design: .rounded))
                            .bold()
                        Text("BPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(context.state.caloriesBurned) kcal")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .bold()
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))

        } dynamicIsland: { context in
            DynamicIsland {
                // --- EXPANDED UI (Wenn man die Island gedrückt hält) ---
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.attributes.workoutIcon)
                            .foregroundColor(AppleColors.ultraOrange)
                        Text(context.attributes.workoutName)
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("\(context.state.caloriesBurned) kcal")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.currentHeartRate) BPM", systemImage: "heart.fill")
                            .foregroundColor(.red)
                            .font(.headline)
                        Spacer()
                        Text(Date(timeIntervalSinceNow: context.state.elapsedTime), style: .timer)
                            .font(.system(.title3, design: .rounded))
                            .bold()
                            .monospacedDigit()
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                // --- COMPACT LEFT (Standard Ansicht) ---
                Image(systemName: context.attributes.workoutIcon)
                    .foregroundColor(AppleColors.ultraOrange)
            } compactTrailing: {
                // --- COMPACT RIGHT (Standard Ansicht) ---
                Text("\(context.state.currentHeartRate)")
                    .foregroundColor(.red)
                    .bold()
            } minimal: {
                // --- MINIMAL (Wenn mehrere Activities laufen) ---
                Image(systemName: "figure.run")
                    .foregroundColor(AppleColors.ultraOrange)
            }
            .widgetURL(URL(string: "fitnessapp://workout"))
            .keylineTint(AppleColors.ultraOrange)
        }
    }
}
