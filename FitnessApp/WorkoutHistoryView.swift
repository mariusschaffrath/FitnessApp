import SwiftUI
import HealthKit

enum WorkoutSortOption: String, CaseIterable {
    case date = "Datum"
    case duration = "Dauer"
    case calories = "Kalorien"
}

enum WorkoutFilterOption: String, CaseIterable {
    case all = "Alle"
    case indoor = "Indoor"
    case outdoor = "Outdoor"
}

struct WorkoutHistoryView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var timeRange: TimeRange = .month
    @State private var rawWorkouts: [Workout] = []
    @State private var dateOffset: Int = 0
    
    @State private var sortOption: WorkoutSortOption = .date
    @State private var filterOption: WorkoutFilterOption = .all
    @State private var displayedWorkouts: [Workout] = []
    
    private func updateDisplayedWorkouts() {
        var result = rawWorkouts
        
        // Filter
        switch filterOption {
        case .indoor: result = result.filter { $0.isIndoor }
        case .outdoor: result = result.filter { !$0.isIndoor }
        case .all: break
        }
        
        // Sort
        switch sortOption {
        case .date: result.sort { $0.date > $1.date }
        case .duration: result.sort { $0.duration > $1.duration }
        case .calories: result.sort { $0.calories > $1.calories }
        }
        
        self.displayedWorkouts = result
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                BackgroundView()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Time Range Selector
                        GlassCard {
                            VStack(spacing: 12) {
                                Picker("Zeitraum", selection: $timeRange) {
                                    ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: timeRange) { dateOffset = 0; fetchWorkouts() }
                                
                                HStack {
                                    Menu {
                                        Picker("Sortierung", selection: $sortOption) {
                                            ForEach(WorkoutSortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                        }
                                    } label: {
                                        Label(sortOption.rawValue, systemImage: "arrow.up.arrow.down")
                                            .font(.caption).bold()
                                            .padding(8).background(.ultraThinMaterial).cornerRadius(8)
                                    }
                                    
                                    Spacer()
                                    
                                    Menu {
                                        Picker("Filter", selection: $filterOption) {
                                            ForEach(WorkoutFilterOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                        }
                                    } label: {
                                        Label(filterOption.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                                            .font(.caption).bold()
                                            .padding(8).background(.ultraThinMaterial).cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Navigation
                        HStack {
                            Button(action: { dateOffset -= 1; fetchWorkouts() }) {
                                Image(systemName: "chevron.left.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                            }
                            Spacer()
                            VStack(spacing: 4) {
                                Text(getDateRangeTitle()).font(.headline).bold()
                                if dateOffset != 0 {
                                    Button("Aktuell") { dateOffset = 0; fetchWorkouts() }
                                        .font(.caption2).foregroundColor(AppleColors.ultraOrange)
                                }
                            }
                            Spacer()
                            Button(action: { dateOffset += 1; fetchWorkouts() }) {
                                Image(systemName: "chevron.right.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                            }.disabled(dateOffset >= 0)
                        }.padding(.horizontal, 30)
                        
                        // Summary Stats
                        HStack(spacing: 15) {
                            MiniStatCard(label: "Anzahl", value: "\(displayedWorkouts.count)", icon: "number", color: .blue)
                            MiniStatCard(label: "Dauer", value: getTotalDuration(), icon: "timer", color: .green)
                            MiniStatCard(label: "Kalorien", value: "\(Int(displayedWorkouts.map { $0.calories }.reduce(0, +)))", icon: "flame.fill", color: .orange)
                        }
                        .padding(.horizontal)
                        
                        // Workouts List
                        LazyVStack(spacing: 12) {
                            if displayedWorkouts.isEmpty {
                                VStack(spacing: 15) {
                                    Image(systemName: "figure.run.circle")
                                        .font(.system(size: 60))
                                        .foregroundColor(.secondary.opacity(0.3))
                                    Text("Keine Trainings gefunden")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("Versuche einen anderen Zeitraum oder Filter.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(displayedWorkouts) { workout in
                                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                        WorkoutRow(workout: workout)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    fetchWorkouts()
                }
                .navigationTitle("Trainings")
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear { fetchWorkouts() }
            .onChange(of: filterOption) { updateDisplayedWorkouts() }
            .onChange(of: sortOption) { updateDisplayedWorkouts() }
        }
    }
    
    private func fetchWorkouts() {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        var start: Date
        var end: Date
        
        switch timeRange {
        case .day:
            start = calendar.date(byAdding: .day, value: dateOffset, to: now)!
            end = calendar.date(byAdding: .day, value: 1, to: start)!
        case .week:
            let endOfWeek = calendar.date(byAdding: .day, value: dateOffset * 7, to: now)!
            start = calendar.date(byAdding: .day, value: -6, to: endOfWeek)!
            end = calendar.date(byAdding: .day, value: 1, to: endOfWeek)!
        case .month:
            let targetMonth = calendar.date(byAdding: .month, value: dateOffset, to: now)!
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: targetMonth))!
            end = calendar.date(byAdding: .month, value: 1, to: start)!
        case .year:
            let targetYear = calendar.date(byAdding: .year, value: dateOffset, to: now)!
            start = calendar.date(from: calendar.dateComponents([.year], from: targetYear))!
            end = calendar.date(byAdding: .year, value: 1, to: start)!
        }
        
        healthKitManager.fetchWorkouts(from: start, to: end) { fetchedWorkouts in
            self.rawWorkouts = fetchedWorkouts
            withAnimation(.spring()) {
                self.updateDisplayedWorkouts()
            }
        }
    }
    
    private func getDateRangeTitle() -> String {
        let calendar = Calendar.current; let now = Date()
        switch timeRange {
        case .day: return calendar.date(byAdding: .day, value: dateOffset, to: now)!.formatted(date: .abbreviated, time: .omitted)
        case .week:
            let endOfWeek = calendar.date(byAdding: .day, value: dateOffset * 7, to: calendar.startOfDay(for: now))!
            let start = calendar.date(byAdding: .day, value: -6, to: endOfWeek)!
            return "\(start.formatted(.dateTime.day().month())) - \(endOfWeek.formatted(.dateTime.day().month()))"
        case .month: return calendar.date(byAdding: .month, value: dateOffset, to: now)!.formatted(.dateTime.month(.wide).year())
        case .year: return calendar.date(byAdding: .year, value: dateOffset, to: now)!.formatted(.dateTime.year())
        }
    }
    
    private func getTotalDuration() -> String {
        let totalSeconds = displayedWorkouts.map { $0.duration }.reduce(0, +)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalSeconds) ?? "0m"
    }
}

struct MiniStatCard: View {
    let label: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.caption).bold()
            Text(value).font(.system(.subheadline, design: .rounded)).bold()
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
