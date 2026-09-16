import Foundation
import SwiftUI

// MARK: - BioMetrics Data Models

/// Status classification for Recovery
public enum RecoveryStatus: String, CaseIterable, Codable {
    case optimal = "Optimal"
    case moderate = "Moderat"
    case low = "Niedrig"
    
    public var color: Color {
        switch self {
        case .optimal: return Color(red: 0.0, green: 0.85, blue: 0.45) // Vivid Green
        case .moderate: return Color(red: 1.0, green: 0.80, blue: 0.0) // Amber Yellow
        case .low: return Color(red: 1.0, green: 0.25, blue: 0.30)      // Crimson Red
        }
    }
}

/// Heart Rate Zones according to Lucía et al. (2003) & Edwards (1993)
public enum HRZone: Int, CaseIterable, Identifiable, Codable {
    case zone1 = 1 // 50-60% HRmax - Very Light / Recovery
    case zone2 = 2 // 60-70% HRmax - Light / Aerobic Base
    case zone3 = 3 // 70-80% HRmax - Moderate / Tempo
    case zone4 = 4 // 80-90% HRmax - Hard / Threshold
    case zone5 = 5 // 90-100% HRmax - Maximum / VO2 Max

    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .zone1: return "Z1 Erholung"
        case .zone2: return "Z2 Aerob"
        case .zone3: return "Z3 Tempo"
        case .zone4: return "Z4 Schwelle"
        case .zone5: return "Z5 Maximal"
        }
    }
    
    public var multiplier: Double {
        switch self {
        case .zone1: return 1.0
        case .zone2: return 2.0
        case .zone3: return 3.0
        case .zone4: return 4.0
        case .zone5: return 5.0
        }
    }
    
    public var color: Color {
        switch self {
        case .zone1: return Color.blue
        case .zone2: return Color.cyan
        case .zone3: return Color.green
        case .zone4: return Color.orange
        case .zone5: return Color.red
        }
    }
}

/// Breakdown of heart rate zones with minutes spent in each zone
public struct HRZoneBreakdown: Identifiable, Codable {
    public var id: Int { zone.rawValue }
    public let zone: HRZone
    public let minutes: Double
    public let percentage: Double
}

/// Breakdown of sleep stages based on Hirshkowitz et al. (2015)
public struct SleepStageBreakdown: Codable {
    public let deepMinutes: Double
    public let remMinutes: Double
    public let coreMinutes: Double
    public let awakeMinutes: Double
    
    public var totalSleepMinutes: Double {
        deepMinutes + remMinutes + coreMinutes
    }
    
    public var totalInBedMinutes: Double {
        totalSleepMinutes + awakeMinutes
    }
    
    public var deepPercentage: Double {
        totalSleepMinutes > 0 ? (deepMinutes / totalSleepMinutes) * 100.0 : 0.0
    }
    
    public var remPercentage: Double {
        totalSleepMinutes > 0 ? (remMinutes / totalSleepMinutes) * 100.0 : 0.0
    }
    
    public var corePercentage: Double {
        totalSleepMinutes > 0 ? (coreMinutes / totalSleepMinutes) * 100.0 : 0.0
    }
    
    public var efficiency: Double {
        totalInBedMinutes > 0 ? (totalSleepMinutes / totalInBedMinutes) * 100.0 : 0.0
    }
}

/// Complete Recovery metrics structure
public struct RecoveryMetrics: Codable {
    public let score: Double // 0 to 100%
    public let status: RecoveryStatus
    public let hrvMs: Double // Today's HRV (SDNN/RMSSD in ms)
    public let hrvBaselineMean: Double
    public let hrvBaselineStd: Double
    public let hrvZScore: Double
    public let rhrBpm: Double // Today's Resting HR
    public let rhrBaselineMean: Double
    public let rhrBaselineStd: Double
    public let rhrZScore: Double
}

/// Complete Strain metrics structure
public struct StrainMetrics: Codable {
    public let strainScale: Double // Whoop-style 0.0 - 21.0
    public let percentage: Double  // 0 - 100%
    public let trimp: Double       // Banister's TRIMP
    public let activeCalories: Double
    public let averageHR: Double
    public let maxHR: Double
    public let zoneBreakdown: [HRZoneBreakdown]
}

