import Foundation

/// The balance and what it's earning, for the Home Screen and Lock Screen widgets and the Live
/// Activity. They can't run the game, so they project the balance forward from here exactly as the
/// game will credit the time when it next opens: the miners keep earning for a minute after the
/// app closes, or until the Offline Mining limit, and then stop.
public struct BalanceSnapshot: Codable, Hashable, Sendable {
    /// The balance at `anchor`.
    public var coins: Double
    /// Coins per second without a Bull Run.
    public var income: Double
    /// What a Bull Run adds per second, until `boostEndsAt`.
    public var boostIncome: Double
    public var boostEndsAt: Date?
    /// The Offline Mining limit (0 until the power-up is bought).
    public var offlineCap: TimeInterval
    /// The coin's finish, picked in Settings.
    public var finish: CoinFinish
    /// The game's clock: `coins` is the balance at this moment. While the app is closed its clock
    /// stays put, so projecting from here matches what it will credit later.
    public var anchor: Date

    public init(coins: Double, income: Double, boostIncome: Double = 0, boostEndsAt: Date? = nil,
                offlineCap: TimeInterval, finish: CoinFinish = .gold, anchor: Date) {
        self.coins = coins
        self.income = income
        self.boostIncome = boostIncome
        self.boostEndsAt = boostEndsAt
        self.offlineCap = offlineCap
        self.finish = finish
        self.anchor = anchor
    }

    /// How long the miners keep earning once the game clock stops: a minute, or the Offline
    /// Mining limit.
    public var miningTime: TimeInterval { max(offlineCap, Tuning.awayThreshold) }

    /// When the miners stop if the app stays closed.
    public var miningEndsAt: Date { anchor.addingTimeInterval(miningTime) }

    /// The miners are still earning at `now`.
    public func isMining(at now: Date) -> Bool { now < miningEndsAt }

    /// Coins per second at `now`: the income, with a Bull Run while it lasts, or nothing once the
    /// miners have stopped.
    public func income(at now: Date) -> Double {
        guard isMining(at: now) else { return 0 }
        if let boostEndsAt, now < boostEndsAt { return income + boostIncome }
        return income
    }

    /// The balance at `now`, as the game will credit it.
    public func coins(at now: Date) -> Double {
        Self.projected(coins: coins, income: income, boostIncome: boostIncome, boostEndsAt: boostEndsAt,
                       offlineCap: offlineCap, anchor: anchor, at: now)
    }

    /// The balance once the miners stop: what the player finds on opening the game after that.
    public var coinsWhenMiningEnds: Double { coins(at: miningEndsAt) }

    /// How far through their time away the miners are at `now`, from 0 to 1.
    public func miningProgress(at now: Date) -> Double {
        min(1, max(0, now.timeIntervalSince(anchor) / miningTime))
    }

    /// Moments for a widget's timeline: `now`, then about every `spacing` (further apart when the
    /// miners have long to go, so there are never more than `limit`), and the moment they stop.
    /// Just `now` once they have stopped.
    public func timelineDates(from now: Date, spacing: TimeInterval = 300, limit: Int = 60) -> [Date] {
        let end = miningEndsAt
        guard now < end, limit >= 2 else { return [now] }
        let span = end.timeIntervalSince(now)
        let step = max(spacing, span / Double(limit - 1))
        var dates: [Date] = []
        var offset = 0.0
        while offset < span - 1 && dates.count < limit - 1 {
            dates.append(now.addingTimeInterval(offset))
            offset += step
        }
        dates.append(end)
        return dates
    }

    /// The balance `seconds` after the game clock stopped at `anchor` with `coins`: the income for
    /// the time the miners keep earning, and a Bull Run's extra for as long as it lasted.
    static func projected(coins: Double, income: Double, boostIncome: Double, boostEndsAt: Date?,
                          offlineCap: TimeInterval, anchor: Date, at now: Date) -> Double {
        let elapsed = min(max(0, now.timeIntervalSince(anchor)), max(offlineCap, Tuning.awayThreshold))
        var boosted = 0.0
        if let boostEndsAt { boosted = min(elapsed, max(0, boostEndsAt.timeIntervalSince(anchor))) }
        return coins + income * elapsed + boostIncome * boosted
    }

    private enum CodingKeys: String, CodingKey {
        case coins, income, boostIncome, boostEndsAt, offlineCap, finish, anchor
    }

    /// Lenient, like the save: a snapshot left by another version of the app still reads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = c.value(.coins, default: 0)
        income = c.value(.income, default: 0)
        boostIncome = c.value(.boostIncome, default: 0)
        boostEndsAt = c.value(.boostEndsAt, default: nil)
        offlineCap = c.value(.offlineCap, default: 0)
        finish = c.value(.finish, default: .gold)
        anchor = try c.decode(Date.self, forKey: .anchor)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(coins, forKey: .coins)
        try c.encode(income, forKey: .income)
        try c.encode(boostIncome, forKey: .boostIncome)
        try c.encodeIfPresent(boostEndsAt, forKey: .boostEndsAt)
        try c.encode(offlineCap, forKey: .offlineCap)
        try c.encode(finish, forKey: .finish)
        try c.encode(anchor, forKey: .anchor)
    }
}

extension GameState {
    /// The balance and its income at the game clock, for the widgets and the Live Activity, with
    /// the coin in `finish`.
    public func balanceSnapshot(finish: CoinFinish = .gold) -> BalanceSnapshot {
        let rates = incomeRates
        let boost = activeBoost(at: lastUpdate)
        return BalanceSnapshot(coins: coins, income: rates.normal,
                               boostIncome: boost == nil ? 0 : rates.boosted - rates.normal,
                               boostEndsAt: boost?.endsAt, offlineCap: offlineCap, finish: finish, anchor: lastUpdate)
    }
}
