import Foundation
import HealthKit
import CryptoClickerKit

/// Reads daily step totals from Apple Health.
///
/// HealthKit's statistics queries merge iPhone and Apple Watch samples and drop overlaps,
/// so each day has one trustworthy total. The game's ledger pays only for steps above
/// what it has already paid for that day, which makes syncing safe to repeat at any time.
struct StepTracker: Sendable {
    private let store = HKHealthStore()
    private static let stepType = HKQuantityType(.stepCount)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Shows the Health permission sheet (only the first time; later calls return at once).
    /// Health never reveals whether reading was allowed: a denied read simply returns no steps.
    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: [Self.stepType])
    }

    /// Step totals for the last `days` calendar days including today, oldest first.
    /// Days without data are included as zero, so the result always spans the whole window.
    func dailySteps(days: Int, until now: Date = .now) async throws -> [StepDay] {
        let calendar = StepDay.calendar()
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: Self.stepType,
                predicate: HKQuery.predicateForSamples(withStart: start, end: nil)),
            options: .cumulativeSum,
            anchorDate: today,
            intervalComponents: DateComponents(day: 1))
        let collection = try await descriptor.result(for: store)
        var result: [StepDay] = []
        collection.enumerateStatistics(from: start, to: now) { statistics, _ in
            let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
            result.append(StepDay(key: StepDay.key(for: statistics.startDate), steps: Int(steps)))
        }
        return result
    }
}
