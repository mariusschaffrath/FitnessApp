import SwiftUI

// MARK: - Hero Ring Mode
public enum HeroRingMode: String, CaseIterable, Identifiable {
    case biometrics = "Bio-Balance"
    case activity = "Aktivität"
    
    public var id: String { rawValue }
}

// MARK: - Unified Hero Rings View
public struct ActivityHeroRingsView: View {
    let snapshot: BioMetricsSnapshot
    let calories: Double
    let calGoal: Double
    let exercise: Double
    let exGoal: Double
    let stand: Double
    let standGoal: Double
    var onOpenDetails: (() -> Void)? = nil
    
    @State private var selectedMode: HeroRingMode = .biometrics
    @State private var selectedRingIndex: Int = 0 // 0, 1, 2
    @Namespace private var animationNamespace
    
    public init(
        snapshot: BioMetricsSnapshot,
        calories: Double,
        calGoal: Double,
        exercise: Double,
        exGoal: Double,
        stand: Double,
        standGoal: Double,
        onOpenDetails: (() -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.calories = calories
        self.calGoal = max(1.0, calGoal)
        self.exercise = exercise
        self.exGoal = max(1.0, exGoal)
        self.stand = stand
        self.standGoal = max(1.0, standGoal)
        self.onOpenDetails = onOpenDetails
    }
    
    // Gradients for BioMetrics
    private var recoveryColors: [Color] {
        switch snapshot.recovery.status {
        case .optimal:
            return [Color(red: 0.0, green: 0.90, blue: 0.48), Color(red: 0.0, green: 0.72, blue: 0.38)]
        case .moderate:
            return [Color(red: 1.0, green: 0.82, blue: 0.05), Color(red: 1.0, green: 0.60, blue: 0.0)]
        case .low:
            return [Color(red: 1.0, green: 0.28, blue: 0.32), Color(red: 0.85, green: 0.12, blue: 0.20)]
        }
    }
    
    private var strainColors: [Color] {
        [Color(red: 1.0, green: 0.38, blue: 0.0), Color(red: 1.0, green: 0.62, blue: 0.0)]
    }
    
    private var sleepColors: [Color] {
        [Color(red: 0.0, green: 0.88, blue: 1.0), Color(red: 0.45, green: 0.35, blue: 1.0)]
    }
    
    // Gradients for Activity
    private var moveColors: [Color] {
        [AppleColors.move, Color(red: 1.0, green: 0.25, blue: 0.45)]
    }
    
    private var exerciseColors: [Color] {
        [AppleColors.exercise, Color(red: 0.45, green: 0.95, blue: 0.15)]
    }
    
    private var standColors: [Color] {
        [AppleColors.stand, Color(red: 0.0, green: 0.75, blue: 1.0)]
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // MARK: - Header & Mode Switcher Pill
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(selectedMode == .biometrics ? "Tagesform & Balance" : "Tagesaktivität")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                        
                        if selectedMode == .biometrics, let onOpenDetails = onOpenDetails {
                            Button(action: onOpenDetails) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Text(selectedMode == .biometrics ? "Autonomes Nervensystem & Schlaf" : "Bewegen, Trainieren & Stehen")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Mode Toggle Capsule
                HStack(spacing: 4) {
                    ForEach(HeroRingMode.allCases) { mode in
                        Button {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedMode = mode
                                selectedRingIndex = 0
                            }
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background {
                                    if selectedMode == mode {
                                        Capsule()
                                            .fill(AppleColors.ultraOrange.opacity(0.18))
                                            .matchedGeometryEffect(id: "mode_pill", in: animationNamespace)
                                    }
                                }
                                .foregroundColor(selectedMode == mode ? AppleColors.ultraOrange : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(3)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 4)
            
            // MARK: - Tri-Ring Display
            HStack(spacing: 10) {
                if selectedMode == .biometrics {
                    // Erholung Ring
                    HeroRingUnit(
                        title: "Erholung",
                        valueText: "\(Int(snapshot.recovery.score))%",
                        badgeText: snapshot.recovery.status.rawValue,
                        progress: snapshot.recovery.score / 100.0,
                        gradientColors: recoveryColors,
                        iconName: "heart.fill",
                        isSelected: selectedRingIndex == 0
                    ) {
                        selectRing(0)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Belastung Ring
                    HeroRingUnit(
                        title: "Belastung",
                        valueText: String(format: "%.1f", snapshot.strain.strainScale),
                        badgeText: "\(Int(snapshot.strain.percentage))%",
                        progress: snapshot.strain.percentage / 100.0,
                        gradientColors: strainColors,
                        iconName: "flame.fill",
                        isSelected: selectedRingIndex == 1
                    ) {
                        selectRing(1)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Schlaf Ring
                    HeroRingUnit(
                        title: "Schlaf",
                        valueText: String(format: "%.1fh", snapshot.sleep.totalSleepHours),
                        badgeText: "\(Int(snapshot.sleep.score))%",
                        progress: snapshot.sleep.score / 100.0,
                        gradientColors: sleepColors,
                        iconName: "moon.stars.fill",
                        isSelected: selectedRingIndex == 2
                    ) {
                        selectRing(2)
                    }
                } else {
                    // Bewegen Ring
                    HeroRingUnit(
                        title: "Bewegen",
                        valueText: "\(Int(calories))",
                        badgeText: "/ \(Int(calGoal)) kcal",
                        progress: calories / calGoal,
                        gradientColors: moveColors,
                        iconName: "flame.fill",
                        isSelected: selectedRingIndex == 0
                    ) {
                        selectRing(0)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Trainieren Ring
                    HeroRingUnit(
                        title: "Trainieren",
                        valueText: "\(Int(exercise))",
                        badgeText: "/ \(Int(exGoal)) Min",
                        progress: exercise / exGoal,
                        gradientColors: exerciseColors,
                        iconName: "timer",
                        isSelected: selectedRingIndex == 1
                    ) {
                        selectRing(1)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Stehen Ring
                    HeroRingUnit(
                        title: "Stehen",
                        valueText: "\(Int(stand))",
                        badgeText: "/ \(Int(standGoal)) Std",
                        progress: stand / standGoal,
                        gradientColors: standColors,
                        iconName: "figure.stand",
                        isSelected: selectedRingIndex == 2
                    ) {
                        selectRing(2)
                    }
                }
            }
            .padding(.vertical, 4)
            
            // MARK: - Contextual Quick Insight Bar
            HStack(spacing: 8) {
                if selectedMode == .biometrics {
                    biometricInsightBar
                } else {
                    activityInsightBar
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
        .padding(18)
        .glassCardStyle()
    }
    
    private func selectRing(_ index: Int) {
        HapticManager.shared.impact(style: .light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedRingIndex = index
        }
    }
    
    // MARK: - Sub-Bars
    @ViewBuilder
    private var biometricInsightBar: some View {
        switch selectedRingIndex {
        case 0:
            Image(systemName: "waveform.path.ecg")
                .foregroundColor(recoveryColors.first)
                .font(.system(size: 13, weight: .bold))
            Text("HRV: \(Int(snapshot.recovery.hrvMs)) ms • Ruhepuls: \(Int(snapshot.recovery.rhrBpm)) bpm")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            Text(snapshot.recovery.status == .optimal ? "Hohe Bereitschaft" : "Aktive Erholung")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(recoveryColors.first)
        case 1:
            Image(systemName: "bolt.fill")
                .foregroundColor(strainColors.first)
                .font(.system(size: 13, weight: .bold))
            Text("TRIMP: \(Int(snapshot.strain.trimp)) • Aktiv: \(Int(snapshot.strain.activeCalories)) kcal")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            Text("Ziel: 10–14")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(strainColors.first)
        default:
            Image(systemName: "bed.double.fill")
                .foregroundColor(sleepColors.first)
                .font(.system(size: 13, weight: .bold))
            Text("Effizienz: \(Int(snapshot.sleep.efficiency))% • Tief: \(Int(snapshot.sleep.breakdown.deepMinutes))m")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            Text(String(format: "Ziel: %.0fh", snapshot.sleep.targetSleepHours))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(sleepColors.first)
        }
    }
    
    @ViewBuilder
    private var activityInsightBar: some View {
        let calPct = min(1.0, calories / calGoal)
        let exPct = min(1.0, exercise / exGoal)
        let standPct = min(1.0, stand / standGoal)
        let closedCount = (calPct >= 1.0 ? 1 : 0) + (exPct >= 1.0 ? 1 : 0) + (standPct >= 1.0 ? 1 : 0)
        
        Image(systemName: closedCount == 3 ? "checkmark.seal.fill" : "chart.bar.fill")
            .foregroundColor(closedCount == 3 ? .green : AppleColors.ultraOrange)
            .font(.system(size: 13, weight: .bold))
        
        Text("\(closedCount) von 3 Ringen geschlossen")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
        
        Spacer()
        
        let remainingCal = max(0, calGoal - calories)
        if remainingCal > 0 {
            Text("Noch \(Int(remainingCal)) kcal")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(AppleColors.move)
        } else {
            Text("Bewegungsziel erreicht! 🎉")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.green)
        }
    }
}

// MARK: - Hero Ring Single Unit
public struct HeroRingUnit: View {
    let title: String
    let valueText: String
    let badgeText: String
    let progress: Double
    let gradientColors: [Color]
    let iconName: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var animatedProgress: Double = 0.0
    
    public var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Ring Graphic
                ZStack {
                    // Track
                    Circle()
                        .stroke(
                            (gradientColors.first ?? .gray).opacity(0.12),
                            lineWidth: 11
                        )
                    
                    // Progress Stroke
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(max(0.0, animatedProgress), 1.0)))
                        .stroke(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 11, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(
                            color: (gradientColors.first ?? .clear).opacity(0.35),
                            radius: 5,
                            x: 0,
                            y: 0
                        )
                    
                    // Center Content
                    VStack(spacing: 1) {
                        Image(systemName: iconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(gradientColors.first)
                        
                        Text(valueText)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                }
                .frame(width: 88, height: 88)
                
                // Labels
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(badgeText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(gradientColors.first)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((gradientColors.first ?? .gray).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill((gradientColors.first ?? .clear).opacity(0.08))
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke((gradientColors.first ?? .clear).opacity(0.3), lineWidth: 1.0)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 45, damping: 12).delay(0.05)) {
                let valid = (progress.isFinite && !progress.isNaN) ? progress : 0.0
                animatedProgress = valid
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                let valid = (newValue.isFinite && !newValue.isNaN) ? newValue : 0.0
                animatedProgress = valid
            }
        }
    }
}

#Preview {
    ZStack {
        BackgroundView()
        ActivityHeroRingsView(
            snapshot: .mock,
            calories: 480,
            calGoal: 600,
            exercise: 32,
            exGoal: 30,
            stand: 10,
            standGoal: 12
        )
        .padding()
    }
}
