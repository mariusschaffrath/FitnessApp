import SwiftUI
import HealthKit
import Charts

// MARK: - Data Model for Charts
struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    let type: String 
    
    static func == (lhs: ChartDataPoint, rhs: ChartDataPoint) -> Bool {
        lhs.date == rhs.date && lhs.value == rhs.value && lhs.type == rhs.type
    }
}

// MARK: - HealthKit Extension for History
extension HealthKitManager {
    
    // Fetch historical data for a given time range and interval
    func fetchStatistics(
        for type: HKQuantityTypeIdentifier,
        startDate: Date,
        endDate: Date,
        interval: DateComponents,
        unit: HKUnit,
        completion: @escaping ([ChartDataPoint]) -> Void
    ) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        // Fix: Use a stable anchor date (start of the request day)
        let anchorDate = Calendar.current.startOfDay(for: startDate)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            var points: [ChartDataPoint] = []
            
            if let results = results {
                // Fix: Always enumerate the FULL range to include zero values
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let val = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    points.append(ChartDataPoint(date: statistics.startDate, value: val, type: type.rawValue))
                }
            }
            
            DispatchQueue.main.async {
                print("📊 Chart Sync: Found \(points.count) points for \(type.rawValue)")
                completion(points)
            }
        }
        
        healthStore.execute(query)
    }
    
    // Fetch historical Stand data (Optimized for performance and zero-fill)
    func fetchStandStatistics(startDate: Date, endDate: Date, completion: @escaping ([ChartDataPoint]) -> Void) {
        let standType = HKCategoryType.categoryType(forIdentifier: .appleStandHour)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: standType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let calendar = Calendar.current
            var dailyPoints: [Date: Set<Int>] = [:]
            
            // Pre-fill range with zeros
            var currentDate = calendar.startOfDay(for: startDate)
            while currentDate <= endDate {
                dailyPoints[currentDate] = []
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            if let standSamples = samples as? [HKCategorySample] {
                for sample in standSamples where sample.value == HKCategoryValueAppleStandHour.stood.rawValue {
                    let dayStart = calendar.startOfDay(for: sample.startDate)
                    let hour = calendar.component(.hour, from: sample.startDate)
                    dailyPoints[dayStart]?.insert(hour)
                }
            }
            
            let points = dailyPoints.map { (date, hours) in
                ChartDataPoint(date: date, value: Double(hours.count), type: "Stand")
            }.sorted { $0.date < $1.date }
            
            DispatchQueue.main.async {
                completion(points)
            }
        }
        healthStore.execute(query)
    }
}

// MARK: - Helper Date Extension
extension Date {
    static var startOfWeek: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = calendar.firstWeekday
        return calendar.date(from: components)!
    }
}
