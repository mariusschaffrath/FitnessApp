import SwiftUI

/// Compact Glassmorphic AI Coach summary card for the main Dashboard
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
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundColor(recommendation.readiness.color)
                    
                    Text("Wissenschaftlicher AI Coach")
                        .font(.headline)
                }
                Spacer()
                
                Button(action: onOpenCoach) {
                    HStack(spacing: 4) {
                        Text("Details")
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
            
            // Readiness Status Banner
            HStack(spacing: 12) {
                Image(systemName: recommendation.readiness.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(recommendation.readiness.color)
                    .frame(width: 44, height: 44)
                    .background(recommendation.readiness.color.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.readinessTitle)
                        .font(.subheadline)
                        .bold()
                    
                    Text("Empfohlener Strain: \(recommendation.targetStrain.formattedRange)")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
