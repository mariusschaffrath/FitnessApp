import SwiftUI
import HealthKit
import Charts

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var heartRateData: [ChartDataPoint] = []
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Header Card
                    HStack(spacing: 20) {
                        Image(systemName: workout.icon)
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.gradient)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.activityName)
                                .font(.system(.title, design: .rounded))
                                .bold()
                            Text(workout.date.formatted(date: .long, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Stats Grid with Glass Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatGlassCard(title: "Duration", value: formatDuration(workout.duration), icon: "timer", color: .green)
                        StatGlassCard(title: "Calories", value: "\(Int(workout.calories)) kcal", icon: "flame.fill", color: .orange)
                        StatGlassCard(title: "Distance", value: String(format: "%.2f km", workout.distance / 1000), icon: "figure.walk", color: .blue)
                        StatGlassCard(title: "Avg HR", value: calculateAvgHR(), icon: "heart.fill", color: .red)
                    }
                    .padding(.horizontal)
                    
                    // Heart Rate Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Heart Rate Intensity")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        GlassCard {
                            if heartRateData.isEmpty {
                                Text("No heart rate samples found")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 150)
                            } else {
                                Chart(heartRateData) { point in
                                    LineMark(
                                        x: .value("Time", point.date),
                                        y: .value("BPM", point.value)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.red.gradient)
                                    
                                    AreaMark(
                                        x: .value("Time", point.date),
                                        y: .value("BPM", point.value)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(LinearGradient(colors: [.red.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                                }
                                .frame(height: 200)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Activity Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fetchHeartRate() }
    }
    
    private func fetchHeartRate() {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.date, end: workout.date.addingTimeInterval(workout.duration), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else { return }
            let points = samples.map { sample in ChartDataPoint(date: sample.startDate, value: sample.quantity.doubleValue(for: HKUnit(from: "count/min")), type: "HR") }
            DispatchQueue.main.async { self.heartRateData = points }
        }
        healthKitManager.healthStore.execute(query)
    }
    
    private func calculateAvgHR() -> String {
        guard !heartRateData.isEmpty else { return "--" }
        let avg = heartRateData.map { $0.value }.reduce(0, +) / Double(heartRateData.count)
        return "\(Int(avg)) bpm"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

struct StatGlassCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.headline)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1), lineWidth: 0.5))
    }
}
