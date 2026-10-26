import Foundation

/// The phone's latest state, sent to Apple Watch. The watch projects the balance
/// forward on its own, so it stays live between updates.
public struct WatchSnapshot: Codable, Equatable, Sendable {
    public var coins: Double
    /// Idle income per second without boosts.
    public var income: Double
    /// Extra income per second until `boostEndsAt`.
    public var boostIncome: Double
    public var boostEndsAt: Date?
    public var tapValue: Double
    /// The phone's Offline Mining limit (0 until the power-up is bought).
    public var offlineCap: TimeInterval
    public var stepsConnected: Bool
    /// Steps already paid for on `stepsDay` (a `StepDay` key), as of the phone's last sync.
    public var stepsToday: Int
    public var stepsDay: String?
    public var stepValue: Double
    /// The newest watch tap batches the phone has applied, oldest first.
    public var appliedBatches: [UUID]
    /// When the phone sent this snapshot. Orders snapshots and shows how fresh they are.
    public var date: Date
    /// The phone's game clock: `coins` is the balance at this moment. While the phone app is in the
    /// background its clock stays put, so projecting from here matches what it will credit later.
    public var anchor: Date

    public init(coins: Double, income: Double, boostIncome: Double, boostEndsAt: Date?, tapValue: Double,
                offlineCap: TimeInterval, stepsConnected: Bool, stepsToday: Int, stepsDay: String?, stepValue: Double,
                appliedBatches: [UUID], date: Date, anchor: Date) {
        self.coins = coins
        self.income = income
        self.boostIncome = boostIncome
        self.boostEndsAt = boostEndsAt
        self.tapValue = tapValue
        self.offlineCap = offlineCap
        self.stepsConnected = stepsConnected
        self.stepsToday = stepsToday
        self.stepsDay = stepsDay
        self.stepValue = stepValue
        self.appliedBatches = appliedBatches
        self.date = date
        self.anchor = anchor
    }

    /// Income per second at `now`, including a boost that is still running.
    public func income(at now: Date) -> Double {
        guard let boostEndsAt, now < boostEndsAt else { return income }
        return income + boostIncome
    }

    /// The phone's balance at `now`: while it is closed it keeps earning for its first minute and
    /// then up to its Offline Mining limit, exactly as it will credit the time when it next opens.
    public func projectedCoins(at now: Date) -> Double {
        let elapsed = min(max(0, now.timeIntervalSince(anchor)), max(offlineCap, Tuning.awayThreshold))
        var boosted = 0.0
        if let boostEndsAt { boosted = min(elapsed, max(0, boostEndsAt.timeIntervalSince(anchor))) }
        return coins + income * elapsed + boostIncome * boosted
    }
}

/// Taps made on the watch, delivered to the phone with `transferUserInfo`
/// (queued, delivered in order, survives either app quitting) and applied there once by `id`.
public struct WatchTapBatch: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let taps: Int
    public let date: Date

    public init(id: UUID = UUID(), taps: Int, date: Date) {
        self.id = id
        self.taps = taps
        self.date = date
    }
}

/// The watch's taps that the phone has not confirmed yet, shown on top of the projected balance.
public struct WatchTapQueue: Codable, Equatable, Sendable {
    /// Taps collected for a moment, so one transfer carries many taps.
    public private(set) var unsent = 0
    /// Batches handed to WatchConnectivity, oldest first.
    public private(set) var sent: [WatchTapBatch] = []

    /// Batches this old are dropped from the display even if never confirmed.
    static let maximumAge: TimeInterval = 24 * 3_600

    public init() {}

    public var pendingTaps: Int { sent.reduce(unsent) { $0 + $1.taps } }

    public mutating func record(taps: Int = 1) {
        unsent += max(0, taps)
    }

    /// Seals the collected taps into a batch for transfer, or returns `nil` if there are none.
    public mutating func seal(at date: Date) -> WatchTapBatch? {
        guard unsent > 0 else { return nil }
        let batch = WatchTapBatch(taps: min(unsent, Tuning.maxWatchTapsPerBatch), date: date)
        unsent -= batch.taps
        sent.append(batch)
        return batch
    }

    /// Drops batches the phone has applied. Transfers arrive in the order they were sent,
    /// so every batch sent before the newest confirmed one has been applied as well.
    public mutating func acknowledge(_ snapshot: WatchSnapshot) {
        let applied = Set(snapshot.appliedBatches)
        if let newest = sent.lastIndex(where: { applied.contains($0.id) }) {
            sent.removeSubrange(...newest)
        }
        sent.removeAll { snapshot.date.timeIntervalSince($0.date) > Self.maximumAge }
    }
}

/// Dictionary keys and JSON coding for WatchConnectivity payloads.
public enum WatchPayload {
    public static let snapshotKey = "snapshot"
    public static let tapBatchKey = "tapBatch"
    public static let refreshKey = "refresh"

    /// Wraps a value as JSON `Data` under `key`, ready for WatchConnectivity.
    public static func make<T: Encodable>(_ value: T, key: String) -> [String: Any]? {
        guard let data = try? GameCoding.encoder().encode(value) else { return nil }
        return [key: data]
    }

    public static func read<T: Decodable>(_ type: T.Type, key: String, from payload: [String: Any]) -> T? {
        guard let data = payload[key] as? Data else { return nil }
        return try? GameCoding.decoder().decode(type, from: data)
    }
}

extension GameState {
    /// The snapshot to send at `now`. Its balance is anchored at `lastUpdate`, the game clock.
    public func watchSnapshot(at now: Date) -> WatchSnapshot {
        let rates = incomeRates
        let boost = activeBoost(at: lastUpdate)
        return WatchSnapshot(
            coins: coins,
            income: rates.normal,
            boostIncome: boost == nil ? 0 : rates.boosted - rates.normal,
            boostEndsAt: boost?.endsAt,
            tapValue: tapValue(at: lastUpdate),
            offlineCap: offlineCap,
            stepsConnected: steps.isConnected,
            stepsToday: steps.todaySteps,
            stepsDay: steps.todayKey,
            stepValue: stepValue,
            appliedBatches: Array(recentWatchBatches.suffix(16)),
            date: now,
            anchor: lastUpdate)
    }
}
