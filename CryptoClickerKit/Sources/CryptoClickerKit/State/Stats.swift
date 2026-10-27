import Foundation

/// Lifetime statistics. Nothing here is reset by a prestige except `runCoins`.
public struct Stats: Codable, Equatable, Sendable {
    /// Every coin ever earned, across all runs. Drives prestige points.
    public internal(set) var lifetimeCoins: Double = 0
    /// Coins earned since the last prestige. Reveals upgrades.
    public internal(set) var runCoins: Double = 0
    public internal(set) var spent: Double = 0
    public internal(set) var peakIncome: Double = 0

    public internal(set) var taps = 0
    public internal(set) var bestTap: Double = 0
    /// Longest run of quick taps.
    public internal(set) var bestCombo = 0

    public internal(set) var lifetimeSteps = 0
    public internal(set) var bestDaySteps = 0

    public internal(set) var maxOwned: [MinerID: Int] = [:]
    public internal(set) var maxTotalMiners = 0
    public internal(set) var maxUpgrades = 0
    /// Miner units bought over all time.
    public internal(set) var minersBought = 0
    /// Miner Mk upgrades bought over all time.
    public internal(set) var minerUpgradesBought = 0

    public internal(set) var blackjackHands = 0
    public internal(set) var blackjackWins = 0
    public internal(set) var blackjackNaturals = 0
    public internal(set) var tetrisGames = 0
    public internal(set) var tetrisLines = 0
    public internal(set) var tetrisBestScore = 0
    public internal(set) var slotsSpins = 0
    public internal(set) var slotsWins = 0
    public internal(set) var slotsJackpots = 0
    public internal(set) var snakeGames = 0
    public internal(set) var snakeBestScore = 0
    public internal(set) var snakeCoinsEaten = 0
    public internal(set) var brickBreakerGames = 0
    public internal(set) var brickBreakerBestScore = 0
    public internal(set) var bricksBroken = 0
    public internal(set) var bubbleGames = 0
    public internal(set) var bubbleBestScore = 0
    public internal(set) var bubblesPopped = 0
    public internal(set) var merge2048Games = 0
    public internal(set) var merge2048BestScore = 0
    public internal(set) var merge2048BestTile = 0
    /// Points scored in 2048 over all games.
    public internal(set) var merge2048Points = 0

    public internal(set) var tokensBought: [TokenID: Int] = [:]
    public internal(set) var tokensSold = 0
    /// Coins received for tokens sold on the market.
    public internal(set) var coinsFromSales: Double = 0
    public internal(set) var airdrops = 0
    public internal(set) var whaleAirdrops = 0
    public internal(set) var prestiges = 0
    public internal(set) var questsCompleted = 0
    public internal(set) var longestStreak = 0

    public internal(set) var earnedFromTaps: Double = 0
    public internal(set) var earnedFromIdle: Double = 0
    public internal(set) var earnedOffline: Double = 0
    public internal(set) var earnedFromSteps: Double = 0
    public internal(set) var earnedFromGames: Double = 0
    public internal(set) var earnedFromAirdrops: Double = 0
    /// Daily quests and the daily reward.
    public internal(set) var earnedFromDaily: Double = 0

    public init() {}

    public var totalTokensBought: Int { tokensBought.values.reduce(0, +) }

