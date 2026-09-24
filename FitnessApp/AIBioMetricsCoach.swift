//
//  AIBioMetricsCoach.swift
//  FitnessApp
//
//  On-Device AI Health & Recovery Coach leveraging Apple FoundationModels (iOS 27+)
//  Provides 100% private, zero-cloud, empathetic sports coaching synthesized
//  directly on the Apple Neural Engine from biometric telemetry.
//

import Foundation
import SwiftUI
import FoundationModels
import Combine

@available(iOS 27.0, macOS 27.0, *)
@MainActor
public final class AIBioMetricsCoach: ObservableObject {
    
    // MARK: - Published State
    @Published public var isAnalyzing: Bool = false
    @Published public var dynamicNarrative: String = ""
    @Published public var activeRecommendation: CoachRecommendation?
    @Published public var isAppleIntelligenceActive: Bool = false
    
    // MARK: - Foundation Model Handle
    private let systemModel: SystemLanguageModel
    private var session: LanguageModelSession?
    
    public init() {
        self.systemModel = SystemLanguageModel.default
        self.isAppleIntelligenceActive = systemModel.isAvailable
        if systemModel.isAvailable {
            self.session = LanguageModelSession(
                model: systemModel,
                instructions: "Du bist ein erstklassiger, persönlicher Performance- und Erholungs-Coach wie bei Whoop und Apple Fitness. Antworte prägnant, motivierend, athletisch und auf Deutsch in maximal 3 Sätzen."
            )
        }
    }
    
    // MARK: - Core Coaching Generation
    
    /// Generates a personalized coaching briefing for the day based on the physiological snapshot.
    /// Uses Apple Foundation Models when available, falling back to deterministic rules.
    public func generateDailyBriefing(for snapshot: BioMetricsSnapshot) async -> CoachRecommendation {
        // Fallback check: If Apple Intelligence / on-device LLM is not available
        guard systemModel.isAvailable else {
            let fallback = RecoveryCoach.generateRecommendation(from: snapshot)
            self.activeRecommendation = fallback
            self.dynamicNarrative = fallback.readinessMessage
            self.isAppleIntelligenceActive = false
            return fallback
        }
        
        self.isAppleIntelligenceActive = true
        self.isAnalyzing = true
        defer { self.isAnalyzing = false }
        
        // Construct targeted sports science prompt
        let prompt = constructPhysiologicalPrompt(from: snapshot)
        
        do {
            // Synthesize personalized insight using Apple Foundation Models
            let aiText = try await queryOnDeviceFoundationModel(prompt: prompt)
            
            // Build enhanced recommendation wrapping AI insight with deterministic targets
            let deterministic = RecoveryCoach.generateRecommendation(from: snapshot)
            
            let enhanced = CoachRecommendation(
                readiness: deterministic.readiness,
                readinessTitle: deterministic.readinessTitle,
                readinessMessage: aiText.isEmpty ? deterministic.readinessMessage : aiText,
                targetStrain: deterministic.targetStrain,
                whatIsGoingWell: deterministic.whatIsGoingWell,
                whatToImprove: deterministic.whatToImprove,
                scientificInsights: deterministic.scientificInsights
            )
            
            self.activeRecommendation = enhanced
            self.dynamicNarrative = enhanced.readinessMessage
            return enhanced
            
        } catch {
            // Graceful fallback on inference error
            let fallback = RecoveryCoach.generateRecommendation(from: snapshot)
            self.activeRecommendation = fallback
            self.dynamicNarrative = fallback.readinessMessage
            return fallback
        }
    }
    
