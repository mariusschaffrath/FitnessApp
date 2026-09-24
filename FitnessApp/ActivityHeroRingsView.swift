import SwiftUI

// MARK: - Selected Ring Enum
public enum SelectedActivityRing: Int, CaseIterable, Identifiable {
    case move = 0
    case exercise = 1
    case stand = 2
    
    public var id: Int { rawValue }
}

// MARK: - Dedicated Activity Hero Rings View
public struct ActivityHeroRingsView: View {
    let calories: Double
    let calGoal: Double
    let exercise: Double
    let exGoal: Double
    let stand: Double
    let standGoal: Double
    var onOpenGoals: (() -> Void)? = nil
    
    @State private var selectedRing: SelectedActivityRing = .move
    
    public init(
        calories: Double,
        calGoal: Double,
        exercise: Double,
        exGoal: Double,
        stand: Double,
        standGoal: Double,
        onOpenGoals: (() -> Void)? = nil
    ) {
        self.calories = calories
        self.calGoal = max(1.0, calGoal)
        self.exercise = exercise
        self.exGoal = max(1.0, exGoal)
        self.stand = stand
        self.standGoal = max(1.0, standGoal)
        self.onOpenGoals = onOpenGoals
    }
    
    // Gradients for Activity Rings
    private var moveColors: [Color] {
        [AppleColors.move, Color(red: 1.0, green: 0.25, blue: 0.45)]
    }
    
    private var exerciseColors: [Color] {
        [AppleColors.exercise, Color(red: 0.45, green: 0.95, blue: 0.15)]
    }
    
    private var standColors: [Color] {
        [AppleColors.stand, Color(red: 0.0, green: 0.75, blue: 1.0)]
    }
    
    private var closedRingsCount: Int {
        var count = 0
        if calories >= calGoal { count += 1 }
        if exercise >= exGoal { count += 1 }
        if stand >= standGoal { count += 1 }
        return count
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // MARK: - Header & Badge
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Aktivitätsringe")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                        
                        if let onOpenGoals = onOpenGoals {
                            Button(action: onOpenGoals) {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppleColors.ultraOrange)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Text("Bewegen, Trainieren & Stehen")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Ring Completion Badge
                HStack(spacing: 5) {
                    Image(systemName: closedRingsCount == 3 ? "checkmark.seal.fill" : "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(closedRingsCount == 3 ? .green : AppleColors.ultraOrange)
                    
                    Text(closedRingsCount == 3 ? "Alle geschlossen!" : "\(closedRingsCount) von 3 Ringen")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 4)
            
            // MARK: - Tri-Ring Display
            HStack(spacing: 10) {
                // Bewegen (Kalorien)
                HeroRingUnit(
                    title: "Bewegen",
                    valueText: "\(Int(calories))",
                    badgeText: "/ \(Int(calGoal)) kcal",
                    percentageText: "\(Int(min(999, (calories / calGoal) * 100)))%",
                    progress: calories / calGoal,
                    gradientColors: moveColors,
                    iconName: "flame.fill",
                    isSelected: selectedRing == .move
                ) {
                    selectRing(.move)
                }
                
                Spacer(minLength: 0)
                
                // Trainieren (Minuten)
                HeroRingUnit(
                    title: "Trainieren",
                    valueText: "\(Int(exercise))",
                    badgeText: "/ \(Int(exGoal)) Min",
                    percentageText: "\(Int(min(999, (exercise / exGoal) * 100)))%",
                    progress: exercise / exGoal,
                    gradientColors: exerciseColors,
                    iconName: "timer",
                    isSelected: selectedRing == .exercise
                ) {
                    selectRing(.exercise)
                }
                
                Spacer(minLength: 0)
                
                // Stehen (Stunden)
                HeroRingUnit(
                    title: "Stehen",
                    valueText: "\(Int(stand))",
                    badgeText: "/ \(Int(standGoal)) Std",
                    percentageText: "\(Int(min(999, (stand / standGoal) * 100)))%",
                    progress: stand / standGoal,
                    gradientColors: standColors,
                    iconName: "figure.stand",
                    isSelected: selectedRing == .stand
                ) {
                    selectRing(.stand)
                }
            }
            .padding(.vertical, 4)
            
            // MARK: - Contextual Quick Insight Bar
            HStack(spacing: 8) {
                activityContextBar
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
    
    private func selectRing(_ ring: SelectedActivityRing) {
        HapticManager.shared.impact(style: .light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedRing = ring
        }
    }
    
    @ViewBuilder
    private var activityContextBar: some View {
        switch selectedRing {
        case .move:
            let remaining = max(0, calGoal - calories)
            Image(systemName: remaining == 0 ? "checkmark.circle.fill" : "flame.fill")
                .foregroundColor(remaining == 0 ? .green : AppleColors.move)
                .font(.system(size: 13, weight: .bold))
            
            if remaining == 0 {
                Text("Bewegungsziel übertroffen (+ \(Int(calories - calGoal)) kcal) 🎉")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            } else {
                Text("Noch \(Int(remaining)) kcal bis zum Bewegen-Ziel")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            Text("\(Int((calories / calGoal) * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(AppleColors.move)
            
        case .exercise:
            let remaining = max(0, exGoal - exercise)
            Image(systemName: remaining == 0 ? "checkmark.circle.fill" : "timer")
                .foregroundColor(remaining == 0 ? .green : AppleColors.exercise)
                .font(.system(size: 13, weight: .bold))
            
            if remaining == 0 {
                Text("Trainingsziel erreicht (+ \(Int(exercise - exGoal)) Min) 🏆")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            } else {
                Text("Noch \(Int(remaining)) Min bis zum Trainingsziel")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            Text("\(Int((exercise / exGoal) * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(AppleColors.exercise)
            
        case .stand:
            let remaining = max(0, standGoal - stand)
            Image(systemName: remaining == 0 ? "checkmark.circle.fill" : "figure.stand")
                .foregroundColor(remaining == 0 ? .green : AppleColors.stand)
                .font(.system(size: 13, weight: .bold))
            
            if remaining == 0 {
                Text("Stehziel für heute erreicht! 🚶‍♂️")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            } else {
                Text("Noch \(Int(remaining)) Std aufstehen und bewegen")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            Text("\(Int((stand / standGoal) * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(AppleColors.stand)
        }
    }
}

// MARK: - Hero Ring Single Unit
public struct HeroRingUnit: View {
    let title: String
    let valueText: String
    let badgeText: String
    let percentageText: String
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
                    
                    Text(percentageText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
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
