import XCTest
@testable import FitnessApp

final class BioMetricsEngineTests: XCTestCase {
    
    // MARK: - 1. Adaptive Baseline Tests
    
    func testAdaptiveBaselineEmptySamplesReturnsFallback() {
        let result = BioMetricsEngine.calculateAdaptiveBaseline(
            samples: [],
            fallbackMean: 55.0,
            fallbackStd: 6.0
        )
        
        XCTAssertEqual(result.mean, 55.0, accuracy: 0.001)
        XCTAssertEqual(result.stdDev, 6.0, accuracy: 0.001)
    }
    
    func testAdaptiveBaselineFiltersInvalidSamples() {
        let invalidSamples = [-10.0, 0.0, Double.nan, Double.infinity, -Double.infinity]
        let result = BioMetricsEngine.calculateAdaptiveBaseline(
            samples: invalidSamples,
            fallbackMean: 60.0,
            fallbackStd: 5.0
        )
        
        XCTAssertEqual(result.mean, 60.0, accuracy: 0.001)
        XCTAssertEqual(result.stdDev, 5.0, accuracy: 0.001)
    }
    
    func testAdaptiveBaselineWithSevenOrMoreSamples() {
        // 7 days of steady HRV values: 60, 62, 58, 64, 60, 61, 63 -> Mean ~61.14
        let samples: [Double] = [60.0, 62.0, 58.0, 64.0, 60.0, 61.0, 63.0]
        let result = BioMetricsEngine.calculateAdaptiveBaseline(
            samples: samples,
            fallbackMean: 50.0,
            fallbackStd: 10.0
        )
        
        // Weight is 1.0 (7 / 7 = 1.0), so mean should equal sample mean
        let expectedMean = samples.reduce(0, +) / Double(samples.count)
        XCTAssertEqual(result.mean, expectedMean, accuracy: 0.01)
        XCTAssertGreaterThan(result.stdDev, 0.0)
    }
    
    func testAdaptiveBaselineSingleSampleBlendsSmoothly() {
        let samples: [Double] = [70.0]
        let result = BioMetricsEngine.calculateAdaptiveBaseline(
            samples: samples,
            fallbackMean: 50.0,
            fallbackStd: 8.0
        )
        
        // 1 sample weight = 1/7 (~0.1428). (0.1428 * 70) + (0.8571 * 50) = 10 + 42.85 = ~52.85
        XCTAssertGreaterThan(result.mean, 50.0)
        XCTAssertLessThan(result.mean, 70.0)
        XCTAssertEqual(result.stdDev, 8.0, accuracy: 0.001)
    }
    
    // MARK: - 2. Recovery Calculation Tests
    
    func testRecoveryFullMetricsOptimalStatus() {
        // High HRV above baseline, Low RHR below baseline, Great sleep -> High Recovery
        let metrics = BioMetricsEngine.calculateRecovery(
            currentHRV: 75.0,
            baselineHRVMean: 60.0,
            baselineHRVStd: 8.0,
            currentRHR: 48.0,
            baselineRHRMean: 55.0,
            baselineRHRStd: 4.0,
            sleepScore: 90.0
        )
        
        XCTAssertGreaterThanOrEqual(metrics.score, 66.0, "Score should be >= 66 for optimal recovery")
        XCTAssertEqual(metrics.status, .optimal)
        XCTAssertGreaterThan(metrics.hrvZScore, 0.0)
        XCTAssertLessThan(metrics.rhrZScore, 0.0)
    }
    
    func testRecoveryLowStatusOnAdverseBiometrics() {
        // Suppressed HRV, Elevated RHR, Poor Sleep
        let metrics = BioMetricsEngine.calculateRecovery(
            currentHRV: 30.0,
            baselineHRVMean: 65.0,
            baselineHRVStd: 6.0,
            currentRHR: 75.0,
            baselineRHRMean: 52.0,
            baselineRHRStd: 3.0,
            sleepScore: 25.0
        )
        
        XCTAssertLessThan(metrics.score, 33.0, "Adverse biometrics must result in low recovery")
        XCTAssertEqual(metrics.status, .low)
    }
    
    func testRecoveryZeroDivisionSafetyAndMissingMetrics() {
        // Zero baseline std, zero current HRV/RHR, no sleep score
        let metrics = BioMetricsEngine.calculateRecovery(
            currentHRV: 0.0,
            baselineHRVMean: 0.0,
            baselineHRVStd: 0.0,
            currentRHR: 0.0,
            baselineRHRMean: 0.0,
            baselineRHRStd: 0.0,
            sleepScore: 0.0
        )
        
        XCTAssertFalse(metrics.score.isNaN)
        XCTAssertFalse(metrics.score.isInfinite)
        XCTAssertGreaterThanOrEqual(metrics.score, 0.0)
        XCTAssertLessThanOrEqual(metrics.score, 100.0)
    }
    
    func testRecoveryHRVOnlyAdaptiveWeighting() {
        // When only HRV is provided
        let metrics = BioMetricsEngine.calculateRecovery(
            currentHRV: 80.0,
            baselineHRVMean: 60.0,
            baselineHRVStd: 10.0,
            currentRHR: 0.0,
            baselineRHRMean: 0.0,
            baselineRHRStd: 0.0,
            sleepScore: 0.0
        )
        
        // Z-score = (80 - 60) / 10 = 2.0. Subscore = 75 + (2.0 * 15) = 105 -> clamped to 100
        XCTAssertEqual(metrics.score, 100.0, accuracy: 1.0)
        XCTAssertEqual(metrics.status, .optimal)
    }
    
    // MARK: - 3. Banister TRIMP & Strain Calculation Tests
    
