import SwiftUI

/// Compact Glassmorphic AI Activity Coach summary card for the main Dashboard
public struct CoachCardView: View {
    let recommendation: CoachRecommendation
    let onOpenCoach: () -> Void
    
    public init(recommendation: CoachRecommendation, onOpenCoach: @escaping () -> Void) {
        self.recommendation = recommendation
        self.onOpenCoach = onOpenCoach
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.title3)
                        .foregroundColor(recommendation.readiness.color)
                    
                    Text("Dein Aktivitäts-Coach")
                        .font(.headline)
                        .bold()
                }
                Spacer()
                
                Button(action: onOpenCoach) {
                    HStack(spacing: 4) {
                        Text("Mehr anzeigen")
                            .font(.caption)
                            .bold()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(recommendation.readiness.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(recommendation.readiness.color.opacity(0.12))
                    .cornerRadius(8)
                }
            }
            
            // Status Banner
            HStack(spacing: 12) {
                Image(systemName: recommendation.readiness.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(recommendation.readiness.color)
                    .frame(width: 44, height: 44)
                    .background(recommendation.readiness.color.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(recommendation.readinessTitle)
                        .font(.subheadline)
                        .bold()
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    
                    Text(recommendation.readinessMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Divider()
            
            // Top Recommendations Summary
            VStack(alignment: .leading, spacing: 8) {
                if let topGood = recommendation.whatIsGoingWell.first {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(.top, 2)
                        Text(topGood)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                }
                
                if let topImprove = recommendation.whatToImprove.first {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .padding(.top, 2)
                        Text(topImprove)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(18)
        .glassCardStyle()
    }
}
