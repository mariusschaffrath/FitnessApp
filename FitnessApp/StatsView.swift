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
    @State private var chartDataCache: [String: [ChartDataPoint]] = [:]
    
    // Berechnete Werte für die Zusammenfassung
    private var totalValue: Double { chartData.reduce(0) { $0 + $1.value } }
    private var averageValue: Double { chartData.isEmpty ? 0 : totalValue / Double(chartData.count) }
    private var maxValue: Double { chartData.map { $0.value }.max() ?? 0 }
    
    var body: some View {
        NavigationView {
            ZStack {
                BackgroundView()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        // 1. Selector Section
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
                        
                        // 2. Navigation Section
                        HStack {
                            Button(action: { withAnimation { dateOffset -= 1; fetchData() } }) {
                                Image(systemName: "chevron.left.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                            }
                            Spacer()
                            VStack(spacing: 4) {
                                Text(getDateRangeTitle()).font(.headline).bold()
                                if dateOffset != 0 {
                                    Button("Heute") { withAnimation { dateOffset = 0; fetchData() } }
                                        .font(.caption2).foregroundColor(AppleColors.ultraOrange)
                                }
                            }
                            Spacer()
                            Button(action: { withAnimation { dateOffset += 1; fetchData() } }) {
                                Image(systemName: "chevron.right.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                            }.disabled(dateOffset >= 0)
                        }.padding(.horizontal, 30)
                        
                        // 3. Main Chart Card
                        GlassCard {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack(alignment: .lastTextBaseline) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Gesamt").font(.caption).bold().foregroundColor(.secondary).textCase(.uppercase)
                                        Text("\(Text(formatValue(totalValue)).font(.system(size: 32, weight: .bold, design: .rounded))) \(Text(getUnitLabel()).font(.headline).foregroundColor(.secondary))")
                                    }
                                    Spacer()
                                    if let _ = selectedDate, let point = getSelectedPoint() {
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(formatSelectedDate(point.date)).font(.caption).foregroundColor(.secondary)
                                            Text(formatValue(point.value)).font(.headline).foregroundColor(getMetricColor())
                                        }.transition(.opacity.combined(with: .move(edge: .trailing)))
                                    }
                                }
                                
                                MainChart
                                    .frame(height: 220)
                                    .padding(.top, 10)
                            }
                        }.padding(.horizontal)
                        
                        // 4. Insights Section
                        HStack(spacing: 15) {
                            InsightBox(title: "Durchschnitt", value: formatValue(averageValue), unit: getUnitLabel(), color: .blue)
                            InsightBox(title: "Bestwert", value: formatValue(maxValue), unit: getUnitLabel(), color: .orange)
                        }.padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }.padding(.vertical)
                }
                .navigationTitle("Trends")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: selectedMetric) { fetchData() }
                .onAppear { fetchData() }
            }
        }
    }
    
    var MainChart: some View {
        Chart {
            ForEach(chartData) { point in
                BarMark(
                    x: .value("Datum", point.date, unit: getIntervalUnit()),
                    y: .value("Wert", point.value)
                )
                .foregroundStyle(getMetricColor().gradient)
                .cornerRadius(6)
                .opacity(selectedDate == nil || isSamePeriod(point.date, selectedDate!) ? 1.0 : 0.3)
            }
            
            if !chartData.isEmpty {
                RuleMark(y: .value("Durchschnitt", averageValue))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Ø \(formatValue(averageValue))")
                            .font(.caption2).bold()
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                    }
            }
            
            if let selectedDate {
                RuleMark(x: .value("Auswahl", selectedDate, unit: getIntervalUnit()))
                    .foregroundStyle(.primary.opacity(0.1))
                    .zIndex(-1)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
                AxisValueLabel().font(.caption2)
            }
        }
        .chartXAxis {
            switch timeRange {
            case .day:
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.hour())
                }
            case .week:
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.weekday(.short))
                }
            case .month:
                AxisMarks(values: .stride(by: .day, count: 4)) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.day())
                }
            case .year:
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSelectedPoint() -> ChartDataPoint? {
        guard let selectedDate else { return nil }
        return chartData.first { isSamePeriod($0.date, selectedDate) }
    }
    
    private func formatSelectedDate(_ date: Date) -> String {
        switch timeRange {
        case .day:
            return date.formatted(date: .omitted, time: .shortened)
        case .year:
            return date.formatted(.dateTime.month(.wide).year())
        default:
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        let isInt = selectedMetric == .steps || selectedMetric == .calories || selectedMetric == .exercise
        return value.formattedWithPoints(isInteger: isInt)
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
    
    private func getDateFormat() -> Date.FormatStyle {
        switch timeRange {
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day()
        case .year: return .dateTime.month(.narrow)
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
        case .day:
            let targetDate = calendar.date(byAdding: .day, value: dateOffset, to: now)!
            return targetDate.formatted(date: .abbreviated, time: .omitted)
        case .week:
            let targetDate = calendar.date(byAdding: .weekOfYear, value: dateOffset, to: now)!
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else { return "" }
            let start = interval.start
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end)!
            return "\(start.formatted(.dateTime.day().month())) - \(end.formatted(.dateTime.day().month()))"
        case .month:
            let targetDate = calendar.date(byAdding: .month, value: dateOffset, to: now)!
            return targetDate.formatted(.dateTime.month(.wide).year())
        case .year:
            let targetDate = calendar.date(byAdding: .year, value: dateOffset, to: now)!
            return targetDate.formatted(.dateTime.year())
        }
    }
    
    private func fetchData(force: Bool = false) {
        let cacheKey = "\(selectedMetric.rawValue)_\(timeRange.rawValue)_\(dateOffset)"
        
        // Schneller Cache-Hit: Sofort ohne HealthKit-Latenz und ohne Akkuverbrauch anzeigen
        if !force, let cached = chartDataCache[cacheKey] {
            self.chartData = cached
            return
        }
        
        let calendar = Calendar.current; let now = Date()
        var startDate: Date; var endDate: Date; let interval: DateComponents
        
        switch timeRange {
        case .day:
            let targetDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: dateOffset, to: now)!)
            startDate = targetDay; endDate = calendar.date(byAdding: .day, value: 1, to: targetDay)!; interval = DateComponents(hour: 1)
        case .week:
            let targetDate = calendar.date(byAdding: .weekOfYear, value: dateOffset, to: now)!
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: targetDate)!.start
            startDate = startOfWeek
            endDate = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            interval = DateComponents(day: 1)
        case .month:
            let targetMonth = calendar.date(byAdding: .month, value: dateOffset, to: now)!
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: targetMonth))!
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!; interval = DateComponents(day: 1)
        case .year:
            let targetYear = calendar.date(byAdding: .year, value: dateOffset, to: now)!
            startDate = calendar.date(from: calendar.dateComponents([.year], from: targetYear))!
            endDate = calendar.date(byAdding: .year, value: 1, to: startDate)!; interval = DateComponents(month: 1)
        }
        
        // Clear old data to avoid visual glitches
        self.chartData = []

        if selectedMetric == .stand {
            healthKitManager.fetchStandStatistics(startDate: startDate, endDate: endDate) { points in
                self.chartDataCache[cacheKey] = points
                withAnimation { self.chartData = points }
            }
            return
        }
        
        let typeIdentifier: HKQuantityTypeIdentifier; let unit: HKUnit
        switch selectedMetric {
        case .steps: typeIdentifier = .stepCount; unit = .count()
        case .calories: typeIdentifier = .activeEnergyBurned; unit = .kilocalorie()
        case .exercise: typeIdentifier = .appleExerciseTime; unit = .minute()
        case .stand: return
        }
        
        healthKitManager.fetchStatistics(for: typeIdentifier, startDate: startDate, endDate: endDate, interval: interval, unit: unit) { points in
            self.chartDataCache[cacheKey] = points
            withAnimation { self.chartData = points }
        }
    }
}

struct InsightBox: View {
    let title: String; let value: String; let unit: String; let color: Color
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.caption).bold().foregroundColor(.secondary).textCase(.uppercase)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(.system(.title3, design: .rounded)).bold()
                    Text(unit).font(.caption).foregroundColor(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
