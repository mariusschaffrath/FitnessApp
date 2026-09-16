import Foundation
import ActivityKit
import SwiftUI
import Combine

/// Manager class for initiating, updating, and ending ActivityKit Live Activities
/// during active workouts and recovery windows.
@MainActor
public final class LiveActivityManager: ObservableObject {
    public static let shared = LiveActivityManager()
    
    @Published public private(set) var activeActivityId: String?
    @Published public private(set) var currentContentState: WorkoutActivityAttributes.ContentState?
    @Published public private(set) var isSimulatingWorkout: Bool = false
    
    private var currentActivity: Activity<WorkoutActivityAttributes>?
    private var simulationTimer: Timer?
    
    private init() {}
    
    /// Checks whether Live Activities are enabled on the device.
    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    /// Starts a new Workout Live Activity.
    @discardableResult
    public func startLiveActivity(
        workoutName: String = "Laufen",
        workoutIcon: String = "figure.run"
    ) -> String? {
        guard areActivitiesEnabled else {
            print("LiveActivityManager: Live Activities are not enabled on this device.")
            return nil
        }
        
        // End existing activity if running
        if currentActivity != nil {
            endLiveActivity()
        }
        
        let attributes = WorkoutActivityAttributes(
            workoutName: workoutName,
            workoutIcon: workoutIcon
        )
        
        let initialState = WorkoutActivityAttributes.ContentState(
            heartRate: 135.0,
            activeCalories: 45.0,
            durationSeconds: 0,
            trimpStrain: 2.1,
            currentZoneName: "Z2 Aerob",
            isPaused: false,
            startDate: Date()
        )
        
        do {
            let activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
            self.activeActivityId = activity.id
            self.currentContentState = initialState
            print("LiveActivityManager: Successfully started Live Activity \(activity.id)")
            return activity.id
        } catch {
            print("LiveActivityManager Error starting Live Activity: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Updates the currently active Live Activity with fresh biometrics.
    public func updateLiveActivity(
        heartRate: Double,
        activeCalories: Double,
        trimpStrain: Double,
        zoneName: String,
        isPaused: Bool = false
    ) {
        guard let activity = currentActivity else { return }
        
        let updatedState = WorkoutActivityAttributes.ContentState(
            heartRate: heartRate,
            activeCalories: activeCalories,
            durationSeconds: currentContentState?.durationSeconds ?? 0,
            trimpStrain: trimpStrain,
            currentZoneName: zoneName,
            isPaused: isPaused,
            startDate: currentContentState?.startDate ?? Date()
        )
        
        self.currentContentState = updatedState
        
        Task {
            let content = ActivityContent(state: updatedState, staleDate: Date().addingTimeInterval(30))
            await activity.update(content)
            print("LiveActivityManager: Updated Live Activity \(activity.id) with HR \(Int(heartRate)) bpm")
        }
    }
    
    /// Ends the current Live Activity seamlessly.
    public func endLiveActivity(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) {
        stopSimulatedWorkoutTimer()
        
        guard let activity = currentActivity else { return }
        
        let finalState = currentContentState ?? WorkoutActivityAttributes.ContentState()
        
        Task {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: dismissalPolicy)
            print("LiveActivityManager: Ended Live Activity \(activity.id)")
            
            Task { @MainActor in
                self.currentActivity = nil
                self.activeActivityId = nil
                self.currentContentState = nil
                self.isSimulatingWorkout = false
            }
        }
    }
    
    // MARK: - Workout Simulation Support (For Testing & Verification)
    
    /// Starts a real-time simulated workout loop updating biometrics every second.
    public func startSimulatedWorkout(
        workoutName: String = "Intervalllauf",
        workoutIcon: String = "figure.run"
    ) {
        startLiveActivity(workoutName: workoutName, workoutIcon: workoutIcon)
        isSimulatingWorkout = true
        
        var secondsElapsed: Double = 0
        var calories: Double = 45.0
        var strain: Double = 2.1
        
        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.currentActivity != nil else { return }
                
                secondsElapsed += 1.0
                calories += Double.random(in: 0.15...0.35)
                strain = min(21.0, strain + Double.random(in: 0.01...0.03))
                
                // Puls oscillation simulating intervals
                let hrWave = sin(secondsElapsed / 15.0)
                let heartRate = max(110.0, min(178.0, 145.0 + (hrWave * 25.0) + Double.random(in: -2...2)))
                
                let zoneName: String
                switch heartRate {
                case ..<120: zoneName = "Z1 Erholung"
                case 120..<140: zoneName = "Z2 Aerob"
                case 140..<155: zoneName = "Z3 Tempo"
                case 155..<170: zoneName = "Z4 Schwelle"
                default: zoneName = "Z5 Maximal"
                }
                
                self.updateLiveActivity(
                    heartRate: heartRate,
                    activeCalories: calories,
                    trimpStrain: strain,
                    zoneName: zoneName,
                    isPaused: false
                )
            }
        }
    }
    
    /// Stops the simulation timer.
    public func stopSimulatedWorkout() {
        endLiveActivity()
    }
    
    private func stopSimulatedWorkoutTimer() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
}
