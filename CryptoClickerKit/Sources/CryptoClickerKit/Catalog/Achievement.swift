import Foundation

/// The lifetime statistic an achievement tracks. Every metric only ever grows,
/// so an earned star can never be lost.
public enum AchievementMetric: Hashable, Sendable {
    case lifetimeCoins, peakIncome, taps, bestTap, lifetimeSteps, bestDaySteps
    case totalMiners, miner(MinerID), upgrades, minerUpgrades, bestCombo
    case blackjackWins, blackjackNaturals, tetrisLines, tetrisBestScore
    case slotsWins, snakeBestScore, bricksBroken, bubblesPopped, merge2048BestTile
    case moonBestMultiplier, pumpDumpCoinsHit, pokerWins, tokenSwapTokens, challengesCompleted
    case tokensExchanged, token(TokenID), tokensSold
    case questsCompleted, longestStreak
    case airdrops, whaleAirdrops, prestiges, perks
    case arcadeRank, tetrisSprints, brickBreakerBosses, bubbleBestWave, tokenSwapStars, merge2048DailyStars
    case weeklyVarietyGoals, invadersDestroyed, invadersBestWave
}

public struct Achievement: Identifiable, Hashable, Sendable {
    public let id: String
    /// The name, and what it counts.
    public let name: String
    public let detail: String
    /// Emoji shown for the achievement, or `nil` when `imageName` is used instead.
    public let emoji: String?
    /// Asset catalog image (token achievements use the token artwork).
    public let imageName: String?
    public let metric: AchievementMetric
    /// Bronze, silver, gold and mythic thresholds, in increasing order.
    public let thresholds: [Double]

    init(id: String, name: String, detail: String, emoji: String?, imageName: String?, metric: AchievementMetric,
         thresholds: [Double]) {
        self.id = id
        self.name = name
        self.detail = detail
        self.emoji = emoji
        self.imageName = imageName
        self.metric = metric
        self.thresholds = thresholds
    }
}

public enum AchievementCatalog {
    public static let tierNames = [localized("Bronze"), localized("Silver"), localized("Gold"), localized("Mythic")]

    public static let all: [Achievement] = general + miners + games + arcade + tokens + daily + prestige

    /// The achievements for playing the mini-games, whose tiers also give Arcade XP.
    public static let arcadeIDs: Set<String> = Set((games + arcade).map(\.id)).subtracting(["exchanger", "trader"])

    public static var tierCount: Int { all.reduce(0) { $0 + $1.thresholds.count } }

    private static let general: [Achievement] = [
        Achievement(id: "miner", name: localized("Miner"), detail: localized("Mine coins over all time"), emoji: "💰", imageName: nil,
                    metric: .lifetimeCoins, thresholds: [1e3, 1e6, 1e9, 1e11]),
        Achievement(id: "tycoon", name: localized("Tycoon"), detail: localized("Mine coins over all time"), emoji: "🏦", imageName: nil,
                    metric: .lifetimeCoins, thresholds: [1e12, 1e15, 1e18, 1e21]),
        Achievement(id: "hashrate", name: localized("Hash Rate"), detail: localized("Reach an income per second"), emoji: "⚡", imageName: nil,
                    metric: .peakIncome, thresholds: [100, 1e6, 1e10, 1e14]),
        Achievement(id: "tapper", name: localized("Tapper"), detail: localized("Tap the coin"), emoji: "👆", imageName: nil,
                    metric: .taps, thresholds: [100, 5_000, 50_000, 250_000]),
        Achievement(id: "golden-touch", name: localized("Golden Touch"), detail: localized("Coins from a single tap"), emoji: "✨", imageName: nil,
                    metric: .bestTap, thresholds: [100, 1e6, 1e10, 1e14]),
        Achievement(id: "walker", name: localized("Walker"), detail: localized("Turn steps into coins"), emoji: "👣", imageName: nil,
                    metric: .lifetimeSteps, thresholds: [10_000, 250_000, 2_500_000, 10_000_000]),
        Achievement(id: "daily-stride", name: localized("Daily Stride"), detail: localized("Steps walked in a single day"), emoji: "🏃", imageName: nil,
                    metric: .bestDaySteps, thresholds: [5_000, 10_000, 20_000, 30_000]),
        Achievement(id: "collector", name: localized("Collector"), detail: localized("Own miners at once"), emoji: "🧰", imageName: nil,
                    metric: .totalMiners, thresholds: [50, 250, 1_000, 5_000]),
        Achievement(id: "upgrader", name: localized("Upgrader"), detail: localized("Own upgrades at once"), emoji: "🔧", imageName: nil,
                    metric: .upgrades, thresholds: [5, 10, 15, Double(UpgradeID.allCases.count)]),
        Achievement(id: "engineer", name: localized("Engineer"), detail: localized("Buy miner Mk upgrades"), emoji: "🛠️", imageName: nil,
                    metric: .minerUpgrades, thresholds: [5, 25, 100, 500]),
        Achievement(id: "combo-king", name: localized("Combo King"), detail: localized("Quick taps in a row"), emoji: "🔥", imageName: nil,
                    metric: .bestCombo, thresholds: [100, 300, 1_500, 2_000]),
    ]

