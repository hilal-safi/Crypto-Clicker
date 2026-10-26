import Foundation

/// The lifetime statistic an achievement tracks. Every metric only ever grows,
/// so an earned star can never be lost.
public enum AchievementMetric: Hashable, Sendable {
    case lifetimeCoins, peakIncome, taps, bestTap, lifetimeSteps, bestDaySteps
    case totalMiners, miner(MinerID), upgrades, minerUpgrades, bestCombo
    case blackjackWins, blackjackNaturals, tetrisLines, tetrisBestScore
    case slotsWins, snakeBestScore, bricksBroken, bubblesPopped
    case tokensExchanged, token(TokenID), tokensSold
    case questsCompleted, longestStreak
    case airdrops, whaleAirdrops, prestiges, perks
}

public struct Achievement: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    /// Emoji shown for the achievement, or `nil` when `imageName` is used instead.
    public let emoji: String?
    /// Asset catalog image (token achievements use the token artwork).
    public let imageName: String?
    public let metric: AchievementMetric
    /// Bronze, silver and gold thresholds, in increasing order.
    public let thresholds: [Double]
}

public enum AchievementCatalog {
    public static let tierNames = ["Bronze", "Silver", "Gold"]

    public static let all: [Achievement] = general + miners + games + tokens + daily + prestige

    public static var tierCount: Int { all.reduce(0) { $0 + $1.thresholds.count } }

    private static let general: [Achievement] = [
        Achievement(id: "miner", name: "Miner", detail: "Mine coins over all time", emoji: "💰", imageName: nil,
                    metric: .lifetimeCoins, thresholds: [1e3, 1e6, 1e9]),
        Achievement(id: "tycoon", name: "Tycoon", detail: "Mine coins over all time", emoji: "🏦", imageName: nil,
                    metric: .lifetimeCoins, thresholds: [1e12, 1e15, 1e18]),
        Achievement(id: "hashrate", name: "Hash Rate", detail: "Reach an income per second", emoji: "⚡", imageName: nil,
                    metric: .peakIncome, thresholds: [100, 1e6, 1e10]),
        Achievement(id: "tapper", name: "Tapper", detail: "Tap the coin", emoji: "👆", imageName: nil,
                    metric: .taps, thresholds: [100, 5_000, 50_000]),
        Achievement(id: "golden-touch", name: "Golden Touch", detail: "Earn this much from a single tap", emoji: "✨", imageName: nil,
                    metric: .bestTap, thresholds: [100, 1e6, 1e10]),
        Achievement(id: "walker", name: "Walker", detail: "Turn steps into coins", emoji: "👣", imageName: nil,
                    metric: .lifetimeSteps, thresholds: [10_000, 250_000, 2_500_000]),
        Achievement(id: "daily-stride", name: "Daily Stride", detail: "Steps rewarded in a single day", emoji: "🏃", imageName: nil,
                    metric: .bestDaySteps, thresholds: [5_000, 10_000, 20_000]),
        Achievement(id: "collector", name: "Collector", detail: "Own miners at once", emoji: "🧰", imageName: nil,
                    metric: .totalMiners, thresholds: [50, 250, 1_000]),
        Achievement(id: "upgrader", name: "Upgrader", detail: "Own upgrades at once", emoji: "🔧", imageName: nil,
                    metric: .upgrades, thresholds: [5, 12, Double(UpgradeID.allCases.count)]),
        Achievement(id: "engineer", name: "Engineer", detail: "Buy miner Mk upgrades", emoji: "🛠️", imageName: nil,
                    metric: .minerUpgrades, thresholds: [5, 25, 100]),
        Achievement(id: "combo-king", name: "Combo King", detail: "Quick taps in a row", emoji: "🔥", imageName: nil,
                    metric: .bestCombo, thresholds: [25, 100, 400]),
    ]

    private static let miners: [Achievement] = MinerID.allCases.map { miner in
        Achievement(id: "own-\(miner.rawValue)", name: "\(miner.name) Fleet", detail: "Own \(miner.pluralName) at once",
                    emoji: miner.emoji, imageName: nil, metric: .miner(miner), thresholds: [25, 100, 250])
    }

