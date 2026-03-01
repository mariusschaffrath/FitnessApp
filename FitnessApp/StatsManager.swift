import SwiftUI
import HealthKit
import Charts

// MARK: - Data Model for Charts
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let type: String // "Steps", "Calories", etc.
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
        
        // Create StatisticsQuery for aggregated data
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: Date.startOfWeek, // Helper needed for anchor
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, _ in
            var points: [ChartDataPoint] = []
            
            results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let val = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                if val > 0 {
                    points.append(ChartDataPoint(date: statistics.startDate, value: val, type: type.rawValue))
                }
            }
            
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
    
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }
    
    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self)!
    }
}
