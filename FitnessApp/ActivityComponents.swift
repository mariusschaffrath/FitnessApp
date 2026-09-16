import SwiftUI

struct AppleColors {
    static let move = Color(red: 249/255, green: 17/255, blue: 64/255)
    static let exercise = Color(red: 162/255, green: 255/255, blue: 0/255)
    static let stand = Color(red: 0/255, green: 219/255, blue: 255/255)
    static let steps = Color.blue
    static let ultraOrange = Color(red: 255/255, green: 94/255, blue: 0/255) // Apple Watch Ultra Orange
}

struct ActivityRing: View {
    var progress: Double
    var color: Color
    var icon: String? = nil
    var size: CGFloat = 80
    var showPercentage: Bool = true
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        VStack(spacing: showPercentage ? 10 : 0) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.1), lineWidth: size * 0.16)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(animatedProgress, 1.0)))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color.opacity(0.6), color]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: size * 0.16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.4), radius: size * 0.1, x: 0, y: 0)
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.22, weight: .black))
                        .foregroundStyle(color.gradient)
                }
            }
            .frame(width: size, height: size)
            
            if showPercentage {
                let validProgress = (progress.isFinite && !progress.isNaN) ? progress : 0.0
                Text("\(Int(validProgress * 100))%")
                    .font(.system(.footnote, design: .rounded))
                    .bold()
                    .foregroundStyle(color.opacity(0.8).gradient)
            }
        }
        .onAppear {
            animateRing()
        }
        .onChange(of: progress) { oldValue, newValue in
            animateRing()
        }
    }
    
    private func animateRing() {
        withAnimation(.interpolatingSpring(stiffness: 40, damping: 12).delay(0.1)) {
            animatedProgress = progress
        }
    }
}

struct GlassCard<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(20)
            .background(.thinMaterial)
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
    }
}

struct StatGlassCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(value)
                    .font(.system(.title3, design: .rounded))
                    .bold()
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}

extension Double {
    func formattedWithPoints(isInteger: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        if isInteger { formatter.maximumFractionDigits = 0 }
        else { formatter.maximumFractionDigits = 1 }
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }
}

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
