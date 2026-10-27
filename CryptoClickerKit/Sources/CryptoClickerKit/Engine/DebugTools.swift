#if DEBUG
import Foundation

/// Testing aids for builds run from Xcode (the Debug configuration). They are compiled out of
/// release builds, so they can never reach the App Store.
extension GameState {
    /// Adds coins as if they had been mined: they count toward lifetime and run totals, so
    /// upgrades, achievements and prestige unlock just as they would in play.
    public mutating func debugAddCoins(_ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }
        coins += amount
        stats.lifetimeCoins += amount
        stats.runCoins += amount
    }

    /// Adds `amount` of every token.
    public mutating func debugAddTokens(_ amount: Int) {
        for token in TokenID.allCases { giveTokens(token, amount: amount) }
    }

    /// Adds `count` of every miner without paying for them.
    public mutating func debugAddMiners(_ count: Int) {
        guard count > 0 else { return }
        for miner in MinerID.allCases {
            let total = owned(miner) + count
            miners[miner] = total
            stats.maxOwned[miner] = max(stats.maxOwned[miner, default: 0], total)
        }
        stats.maxTotalMiners = max(stats.maxTotalMiners, totalMiners)
    }

    /// Gives every upgrade for free.
    public mutating func debugGiveAllUpgrades() {
        upgrades = Set(UpgradeID.allCases)
        stats.maxUpgrades = max(stats.maxUpgrades, upgrades.count)
    }

    /// Adds Offline Mining levels for free (a negative count removes them), within its range.
    public mutating func debugAddOfflineMining(levels: Int) {
        offlineMiningLevel = min(max(0, offlineMiningLevel + levels), Tuning.offlineMiningMaxLevel)
    }

    public mutating func debugUnlockAllGames() {
        unlockedGames = Set(MiniGame.allCases)
    }

    /// Counts enough taps to unlock steps.
    public mutating func debugUnlockSteps() {
        stats.taps = max(stats.taps, Tuning.stepsUnlockTaps)
    }

    public mutating func debugStartBullRun(at now: Date) {
        boost = Boost(multiplier: Tuning.bullRunMultiplier, endsAt: now.addingTimeInterval(bullRunDuration))
    }

    /// Adds prestige points without prestiging: they add production and can be spent on perks.
    public mutating func debugAddPrestigePoints(_ points: Int) {
        guard points > 0 else { return }
        prestigePoints = Self.addingPoints(prestigePoints, min(points, Tuning.maxPrestigePoints))
    }

    /// Marks today's quests as done, ready to claim.
    public mutating func debugCompleteQuests() {
        daily.quests = daily.quests.map { quest in
            Quest(kind: quest.kind, target: quest.target, baseline: questMetric(quest.kind) - quest.target,
                  reward: quest.reward, isClaimed: quest.isClaimed)
        }
    }

    /// Makes the daily reward, new quests and a fresh daily challenge available again today,
    /// keeping the streak going.
    public mutating func debugResetDaily(yesterday: String) {
        if daily.lastRewardDay != nil { daily.lastRewardDay = yesterday }
        daily.questDay = nil
        daily.quests = []
        daily.challenge = nil
    }

    /// Moves the game clock back, as if the app had been closed for `seconds`. The next
    /// `advance(to:)` then pays the time away (up to the Offline Mining limit) with a welcome-back report.
    /// A running Bull Run moves back too, so it covers only the time it had left when the player "left".
    public mutating func debugRewind(_ seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
        lastUpdate = lastUpdate.addingTimeInterval(-seconds)
        if let boost {
            self.boost = Boost(multiplier: boost.multiplier, endsAt: boost.endsAt.addingTimeInterval(-seconds))
        }
    }
}
#endif
