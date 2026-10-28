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
    /// Hands won in a row right now (a push doesn't end the streak).
    public internal(set) var blackjackStreak = 0
    public internal(set) var blackjackBestStreak = 0
    /// The most a round has won, in coins: tokens at list price plus the coin bonus.
    public internal(set) var blackjackBiggestWin: Double = 0
    public internal(set) var tetrisGames = 0
    public internal(set) var tetrisLines = 0
    public internal(set) var tetrisBestScore = 0
    public internal(set) var slotsSpins = 0
    public internal(set) var slotsWins = 0
    public internal(set) var slotsJackpots = 0
    /// Tokens bet and paid at Crypto Slots, valued in coins at list price.
    public internal(set) var slotsWagered: Double = 0
    public internal(set) var slotsPaidOut: Double = 0
    /// The biggest win, as a multiple of the bet.
    public internal(set) var slotsBestMultiple = 0
    public internal(set) var snakeGames = 0
    public internal(set) var snakeBestScore = 0
    public internal(set) var snakeCoinsEaten = 0
    public internal(set) var snakeLongest = 0
    public internal(set) var brickBreakerGames = 0
    public internal(set) var brickBreakerBestScore = 0
    public internal(set) var bricksBroken = 0
    public internal(set) var brickBreakerBestLevel = 0
    public internal(set) var bubbleGames = 0
    public internal(set) var bubbleBestScore = 0
    public internal(set) var bubblesPopped = 0
    /// Most bubbles cleared by one shot.
    public internal(set) var bubbleBestShot = 0
    public internal(set) var merge2048Games = 0
    public internal(set) var merge2048BestScore = 0
    public internal(set) var merge2048BestTile = 0
    /// Points scored in 2048 over all games.
    public internal(set) var merge2048Points = 0
    public internal(set) var moonFlights = 0
    public internal(set) var moonCashOuts = 0
    public internal(set) var moonBestMultiplier: Double = 0
    /// Tokens bet and paid at To the Moon, valued in coins at list price.
    public internal(set) var moonWagered: Double = 0
    public internal(set) var moonPaidOut: Double = 0
    /// The most a flight has won, in coins: profit in tokens at list price plus the coin bonus.
    public internal(set) var moonBiggestWin: Double = 0
    public internal(set) var pumpDumpGames = 0
    public internal(set) var pumpDumpBestScore = 0
    public internal(set) var pumpDumpCoinsHit = 0
    public internal(set) var pumpDumpScamsHit = 0
    public internal(set) var pumpDumpBestCombo = 0
    /// Token Swap levels played to the end, won or lost.
    public internal(set) var tokenSwapLevelsPlayed = 0
    /// The furthest round a Pump and Dump run has reached.
    public internal(set) var pumpDumpBestRound = 0
    public internal(set) var pokerHands = 0
    /// Hands that paid (a pair of jacks or better).
    public internal(set) var pokerWins = 0
    /// Tokens bet and paid at Video Poker, valued in coins at list price.
    public internal(set) var pokerWagered: Double = 0
    public internal(set) var pokerPaidOut: Double = 0
    /// The best hand made, as a `PokerHand` raw value (0 before any).
    public internal(set) var pokerBestHand = 0
    public internal(set) var pokerRoyals = 0
    /// The most a hand has won, in coins: profit in tokens at list price plus the coin bonus.
    public internal(set) var pokerBiggestWin: Double = 0
    /// Classic Token Swap rounds, and the best Classic score.
    public internal(set) var tokenSwapGames = 0
    public internal(set) var tokenSwapBestScore = 0
    /// Tokens matched in Token Swap over every mode.
    public internal(set) var tokenSwapTokens = 0
    /// The most waves one swap set off, in any mode.
    public internal(set) var tokenSwapBestChain = 0
    /// Specials set off in any mode (saved under the name it had when there was only the Blast).
    public internal(set) var tokenSwapBlasts = 0

    public internal(set) var tokensBought: [TokenID: Int] = [:]
    public internal(set) var tokensSold = 0
    /// Coins received for tokens sold on the market.
    public internal(set) var coinsFromSales: Double = 0
    public internal(set) var airdrops = 0
    public internal(set) var whaleAirdrops = 0
    public internal(set) var prestiges = 0
    public internal(set) var questsCompleted = 0
    public internal(set) var longestStreak = 0
    /// Daily challenges completed.
    public internal(set) var challengesCompleted = 0

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
        case blackjackStreak, blackjackBestStreak, blackjackBiggestWin, slotsWagered, slotsPaidOut, slotsBestMultiple
        case snakeLongest, brickBreakerBestLevel, bubbleBestShot
        case slotsSpins, slotsWins, slotsJackpots, snakeGames, snakeBestScore, snakeCoinsEaten
        case brickBreakerGames, brickBreakerBestScore, bricksBroken, bubbleGames, bubbleBestScore, bubblesPopped
        case merge2048Games, merge2048BestScore, merge2048BestTile, merge2048Points
        case moonFlights, moonCashOuts, moonBestMultiplier, moonWagered, moonPaidOut, moonBiggestWin
        case pumpDumpGames, pumpDumpBestScore, pumpDumpCoinsHit, pumpDumpScamsHit, pumpDumpBestCombo, pumpDumpBestRound
        case tokenSwapLevelsPlayed
        case pokerHands, pokerWins, pokerWagered, pokerPaidOut, pokerBestHand, pokerRoyals, pokerBiggestWin
        case tokenSwapGames, tokenSwapBestScore, tokenSwapTokens, tokenSwapBestChain, tokenSwapBlasts
        case tokensBought, tokensSold, coinsFromSales, airdrops, whaleAirdrops, questsCompleted, longestStreak
        case prestiges = "forksPerformed" // Saved under its old Hard Fork name.
        case earnedFromTaps, earnedFromIdle, earnedOffline, earnedFromSteps, earnedFromGames, earnedFromAirdrops
        case earnedFromDaily, challengesCompleted
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
        blackjackStreak = c.value(.blackjackStreak, default: 0)
        blackjackBestStreak = c.value(.blackjackBestStreak, default: 0)
        blackjackBiggestWin = c.value(.blackjackBiggestWin, default: 0)
        slotsWagered = c.value(.slotsWagered, default: 0)
        slotsPaidOut = c.value(.slotsPaidOut, default: 0)
        slotsBestMultiple = c.value(.slotsBestMultiple, default: 0)
        snakeLongest = c.value(.snakeLongest, default: 0)
        brickBreakerBestLevel = c.value(.brickBreakerBestLevel, default: 0)
        bubbleBestShot = c.value(.bubbleBestShot, default: 0)
        moonFlights = c.value(.moonFlights, default: 0)
        moonCashOuts = c.value(.moonCashOuts, default: 0)
        moonBestMultiplier = c.value(.moonBestMultiplier, default: 0)
        moonWagered = c.value(.moonWagered, default: 0)
        moonPaidOut = c.value(.moonPaidOut, default: 0)
        moonBiggestWin = c.value(.moonBiggestWin, default: 0)
        pumpDumpGames = c.value(.pumpDumpGames, default: 0)
        pumpDumpBestScore = c.value(.pumpDumpBestScore, default: 0)
        pumpDumpCoinsHit = c.value(.pumpDumpCoinsHit, default: 0)
        pumpDumpScamsHit = c.value(.pumpDumpScamsHit, default: 0)
        pumpDumpBestCombo = c.value(.pumpDumpBestCombo, default: 0)
        pumpDumpBestRound = c.value(.pumpDumpBestRound, default: 0)
        tokenSwapLevelsPlayed = c.value(.tokenSwapLevelsPlayed, default: 0)
        pokerHands = c.value(.pokerHands, default: 0)
        pokerWins = c.value(.pokerWins, default: 0)
        pokerWagered = c.value(.pokerWagered, default: 0)
        pokerPaidOut = c.value(.pokerPaidOut, default: 0)
        pokerBestHand = c.value(.pokerBestHand, default: 0)
        pokerRoyals = c.value(.pokerRoyals, default: 0)
        pokerBiggestWin = c.value(.pokerBiggestWin, default: 0)
        tokenSwapGames = c.value(.tokenSwapGames, default: 0)
        tokenSwapBestScore = c.value(.tokenSwapBestScore, default: 0)
        tokenSwapTokens = c.value(.tokenSwapTokens, default: 0)
        tokenSwapBestChain = c.value(.tokenSwapBestChain, default: 0)
        tokenSwapBlasts = c.value(.tokenSwapBlasts, default: 0)
        challengesCompleted = c.value(.challengesCompleted, default: 0)
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
        try c.encode(blackjackStreak, forKey: .blackjackStreak)
        try c.encode(blackjackBestStreak, forKey: .blackjackBestStreak)
        try c.encode(blackjackBiggestWin, forKey: .blackjackBiggestWin)
        try c.encode(slotsWagered, forKey: .slotsWagered)
        try c.encode(slotsPaidOut, forKey: .slotsPaidOut)
        try c.encode(slotsBestMultiple, forKey: .slotsBestMultiple)
        try c.encode(snakeLongest, forKey: .snakeLongest)
        try c.encode(brickBreakerBestLevel, forKey: .brickBreakerBestLevel)
        try c.encode(bubbleBestShot, forKey: .bubbleBestShot)
        try c.encode(moonFlights, forKey: .moonFlights)
        try c.encode(moonCashOuts, forKey: .moonCashOuts)
        try c.encode(moonBestMultiplier, forKey: .moonBestMultiplier)
        try c.encode(moonWagered, forKey: .moonWagered)
        try c.encode(moonPaidOut, forKey: .moonPaidOut)
        try c.encode(moonBiggestWin, forKey: .moonBiggestWin)
        try c.encode(pumpDumpGames, forKey: .pumpDumpGames)
        try c.encode(pumpDumpBestScore, forKey: .pumpDumpBestScore)
        try c.encode(pumpDumpCoinsHit, forKey: .pumpDumpCoinsHit)
        try c.encode(pumpDumpScamsHit, forKey: .pumpDumpScamsHit)
        try c.encode(pumpDumpBestCombo, forKey: .pumpDumpBestCombo)
        try c.encode(pumpDumpBestRound, forKey: .pumpDumpBestRound)
        try c.encode(tokenSwapLevelsPlayed, forKey: .tokenSwapLevelsPlayed)
        try c.encode(pokerHands, forKey: .pokerHands)
        try c.encode(pokerWins, forKey: .pokerWins)
        try c.encode(pokerWagered, forKey: .pokerWagered)
        try c.encode(pokerPaidOut, forKey: .pokerPaidOut)
        try c.encode(pokerBestHand, forKey: .pokerBestHand)
        try c.encode(pokerRoyals, forKey: .pokerRoyals)
        try c.encode(pokerBiggestWin, forKey: .pokerBiggestWin)
        try c.encode(tokenSwapGames, forKey: .tokenSwapGames)
        try c.encode(tokenSwapBestScore, forKey: .tokenSwapBestScore)
        try c.encode(tokenSwapTokens, forKey: .tokenSwapTokens)
        try c.encode(tokenSwapBestChain, forKey: .tokenSwapBestChain)
        try c.encode(tokenSwapBlasts, forKey: .tokenSwapBlasts)
        try c.encode(challengesCompleted, forKey: .challengesCompleted)
    }
}
