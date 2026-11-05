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
    /// Steps counted on `stepsDay` (a `StepDay` key), as of the phone's last sync.
    public var stepsToday: Int
    public var stepsDay: String?
    public var stepValue: Double
    /// Today's steps wait for tomorrow (the game's first day). `nil` from phones that paid every
    /// step the next day.
    public var stepsPaidNextDay: Bool?
    /// The newest watch tap batches the phone has applied, oldest first (for batches from watch apps
    /// that don't number them).
    public var appliedBatches: [UUID]
    /// For each watch (by its queue's `source`), the number of the last batch the phone applied:
    /// every batch up to it is in the game.
    public var appliedSequences: [String: Int]?
    /// When the phone sent this snapshot. Orders snapshots and shows how fresh they are.
    public var date: Date
    /// The phone's game clock: `coins` is the balance at this moment. While the phone app is in the
    /// background its clock stays put, so projecting from here matches what it will credit later.
    public var anchor: Date

    public init(coins: Double, income: Double, boostIncome: Double, boostEndsAt: Date?, tapValue: Double,
                offlineCap: TimeInterval, stepsConnected: Bool, stepsToday: Int, stepsDay: String?, stepValue: Double,
                stepsPaidNextDay: Bool? = nil, appliedBatches: [UUID], appliedSequences: [String: Int]? = nil,
                date: Date, anchor: Date) {
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
        self.stepsPaidNextDay = stepsPaidNextDay
        self.appliedBatches = appliedBatches
        self.appliedSequences = appliedSequences
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
        BalanceSnapshot.projected(coins: coins, income: income, boostIncome: boostIncome, boostEndsAt: boostEndsAt,
                                  offlineCap: offlineCap, anchor: anchor, at: now)
    }
}

/// Taps made on the watch, delivered to the phone with `transferUserInfo`
/// (queued, delivered in order, survives either app quitting) and applied there once by `id`.
public struct WatchTapBatch: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let taps: Int
    public let date: Date
    /// The watch that sent it (its queue's `source`) and the batch's number from that watch,
    /// counting up from 1. Batches from one watch arrive in order, so the phone only needs to
    /// remember the last number it applied. `nil` from watch apps that don't number batches.
    public let source: UUID?
    public let sequence: Int?

    public init(id: UUID = UUID(), taps: Int, date: Date, source: UUID? = nil, sequence: Int? = nil) {
        self.id = id
        self.taps = taps
        self.date = date
        self.source = source
        self.sequence = sequence
    }
}

/// The watch's taps that the phone has not confirmed yet, shown on top of the projected balance.
public struct WatchTapQueue: Codable, Equatable, Sendable {
    /// Taps collected for a moment, so one transfer carries many taps.
    public private(set) var unsent = 0
    /// Batches handed to WatchConnectivity, oldest first.
    public private(set) var sent: [WatchTapBatch] = []
    /// This watch, as the phone knows it, and the number the next batch gets.
    public private(set) var source = UUID()
    public private(set) var nextSequence = 1

    /// Batches this old are dropped from the display even if never confirmed.
    static let maximumAge: TimeInterval = 24 * 3_600

    public init() {}

    private enum CodingKeys: String, CodingKey { case unsent, sent, source, nextSequence }

    /// A queue saved by an earlier version starts numbering now, under a new source.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unsent = max(0, c.value(.unsent, default: 0))
        sent = c.value(.sent, default: [])
        source = c.value(.source, default: UUID())
        nextSequence = max(1, c.value(.nextSequence, default: 1))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(unsent, forKey: .unsent)
        try c.encode(sent, forKey: .sent)
        try c.encode(source, forKey: .source)
        try c.encode(nextSequence, forKey: .nextSequence)
    }

    public var pendingTaps: Int { sent.reduce(unsent) { $0 + $1.taps } }

    public mutating func record(taps: Int = 1) {
        unsent += max(0, taps)
    }

    /// Seals the collected taps into a batch for transfer, or returns `nil` if there are none.
    public mutating func seal(at date: Date) -> WatchTapBatch? {
        guard unsent > 0 else { return nil }
        let batch = WatchTapBatch(taps: min(unsent, Tuning.maxWatchTapsPerBatch), date: date,
                                  source: source, sequence: nextSequence)
        nextSequence = nextSequence < Int.max ? nextSequence + 1 : nextSequence
        unsent -= batch.taps
        sent.append(batch)
        return batch
    }

    /// Drops batches the phone has applied. Transfers arrive in the order they were sent,
    /// so every batch sent before the newest confirmed one has been applied as well.
    public mutating func acknowledge(_ snapshot: WatchSnapshot) {
        if let last = snapshot.appliedSequences?[source.uuidString] {
            sent.removeAll { batch in batch.source == source && (batch.sequence ?? .max) <= last }
        }
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
            stepsPaidNextDay: stepsPaidNextDay(today: StepDay.key(for: now)),
            appliedBatches: Array(recentWatchBatches.suffix(16)),
            appliedSequences: watchSequences,
            date: now,
            anchor: lastUpdate)
    }
}