    /// Generates a personalized coaching briefing focused on the 3 Apple Fitness rings and steps.
    public func generateDailyActivityBriefing(
        calories: Double,
        calGoal: Double,
        exercise: Double,
        exGoal: Double,
        stand: Double,
        standGoal: Double,
        steps: Double,
        stepsGoal: Double
    ) async -> CoachRecommendation {
        guard systemModel.isAvailable else {
            let fallback = RecoveryCoach.generateActivityRecommendation(
                calories: calories,
                calGoal: calGoal,
                exercise: exercise,
                exGoal: exGoal,
                stand: stand,
                standGoal: standGoal,
                steps: steps,
                stepsGoal: stepsGoal
            )
            self.activeRecommendation = fallback
            self.dynamicNarrative = fallback.readinessMessage
            self.isAppleIntelligenceActive = false
            return fallback
        }
        
        self.isAppleIntelligenceActive = true
        self.isAnalyzing = true
        defer { self.isAnalyzing = false }
        
        let prompt = constructActivityPrompt(
            calories: calories,
            calGoal: calGoal,
            exercise: exercise,
            exGoal: exGoal,
            stand: stand,
            standGoal: standGoal,
            steps: steps,
            stepsGoal: stepsGoal
        )
        
        do {
            let aiText = try await queryOnDeviceFoundationModel(prompt: prompt)
            let deterministic = RecoveryCoach.generateActivityRecommendation(
                calories: calories,
                calGoal: calGoal,
                exercise: exercise,
                exGoal: exGoal,
                stand: stand,
                standGoal: standGoal,
                steps: steps,
                stepsGoal: stepsGoal
            )
            
            let enhanced = CoachRecommendation(
                readiness: deterministic.readiness,
                readinessTitle: deterministic.readinessTitle,
                readinessMessage: aiText.isEmpty ? deterministic.readinessMessage : aiText,
                targetStrain: deterministic.targetStrain,
                whatIsGoingWell: deterministic.whatIsGoingWell,
                whatToImprove: deterministic.whatToImprove,
                scientificInsights: deterministic.scientificInsights
            )
            
            self.activeRecommendation = enhanced
            self.dynamicNarrative = enhanced.readinessMessage
            return enhanced
        } catch {
            let fallback = RecoveryCoach.generateActivityRecommendation(
                calories: calories,
                calGoal: calGoal,
                exercise: exercise,
                exGoal: exGoal,
                stand: stand,
                standGoal: standGoal,
                steps: steps,
                stepsGoal: stepsGoal
            )
            self.activeRecommendation = fallback
            self.dynamicNarrative = fallback.readinessMessage
            return fallback
        }
    }
    
    // MARK: - Prompt Construction
    
    private func constructPhysiologicalPrompt(from snapshot: BioMetricsSnapshot) -> String {
        let statusText = snapshot.recovery.status.rawValue
        return """
        Du bist ein persönlicher Performance- und Erholungs-Coach.
        Analysiere folgende physiologische Daten des Nutzers für den heutigen Tag:
        
        • Erholungs-Score: \(Int(snapshot.recovery.score))% (Status: \(statusText))
        • HRV: \(Int(snapshot.recovery.hrvMs)) ms (Baseline-Abweichung: \(String(format: "%.2f", snapshot.recovery.hrvZScore)) SD)
        • Ruhepuls: \(Int(snapshot.recovery.rhrBpm)) bpm (Baseline: \(Int(snapshot.recovery.rhrBaselineMean)) bpm)
        • Gestriger Belastungs-Score (Strain): \(String(format: "%.1f", snapshot.strain.strainScale)) / 21.0
        • Schlafqualität: \(Int(snapshot.sleep.score))% (Dauer: \(String(format: "%.1f", snapshot.sleep.totalSleepHours))h, Tiefschlaf: \(Int(snapshot.sleep.breakdown.deepMinutes))m, REM: \(Int(snapshot.sleep.breakdown.remMinutes))m)
        
        Erstelle eine prägnante, motivierende und athletische Tagesempfehlung (maximal 3 Sätze):
        1. Erkläre den physiologischen Hauptgrund für den heutigen Erholungswert.
        2. Gib eine konkrete Empfehlung für die heutige Trainingsintensität.
        """
    }
    
    private func constructActivityPrompt(
        calories: Double,
        calGoal: Double,
        exercise: Double,
        exGoal: Double,
        stand: Double,
        standGoal: Double,
        steps: Double,
        stepsGoal: Double
    ) -> String {
        return """
        Du bist ein erstklassiger, persönlicher Apple-Fitness- und Aktivitäts-Coach.
        Analysiere die heutigen Aktivitätsringe und Werte des Nutzers:
        
        • Bewegen: \(Int(calories)) von \(Int(calGoal)) kcal (\(Int((calories / max(1.0, calGoal)) * 100))%)
        • Trainieren: \(Int(exercise)) von \(Int(exGoal)) Min (\(Int((exercise / max(1.0, exGoal)) * 100))%)
        • Stehen: \(Int(stand)) von \(Int(standGoal)) Std (\(Int((stand / max(1.0, standGoal)) * 100))%)
        • Schritte: \(Int(steps)) von \(Int(stepsGoal)) Schritten
        
        Erstelle eine motivierende, sportliche und sympathische Tagesempfehlung (maximal 3 Sätze):
        1. Lobe die bisher geschlossenen Ringe und die bisherige Aktivität.
        2. Gib einen konkreten, praxistauglichen Tipp, wie die noch offenen Ringe heute geschlossen werden können.
        """
    }
    
    // MARK: - On-Device Model Execution
    
    private func queryOnDeviceFoundationModel(prompt: String) async throws -> String {
        if let session = self.session {
            let response = try await session.respond(to: prompt)
            let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        
        return "Du bist heute auf einem großartigen Weg mit deinen Aktivitätsringen. Halte den Schwung bei und schließe heute alle drei Ringe!"
    }
}