    private enum CodingKeys: String, CodingKey {
        case lifetimeCoins, runCoins, spent, peakIncome, taps, bestTap, bestCombo, lifetimeSteps, bestDaySteps
        case maxOwned, maxTotalMiners, maxUpgrades, minersBought, minerUpgradesBought
        case blackjackHands, blackjackWins, blackjackNaturals, tetrisGames, tetrisLines, tetrisBestScore
        case slotsSpins, slotsWins, slotsJackpots, snakeGames, snakeBestScore, snakeCoinsEaten
        case brickBreakerGames, brickBreakerBestScore, bricksBroken, bubbleGames, bubbleBestScore, bubblesPopped
        case merge2048Games, merge2048BestScore, merge2048BestTile, merge2048Points
        case tokensBought, tokensSold, coinsFromSales, airdrops, whaleAirdrops, questsCompleted, longestStreak
        case prestiges = "forksPerformed" // Saved under its old Hard Fork name.
        case earnedFromTaps, earnedFromIdle, earnedOffline, earnedFromSteps, earnedFromGames, earnedFromAirdrops
        case earnedFromDaily
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lifetimeCoins = c.value(.lifetimeCoins, default: 0)
        runCoins = c.value(.runCoins, default: 0)
        spent = c.value(.spent, default: 0)
        peakIncome = c.value(.peakIncome, default: 0)
        taps = c.value(.taps, default: 0)
        bestTap = c.value(.bestTap, default: 0)
        bestCombo = c.value(.bestCombo, default: 0)
        lifetimeSteps = c.value(.lifetimeSteps, default: 0)
        bestDaySteps = c.value(.bestDaySteps, default: 0)
        maxOwned = c.enumKeyed(.maxOwned, as: MinerID.self)
        maxTotalMiners = c.value(.maxTotalMiners, default: 0)
        maxUpgrades = c.value(.maxUpgrades, default: 0)
        minersBought = c.value(.minersBought, default: 0)
        minerUpgradesBought = c.value(.minerUpgradesBought, default: 0)
        blackjackHands = c.value(.blackjackHands, default: 0)
        blackjackWins = c.value(.blackjackWins, default: 0)
        blackjackNaturals = c.value(.blackjackNaturals, default: 0)
        tetrisGames = c.value(.tetrisGames, default: 0)
        tetrisLines = c.value(.tetrisLines, default: 0)
        tetrisBestScore = c.value(.tetrisBestScore, default: 0)
        slotsSpins = c.value(.slotsSpins, default: 0)
        slotsWins = c.value(.slotsWins, default: 0)
        slotsJackpots = c.value(.slotsJackpots, default: 0)
        snakeGames = c.value(.snakeGames, default: 0)
        snakeBestScore = c.value(.snakeBestScore, default: 0)
        snakeCoinsEaten = c.value(.snakeCoinsEaten, default: 0)
        brickBreakerGames = c.value(.brickBreakerGames, default: 0)
        brickBreakerBestScore = c.value(.brickBreakerBestScore, default: 0)
        bricksBroken = c.value(.bricksBroken, default: 0)
        bubbleGames = c.value(.bubbleGames, default: 0)
        bubbleBestScore = c.value(.bubbleBestScore, default: 0)
        bubblesPopped = c.value(.bubblesPopped, default: 0)
        merge2048Games = c.value(.merge2048Games, default: 0)
        merge2048BestScore = c.value(.merge2048BestScore, default: 0)
        merge2048BestTile = c.value(.merge2048BestTile, default: 0)
        merge2048Points = c.value(.merge2048Points, default: 0)
        tokensBought = c.enumKeyed(.tokensBought, as: TokenID.self)
        tokensSold = c.value(.tokensSold, default: 0)
        coinsFromSales = c.value(.coinsFromSales, default: 0)
        airdrops = c.value(.airdrops, default: 0)
        whaleAirdrops = c.value(.whaleAirdrops, default: 0)
        prestiges = c.value(.prestiges, default: 0)
        questsCompleted = c.value(.questsCompleted, default: 0)
        longestStreak = c.value(.longestStreak, default: 0)
        earnedFromTaps = c.value(.earnedFromTaps, default: 0)
        earnedFromIdle = c.value(.earnedFromIdle, default: 0)
        earnedOffline = c.value(.earnedOffline, default: 0)
        earnedFromSteps = c.value(.earnedFromSteps, default: 0)
        earnedFromGames = c.value(.earnedFromGames, default: 0)
        earnedFromAirdrops = c.value(.earnedFromAirdrops, default: 0)
        earnedFromDaily = c.value(.earnedFromDaily, default: 0)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lifetimeCoins, forKey: .lifetimeCoins)
        try c.encode(runCoins, forKey: .runCoins)
        try c.encode(spent, forKey: .spent)
        try c.encode(peakIncome, forKey: .peakIncome)
        try c.encode(taps, forKey: .taps)
        try c.encode(bestTap, forKey: .bestTap)
        try c.encode(bestCombo, forKey: .bestCombo)
        try c.encode(lifetimeSteps, forKey: .lifetimeSteps)
        try c.encode(bestDaySteps, forKey: .bestDaySteps)
        try c.encode(maxOwned.stringKeyed, forKey: .maxOwned)
        try c.encode(maxTotalMiners, forKey: .maxTotalMiners)
        try c.encode(maxUpgrades, forKey: .maxUpgrades)
        try c.encode(minersBought, forKey: .minersBought)
        try c.encode(minerUpgradesBought, forKey: .minerUpgradesBought)
        try c.encode(blackjackHands, forKey: .blackjackHands)
        try c.encode(blackjackWins, forKey: .blackjackWins)
        try c.encode(blackjackNaturals, forKey: .blackjackNaturals)
        try c.encode(tetrisGames, forKey: .tetrisGames)
        try c.encode(tetrisLines, forKey: .tetrisLines)
        try c.encode(tetrisBestScore, forKey: .tetrisBestScore)
        try c.encode(slotsSpins, forKey: .slotsSpins)
        try c.encode(slotsWins, forKey: .slotsWins)
        try c.encode(slotsJackpots, forKey: .slotsJackpots)
        try c.encode(snakeGames, forKey: .snakeGames)
        try c.encode(snakeBestScore, forKey: .snakeBestScore)
        try c.encode(snakeCoinsEaten, forKey: .snakeCoinsEaten)
        try c.encode(brickBreakerGames, forKey: .brickBreakerGames)
        try c.encode(brickBreakerBestScore, forKey: .brickBreakerBestScore)
        try c.encode(bricksBroken, forKey: .bricksBroken)
        try c.encode(bubbleGames, forKey: .bubbleGames)
        try c.encode(bubbleBestScore, forKey: .bubbleBestScore)
        try c.encode(bubblesPopped, forKey: .bubblesPopped)
        try c.encode(merge2048Games, forKey: .merge2048Games)
        try c.encode(merge2048BestScore, forKey: .merge2048BestScore)
        try c.encode(merge2048BestTile, forKey: .merge2048BestTile)
        try c.encode(merge2048Points, forKey: .merge2048Points)
        try c.encode(tokensBought.stringKeyed, forKey: .tokensBought)
        try c.encode(tokensSold, forKey: .tokensSold)
        try c.encode(coinsFromSales, forKey: .coinsFromSales)
        try c.encode(airdrops, forKey: .airdrops)
        try c.encode(whaleAirdrops, forKey: .whaleAirdrops)
        try c.encode(prestiges, forKey: .prestiges)
        try c.encode(questsCompleted, forKey: .questsCompleted)
        try c.encode(longestStreak, forKey: .longestStreak)
        try c.encode(earnedFromTaps, forKey: .earnedFromTaps)
        try c.encode(earnedFromIdle, forKey: .earnedFromIdle)
        try c.encode(earnedOffline, forKey: .earnedOffline)
        try c.encode(earnedFromSteps, forKey: .earnedFromSteps)
        try c.encode(earnedFromGames, forKey: .earnedFromGames)
        try c.encode(earnedFromAirdrops, forKey: .earnedFromAirdrops)
        try c.encode(earnedFromDaily, forKey: .earnedFromDaily)
    }
}
