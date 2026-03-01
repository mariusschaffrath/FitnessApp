import SwiftUI

struct AppleColors {
    static let move = Color(red: 249/255, green: 17/255, blue: 64/255)
    static let exercise = Color(red: 162/255, green: 255/255, blue: 0/255)
    static let stand = Color(red: 0/255, green: 219/255, blue: 255/255)
    static let steps = Color.blue
}

struct ActivityRing: View {
    var progress: Double
    var color: Color
    var icon: String
    var size: CGFloat = 80
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Deeper base shadow for spatial effect
                Circle()
                    .stroke(color.opacity(0.1), lineWidth: size * 0.16)
                
                // Outer glow for the "Liquid" look
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
                    .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 0)
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.22, weight: .black))
                    .foregroundStyle(color.gradient)
            }
            .frame(width: size, height: size)
            
            Text("\(Int(progress * 100))%")
                .font(.system(.footnote, design: .rounded))
                .bold()
                .foregroundStyle(color.secondary.gradient)
        }
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 40, damping: 15)) {
                animatedProgress = progress
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    
    var body: some View {
        content
            .padding(20)
            .background(.thinMaterial) // iOS 26 standard for readability
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
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
