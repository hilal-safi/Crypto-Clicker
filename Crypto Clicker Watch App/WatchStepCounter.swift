import Foundation
import HealthKit
import CryptoClickerKit

/// Today's step count as Apple Watch sees it, for a live display only.
/// Steps are paid on the iPhone, which reads the combined iPhone and Apple Watch total.
struct WatchStepCounter: Sendable {
    private let store = HKHealthStore()
    private static let stepType = HKQuantityType(.stepCount)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: [Self.stepType])
    }

    func todaySteps(now: Date = .now) async throws -> Int {
        let start = StepDay.calendar().startOfDay(for: now)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.stepType,
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: nil)),
            options: .cumulativeSum)
        let statistics = try await descriptor.result(for: store)
        return Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
    }
}
