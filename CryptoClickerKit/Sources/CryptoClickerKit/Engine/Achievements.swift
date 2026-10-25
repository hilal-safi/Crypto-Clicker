import Foundation

extension GameState {
    /// Current value of an achievement's metric. All metrics are lifetime highs.
    public func value(of metric: AchievementMetric) -> Double {
        switch metric {
        case .lifetimeCoins: stats.lifetimeCoins
        case .peakIncome: stats.peakIncome
        case .taps: Double(stats.taps)
        case .bestTap: stats.bestTap
        case .lifetimeSteps: Double(stats.lifetimeSteps)
        case .bestDaySteps: Double(stats.bestDaySteps)
        case .totalMiners: Double(stats.maxTotalMiners)
        case .miner(let miner): Double(stats.maxOwned[miner, default: 0])
        case .upgrades: Double(stats.maxUpgrades)
        case .blackjackWins: Double(stats.blackjackWins)
        case .blackjackNaturals: Double(stats.blackjackNaturals)
        case .tetrisLines: Double(stats.tetrisLines)
        case .tetrisBestScore: Double(stats.tetrisBestScore)
        case .tokensExchanged: Double(stats.totalTokensBought)
        case .token(let token): Double(stats.tokensBought[token, default: 0])
        case .airdrops: Double(stats.airdrops)
        case .forks: Double(stats.forksPerformed)
        }
    }

    /// Tiers earned for an achievement (0 to 3).
    public func tiersEarned(_ achievement: Achievement) -> Int {
        achievementTiers[achievement.id, default: 0]
    }

    /// The next threshold to reach, or `nil` when every tier is earned.
    public func nextThreshold(_ achievement: Achievement) -> Double? {
        let earned = tiersEarned(achievement)
        return earned < achievement.thresholds.count ? achievement.thresholds[earned] : nil
    }

    /// Records any newly reached tiers and returns them (for the unlock banner).
    /// Earned tiers are stored, so they stay earned even if a metric could ever drop.
    @discardableResult
    public mutating func refreshAchievements() -> [EarnedTier] {
        var newlyEarned: [EarnedTier] = []
        for achievement in AchievementCatalog.all {
            let current = value(of: achievement.metric)
            let reached = achievement.thresholds.lazy.filter { current >= $0 }.count
            let earned = tiersEarned(achievement)
            guard reached > earned else { continue }
            for tier in earned..<reached {
                newlyEarned.append(EarnedTier(achievement: achievement, tier: tier))
            }
            achievementTiers[achievement.id] = reached
        }
        return newlyEarned
    }
}
