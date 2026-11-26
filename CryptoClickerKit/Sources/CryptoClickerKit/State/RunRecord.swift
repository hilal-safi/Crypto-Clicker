import Foundation

/// A finished run, as the run history keeps it: from its start (a new game or the last prestige)
/// to the prestige that ended it.
public struct RunRecord: Codable, Hashable, Sendable, Identifiable {
    /// Which run this was: 1 for the first, the one the first prestige ended.
    public var number: Int
    public var startedAt: Date
    public var endedAt: Date
    /// Coins mined in the run.
    public var coins: Double
    /// Prestige points the run earned, and the points earned in all once it ended.
    public var points: Int
    public var totalPoints: Int
    /// Idle income when the run ended, before its points added to production.
    public var income: Double
    /// Miner tiers owned when it ended.
    public var tiers: Int

    public var id: Int { number }

    /// How long the run took.
    public var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }

    public init(number: Int, startedAt: Date, endedAt: Date, coins: Double, points: Int, totalPoints: Int,
                income: Double, tiers: Int) {
        self.number = number
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.coins = coins
        self.points = points
        self.totalPoints = totalPoints
        self.income = income
        self.tiers = tiers
    }
}

/// The record runs of all time. They're kept apart from the run history, which holds only the
/// latest `Tuning.runHistoryLimit` runs, so a record stays one after its run has left the history.
/// The first of any ties keeps a record.
public struct RunRecords: Codable, Equatable, Sendable {
    /// The run that took the least time.
    public internal(set) var fastest: RunRecord?
    /// The run that earned the most prestige points.
    public internal(set) var mostPoints: RunRecord?
    /// The run that mined the most coins.
    public internal(set) var mostCoins: RunRecord?
    /// The run whose miners earned the most a second by its end.
    public internal(set) var highestIncome: RunRecord?

    public init() {}

    /// The records of `runs`, oldest first.
    init(runs: [RunRecord]) {
        for run in runs { count(run) }
    }

    /// Counts a finished run: it takes every record it beats.
    mutating func count(_ run: RunRecord) {
        if fastest.map({ run.duration < $0.duration }) ?? true { fastest = run }
        if mostPoints.map({ run.points > $0.points }) ?? true { mostPoints = run }
        if mostCoins.map({ run.coins > $0.coins }) ?? true { mostCoins = run }
        if highestIncome.map({ run.income > $0.income }) ?? true { highestIncome = run }
    }
}

extension GameState {
    /// The finished run that took the least time, of all time (`runRecords`).
    public var fastestRun: RunRecord? { runRecords.fastest }

    /// The finished run that earned the most prestige points, of all time.
    public var biggestRun: RunRecord? { runRecords.mostPoints }

    /// The finished run that mined the most coins, of all time.
    public var richestRun: RunRecord? { runRecords.mostCoins }

    /// The finished run whose miners earned the most a second by its end, of all time.
    public var mostProductiveRun: RunRecord? { runRecords.highestIncome }
}
