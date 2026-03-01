import SwiftUI

struct FitnessLogo: View {
    var size: CGFloat = 100
    
    // Interne Farben für maximale Unabhängigkeit
    private let moveRed = Color(red: 249/255, green: 17/255, blue: 64/255)
    private let exerciseGreen = Color(red: 162/255, green: 255/255, blue: 0/255)
    private let standCyan = Color(red: 0/255, green: 219/255, blue: 255/255)
    
    var body: some View {
        ZStack {
            // Heart shape segments using gradients
            ZStack {
                Circle()
                    .trim(from: 0.0, to: 0.7)
                    .stroke(moveRed.gradient, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                    .frame(width: size * 0.95)
                
                Circle()
                    .trim(from: 0.2, to: 0.9)
                    .stroke(exerciseGreen.gradient, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                    .frame(width: size * 0.75)
                
                Circle()
                    .trim(from: 0.5, to: 1.2)
                    .stroke(standCyan.gradient, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                    .frame(width: size * 0.55)
            }
            .rotationEffect(.degrees(-90))
            
            // Central Heart Icon
            Image(systemName: "heart.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.3)
                .foregroundStyle(moveRed.gradient)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .frame(width: size, height: size)
    }
}

// iOS 17+ Preview
#Preview {
    ZStack {
        Color.black.edgesIgnoringSafeArea(.all)
        FitnessLogo(size: 250)
    }
}

// Support für ältere Previews
struct LogoView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            FitnessLogo(size: 250)
        }
        .previewLayout(.sizeThatFits)
    }
}