/// Complete Sleep metrics structure
public struct SleepMetrics: Codable {
    public let score: Double // 0 to 100%
    public let totalSleepHours: Double
    public let targetSleepHours: Double
    public let efficiency: Double // %
    public let breakdown: SleepStageBreakdown
}

/// Consolidated Biometric Data Snapshot
public struct BioMetricsSnapshot: Codable {
    public let timestamp: Date
    public let recovery: RecoveryMetrics
    public let strain: StrainMetrics
    public let sleep: SleepMetrics
}

// MARK: - BioMetrics Engine (Scientific Algorithms)

/// Scientific calculation engine for Recovery, Strain, and Sleep scores.
///
/// **Scientific References & Publications:**
/// 1. **Plews DJ et al. (2013)**: *"Training adaptation and heart rate variability in elite endurance athletes: opening the door to effective monitoring."* Sports Med 43(9):773-81.
/// 2. **Stanley J et al. (2013)**: *"Cardiac parasympathetic activity and race performance: an indicator of athletic readiness."* Int J Sports Physiol Perform 8(1):43-50.
/// 3. **Banister EW (1991)**: *"Modeling Elite Athletic Performance."* Physiological Testing of the High-Performance Athlete, Human Kinetics, pp. 403-424.
/// 4. **Lucía A et al. (2003)**: *"Heart rate and performance in masters cyclists."* Med Sci Sports Exerc 35(5):840-8.
/// 5. **Hirshkowitz M et al. (2015)**: *"National Sleep Foundation's sleep time duration recommendations."* Sleep Health 1(1):40-43.
/// 6. **Ohayon M et al. (2017)**: *"National Sleep Foundation's sleep quality recommendations."* Sleep Health 3(1):6-19.
public struct BioMetricsEngine {
    
    // MARK: - Adaptive Baseline Computation
    
    /// Adaptive baseline calculation from historical sample arrays.
    /// Handles sparse data gracefully by blending population defaults with available user samples.
    public static func calculateAdaptiveBaseline(
        samples: [Double],
        fallbackMean: Double = 55.0,
        fallbackStd: Double = 6.0
    ) -> (mean: Double, stdDev: Double) {
        let validSamples = samples.filter { $0.isFinite && !$0.isNaN && $0 > 0 }
        guard !validSamples.isEmpty else {
            return (fallbackMean, fallbackStd)
        }
        
        let sampleSum = validSamples.reduce(0.0, +)
        let sampleMean = sampleSum / Double(validSamples.count)
        
        let sampleWeight = min(1.0, Double(validSamples.count) / 7.0)
        let blendedMean = (sampleWeight * sampleMean) + ((1.0 - sampleWeight) * fallbackMean)
        
        if validSamples.count < 2 {
            return (blendedMean, fallbackStd)
        }
        
        let variance = validSamples.reduce(0.0) { $0 + pow($1 - sampleMean, 2) } / Double(validSamples.count - 1)
        let sampleStd = sqrt(variance)
        let safeStd = max(fallbackStd * 0.5, sampleStd)
        let blendedStd = (sampleWeight * safeStd) + ((1.0 - sampleWeight) * fallbackStd)
        
        return (blendedMean, max(2.0, blendedStd))
    }
    
    // MARK: - 1. Recovery Score Calculation
    
