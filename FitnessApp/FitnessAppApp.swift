import SwiftUI
import HealthKit

@main
struct FitnessAppApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var persistenceManager = PersistenceManager.shared
    @StateObject private var userSettings = UserSettingsStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(persistenceManager)
                .environmentObject(userSettings)
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