    private static let miners: [Achievement] = MinerID.allCases.map { miner in
        Achievement(id: "own-\(miner.rawValue)", name: localized("\(miner.name) Fleet"), detail: localized("Own \(miner.pluralName) at once"),
                    emoji: miner.emoji, imageName: nil, metric: .miner(miner), thresholds: [25, 100, 250, 500])
    }

    private static let games: [Achievement] = [
        Achievement(id: "card-shark", name: localized("Card Shark"), detail: localized("Win hands of 21 Million"),
                    emoji: "🃏", imageName: nil, metric: .blackjackWins, thresholds: [10, 100, 1_000, 5_000]),
        Achievement(id: "natural", name: localized("Natural"), detail: localized("Deal yourself a natural 21"),
                    emoji: "🂡", imageName: nil, metric: .blackjackNaturals, thresholds: [1, 10, 100, 500]),
        Achievement(id: "line-clearer", name: localized("Line Clearer"), detail: localized("Clear lines in Block Chain"),
                    emoji: "🧱", imageName: nil, metric: .tetrisLines, thresholds: [10, 100, 1_000, 10_000]),
        Achievement(id: "high-score", name: localized("High Score"), detail: localized("Score in a single Block Chain game"),
                    emoji: "🏆", imageName: nil, metric: .tetrisBestScore, thresholds: [5_000, 25_000, 100_000, 500_000]),
        Achievement(id: "high-roller", name: localized("High Roller"), detail: localized("Win spins at Crypto Slots"), emoji: "🎰", imageName: nil,
                    metric: .slotsWins, thresholds: [10, 100, 1_000, 10_000]),
        Achievement(id: "snake-charmer", name: localized("Chain Reaction"), detail: localized("Score in a single Hash Chain game"),
                    emoji: "🔗", imageName: nil, metric: .snakeBestScore, thresholds: [100, 300, 600, 1_000]),
        Achievement(id: "brick-smasher", name: localized("Hash Smasher"), detail: localized("Smash blocks in Hash Smash"),
                    emoji: "💥", imageName: nil, metric: .bricksBroken, thresholds: [50, 500, 5_000, 50_000]),
        Achievement(id: "bubble-popper", name: localized("Bubble Popper"), detail: localized("Pop bubbles in Bubble Market"),
                    emoji: "🫧", imageName: nil, metric: .bubblesPopped, thresholds: [100, 1_000, 10_000, 100_000]),
        Achievement(id: "merge-master", name: localized("Merge Master"), detail: localized("Merge a miner this big in Merge Mining"),
                    emoji: "⛏️", imageName: nil, metric: .merge2048BestTile, thresholds: [128, 512, 2_048, 8_192]),
        Achievement(id: "moonshot", name: localized("Moonshot"), detail: localized("Cash out this high in To the Moon"), emoji: "🚀",
                    imageName: nil, metric: .moonBestMultiplier, thresholds: [2, 5, 20, 100]),
        Achievement(id: "whack-a-coin", name: localized("Coin Whacker"), detail: localized("Hit coins in Pump and Dump"), emoji: "🔨",
                    imageName: nil, metric: .pumpDumpCoinsHit, thresholds: [100, 1_000, 10_000, 50_000]),
        Achievement(id: "poker-face", name: localized("Poker Face"), detail: localized("Win hands of Diamond Hands"),
                    emoji: "💎", imageName: nil, metric: .pokerWins, thresholds: [10, 100, 1_000, 5_000]),
        Achievement(id: "token-swapper", name: localized("Token Swapper"), detail: localized("Match tokens in Token Swap"), emoji: "🪙",
                    imageName: nil, metric: .tokenSwapTokens, thresholds: [250, 2_500, 25_000, 250_000]),
        Achievement(id: "invader-hunter", name: localized("Invader Hunter"), detail: localized("Shoot down invaders in Scam Invaders"), emoji: "🛸",
                    imageName: nil, metric: .invadersDestroyed, thresholds: [100, 1_000, 10_000, 100_000]),
        Achievement(id: "exchanger", name: localized("Exchanger"), detail: localized("Buy tokens in the Shop"), emoji: "🔁", imageName: nil,
                    metric: .tokensExchanged, thresholds: [10, 100, 1_000, 100_000]),
        Achievement(id: "trader", name: localized("Trader"), detail: localized("Sell tokens in the Shop"), emoji: "📈", imageName: nil,
                    metric: .tokensSold, thresholds: [10, 250, 5_000, 100_000]),
    ]