    /// Calculates the scientific Recovery Score (0–100%) based on HRV z-score, RHR z-score, and Sleep score.
    /// Handles missing or sparse HRV/RHR dynamically with adaptive weighting.
    ///
    /// - Reference: **Plews et al. (2013)** & **Stanley et al. (2013)**
    public static func calculateRecovery(
        currentHRV: Double,
        baselineHRVMean: Double,
        baselineHRVStd: Double,
        currentRHR: Double,
        baselineRHRMean: Double,
        baselineRHRStd: Double,
        sleepScore: Double
    ) -> RecoveryMetrics {
        let hasHrv = currentHRV > 0 && currentHRV.isFinite
        let hasRhr = currentRHR > 0 && currentRHR.isFinite
        let hasSleep = sleepScore >= 0 && sleepScore.isFinite
        
        let effectiveHrvMean = baselineHRVMean > 0 ? baselineHRVMean : (hasHrv ? currentHRV : 58.0)
        let effectiveHrvStd = max(baselineHRVStd, max(3.0, effectiveHrvMean * 0.08))
        
        let effectiveRhrMean = baselineRHRMean > 0 ? baselineRHRMean : (hasRhr ? currentRHR : 56.0)
        let effectiveRhrStd = max(baselineRHRStd, max(2.0, effectiveRhrMean * 0.05))
        
        let safeHrv = hasHrv ? currentHRV : effectiveHrvMean
        let safeRhr = hasRhr ? currentRHR : effectiveRhrMean
        
        let hrvZScore = (safeHrv - effectiveHrvMean) / effectiveHrvStd
        let rhrZScore = (safeRhr - effectiveRhrMean) / effectiveRhrStd
        
        let hrvSubScore = max(0.0, min(100.0, 75.0 + (hrvZScore * 15.0)))
        let rhrSubScore = max(0.0, min(100.0, 75.0 - (rhrZScore * 15.0)))
        let sleepSubScore = max(0.0, min(100.0, sleepScore))
        
        // Dynamic adaptive weighting based on available metric inputs
        let hrvWeight: Double
        let rhrWeight: Double
        let sleepWeight: Double
        
        switch (hasHrv, hasRhr, hasSleep && sleepScore > 0) {
        case (true, true, true):
            hrvWeight = 0.45; rhrWeight = 0.30; sleepWeight = 0.25
        case (true, false, true):
            hrvWeight = 0.65; rhrWeight = 0.00; sleepWeight = 0.35
        case (false, true, true):
            hrvWeight = 0.00; rhrWeight = 0.60; sleepWeight = 0.40
        case (true, true, false):
            hrvWeight = 0.60; rhrWeight = 0.40; sleepWeight = 0.00
        case (true, false, false):
            hrvWeight = 1.00; rhrWeight = 0.00; sleepWeight = 0.00
        case (false, true, false):
            hrvWeight = 0.00; rhrWeight = 1.00; sleepWeight = 0.00
        case (false, false, true):
            hrvWeight = 0.00; rhrWeight = 0.00; sleepWeight = 1.00
        case (false, false, false):
            hrvWeight = 0.45; rhrWeight = 0.30; sleepWeight = 0.25
        }
        
        let rawRecovery = (hrvWeight * hrvSubScore) + (rhrWeight * rhrSubScore) + (sleepWeight * sleepSubScore)
        let finalScore = max(0.0, min(100.0, rawRecovery))
        
        let status: RecoveryStatus
        if finalScore >= 66.0 {
            status = .optimal
        } else if finalScore >= 33.0 {
            status = .moderate
        } else {
            status = .low
        }
        
        return RecoveryMetrics(
            score: finalScore,
            status: status,
            hrvMs: safeHrv,
            hrvBaselineMean: effectiveHrvMean,
            hrvBaselineStd: effectiveHrvStd,
            hrvZScore: hrvZScore,
            rhrBpm: safeRhr,
            rhrBaselineMean: effectiveRhrMean,
            rhrBaselineStd: effectiveRhrStd,
            rhrZScore: rhrZScore
        )
    }
    
    // MARK: - 2. Strain Score Calculation (TRIMP & HR Zones)
    
