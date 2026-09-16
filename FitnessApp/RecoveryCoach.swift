import Foundation
import SwiftUI

/// Scientific Readiness Level based on Strain vs Recovery balance
public enum ReadinessLevel: String, Codable {
    case highPerformance = "Hohe Leistungsfähigkeit"
    case optimal = "Optimales Training"
    case moderate = "Moderate Belastung"
    case activeRecovery = "Aktive Erholung"
    case restDay = "Ruhetag Erforderlich"
    
    public var icon: String {
        switch self {
        case .highPerformance: return "bolt.fill"
        case .optimal: return "figure.run"
        case .moderate: return "figure.walk"
        case .activeRecovery: return "leaf.fill"
        case .restDay: return "bed.double.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .highPerformance, .optimal: return Color(red: 0.0, green: 0.85, blue: 0.45)
        case .moderate: return Color(red: 1.0, green: 0.80, blue: 0.0)
        case .activeRecovery: return Color(red: 0.2, green: 0.7, blue: 1.0)
        case .restDay: return Color(red: 1.0, green: 0.25, blue: 0.30)
        }
    }
}

/// Target Strain Range (0.0 to 21.0 Whoop scale)
public struct TargetStrainRange: Codable {
    public let minStrain: Double
    public let maxStrain: Double
    public let summary: String
    
    public var formattedRange: String {
        String(format: "%.1f – %.1f", minStrain, maxStrain)
    }
}

/// Scientific publication insight with citation
public struct ScientificInsight: Identifiable, Codable {
    public let id: String
    public let title: String
    public let citation: String
    public let detail: String
}

/// Comprehensive Coach Recommendation structure
public struct CoachRecommendation: Codable {
    public let readiness: ReadinessLevel
    public let readinessTitle: String
    public let readinessMessage: String
    public let targetStrain: TargetStrainRange
    public let whatIsGoingWell: [String]
    public let whatToImprove: [String]
    public let scientificInsights: [ScientificInsight]
}

/// Scientific AI Coach Engine analyzing Strain, Recovery, and Sleep parameters.
public struct RecoveryCoach {
    
