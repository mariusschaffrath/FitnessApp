import SwiftUI
import HealthKit

struct GoalSettingsView: View {
    @AppStorage("stepsGoal") var stepsGoal: Double = 10000
    @AppStorage("caloriesGoal") var caloriesGoal: Double = 500
    @AppStorage("exerciseGoal") var exerciseGoal: Double = 30
    @AppStorage("standGoal") var standGoal: Double = 12
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Daily Goals")) {
                    GoalInputField(label: "Move (kcal)", value: $caloriesGoal, icon: "flame.fill", color: AppleColors.move)
                    GoalInputField(label: "Exercise (min)", value: $exerciseGoal, icon: "timer", color: AppleColors.exercise)
                    GoalInputField(label: "Stand (hours)", value: $standGoal, icon: "figure.stand", color: AppleColors.stand)
                    GoalInputField(label: "Steps", value: $stepsGoal, icon: "figure.walk", color: AppleColors.steps)
                }
            }
            .navigationTitle("Edit Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct GoalInputField: View {
    let label: String
    @Binding var value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color)
            Text(label)
            Spacer()
            TextField(label, value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct LogWaterView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var amount: Double = 250
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "drop.fill").font(.system(size: 80)).foregroundColor(.blue).padding()
                Text("\(Int(amount)) ml").font(.largeTitle).bold()
                Slider(value: $amount, in: 100...1000, step: 50).padding(.horizontal, 40)
                HStack(spacing: 20) {
                    Button("250ml") { amount = 250 }.buttonStyle(.bordered)
                    Button("500ml") { amount = 500 }.buttonStyle(.bordered)
                }
                Button(action: { logWater() }) {
                    Text("Log Water").bold().frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }.padding(.horizontal, 40).padding(.top, 20)
                Spacer()
            }
            .navigationTitle("Log Water")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
    
    private func logWater() {
        healthKitManager.saveWater(ml: amount) { success, _ in
            if success { dismiss() }
        }
    }
}