    private static let games: [Achievement] = [
        Achievement(id: "card-shark", name: "Card Shark", detail: "Win blackjack hands", emoji: "🃏", imageName: nil,
                    metric: .blackjackWins, thresholds: [10, 100, 1_000]),
        Achievement(id: "natural", name: "Natural", detail: "Deal yourself a blackjack", emoji: "🂡", imageName: nil,
                    metric: .blackjackNaturals, thresholds: [1, 10, 100]),
        Achievement(id: "line-clearer", name: "Line Clearer", detail: "Clear Tetris lines", emoji: "🧱", imageName: nil,
                    metric: .tetrisLines, thresholds: [10, 100, 1_000]),
        Achievement(id: "high-score", name: "High Score", detail: "Score in a single Tetris game", emoji: "🏆", imageName: nil,
                    metric: .tetrisBestScore, thresholds: [5_000, 25_000, 100_000]),
        Achievement(id: "high-roller", name: "High Roller", detail: "Win spins at Crypto Slots", emoji: "🎰", imageName: nil,
                    metric: .slotsWins, thresholds: [10, 100, 1_000]),
        Achievement(id: "snake-charmer", name: "Snake Charmer", detail: "Score in a single Snake game", emoji: "🐍", imageName: nil,
                    metric: .snakeBestScore, thresholds: [100, 300, 600]),
        Achievement(id: "brick-smasher", name: "Brick Smasher", detail: "Break bricks in Brick Breaker", emoji: "💥", imageName: nil,
                    metric: .bricksBroken, thresholds: [50, 500, 5_000]),
        Achievement(id: "bubble-popper", name: "Bubble Popper", detail: "Pop bubbles in Bubble Blaster", emoji: "🫧", imageName: nil,
                    metric: .bubblesPopped, thresholds: [100, 1_000, 10_000]),
        Achievement(id: "exchanger", name: "Exchanger", detail: "Buy tokens on the exchange", emoji: "🔁", imageName: nil,
                    metric: .tokensExchanged, thresholds: [10, 100, 1_000]),
        Achievement(id: "trader", name: "Trader", detail: "Sell tokens on the market", emoji: "📈", imageName: nil,
                    metric: .tokensSold, thresholds: [10, 250, 5_000]),
    ]

    private static let tokens: [Achievement] = TokenID.allCases.map { token in
        Achievement(id: "token-\(token.rawValue)", name: "Exchanged \(token.name)", detail: "Buy \(token.name) tokens",
                    emoji: nil, imageName: token.imageName, metric: .token(token), thresholds: [1, 10, 100])
    }

    private static let daily: [Achievement] = [
        Achievement(id: "quest-master", name: "Quest Master", detail: "Complete daily quests", emoji: "📜", imageName: nil,
                    metric: .questsCompleted, thresholds: [5, 50, 300]),
        Achievement(id: "loyal-miner", name: "Loyal Miner", detail: "Claim the daily reward days in a row", emoji: "📅",
                    imageName: nil, metric: .longestStreak, thresholds: [3, 7, 30]),
    ]

    private static let prestige: [Achievement] = [
        Achievement(id: "airdrop-hunter", name: "Airdrop Hunter", detail: "Catch airdrops", emoji: "🪂", imageName: nil,
                    metric: .airdrops, thresholds: [1, 25, 250]),
        Achievement(id: "whale-spotter", name: "Whale Spotter", detail: "Catch whale airdrops", emoji: "🐋", imageName: nil,
                    metric: .whaleAirdrops, thresholds: [1, 5, 25]),
        // The id dates from when prestiging was called a Hard Fork; earned stars are saved under it.
        Achievement(id: "hard-forker", name: "Prestigious", detail: "Prestige", emoji: "🌟", imageName: nil,
                    metric: .prestiges, thresholds: [1, 5, 25]),
        Achievement(id: "perk-collector", name: "Perk Collector", detail: "Own prestige perks", emoji: "🎖️", imageName: nil,
                    metric: .perks, thresholds: [1, 8, Double(PerkID.allCases.count)]),
    ]
}

/// A newly earned achievement tier, used for the unlock banner.
public struct EarnedTier: Equatable, Sendable, Identifiable {
    public let achievement: Achievement
    /// 0 = bronze, 1 = silver, 2 = gold.
    public let tier: Int
    public var id: String { "\(achievement.id)#\(tier)" }
    public var tierName: String { AchievementCatalog.tierNames[min(tier, AchievementCatalog.tierNames.count - 1)] }
}
