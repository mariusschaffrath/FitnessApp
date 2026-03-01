import SwiftUI
import HealthKit
import Charts

enum TimeRange: String, CaseIterable {
    case day = "Tag"
    case week = "Woche"
    case month = "Monat"
    case year = "Jahr"
}

enum MetricType: String, CaseIterable {
    case steps = "Schritte"
    case calories = "Kalorien"
    case exercise = "Training"
    case stand = "Stehen"
}

struct StatsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var timeRange: TimeRange = .week
    @State private var selectedMetric: MetricType = .steps
    @State private var chartData: [ChartDataPoint] = []
    @State private var dateOffset: Int = 0
    @State private var selectedDate: Date?
    
    var body: some View {
        NavigationView {
            ZStack {
                BackgroundView()
                
                ScrollView {
                    VStack(spacing: 20) {
                        GlassCard {
                            VStack(spacing: 15) {
                                Picker("Metrik", selection: $selectedMetric) {
                                    ForEach(MetricType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                }.pickerStyle(.segmented)
                                
                                Picker("Zeitraum", selection: $timeRange) {
                                    ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                }.pickerStyle(.segmented)
                                .onChange(of: timeRange) { dateOffset = 0; fetchData() }
                            }
                        }.padding(.horizontal)
                        
                        HStack {
                            Button(action: { dateOffset -= 1; fetchData() }) {
                                Image(systemName: "chevron.left.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                            }
                            Spacer()
                            Text(getDateRangeTitle()).font(.headline).bold()
                            Spacer()
                            Button(action: { dateOffset += 1; fetchData() }) {
                                Image(systemName: "chevron.right.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                            }.disabled(dateOffset >= 0)
                        }.padding(.horizontal, 30)
                        
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(selectedMetric.rawValue).font(.headline).foregroundColor(.secondary)
                                Text(calculateTotal()).font(.system(.title, design: .rounded)).bold()
                                
                                Chart {
                                    ForEach(chartData) { point in
                                        BarMark(
                                            x: .value("Datum", point.date, unit: getIntervalUnit()),
                                            y: .value("Wert", point.value)
                                        )
                                        .foregroundStyle(getMetricColor().gradient)
                                        .cornerRadius(4)
                                        .opacity(selectedDate == nil || isSamePeriod(point.date, selectedDate!) ? 1.0 : 0.5)
                                    }
                                    
                                    if let selectedDate, let selectedPoint = getSelectedPoint() {
                                        RuleMark(x: .value("Auswahl", selectedDate, unit: getIntervalUnit()))
                                            .foregroundStyle(.secondary.opacity(0.3))
                                            .annotation(position: .top, spacing: 0) {
                                                VStack {
                                                    Text(selectedPoint.date.formatted(date: .abbreviated, time: .omitted))
                                                        .font(.caption2).foregroundColor(.secondary)
                                                    Text(formatValue(selectedPoint.value))
                                                        .font(.headline).bold()
                                                }
                                                .padding(8)
                                                .background(.ultraThinMaterial)
                                                .cornerRadius(8)
                                                .shadow(radius: 2)
                                            }
                                    }
                                }
                                .frame(height: 250)
                                .chartXSelection(value: $selectedDate)
                                .padding(.vertical)
                            }
                        }.padding(.horizontal)
                        
                        Spacer(minLength: 50)
                    }.padding(.vertical)
                }
                .navigationTitle("Statistiken")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: selectedMetric) { fetchData() }
                .onAppear { fetchData() }
            }
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        let isInt = selectedMetric == .steps || selectedMetric == .calories || selectedMetric == .exercise
        return value.formattedWithPoints(isInteger: isInt)
    }
    
    private func getSelectedPoint() -> ChartDataPoint? {
        guard let selectedDate else { return nil }
        return chartData.first { isSamePeriod($0.date, selectedDate) }
    }
    
    private func isSamePeriod(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        switch timeRange {
        case .day: return calendar.isDate(date1, equalTo: date2, toGranularity: .hour)
        case .week, .month: return calendar.isDate(date1, equalTo: date2, toGranularity: .day)
        case .year: return calendar.isDate(date1, equalTo: date2, toGranularity: .month)
        }
    }
    
    private func getIntervalUnit() -> Calendar.Component {
        switch timeRange {
        case .day: return .hour
        case .week, .month: return .day
        case .year: return .month
        }
    }
    
    private func getMetricColor() -> Color {
        switch selectedMetric {
        case .steps: return AppleColors.steps
        case .calories: return AppleColors.move
        case .exercise: return AppleColors.exercise
        case .stand: return AppleColors.stand
        }
    }
    
    private func calculateTotal() -> String {
        let total = chartData.map { $0.value }.reduce(0, +)
        return "\(formatValue(total)) \(getUnitLabel())"
    }
    
    private func getUnitLabel() -> String {
        switch selectedMetric {
        case .steps: return "Schritte"
        case .calories: return "kcal"
        case .exercise: return "Min"
        case .stand: return "Std"
        }
    }
    
    private func getDateRangeTitle() -> String {
        let calendar = Calendar.current; let now = Date()
        switch timeRange {
        case .day: return calendar.date(byAdding: .day, value: dateOffset, to: now)!.formatted(date: .abbreviated, time: .omitted)
        case .week:
            let start = calendar.date(byAdding: .day, value: (dateOffset * 7) - 7, to: now)!
            let end = calendar.date(byAdding: .day, value: dateOffset * 7, to: now)!
            return "\(start.formatted(.dateTime.day().month())) - \(end.formatted(.dateTime.day().month()))"
        case .month: return calendar.date(byAdding: .month, value: dateOffset, to: now)!.formatted(.dateTime.month(.wide).year())
        case .year: return calendar.date(byAdding: .year, value: dateOffset, to: now)!.formatted(.dateTime.year())
        }
    }
    
    private func fetchData() {
        let typeIdentifier: HKQuantityTypeIdentifier; let unit: HKUnit
        switch selectedMetric {
        case .steps: typeIdentifier = .stepCount; unit = .count()
        case .calories: typeIdentifier = .activeEnergyBurned; unit = .kilocalorie()
        case .exercise: typeIdentifier = .appleExerciseTime; unit = .minute()
        case .stand: 
            fetchStandStatistics()
            return
        }
        
        let calendar = Calendar.current; let now = Date()
        var startDate: Date; var endDate: Date; let interval: DateComponents
        switch timeRange {
        case .day:
            let targetDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: dateOffset, to: now)!)
            startDate = targetDay; endDate = calendar.date(byAdding: .day, value: 1, to: targetDay)!; interval = DateComponents(hour: 1)
        case .week:
            let endOfWeek = calendar.date(byAdding: .day, value: dateOffset * 7, to: now)!
            startDate = calendar.date(byAdding: .day, value: -7, to: endOfWeek)!; endDate = endOfWeek; interval = DateComponents(day: 1)
        case .month:
            let targetMonth = calendar.date(byAdding: .month, value: dateOffset, to: now)!
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: targetMonth))!
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!; interval = DateComponents(day: 1)
        case .year:
            let targetYear = calendar.date(byAdding: .year, value: dateOffset, to: now)!
            startDate = calendar.date(from: calendar.dateComponents([.year], from: targetYear))!
            endDate = calendar.date(byAdding: .year, value: 1, to: startDate)!; interval = DateComponents(month: 1)
        }
        healthKitManager.fetchStatistics(for: typeIdentifier, startDate: startDate, endDate: endDate, interval: interval, unit: unit) { points in
            self.chartData = points
        }
    }
    
    private func fetchStandStatistics() {
        // Stand logic requires a sample query instead of a statistics query for precise hour counting
        // Placeholder for now to keep the code clean
        self.chartData = []
    }
}
