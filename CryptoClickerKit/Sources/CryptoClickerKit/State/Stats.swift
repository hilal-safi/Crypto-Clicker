import Foundation

/// Lifetime statistics. Nothing here is reset by a Hard Fork except `runCoins`.
public struct Stats: Codable, Equatable, Sendable {
    /// Every coin ever earned, across all runs. Drives fork points.
    public internal(set) var lifetimeCoins: Double = 0
    /// Coins earned since the last Hard Fork. Reveals upgrades.
    public internal(set) var runCoins: Double = 0
    public internal(set) var spent: Double = 0
    public internal(set) var peakIncome: Double = 0

    public internal(set) var taps = 0
    public internal(set) var bestTap: Double = 0

    public internal(set) var lifetimeSteps = 0
    public internal(set) var bestDaySteps = 0

    public internal(set) var maxOwned: [MinerID: Int] = [:]
    public internal(set) var maxTotalMiners = 0
    public internal(set) var maxUpgrades = 0

    public internal(set) var blackjackHands = 0
    public internal(set) var blackjackWins = 0
    public internal(set) var blackjackNaturals = 0
    public internal(set) var tetrisGames = 0
    public internal(set) var tetrisLines = 0
    public internal(set) var tetrisBestScore = 0

    public internal(set) var tokensBought: [TokenID: Int] = [:]
    public internal(set) var airdrops = 0
    public internal(set) var forksPerformed = 0

    public internal(set) var earnedFromTaps: Double = 0
    public internal(set) var earnedFromIdle: Double = 0
    public internal(set) var earnedOffline: Double = 0
    public internal(set) var earnedFromSteps: Double = 0
    public internal(set) var earnedFromGames: Double = 0
    public internal(set) var earnedFromAirdrops: Double = 0

    public init() {}

    public var totalTokensBought: Int { tokensBought.values.reduce(0, +) }

    private enum CodingKeys: String, CodingKey {
        case lifetimeCoins, runCoins, spent, peakIncome, taps, bestTap, lifetimeSteps, bestDaySteps
        case maxOwned, maxTotalMiners, maxUpgrades
        case blackjackHands, blackjackWins, blackjackNaturals, tetrisGames, tetrisLines, tetrisBestScore
        case tokensBought, airdrops, forksPerformed
        case earnedFromTaps, earnedFromIdle, earnedOffline, earnedFromSteps, earnedFromGames, earnedFromAirdrops
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lifetimeCoins = c.value(.lifetimeCoins, default: 0)
        runCoins = c.value(.runCoins, default: 0)
        spent = c.value(.spent, default: 0)
        peakIncome = c.value(.peakIncome, default: 0)
        taps = c.value(.taps, default: 0)
        bestTap = c.value(.bestTap, default: 0)
        lifetimeSteps = c.value(.lifetimeSteps, default: 0)
        bestDaySteps = c.value(.bestDaySteps, default: 0)
        maxOwned = c.enumKeyed(.maxOwned, as: MinerID.self)
        maxTotalMiners = c.value(.maxTotalMiners, default: 0)
        maxUpgrades = c.value(.maxUpgrades, default: 0)
        blackjackHands = c.value(.blackjackHands, default: 0)
        blackjackWins = c.value(.blackjackWins, default: 0)
        blackjackNaturals = c.value(.blackjackNaturals, default: 0)
        tetrisGames = c.value(.tetrisGames, default: 0)
        tetrisLines = c.value(.tetrisLines, default: 0)
        tetrisBestScore = c.value(.tetrisBestScore, default: 0)
        tokensBought = c.enumKeyed(.tokensBought, as: TokenID.self)
        airdrops = c.value(.airdrops, default: 0)
        forksPerformed = c.value(.forksPerformed, default: 0)
        earnedFromTaps = c.value(.earnedFromTaps, default: 0)
        earnedFromIdle = c.value(.earnedFromIdle, default: 0)
        earnedOffline = c.value(.earnedOffline, default: 0)
        earnedFromSteps = c.value(.earnedFromSteps, default: 0)
        earnedFromGames = c.value(.earnedFromGames, default: 0)
        earnedFromAirdrops = c.value(.earnedFromAirdrops, default: 0)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lifetimeCoins, forKey: .lifetimeCoins)
        try c.encode(runCoins, forKey: .runCoins)
        try c.encode(spent, forKey: .spent)
        try c.encode(peakIncome, forKey: .peakIncome)
        try c.encode(taps, forKey: .taps)
        try c.encode(bestTap, forKey: .bestTap)
        try c.encode(lifetimeSteps, forKey: .lifetimeSteps)
        try c.encode(bestDaySteps, forKey: .bestDaySteps)
        try c.encode(maxOwned.stringKeyed, forKey: .maxOwned)
        try c.encode(maxTotalMiners, forKey: .maxTotalMiners)
        try c.encode(maxUpgrades, forKey: .maxUpgrades)
        try c.encode(blackjackHands, forKey: .blackjackHands)
        try c.encode(blackjackWins, forKey: .blackjackWins)
        try c.encode(blackjackNaturals, forKey: .blackjackNaturals)
        try c.encode(tetrisGames, forKey: .tetrisGames)
        try c.encode(tetrisLines, forKey: .tetrisLines)
        try c.encode(tetrisBestScore, forKey: .tetrisBestScore)
        try c.encode(tokensBought.stringKeyed, forKey: .tokensBought)
        try c.encode(airdrops, forKey: .airdrops)
        try c.encode(forksPerformed, forKey: .forksPerformed)
        try c.encode(earnedFromTaps, forKey: .earnedFromTaps)
        try c.encode(earnedFromIdle, forKey: .earnedFromIdle)
        try c.encode(earnedOffline, forKey: .earnedOffline)
        try c.encode(earnedFromSteps, forKey: .earnedFromSteps)
        try c.encode(earnedFromGames, forKey: .earnedFromGames)
        try c.encode(earnedFromAirdrops, forKey: .earnedFromAirdrops)
    }
}
