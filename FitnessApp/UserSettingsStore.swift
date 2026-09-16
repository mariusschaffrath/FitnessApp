import SwiftUI
import Combine

/// Store for managing persistent user daily goals and settings.
/// Synchronized across the app using `@MainActor` and `UserDefaults`.
@MainActor
public final class UserSettingsStore: ObservableObject {
    public static let shared = UserSettingsStore()
    
    private enum Keys {
        static let stepsGoal = "user_steps_goal"
        static let caloriesGoal = "user_calories_goal"
        static let exerciseGoal = "user_exercise_goal"
    }
    
    /// Target daily step count
    @Published public var stepsGoal: Double {
        didSet {
            UserDefaults.standard.set(stepsGoal, forKey: Keys.stepsGoal)
        }
    }
    
    /// Target daily active calories (kcal)
    @Published public var caloriesGoal: Double {
        didSet {
            UserDefaults.standard.set(caloriesGoal, forKey: Keys.caloriesGoal)
        }
    }
    
    /// Target daily exercise time (minutes)
    @Published public var exerciseGoal: Double {
        didSet {
            UserDefaults.standard.set(exerciseGoal, forKey: Keys.exerciseGoal)
        }
    }
    
    public init() {
        let storedSteps = UserDefaults.standard.double(forKey: Keys.stepsGoal)
        self.stepsGoal = storedSteps > 0 ? storedSteps : 10000.0
        
        let storedCalories = UserDefaults.standard.double(forKey: Keys.caloriesGoal)
        self.caloriesGoal = storedCalories > 0 ? storedCalories : 500.0
        
        let storedExercise = UserDefaults.standard.double(forKey: Keys.exerciseGoal)
        self.exerciseGoal = storedExercise > 0 ? storedExercise : 30.0
    }
    
    /// Reset all goals to default values
    public func resetToDefaults() {
        stepsGoal = 10000.0
        caloriesGoal = 500.0
        exerciseGoal = 30.0
    }
}