    /// Records from the mini-game overhaul and Arcade Rank.
    private static let arcade: [Achievement] = [
        Achievement(id: "arcade-rank", name: localized("Arcade Star"), detail: localized("Reach this Arcade Rank"), emoji: "🕹️",
                    imageName: nil, metric: .arcadeRank, thresholds: [5, 10, 20, 30]),
        Achievement(id: "all-rounder", name: localized("All-Rounder"), detail: localized("Meet the weekly variety goal"), emoji: "🎲",
                    imageName: nil, metric: .weeklyVarietyGoals, thresholds: [1, 4, 12, 52]),
        Achievement(id: "sprinter", name: localized("Sprinter"), detail: localized("Finish Block Rushes in Block Chain"),
                    emoji: "⏱️", imageName: nil, metric: .tetrisSprints, thresholds: [1, 10, 50, 200]),
        Achievement(id: "boss-slayer", name: localized("Whale Hunter"), detail: localized("Beat the whale in Hash Smash"),
                    emoji: "🐋", imageName: nil, metric: .brickBreakerBosses, thresholds: [1, 5, 25, 100]),
        Achievement(id: "wave-rider", name: localized("Wave Rider"), detail: localized("Wave reached in Bubble Market"),
                    emoji: "🌊", imageName: nil, metric: .bubbleBestWave, thresholds: [3, 5, 8, 12]),
        Achievement(id: "star-collector", name: localized("Star Collector"), detail: localized("Earn Token Swap level stars"), emoji: "⭐",
                    imageName: nil, metric: .tokenSwapStars, thresholds: [10, 25, 40, 54]),
        Achievement(id: "puzzle-solver", name: localized("Puzzle Solver"), detail: localized("Stars from daily Merge Mining puzzles"),
                    emoji: "🧩", imageName: nil, metric: .merge2048DailyStars, thresholds: [3, 15, 60, 200]),
        Achievement(id: "last-line", name: localized("Last Line of Defense"), detail: localized("Wave reached in Scam Invaders"), emoji: "🛡️",
                    imageName: nil, metric: .invadersBestWave, thresholds: [3, 6, 10, 15]),
    ]

    private static let tokens: [Achievement] = TokenID.allCases.map { token in
        Achievement(id: "token-\(token.rawValue)", name: localized("Exchanged \(token.name)"), detail: localized("Buy \(token.name) tokens"),
                    emoji: nil, imageName: token.imageName, metric: .token(token), thresholds: [1, 10, 100, 1_000])
    }

    private static let daily: [Achievement] = [
        Achievement(id: "quest-master", name: localized("Quest Master"), detail: localized("Complete daily quests"), emoji: "📜", imageName: nil,
                    metric: .questsCompleted, thresholds: [5, 50, 300, 1_000]),
        Achievement(id: "loyal-miner", name: localized("Loyal Miner"), detail: localized("Daily rewards claimed in a row"), emoji: "📅",
                    imageName: nil, metric: .longestStreak, thresholds: [3, 7, 30, 100]),
        Achievement(id: "challenger", name: localized("Challenger"), detail: localized("Complete daily challenges"), emoji: "🎯",
                    imageName: nil, metric: .challengesCompleted, thresholds: [1, 10, 50, 200]),
    ]

    private static let prestige: [Achievement] = [
        Achievement(id: "airdrop-hunter", name: localized("Airdrop Hunter"), detail: localized("Catch airdrops"), emoji: "🪂", imageName: nil,
                    metric: .airdrops, thresholds: [1, 25, 250, 1_000]),
        Achievement(id: "whale-spotter", name: localized("Whale Spotter"), detail: localized("Catch whale airdrops"), emoji: "🐋", imageName: nil,
                    metric: .whaleAirdrops, thresholds: [1, 5, 25, 100]),
        // The id dates from when prestiging was called a Hard Fork; earned stars are saved under it.
        Achievement(id: "hard-forker", name: localized("Prestigious"), detail: localized("Prestige"), emoji: "🌟", imageName: nil,
                    metric: .prestiges, thresholds: [1, 5, 25, 50]),
        Achievement(id: "perk-collector", name: localized("Perk Collector"), detail: localized("Own prestige perks"), emoji: "🎖️", imageName: nil,
                    metric: .perks, thresholds: [1, 5, 10, Double(PerkID.allCases.count)]),
    ]
}

/// A newly earned achievement tier, used for the unlock banner.
public struct EarnedTier: Equatable, Sendable, Identifiable {
    public let achievement: Achievement
    /// 0 = bronze, 1 = silver, 2 = gold, 3 = mythic.
    public let tier: Int
    public var id: String { "\(achievement.id)#\(tier)" }
    public var tierName: String { AchievementCatalog.tierNames[min(tier, AchievementCatalog.tierNames.count - 1)] }
}
