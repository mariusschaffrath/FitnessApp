import SwiftUI
import HealthKit

@main
struct FitnessAppApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