    func testStrainEmptySamplesFallback() {
        let strain = BioMetricsEngine.calculateStrain(
            hrSamples: [],
            restingHR: 60.0,
            maxHR: 190.0,
            activeCalories: 400.0
        )
        
        XCTAssertEqual(strain.activeCalories, 400.0)
        XCTAssertGreaterThan(strain.strainScale, 0.0)
        XCTAssertLessThanOrEqual(strain.strainScale, 21.0)
        XCTAssertEqual(strain.zoneBreakdown.count, HRZone.allCases.count)
    }
    
    func testStrainCalculationScalesWithin21Scale() {
        let now = Date()
        // Simulate a 45-minute intense workout with HR oscillating in Zone 4 / Zone 5
        var samples: [(date: Date, bpm: Double)] = []
        for i in 0..<45 {
            let bpm = 165.0 + Double(i % 10) * 2.0 // 165 to 183 bpm
            samples.append((date: now.addingTimeInterval(Double(i * 60)), bpm: bpm))
        }
        
        let strain = BioMetricsEngine.calculateStrain(
            hrSamples: samples,
            restingHR: 50.0,
            maxHR: 195.0,
            activeCalories: 550.0
        )
        
        XCTAssertGreaterThan(strain.strainScale, 5.0, "Intense 45min session should produce significant strain")
        XCTAssertLessThanOrEqual(strain.strainScale, 21.0, "Strain scale must strictly cap at 21.0")
        XCTAssertGreaterThan(strain.trimp, 0.0)
        XCTAssertGreaterThan(strain.averageHR, 160.0)
        XCTAssertEqual(strain.percentage, (strain.strainScale / 21.0) * 100.0, accuracy: 0.01)
    }
    
    func testStrainZoneBreakdownCalculatesCorrectly() {
        let now = Date()
        // 10 samples at 100 bpm (Zone 1) and 10 samples at 180 bpm (Zone 5)
        var samples: [(date: Date, bpm: Double)] = []
        for i in 0..<10 {
            samples.append((date: now.addingTimeInterval(Double(i * 60)), bpm: 100.0))
        }
        for i in 10..<20 {
            samples.append((date: now.addingTimeInterval(Double(i * 60)), bpm: 185.0))
        }
        
        let strain = BioMetricsEngine.calculateStrain(
            hrSamples: samples,
            restingHR: 55.0,
            maxHR: 200.0,
            activeCalories: 200.0
        )
        
        let z1 = strain.zoneBreakdown.first { $0.zone == .zone1 }
        let z5 = strain.zoneBreakdown.first { $0.zone == .zone5 }
        
        XCTAssertNotNil(z1)
        XCTAssertNotNil(z5)
        XCTAssertEqual(z1?.minutes ?? 0, 10.0, accuracy: 0.1)
        XCTAssertEqual(z5?.minutes ?? 0, 10.0, accuracy: 0.1)
    }
    
    // MARK: - 4. Sleep Score Tests
    
    func testSleepScoreZeroMinutesReturnsZero() {
        let emptyBreakdown = SleepStageBreakdown(
            deepMinutes: 0,
            remMinutes: 0,
            coreMinutes: 0,
            awakeMinutes: 0
        )
        
        let sleep = BioMetricsEngine.calculateSleep(breakdown: emptyBreakdown, targetSleepHours: 8.0)
        XCTAssertEqual(sleep.score, 0.0)
        XCTAssertEqual(sleep.totalSleepHours, 0.0)
    }
    
    func testSleepScoreIdealStagesReturnsHighQuality() {
        // Ideal night: 8 hours total sleep (480 min). 20% Deep (96 min), 22% REM (105 min), Core (279 min), Awake 30 min.
        let idealBreakdown = SleepStageBreakdown(
            deepMinutes: 96.0,
            remMinutes: 105.0,
            coreMinutes: 279.0,
            awakeMinutes: 30.0
        )
        
        let sleep = BioMetricsEngine.calculateSleep(breakdown: idealBreakdown, targetSleepHours: 8.0)
        
        XCTAssertGreaterThanOrEqual(sleep.score, 85.0, "Ideal sleep architecture should score >= 85%")
        XCTAssertGreaterThan(sleep.efficiency, 90.0)
        XCTAssertEqual(sleep.totalSleepHours, 8.0, accuracy: 0.01)
    }
    
    func testSleepScoreAdaptiveWithoutStages() {
        // Tracker that only records total sleep without REM/Deep stages
        let stageLessBreakdown = SleepStageBreakdown(
            deepMinutes: 0,
            remMinutes: 0,
            coreMinutes: 450.0,
            awakeMinutes: 30.0
        )
        
        let sleep = BioMetricsEngine.calculateSleep(breakdown: stageLessBreakdown, targetSleepHours: 7.5)
        
        XCTAssertGreaterThan(sleep.score, 70.0, "Adaptive calculation should still reward good duration & efficiency")
        XCTAssertEqual(sleep.breakdown.deepPercentage, 0.0)
        XCTAssertEqual(sleep.breakdown.remPercentage, 0.0)
    }
    
    // MARK: - 5. Snapshot Mock Test
    
    func testMockSnapshotIntegrity() {
        let mock = BioMetricsSnapshot.mock
        XCTAssertGreaterThan(mock.recovery.score, 0.0)
        XCTAssertLessThanOrEqual(mock.recovery.score, 100.0)
        XCTAssertGreaterThan(mock.strain.strainScale, 0.0)
        XCTAssertLessThanOrEqual(mock.strain.strainScale, 21.0)
        XCTAssertGreaterThan(mock.sleep.score, 0.0)
        XCTAssertLessThanOrEqual(mock.sleep.score, 100.0)
        XCTAssertEqual(mock.strain.zoneBreakdown.count, 5)
    }
}
