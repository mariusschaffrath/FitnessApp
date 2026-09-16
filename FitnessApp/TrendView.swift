import SwiftUI
import Charts
import SwiftData

/// Dedicated Trend Analysis view displaying 7-day vs 30-day averages,
/// HRV indicators (Rising ↗️, Stable ➡️, Falling ↘️), and historical charts.
public struct TrendView: View {
    @EnvironmentObject var persistenceManager: PersistenceManager
    
    @State private var selectedDays: Int = 30
    @State private var snapshots: [BioMetricsSnapshotEntity] = []
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - 1. Time Range Selector
                Picker("Zeitraum", selection: $selectedDays) {
                    Text("7 Tage").tag(7)
                    Text("30 Tage").tag(30)
                    Text("90 Tage").tag(90)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedDays) { loadSnapshots() }
                
                // MARK: - 2. Trend Indicator Cards Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trend-Analysen (7 Tage vs. 30 Tage)")
                        .font(.headline)
                        .bold()
                        .padding(.horizontal, 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            TrendCardView(card: hrvTrendCard)
                            TrendCardView(card: recoveryTrendCard)
                            TrendCardView(card: strainTrendCard)
                            TrendCardView(card: rhrTrendCard)
                            TrendCardView(card: sleepTrendCard)
                        }
                    }
                }
                .padding(.horizontal)
                
                // MARK: - 3. HRV & Ruhepuls Historical Chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.purple)
                        Text("HRV & Ruhepuls Verlauf")
                            .font(.headline)
                    }
                    
                    if snapshots.isEmpty {
                        Text("Keine Trenddaten vorhanden.")
                            .foregroundColor(.secondary)
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                    } else {
                        Chart {
                            ForEach(snapshots) { snap in
                                LineMark(
                                    x: .value("Datum", snap.date, unit: .day),
                                    y: .value("HRV (ms)", snap.hrvValue),
                                    series: .value("Metrik", "HRV")
                                )
                                .foregroundStyle(Color.purple)
                                .interpolationMethod(.catmullRom)
                                
                                PointMark(
                                    x: .value("Datum", snap.date, unit: .day),
                                    y: .value("HRV (ms)", snap.hrvValue)
                                )
                                .foregroundStyle(Color.purple)
                                
                                LineMark(
                                    x: .value("Datum", snap.date, unit: .day),
                                    y: .value("RHR (bpm)", snap.rhrValue),
                                    series: .value("Metrik", "Ruhepuls")
                                )
                                .foregroundStyle(Color.red)
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        .frame(height: 220)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        
                        HStack(spacing: 16) {
                            Label("HRV (ms)", systemImage: "circle.fill")
                                .font(.caption)
                                .foregroundColor(.purple)
                            Label("Ruhepuls (bpm)", systemImage: "circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .glassCardStyle()
                .padding(.horizontal)
                
                // MARK: - 4. Recovery & Strain Combined Chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bolt.heart.fill")
                            .foregroundColor(.green)
                        Text("Erholung (%) vs. Belastung (Strain)")
                            .font(.headline)
                    }
                    
                    if snapshots.isEmpty {
                        Text("Keine Verlaufsdaten vorhanden.")
                            .foregroundColor(.secondary)
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                    } else {
                        Chart {
                            ForEach(snapshots) { snap in
                                LineMark(
                                    x: .value("Datum", snap.date, unit: .day),
                                    y: .value("Erholung (%)", snap.recoveryScore),
                                    series: .value("Metrik", "Erholung")
                                )
                                .foregroundStyle(Color.green)
                                .interpolationMethod(.catmullRom)
                                
                                BarMark(
                                    x: .value("Datum", snap.date, unit: .day),
                                    y: .value("Strain (x4.76)", snap.strainScore * 4.76) // Scaled to 0-100 for visual comparison
                                )
                                .foregroundStyle(Color.orange.opacity(0.4))
                            }
                        }
                        .frame(height: 220)
                        
                        HStack(spacing: 16) {
                            Label("Erholung (%)", systemImage: "line.diagonal")
                                .font(.caption)
                                .foregroundColor(.green)
                            Label("Belastung (Strain 0-21)", systemImage: "square.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .glassCardStyle()
                .padding(.horizontal)
                
                Spacer(minLength: 30)
            }
            .padding(.vertical)
        }
        .onAppear {
            loadSnapshots()
        }
    }
    
    private func loadSnapshots() {
        self.snapshots = persistenceManager.fetchSnapshots(days: selectedDays)
    }
    
    // MARK: - Calculated Trend Cards Data (7d vs 30d)
    private var snapshots7d: [BioMetricsSnapshotEntity] {
        persistenceManager.fetchSnapshots(days: 7)
    }
    
    private var snapshots30d: [BioMetricsSnapshotEntity] {
        persistenceManager.fetchSnapshots(days: 30)
    }
    
    private var hrvTrendCard: TrendCardData {
        let avg7 = snapshots7d.isEmpty ? 0 : snapshots7d.reduce(0.0) { $0 + $1.hrvValue } / Double(snapshots7d.count)
        let avg30 = snapshots30d.isEmpty ? 0 : snapshots30d.reduce(0.0) { $0 + $1.hrvValue } / Double(snapshots30d.count)
        return TrendCardData(
            title: "HRV Trend",
            currentAvg: avg7,
            baselineAvg: avg30,
            unit: "ms",
            symbol: "waveform.path.ecg",
            isLowerBetter: false
        )
    }
    
    private var recoveryTrendCard: TrendCardData {
        let avg7 = snapshots7d.isEmpty ? 0 : snapshots7d.reduce(0.0) { $0 + $1.recoveryScore } / Double(snapshots7d.count)
        let avg30 = snapshots30d.isEmpty ? 0 : snapshots30d.reduce(0.0) { $0 + $1.recoveryScore } / Double(snapshots30d.count)
        return TrendCardData(
            title: "Erholung",
            currentAvg: avg7,
            baselineAvg: avg30,
            unit: "%",
            symbol: "leaf.fill",
            isLowerBetter: false
        )
    }
    
    private var strainTrendCard: TrendCardData {
        let avg7 = snapshots7d.isEmpty ? 0 : snapshots7d.reduce(0.0) { $0 + $1.strainScore } / Double(snapshots7d.count)
        let avg30 = snapshots30d.isEmpty ? 0 : snapshots30d.reduce(0.0) { $0 + $1.strainScore } / Double(snapshots30d.count)
        return TrendCardData(
            title: "Belastung",
            currentAvg: avg7,
            baselineAvg: avg30,
            unit: "pts",
            symbol: "flame.fill",
            isLowerBetter: false
        )
    }
    
    private var rhrTrendCard: TrendCardData {
        let avg7 = snapshots7d.isEmpty ? 0 : snapshots7d.reduce(0.0) { $0 + $1.rhrValue } / Double(snapshots7d.count)
        let avg30 = snapshots30d.isEmpty ? 0 : snapshots30d.reduce(0.0) { $0 + $1.rhrValue } / Double(snapshots30d.count)
        return TrendCardData(
            title: "Ruhepuls",
            currentAvg: avg7,
            baselineAvg: avg30,
            unit: "bpm",
            symbol: "heart.fill",
            isLowerBetter: true
        )
    }
    
    private var sleepTrendCard: TrendCardData {
        let avg7 = snapshots7d.isEmpty ? 0 : snapshots7d.reduce(0.0) { $0 + $1.sleepScore } / Double(snapshots7d.count)
        let avg30 = snapshots30d.isEmpty ? 0 : snapshots30d.reduce(0.0) { $0 + $1.sleepScore } / Double(snapshots30d.count)
        return TrendCardData(
            title: "Schlaf-Score",
            currentAvg: avg7,
            baselineAvg: avg30,
            unit: "%",
            symbol: "moon.stars.fill",
            isLowerBetter: false
        )
    }
}

// MARK: - Trend Card Data & Subview
public struct TrendCardData: Identifiable {
    public let id = UUID()
    public let title: String
    public let currentAvg: Double
    public let baselineAvg: Double
    public let unit: String
    public let symbol: String
    public let isLowerBetter: Bool
    
    public var pctChange: Double {
        guard baselineAvg > 0 else { return 0 }
        return ((currentAvg - baselineAvg) / baselineAvg) * 100.0
    }
    
    public var directionIcon: String {
        if abs(pctChange) < 2.0 { return "arrow.right" }
        if isLowerBetter {
            return pctChange < 0 ? "arrow.down.forward" : "arrow.up.forward"
        } else {
            return pctChange > 0 ? "arrow.up.forward" : "arrow.down.forward"
        }
    }
    
    public var directionText: String {
        if abs(pctChange) < 2.0 { return "Stabil ➡️" }
        if isLowerBetter {
            return pctChange < 0 ? "Verbessert ↗️" : "Erhöht ↘️"
        } else {
            return pctChange > 0 ? "Steigend ↗️" : "Fallend ↘️"
        }
    }
    
    public var statusColor: Color {
        if abs(pctChange) < 2.0 { return .blue }
        if isLowerBetter {
            return pctChange < 0 ? .green : .red
        } else {
            return pctChange > 0 ? .green : .orange
        }
    }
}

public struct TrendCardView: View {
    public let card: TrendCardData
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: card.symbol)
                    .foregroundColor(card.statusColor)
                Text(card.title)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", card.currentAvg))
                    .font(.title2)
                    .bold()
                Text(card.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: card.directionIcon)
                Text(card.directionText)
                    .font(.caption2)
                    .bold()
            }
            .foregroundColor(card.statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(card.statusColor.opacity(0.15))
            .cornerRadius(6)
            
            Text("30d Avg: \(String(format: "%.1f", card.baselineAvg)) \(card.unit)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 145)
        .glassCardStyle()
    }
}