    /// Generates structured recovery and training guidance.
    public static func generateRecommendation(from metrics: BioMetricsSnapshot) -> CoachRecommendation {
        let recScore = metrics.recovery.score
        let strainVal = metrics.strain.strainScale
        let sleepScore = metrics.sleep.score
        let hrvZ = metrics.recovery.hrvZScore
        let rhrZ = metrics.recovery.rhrZScore
        let deepPct = metrics.sleep.breakdown.deepPercentage
        let remPct = metrics.sleep.breakdown.remPercentage
        let totalSleep = metrics.sleep.totalSleepHours
        
        // 1. Determine Readiness Level & Target Strain Range
        let readiness: ReadinessLevel
        let targetStrain: TargetStrainRange
        let readinessTitle: String
        let readinessMessage: String
        
        if recScore >= 80.0 {
            readiness = .highPerformance
            targetStrain = TargetStrainRange(
                minStrain: 14.0,
                maxStrain: 18.5,
                summary: "Dein Nervensystem ist exzellent erholt. Du kannst heute hohe Trainingsreize setzen (Intervalle, Kraft-PRs)."
            )
            readinessTitle = "Bereit für Höchstleistungen 🔥"
            readinessMessage = "Dein parasympathisches Nervensystem zeigt hervorragende Erholungssignale. Ein intensives Workout wird positive Trainingsanpassungen auslösen."
            
        } else if recScore >= 66.0 {
            readiness = .optimal
            targetStrain = TargetStrainRange(
                minStrain: 11.0,
                maxStrain: 15.0,
                summary: "Solide Erholung. Ideal für strukturiertes Grundlagentraining oder moderate Krafteinheiten."
            )
            readinessTitle = "Gute Trainingsbereitschaft 💪"
            readinessMessage = "Du bist gut erholt und bereit für ein qualitatives Training. Vermeide jedoch extreme Ausdauer-Überlastungen."
            
        } else if recScore >= 45.0 {
            readiness = .moderate
            targetStrain = TargetStrainRange(
                minStrain: 8.0,
                maxStrain: 12.0,
                summary: "Moderate Erholung. Halte die Intensität im grünen Bereich (Z1–Z2)."
            )
            readinessTitle = "Moderate Ausgewogenheit ⚖️"
            readinessMessage = "Dein Körper befindet sich in kontinuierlicher Erholung. Fokus auf Technik, Z2-Ausdauer oder leichtes Mobility-Training."
            
        } else if recScore >= 30.0 {
            readiness = .activeRecovery
            targetStrain = TargetStrainRange(
                minStrain: 5.0,
                maxStrain: 8.5,
                summary: "Fokus auf aktive Regeneration (Spaziergang, leichtes Yoga, Dehnen)."
            )
            readinessTitle = "Aktive Erholung empfohlen 🧘"
            readinessMessage = "Erhöhte physiologische Belastung. Vermeide intensives Training, um Übertraining zu verhindern."
            
        } else {
            readiness = .restDay
            targetStrain = TargetStrainRange(
                minStrain: 0.0,
                maxStrain: 5.0,
                summary: "Vollständiger Ruhetag dringend empfohlen."
            )
            readinessTitle = "Priorität: Erholung & Schlaf 🛌"
            readinessMessage = "Signifikante Abweichung von deiner HRV-Baseline und erhöhter Ruhepuls. Gib deinem Körper Zeit zur Gewebereparatur."
        }
        
        // 2. What is going well ("Was super läuft")
        var goingWell: [String] = []
        if hrvZ >= 0.2 {
            goingWell.append(String(format: "Starke HRV (%.0f ms, +%.1f SD über Baseline) deutet auf hohe parasympathische Aktivität hin.", metrics.recovery.hrvMs, hrvZ))
        }
        if rhrZ <= -0.2 {
            goingWell.append(String(format: "Niedriger Ruhepuls (%.0f bpm, %.1f SD unter Baseline) zeigt eine effiziente Herz-Kreislauf-Erholung.", metrics.recovery.rhrBpm, abs(rhrZ)))
        }
        if sleepScore >= 75.0 {
            goingWell.append(String(format: "Hohe Schlafqualität (Score %.0f%%) mit exzellenter Regeneration.", sleepScore))
        }
        if deepPct >= 15.0 {
            goingWell.append(String(format: "Optimaler Tiefschlaf-Anteil (%.1f%%) fördert die körperliche Gewebereparatur.", deepPct))
        }
        if remPct >= 20.0 {
            goingWell.append(String(format: "Sehr guter REM-Schlaf (%.1f%%) unterstützt kognitive Konsolidierung und Nervenerholung.", remPct))
        }
        if goingWell.isEmpty {
            goingWell.append("Stabile Basisfunktionen des Herz-Kreislauf-Systems aufrechterhalten.")
        }
        
        // 3. What to improve ("Was du verbessern kannst")
        var toImprove: [String] = []
        if hrvZ < -0.5 {
            toImprove.append(String(format: "HRV (%.0f ms) liegt %.1f SD unter deiner 7-Tage-Baseline. Reduziere Stressoren vor dem Schlafengehen.", metrics.recovery.hrvMs, abs(hrvZ)))
        }
        if rhrZ > 0.5 {
            toImprove.append(String(format: "Ruhepuls (%.0f bpm) ist um %.1f SD erhöht. Vermide späte Mahlzeiten und Alkohol.", metrics.recovery.rhrBpm, rhrZ))
        }
        if totalSleep < metrics.sleep.targetSleepHours - 0.5 {
            toImprove.append(String(format: "Schlafmanko von %.1f Stunden. Versuche heute Abend 30 Minuten früher ins Bett zu gehen.", metrics.sleep.targetSleepHours - totalSleep))
        }
        if deepPct < 15.0 {
            toImprove.append(String(format: "Tiefschlaf (%.1f%%) unter dem Richtwert (15–25%%). Achte auf ein kühles, dunkles Schlafzimmer (18°C).", deepPct))
        }
        if metrics.sleep.efficiency < 85.0 {
            toImprove.append(String(format: "Schlafeffizienz bei %.0f%%. Reduziere Bildschirmzeit 1 Std. vor dem Schlafen.", metrics.sleep.efficiency))
        }
        if strainVal > 15.0 && recScore < 50.0 {
            toImprove.append("Hohe Vortagsbelastung trifft auf moderate Erholung. Priorisiere Hydration und Nährstoffzufuhr.")
        }
        if toImprove.isEmpty {
            toImprove.append("Behalte dein aktuelles Schlaf- und Erholungs-Regime bei!")
        }
        
        // 4. Scientific Insights & Publications
        let insights: [ScientificInsight] = [
            ScientificInsight(
                id: "plews_2013",
                title: "HRV-Baseline & Trainingsanpassung",
                citation: "Plews DJ et al. (2013). Sports Med 43(9):773-81",
                detail: "Veränderungen der HRV im Vergleich zur individuellen 7-Tage-Rolling-Baseline reflektieren die parasympathische Erholung verlässlicher als absolute Einzelwerte."
            ),
            ScientificInsight(
                id: "banister_1991",
                title: "TRIMP (Training Impulse) Modell",
                citation: "Banister EW (1991). Human Kinetics, pp. 403-424",
                detail: "Die Belastung berechnet sich exponentiell über die Herzfrequenzreserve. Höhere Zonen (Z4/Z5) verursachen überproportional höhere Erholungsanforderungen."
            ),
            ScientificInsight(
                id: "hirshkowitz_2015",
                title: "Schlafarchitektur & NSF Standards",
                citation: "Hirshkowitz M et al. (2015). Sleep Health 1(1):40-43",
                detail: "Erwachsene benötigen 7–9 Stunden Schlaf mit 15–25% Tiefschlaf (SWS) für hormonelle Regeneration und Wachstumshormonausschüttung."
            ),
            ScientificInsight(
                id: "stanley_2013",
                title: "Parasympathische Reaktivierung",
                citation: "Stanley J et al. (2013). Int J Sports Physiol Perform 8(1):43-50",
                detail: "Erholung des autonomen Nervensystems benötigt nach hochintensiven Reizen bis zu 48 Stunden. Ruhepuls und HRV sind Schlüsselindikatoren."
            )
        ]
        
        return CoachRecommendation(
            readiness: readiness,
            readinessTitle: readinessTitle,
            readinessMessage: readinessMessage,
            targetStrain: targetStrain,
            whatIsGoingWell: goingWell,
            whatToImprove: toImprove,
            scientificInsights: insights
        )
    }
}
