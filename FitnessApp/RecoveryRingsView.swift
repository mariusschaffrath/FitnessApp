import SwiftUI

// MARK: - Premium Glassmorphic Card Style

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.75))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: colorScheme == .dark ?
                            [Color.white.opacity(0.18), Color.white.opacity(0.03)] :
                            [Color.black.opacity(0.12), Color.black.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 15, x: 0, y: 8)
    }
}

extension View {
    func glassCardStyle() -> some View {
        self.modifier(GlassCardModifier())
    }
}

// MARK: - Single Biometric Ring Component

struct BiometricRing: View {
    let title: String
    let valueText: String
    let subtitleText: String
    let progress: Double // 0.0 to 1.0
    let gradientColors: [Color]
    let iconName: String
    var isSelected: Bool = false
    
    @State var animatedProgress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background Track Ring
                Circle()
                    .stroke(gradientColors.first?.opacity(0.15) ?? Color.gray.opacity(0.15), lineWidth: 13)
                
                // Animated Gradient Ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(animatedProgress, 1.0)))
                    .stroke(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: (gradientColors.first ?? .clear).opacity(0.4), radius: 6, x: 0, y: 0)
                
                // Center Icon and Main Value
                VStack(spacing: 2) {
                    Image(systemName: iconName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(gradientColors.first)
                    
                    Text(valueText)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(width: 95, height: 95)
            
            // Labels
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitleText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(gradientColors.first)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((gradientColors.first ?? .gray).opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isSelected ? (gradientColors.first?.opacity(0.12) ?? Color.clear) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? (gradientColors.first?.opacity(0.4) ?? Color.clear) : Color.clear, lineWidth: 1.5)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Recovery Rings Hero Container & Detail Panels

public struct RecoveryRingsView: View {
    let snapshot: BioMetricsSnapshot
    
    public init(snapshot: BioMetricsSnapshot) {
        self.snapshot = snapshot
    }
    
    @State private var selectedTab: RingDetailTab = .overview
    
    enum RingDetailTab: String, CaseIterable, Identifiable {
        case overview = "Übersicht"
        case recovery = "Erholung"
        case strain = "Belastung"
        case sleep = "Schlaf"
        
        var id: String { rawValue }
    }
    
    // Gradient definitions
    var recoveryGradients: [Color] {
        switch snapshot.recovery.status {
        case .optimal:
            return [Color(red: 0.0, green: 0.9, blue: 0.45), Color(red: 0.0, green: 0.7, blue: 0.35)]
        case .moderate:
            return [Color(red: 1.0, green: 0.82, blue: 0.0), Color(red: 1.0, green: 0.60, blue: 0.0)]
        case .low:
            return [Color(red: 1.0, green: 0.25, blue: 0.30), Color(red: 0.85, green: 0.1, blue: 0.2)]
        }
    }
    
    var strainGradients: [Color] {
        [Color(red: 1.0, green: 0.37, blue: 0.0), Color(red: 1.0, green: 0.62, blue: 0.0)] // Whoop Orange/Red
    }
    
    var sleepGradients: [Color] {
        [Color(red: 0.0, green: 0.9, blue: 1.0), Color(red: 0.48, green: 0.3, blue: 1.0)] // Electric Cyan / Indigo
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // MARK: Hero Rings Section
            VStack(spacing: 16) {
                HStack {
                    Text("BioMetrics & Balance")
                        .font(.title3)
                        .bold()
                    Spacer()
                    Text(snapshot.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                
                // Ring Selector Row
                HStack(spacing: 8) {
                    // Erholung (Recovery) Ring
                    Button {
                        withAnimation { selectedTab = .recovery }
                    } label: {
                        BiometricRing(
                            title: "Erholung",
                            valueText: "\(Int(snapshot.recovery.score))%",
                            subtitleText: snapshot.recovery.status.rawValue,
                            progress: snapshot.recovery.score / 100.0,
                            gradientColors: recoveryGradients,
                            iconName: "heart.fill",
                            isSelected: selectedTab == .recovery
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer(minLength: 0)
                    
                    // Belastung (Strain) Ring
                    Button {
                        withAnimation { selectedTab = .strain }
                    } label: {
                        BiometricRing(
                            title: "Belastung",
                            valueText: String(format: "%.1f", snapshot.strain.strainScale),
                            subtitleText: "\(Int(snapshot.strain.percentage))%",
                            progress: snapshot.strain.percentage / 100.0,
                            gradientColors: strainGradients,
                            iconName: "flame.fill",
                            isSelected: selectedTab == .strain
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer(minLength: 0)
                    
                    // Schlaf (Sleep) Ring
                    Button {
                        withAnimation { selectedTab = .sleep }
                    } label: {
                        BiometricRing(
                            title: "Schlaf",
                            valueText: "\(Int(snapshot.sleep.score))%",
                            subtitleText: String(format: "%.1fh", snapshot.sleep.totalSleepHours),
                            progress: snapshot.sleep.score / 100.0,
                            gradientColors: sleepGradients,
                            iconName: "moon.stars.fill",
                            isSelected: selectedTab == .sleep
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(18)
            .glassCardStyle()
            
            // MARK: Interactive Segment Switcher
            Picker("Detail", selection: $selectedTab) {
                ForEach(RingDetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // MARK: Dynamic Detail Cards
            switch selectedTab {
            case .overview:
                overviewCard
            case .recovery:
                recoveryDetailCard
            case .strain:
                strainDetailCard
            case .sleep:
                sleepDetailCard
            }
        }
    }
    
    // MARK: - Subview Cards
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Physiologischer Tagesüberblick")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    metricBadge(icon: "waveform.path.ecg", title: "HRV (SDNN)", value: String(format: "%.0f ms", snapshot.recovery.hrvMs), color: .green)
                    metricBadge(icon: "heart.square.fill", title: "Ruhepuls", value: String(format: "%.0f bpm", snapshot.recovery.rhrBpm), color: .red)
                }
                GridRow {
                    metricBadge(icon: "bolt.horizontal.fill", title: "TRIMP Impulse", value: String(format: "%.0f", snapshot.strain.trimp), color: .orange)
                    metricBadge(icon: "bed.double.fill", title: "Schlafdauer", value: String(format: "%.1fh / %.0fh", snapshot.sleep.totalSleepHours, snapshot.sleep.targetSleepHours), color: .cyan)
                }
            }
        }
        .padding(18)
        .glassCardStyle()
    }
    
    private var recoveryDetailCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Erholungs-Analyse", systemImage: "heart.text.square.fill")
                    .font(.headline)
                    .foregroundColor(recoveryGradients.first)
                Spacer()
                Text("Score: \(Int(snapshot.recovery.score))%")
                    .bold()
            }
            
            Divider()
            
            // HRV Comparison
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Herzfrequenzvariabilität (HRV)")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "%.0f ms", snapshot.recovery.hrvMs))
                        .bold()
                }
                Text(String(format: "7-Tage-Baseline: %.0f ms (Z-Score: %+.2f SD)", snapshot.recovery.hrvBaselineMean, snapshot.recovery.hrvZScore))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: max(0.0, min(1.0, 0.5 + (snapshot.recovery.hrvZScore * 0.25))))
                    .tint(snapshot.recovery.hrvZScore >= 0 ? .green : .orange)
            }
            
            // RHR Comparison
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Ruhepuls (RHR)")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "%.0f bpm", snapshot.recovery.rhrBpm))
                        .bold()
                }
                Text(String(format: "7-Tage-Baseline: %.0f bpm (Z-Score: %+.2f SD)", snapshot.recovery.rhrBaselineMean, snapshot.recovery.rhrZScore))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: max(0.0, min(1.0, 0.5 - (snapshot.recovery.rhrZScore * 0.25))))
                    .tint(snapshot.recovery.rhrZScore <= 0 ? .green : .red)
            }
            
            Text("Studiengrundlage: Plews et al. (2013), Stanley et al. (2013). HRV- und Ruhepuls-Abweichungen von der 7-Tage-Baseline sind der Goldstandard für autonomic Readiness.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(18)
        .glassCardStyle()
    }
    
    private var strainDetailCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Belastungs-Analyse", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
                Text(String(format: "Strain: %.1f / 21.0", snapshot.strain.strainScale))
                    .bold()
            }
            
            Divider()
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Banister TRIMP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f", snapshot.strain.trimp))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Aktivkalorien")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f kcal", snapshot.strain.activeCalories))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Ø Herzfrequenz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f bpm", snapshot.strain.averageHR))
                        .font(.title3)
                        .bold()
                }
            }
            
            // HR Zones Breakdown Bar Chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Herzfrequenz-Zonen (Lucía et al. 2003)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(snapshot.strain.zoneBreakdown) { zb in
                            let width = zb.percentage > 0 ? (geo.size.width * (zb.percentage / 100.0)) - 2 : 0
                            Rectangle()
                                .fill(zb.zone.color)
                                .frame(width: max(0, width), height: 16)
                                .cornerRadius(3)
                        }
                    }
                }
                .frame(height: 16)
                
                // Legend
                HStack {
                    ForEach(snapshot.strain.zoneBreakdown) { zb in
                        HStack(spacing: 3) {
                            Circle().fill(zb.zone.color).frame(width: 8, height: 8)
                            Text("\(zb.zone.name): \(Int(zb.minutes))m")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassCardStyle()
    }
    
    private var sleepDetailCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Schlafarchitektur (NSF)", systemImage: "moon.stars.fill")
                    .font(.headline)
                    .foregroundColor(.cyan)
                Spacer()
                Text("Score: \(Int(snapshot.sleep.score))%")
                    .bold()
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Gesamtschlaf")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fh / %.0fh", snapshot.sleep.totalSleepHours, snapshot.sleep.targetSleepHours))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Effizienz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", snapshot.sleep.efficiency))
                        .font(.title3)
                        .bold()
                }
            }
            
            // Sleep Stage Proportions
            VStack(alignment: .leading, spacing: 8) {
                Text("Schlafphasen-Verteilung")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                let b = snapshot.sleep.breakdown
                VStack(spacing: 8) {
                    stageRow(name: "Tiefschlaf (Deep)", minutes: b.deepMinutes, pct: b.deepPercentage, color: .indigo, target: "15–25%")
                    stageRow(name: "REM-Schlaf", minutes: b.remMinutes, pct: b.remPercentage, color: .purple, target: "20–25%")
                    stageRow(name: "Leichtschlaf (Core)", minutes: b.coreMinutes, pct: b.corePercentage, color: .cyan, target: "50–60%")
                    stageRow(name: "Wachzeiten", minutes: b.awakeMinutes, pct: (b.awakeMinutes / max(1, b.totalInBedMinutes)) * 100.0, color: .gray, target: "< 10%")
                }
            }
        }
        .padding(18)
        .glassCardStyle()
    }
    
    // MARK: - Helper Views
    
    private func metricBadge(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func stageRow(name: String, minutes: Double, pct: Double, color: Color, target: String) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(name)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.0f min (%.1f%%)", minutes, pct))
                    .font(.caption)
                    .bold()
                Text("[\(target)]")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            ProgressView(value: max(0.0, min(1.0, pct / 100.0)))
                .tint(color)
        }
    }
}
