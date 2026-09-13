import SwiftUI
import HealthKit
import Charts
import MapKit
import CoreLocation

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var heartRateData: [ChartDataPoint] = []
    @State private var workoutSteps: Double? = nil
    @State private var routeLocations: [CLLocation] = []
    @State private var mapPosition: MapCameraPosition = .automatic
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Header Card
                    HStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(AppleColors.ultraOrange.gradient.opacity(0.2))
                                .frame(width: 70, height: 70)
                            Image(systemName: workout.icon)
                                .font(.system(size: 32))
                                .foregroundStyle(AppleColors.ultraOrange.gradient)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.activityName)
                                .font(.system(.title2, design: .rounded))
                                .bold()
                            Text(workout.date.formatted(date: .long, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Route Map (Modern iOS 17 API)
                    if !workout.isIndoor && !routeLocations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trainings-Route")
                                .font(.system(.headline, design: .rounded))
                                .padding(.horizontal)
                            
                            Map(position: $mapPosition) {
                                MapPolyline(coordinates: routeLocations.map { $0.coordinate })
                                    .stroke(.blue, lineWidth: 4)
                                
                                if let start = routeLocations.first {
                                    Marker("Start", systemImage: "figure.run", coordinate: start.coordinate)
                                        .tint(.green)
                                }
                                
                                if let end = routeLocations.last {
                                    Marker("Ziel", systemImage: "flag.checkered", coordinate: end.coordinate)
                                        .tint(.red)
                                }
                            }
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)
                        }
                    }
                    
                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatGlassCard(title: "Dauer", value: formatDuration(workout.duration), icon: "timer", color: .green)
                        StatGlassCard(title: "Kalorien", value: "\(Int(workout.calories)) kcal", icon: "flame.fill", color: .orange)
                        StatGlassCard(title: "Distanz", value: String(format: "%.2f km", workout.distance / 1000), icon: "figure.walk", color: .blue)
                        
                        if let steps = workoutSteps {
                            StatGlassCard(title: "Schritte", value: "\(Int(steps))", icon: "shoe.fill", color: .cyan)
                        } else if workout.type == .running || workout.type == .walking {
                            StatGlassCard(title: "Schritte", value: "Lade...", icon: "shoe.fill", color: .cyan)
                        }
                        
                        StatGlassCard(title: "∅ Puls", value: calculateAvgHR(), icon: "heart.fill", color: .red)
                    }
                    .padding(.horizontal)
                    
                    // Heart Rate Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Herzfrequenz-Intensität")
                            .font(.system(.headline, design: .rounded))
                            .padding(.horizontal)
                        
                        GlassCard {
                            if heartRateData.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "heart.slash.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.3))
                                    Text("Keine Herzfrequenz-Daten")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 180)
                            } else {
                                Chart(heartRateData) { point in
                                    LineMark(
                                        x: .value("Zeit", point.date),
                                        y: .value("BPM", point.value)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.red.gradient)
                                    
                                    AreaMark(
                                        x: .value("Zeit", point.date),
                                        y: .value("BPM", point.value)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(LinearGradient(colors: [.red.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                                }
                                .frame(height: 200)
                                .chartYScale(domain: .automatic(includesZero: false))
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .minute, count: 5)) { value in
                                        AxisValueLabel(format: .dateTime.hour().minute())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { 
            fetchHeartRate()
            if workout.type == .running || workout.type == .walking {
                fetchSteps()
            }
            if !workout.isIndoor {
                fetchRoute()
            }
        }
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
    
    private func fetchSteps() {
        healthKitManager.fetchStepsForWorkout(workout) { steps in
            self.workoutSteps = steps
        }
    }
    
    private func fetchRoute() {
        healthKitManager.fetchRoute(for: workout) { locations in
            guard !locations.isEmpty else { return }
            self.routeLocations = locations
        }
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