    /// Calculates Banister's TRIMP (Training Impulse) and maps it to a Whoop-style 0.0–21.0 logarithmic scale.
    ///
    /// - References: **Banister (1991)** & **Lucía et al. (2003)**
    /// - TRIMP = Sum(duration_min * deltaHR * e^(1.92 * deltaHR))
    /// - Strain 0-21.0 mapped via smooth non-linear logarithmic scaling curve.
    public static func calculateStrain(
        hrSamples: [(date: Date, bpm: Double)],
        restingHR: Double = 60.0,
        maxHR: Double = 190.0,
        activeCalories: Double = 0.0
    ) -> StrainMetrics {
        guard !hrSamples.isEmpty else {
            return fallbackStrain(activeCalories: activeCalories)
        }
        
        let safeRestingHR = max(35.0, min(100.0, restingHR))
        let safeMaxHR = max(safeRestingHR + 40.0, min(220.0, maxHR))
        let hrRange = safeMaxHR - safeRestingHR
        
        var totalBanisterTRIMP: Double = 0.0
        var zoneMinutes: [HRZone: Double] = [.zone1: 0, .zone2: 0, .zone3: 0, .zone4: 0, .zone5: 0]
        var totalBpmSum: Double = 0.0
        var recordedMaxBpm: Double = 0.0
        
        // Assume samples are spaced ~1 minute or sample interval apart
        let sampleIntervalMinutes = 1.0
        
        for sample in hrSamples {
            let bpm = sample.bpm
            totalBpmSum += bpm
            if bpm > recordedMaxBpm { recordedMaxBpm = bpm }
            
            // Fractional Heart Rate Reserve (HRR)
            let deltaHR = max(0.0, min(1.0, (bpm - safeRestingHR) / hrRange))
            
            // Banister TRIMP component (unisex exponent coefficient 1.92)
            let banisterImpulse = sampleIntervalMinutes * deltaHR * exp(1.92 * deltaHR)
            totalBanisterTRIMP += banisterImpulse
            
            // Heart Rate Percentage of Max HR for Zone classification
            let pctMax = (bpm / safeMaxHR) * 100.0
            switch pctMax {
            case ..<60.0:
                zoneMinutes[.zone1, default: 0] += sampleIntervalMinutes
            case 60.0..<70.0:
                zoneMinutes[.zone2, default: 0] += sampleIntervalMinutes
            case 70.0..<80.0:
                zoneMinutes[.zone3, default: 0] += sampleIntervalMinutes
            case 80.0..<90.0:
                zoneMinutes[.zone4, default: 0] += sampleIntervalMinutes
            default:
                zoneMinutes[.zone5, default: 0] += sampleIntervalMinutes
            }
        }
        
        let totalZoneMinutes = zoneMinutes.values.reduce(0, +)
        let zoneBreakdown: [HRZoneBreakdown] = HRZone.allCases.map { zone in
            let mins = zoneMinutes[zone] ?? 0.0
            let pct = totalZoneMinutes > 0 ? (mins / totalZoneMinutes) * 100.0 : 0.0
            return HRZoneBreakdown(zone: zone, minutes: mins, percentage: pct)
        }
        
        // Combine Banister TRIMP with Lucía Zone TRIMP
        let luciaTRIMP = zoneBreakdown.reduce(0.0) { $0 + ($1.minutes * $1.zone.multiplier) }
        let compositeTRIMP = (totalBanisterTRIMP * 1.5) + (luciaTRIMP * 0.5) + (activeCalories * 0.05)
        
        // Whoop-like Strain mapping: 0.0 to 21.0 scale using logarithmic saturation curve
        // Strain = 21.0 * (1 - exp(-compositeTRIMP / 110.0))
        let strainScale = min(21.0, max(0.0, 21.0 * (1.0 - exp(-compositeTRIMP / 110.0))))
        let strainPercentage = (strainScale / 21.0) * 100.0
        
        let avgHR = totalBpmSum / Double(hrSamples.count)
        
        return StrainMetrics(
            strainScale: strainScale,
            percentage: strainPercentage,
            trimp: compositeTRIMP,
            activeCalories: activeCalories,
            averageHR: avgHR,
            maxHR: recordedMaxBpm > 0 ? recordedMaxBpm : avgHR,
            zoneBreakdown: zoneBreakdown
        )
    }
    
    private static func fallbackStrain(activeCalories: Double) -> StrainMetrics {
        // Fallback when HR samples are sparse
        let estimatedTRIMP = activeCalories * 0.25
        let strainScale = min(21.0, max(0.0, 21.0 * (1.0 - exp(-estimatedTRIMP / 110.0))))
        let percentage = (strainScale / 21.0) * 100.0
        
        let emptyBreakdown: [HRZoneBreakdown] = HRZone.allCases.map {
            HRZoneBreakdown(zone: $0, minutes: 0, percentage: 0)
        }
        
        return StrainMetrics(
            strainScale: strainScale,
            percentage: percentage,
            trimp: estimatedTRIMP,
            activeCalories: activeCalories,
            averageHR: 0,
            maxHR: 0,
            zoneBreakdown: emptyBreakdown
        )
    }
    
    // MARK: - 3. Sleep Score Calculation
    
