import Foundation
import UserNotifications
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Benachrichtigungen erlaubt")
            } else if let error = error {
                print("Fehler bei Benachrichtigungs-Erlaubnis: \(error.localizedDescription)")
            }
        }
    }
    
    func sendWorkoutSummary(activityName: String, duration: String, calories: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Workout abgeschlossen! 🏆"
        content.body = "Super gemacht! Dein \(activityName) Training dauerte \(duration) und du hast ca. \(calories) kcal verbrannt."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // Sofort senden
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendGoalReachedNotification(goalType: String) {
        let content = UNMutableNotificationContent()
        content.title = "Ziel erreicht! 🎉"
        content.body = "Herzlichen Glückwunsch! Du hast dein Tagesziel für \(goalType) erreicht. Bleib so aktiv!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
