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

/// Target Strain Range (0.0 to 21.0 Whoop scale) or Activity Target
public struct TargetStrainRange: Codable {
    public let minStrain: Double
    public let maxStrain: Double
    public let summary: String
    
    public init(minStrain: Double, maxStrain: Double, summary: String) {
        self.minStrain = minStrain
        self.maxStrain = maxStrain
        self.summary = summary
    }
    
    public var formattedRange: String {
        if maxStrain > 21.0 {
            return "\(Int(minStrain)) / \(Int(maxStrain)) kcal"
        }
        return String(format: "%.1f – %.1f", minStrain, maxStrain)
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
    
    /// Generates structured activity and ring coaching based on Bewegen, Trainieren, Stehen and Schritte.
    public static func generateActivityRecommendation(
        calories: Double,
        calGoal: Double,
        exercise: Double,
        exGoal: Double,
        stand: Double,
        standGoal: Double,
        steps: Double,
        stepsGoal: Double
    ) -> CoachRecommendation {
        let validCalGoal = max(1.0, calGoal)
        let validExGoal = max(1.0, exGoal)
        let validStandGoal = max(1.0, standGoal)
        let validStepsGoal = max(1.0, stepsGoal)
        
        let calPct = calories / validCalGoal
        let exPct = exercise / validExGoal
        let standPct = stand / validStandGoal
        let stepsPct = steps / validStepsGoal
        
        var closedCount = 0
        if calPct >= 1.0 { closedCount += 1 }
        if exPct >= 1.0 { closedCount += 1 }
        if standPct >= 1.0 { closedCount += 1 }
        
        let readiness: ReadinessLevel
        let readinessTitle: String
        let readinessMessage: String
        
        if closedCount == 3 {
            readiness = .highPerformance
            readinessTitle = "Alle 3 Ringe geschlossen! 🎉"
            readinessMessage = "Hervorragende Leistung! Du hast deine Tagesziele für Bewegen, Trainieren und Stehen heute vollständig erreicht."
        } else if closedCount == 2 {
            readiness = .optimal
            readinessTitle = "2 von 3 Ringen geschafft 💪"
            readinessMessage = "Du bist auf einem exzellenten Weg. Schließe jetzt noch den letzten Ring, um deinen Tag perfekt zu machen."
        } else if closedCount == 1 {
            readiness = .moderate
            readinessTitle = "Erster Ring geschlossen ⚡️"
            readinessMessage = "Starker Start! Mit etwas zusätzlicher Bewegung erreichst du heute auch die weiteren Ringe."
        } else if (calPct + exPct + standPct) / 3.0 >= 0.5 {
            readiness = .moderate
            readinessTitle = "Über die Hälfte geschafft 🏃‍♂️"
            readinessMessage = "Deine Aktivitätskurve zeigt nach oben. Bleibe heute aktiv und nimm die Treppe statt den Aufzug."
        } else {
            readiness = .activeRecovery
            readinessTitle = "Zeit für Aktivität 🚶‍♂️"
            readinessMessage = "Dein Tag hat noch viel Potenzial. Starte mit einem zügigen Spaziergang oder einer kurzen Trainingseinheit."
        }
        
        // Target Summary
        let targetStrain = TargetStrainRange(
            minStrain: calories,
            maxStrain: validCalGoal,
            summary: calPct >= 1.0 
                ? "Bewegungsziel mit \(Int(calories)) von \(Int(validCalGoal)) kcal gemeistert!" 
                : "Noch \(Int(max(0, validCalGoal - calories))) kcal bis zum Tagesziel von \(Int(validCalGoal)) kcal."
        )
        
        // Was super läuft
        var goingWell: [String] = []
        if calPct >= 1.0 {
            goingWell.append(String(format: "Bewegungsring übertroffen: %d von %d kcal verbrannt (+%d kcal).", Int(calories), Int(validCalGoal), Int(calories - validCalGoal)))
        } else if calPct >= 0.75 {
            goingWell.append(String(format: "Starker Kalorienumsatz: Bereits %d von %d kcal erreicht (%.0f%%).", Int(calories), Int(validCalGoal), calPct * 100))
        }
        
        if exPct >= 1.0 {
            goingWell.append(String(format: "Trainingsziel gemeistert: %d Minuten absolviert (Ziel: %d Min).", Int(exercise), Int(validExGoal)))
        } else if exPct >= 0.5 {
            goingWell.append(String(format: "Aktives Training: %d von %d Trainingsminuten abgeschlossen.", Int(exercise), Int(validExGoal)))
        }
        
        if standPct >= 1.0 {
            goingWell.append(String(format: "Stehziel voll erreicht: %d von %d Stunden mit Bewegung.", Int(stand), Int(validStandGoal)))
        } else if standPct >= 0.6 {
            goingWell.append(String(format: "Regelmäßiges Aufstehen: %d von %d Stehstunden verbucht.", Int(stand), Int(validStandGoal)))
        }
        
        if stepsPct >= 1.0 {
            goingWell.append(String(format: "Schrittziel erreicht: %d Schritte absolviert.", Int(steps)))
        } else if stepsPct >= 0.7 {
            goingWell.append(String(format: "Solide Schrittbasis: Bereits %d von %d Schritten gemacht.", Int(steps), Int(validStepsGoal)))
        }
        
        if goingWell.isEmpty {
            goingWell.append("Aktivitätsaufzeichnung aktiv – jede Bewegung heute zählt für deine Ringe.")
        }
        
        // Was du verbessern kannst
        var toImprove: [String] = []
        if calPct < 1.0 {
            let remCal = Int(validCalGoal - calories)
            let walkMins = max(10, remCal / 5)
            toImprove.append("Noch \(remCal) kcal für den Bewegungsring – ein \(walkMins)-minütiger zügiger Spaziergang schließt die Lücke.")
        }
        if exPct < 1.0 {
            let remEx = Int(validExGoal - exercise)
            toImprove.append("Noch \(remEx) Minuten Training offen. Eine kurze HIIT-Einheit, Radfahren oder Yoga bringen dich ans Ziel.")
        }
        if standPct < 1.0 {
            let remStand = Int(validStandGoal - stand)
            toImprove.append("Noch \(remStand) Stehstunden ausstehend. Versuche, jede Stunde einmal für mindestens 1 Minute aufzustehen.")
        }
        if stepsPct < 1.0 && stepsPct > 0.0 {
            let remSteps = Int(validStepsGoal - steps)
            toImprove.append("Noch \(remSteps) Schritte bis zu deinem Tages-Schrittziel.")
        }
        if toImprove.isEmpty {
            toImprove.append("Großartige Leistung! Alle deine heutigen Aktivitätsziele wurden erfolgreich erreicht.")
        }
        
        // Wissenschaftliche Insights zu Bewegung & Ringen
        let insights: [ScientificInsight] = [
            ScientificInsight(
                id: "who_2020",
                title: "WHO-Bewegungsrichtlinien",
                citation: "Bull FC et al. (2020). Br J Sports Med 54(24):1451-1462",
                detail: "Mindestens 150 bis 300 Minuten moderate Bewegung pro Woche reduzieren das Risiko für Herz-Kreislauf-Erkrankungen und stärken das Immunsystem nachhaltig."
            ),
            ScientificInsight(
                id: "neat_levine",
                title: "NEAT & Alltags-Thermogenese",
                citation: "Levine JA (2004). Am J Physiol Endocrinol Metab 286(5):E675-85",
                detail: "Alltägliche Nicht-Trainingsaktivität (Treppensteigen, Stehen, Gehen) macht bis zu 50% des täglichen Energieverbrauchs aus und übertrifft oft geplante Workouts."
            ),
            ScientificInsight(
                id: "stand_sedentary",
                title: "Unterbrechung von Sitzphasen",
                citation: "Dunstan DW et al. (2012). Diabetes Care 35(5):976-983",
                detail: "Bereits 1 bis 2 Minuten leichtes Aufstehen und Gehen pro Stunde senken den postprandialen Glukosespiegel signifikant und kurbeln den Fettstoffwechsel an."
            ),
            ScientificInsight(
                id: "paluch_steps_2022",
                title: "Schritte & Langlebigkeit",
                citation: "Paluch AE et al. (2022). Lancet Public Health 7(3):e219-e228",
                detail: "Tägliche Schrittzahlen zwischen 8.000 und 10.000 Schritten führen zu einer maximalen Risikominimierung für Gesamtmortalität bei Erwachsenen."
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
