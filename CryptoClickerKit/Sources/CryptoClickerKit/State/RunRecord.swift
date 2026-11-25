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

extension GameState {
    /// The finished run that took the least time, the first of any ties.
    public var fastestRun: RunRecord? {
        runHistory.min { $0.duration < $1.duration }
    }

    /// The finished run that earned the most prestige points, the first of any ties.
    public var biggestRun: RunRecord? {
        runHistory.max { $0.points < $1.points }
    }

    /// The finished run that mined the most coins, the first of any ties.
    public var richestRun: RunRecord? {
        runHistory.max { $0.coins < $1.coins }
    }
}