    /// Calculates the scientific Sleep Score (0–100%) based on NSF guidelines.
    ///
    /// - Reference: **Hirshkowitz et al. (2015)** & **Ohayon et al. (2017)**
    /// - Duration Score (40%): Hours slept vs target (recommended 7.0–9.0 hours).
    /// - Architecture Score (35%): Proportions of Deep (target ~20%) and REM (target ~22.5%) sleep.
    /// - Efficiency Score (25%): Time asleep vs time in bed (optimal >= 85%).
    public static func calculateSleep(
        breakdown: SleepStageBreakdown,
        targetSleepHours: Double = 8.0
    ) -> SleepMetrics {
        let totalHours = breakdown.totalSleepMinutes / 60.0
        
        guard totalHours > 0.0 else {
            return SleepMetrics(
                score: 0.0,
                totalSleepHours: 0.0,
                targetSleepHours: max(4.0, targetSleepHours),
                efficiency: 0.0,
                breakdown: breakdown
            )
        }
        
        let safeTargetHours = max(4.0, min(12.0, targetSleepHours))
        
        // 1. Duration Score (40%)
        let durationRatio = min(1.2, totalHours / safeTargetHours)
        let durationScore = min(100.0, durationRatio * 100.0)
        
        // 2. Efficiency Score (25%)
        let efficiency = breakdown.efficiency
        let efficiencyScore = min(100.0, (efficiency / 85.0) * 100.0)
        
        // 3. Architecture Score (35%)
        let hasStageData = breakdown.deepMinutes > 0 || breakdown.remMinutes > 0
        let architectureScore: Double
        
        if hasStageData {
            let deepPct = breakdown.deepPercentage
            let deepScore: Double
            if deepPct >= 15.0 && deepPct <= 25.0 {
                deepScore = 100.0
            } else if deepPct < 15.0 {
                deepScore = (deepPct / 15.0) * 100.0
            } else {
                deepScore = max(70.0, 100.0 - ((deepPct - 25.0) * 2.0))
            }
            
            let remPct = breakdown.remPercentage
            let remScore: Double
            if remPct >= 20.0 && remPct <= 25.0 {
                remScore = 100.0
            } else if remPct < 20.0 {
                remScore = (remPct / 20.0) * 100.0
            } else {
                remScore = max(70.0, 100.0 - ((remPct - 25.0) * 2.0))
            }
            
            architectureScore = (deepScore * 0.5) + (remScore * 0.5)
        } else {
            // Adaptive score when device does not support stage breakdown (e.g. basic sleep tracking)
            architectureScore = (durationScore * 0.65) + (efficiencyScore * 0.35)
        }
        
        let finalScore = (0.40 * durationScore) + (0.35 * architectureScore) + (0.25 * efficiencyScore)
        let clampedScore = max(0.0, min(100.0, finalScore))
        
        return SleepMetrics(
            score: clampedScore,
            totalSleepHours: totalHours,
            targetSleepHours: safeTargetHours,
            efficiency: efficiency,
            breakdown: breakdown
        )
    }
}

// MARK: - Mock & Sample Data Extension

extension BioMetricsSnapshot {
    public static var mock: BioMetricsSnapshot {
        BioMetricsSnapshot(
            timestamp: Date(),
            recovery: RecoveryMetrics(
                score: 78.0,
                status: .optimal,
                hrvMs: 68.0,
                hrvBaselineMean: 62.0,
                hrvBaselineStd: 8.5,
                hrvZScore: 0.71,
                rhrBpm: 54.0,
                rhrBaselineMean: 58.0,
                rhrBaselineStd: 3.2,
                rhrZScore: -1.25
            ),
            strain: StrainMetrics(
                strainScale: 11.4,
                percentage: 54.2,
                trimp: 142.0,
                activeCalories: 480.0,
                averageHR: 132.0,
                maxHR: 168.0,
                zoneBreakdown: [
                    HRZoneBreakdown(zone: .zone1, minutes: 15.0, percentage: 25.0),
                    HRZoneBreakdown(zone: .zone2, minutes: 25.0, percentage: 41.7),
                    HRZoneBreakdown(zone: .zone3, minutes: 12.0, percentage: 20.0),
                    HRZoneBreakdown(zone: .zone4, minutes: 8.0, percentage: 13.3),
                    HRZoneBreakdown(zone: .zone5, minutes: 0.0, percentage: 0.0)
                ]
            ),
            sleep: SleepMetrics(
                score: 82.0,
                totalSleepHours: 7.8,
                targetSleepHours: 8.0,
                efficiency: 91.0,
                breakdown: SleepStageBreakdown(
                    deepMinutes: 98.0,
                    remMinutes: 112.0,
                    coreMinutes: 245.0,
                    awakeMinutes: 35.0
                )
            )
        )
    }
}

