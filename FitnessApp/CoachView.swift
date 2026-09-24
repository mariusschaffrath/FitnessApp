import SwiftUI

/// Full Scientific AI Coach view with readiness guidance, categorized feedback, and study insights.
public struct CoachView: View {
    let customRecommendation: CoachRecommendation?
    let snapshot: BioMetricsSnapshot?
    
    @State private var expandedInsightId: String? = nil
    
    public init(recommendation: CoachRecommendation) {
        self.customRecommendation = recommendation
        self.snapshot = nil
    }
    
    public init(snapshot: BioMetricsSnapshot, recommendation: CoachRecommendation? = nil) {
        self.snapshot = snapshot
        self.customRecommendation = recommendation
    }
    
    var recommendation: CoachRecommendation {
        if let custom = customRecommendation {
            return custom
        }
        if let snap = snapshot {
            return RecoveryCoach.generateRecommendation(from: snap)
        }
        return RecoveryCoach.generateActivityRecommendation(
            calories: 500, calGoal: 500, exercise: 30, exGoal: 30, stand: 12, standGoal: 12, steps: 10000, stepsGoal: 10000
        )
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    
                    // MARK: 1. Training Readiness & Target Strain Header
                    readinessBannerSection
                    
                    // MARK: 2. "Was super läuft" (Positive Signals)
                    goingWellSection
                    
                    // MARK: 3. "Was du verbessern kannst" (Actionable Tips)
                    toImproveSection
                    
                    // MARK: 4. "Wissenschaftliche Insights & Studien" (Citations)
                    scientificInsightsSection
                    
                    Spacer(minLength: 30)
                }
                .padding()
            }
            .navigationTitle("Dein Aktivitäts-Coach")
        }
    }
    
    // MARK: - Sections
    
    private var readinessBannerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(recommendation.readiness.color.opacity(0.18))
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: recommendation.readiness.icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(recommendation.readiness.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.readinessTitle)
                        .font(.title3)
                        .bold()
                    
                    Text("Aktivitäts-Status: \(recommendation.readiness.rawValue)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(recommendation.readiness.color)
                }
            }
            
            Text(recommendation.readinessMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
            
            // Target Strain Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Empfohlenes Aktivitäts-Ziel", systemImage: "target")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                    Text(recommendation.targetStrain.formattedRange)
                        .font(.title3)
                        .bold()
                        .foregroundColor(recommendation.readiness.color)
                }
                
                // Visual Strain / Activity Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 10)
                        
                        if recommendation.targetStrain.maxStrain > 21.0 {
                            let progress = min(1.0, max(0.0, recommendation.targetStrain.minStrain / max(1.0, recommendation.targetStrain.maxStrain)))
                            Capsule()
                                .fill(recommendation.readiness.color)
                                .frame(width: max(10, geo.size.width * CGFloat(progress)), height: 10)
                        } else {
                            let minPct = min(1.0, max(0.0, recommendation.targetStrain.minStrain / 21.0))
                            let maxPct = min(1.0, max(0.0, recommendation.targetStrain.maxStrain / 21.0))
                            let startX = geo.size.width * minPct
                            let width = geo.size.width * (maxPct - minPct)
                            
                            Capsule()
                                .fill(recommendation.readiness.color)
                                .frame(width: max(10, width), height: 10)
                                .offset(x: startX)
                        }
                    }
                }
                .frame(height: 10)
                
                Text(recommendation.targetStrain.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .glassCardStyle()
    }
    
    private var goingWellSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                Text("Was super läuft")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(recommendation.whatIsGoingWell, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 15))
                            .padding(.top, 2)
                        
                        Text(item)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(12)
                }
            }
        }
        .padding(18)
        .glassCardStyle()
    }
    
    private var toImproveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.forward.app.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                Text("Tipps für deine Ringe")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(recommendation.whatToImprove, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 15))
                            .padding(.top, 2)
                        
                        Text(item)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(12)
                }
            }
        }
        .padding(18)
        .glassCardStyle()
    }
    
    private var scientificInsightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.purple)
                    .font(.title3)
                Text("Wissenschaftliche Insights & Studien")
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                ForEach(recommendation.scientificInsights) { insight in
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation {
                                if expandedInsightId == insight.id {
                                    expandedInsightId = nil
                                } else {
                                    expandedInsightId = insight.id
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(insight.title)
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(.primary)
                                    Text(insight.citation)
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                                Image(systemName: expandedInsightId == insight.id ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if expandedInsightId == insight.id {
                            Text(insight.detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(14)
                    .background(Color.purple.opacity(0.06))
                    .cornerRadius(14)
                }
            }
        }
        .padding(18)
        .glassCardStyle()
    }
}
