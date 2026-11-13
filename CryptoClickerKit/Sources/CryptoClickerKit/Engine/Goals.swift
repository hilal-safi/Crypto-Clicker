import Foundation

/// One thing worth working toward next, for the Goals page: what it is, how far along it is, and
/// what it's worth.
public struct Goal: Equatable, Sendable, Identifiable {
    public enum Kind: String, CaseIterable, Sendable {
        case miner, milestone, upgrade, game, achievement, arcadeRank, tokenSwap, prestige
    }

    public let kind: Kind
    /// What to do: "Buy a Data Center", "Own 25 GPU Rigs".
    public let title: String
    /// What it brings, or how far there is to go.
    public let detail: String
    /// From 0 to 1.
    public let progress: Double

    public var id: String { kind.rawValue }

    init(_ kind: Kind, _ title: String, _ detail: String, progress: Double) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.progress = progress.isFinite ? min(max(progress, 0), 1) : 0
    }
}

extension GameState {
    /// The next few meaningful goals, one of each kind that applies, in the order they matter for
    /// this run: the next miner, a milestone, the cheapest upgrade or game to unlock, the closest
    /// achievement star, the next Arcade Rank, the next Token Swap level and the next prestige.
    public var nextGoals: [Goal] {
        [minerGoal, milestoneGoal, upgradeGoal, gameGoal, achievementGoal, arcadeRankGoal, tokenSwapGoal, prestigeGoal]
            .compactMap(\.self)
    }

    /// The next tier to buy, or what reveals it.
    private var minerGoal: Goal? {
        guard let miner = MinerID.allCases.first(where: { owned($0) == 0 }) else { return nil }
        if isRevealed(miner) {
            let price = price(of: miner, quantity: 1)
            return Goal(.miner, localized("Buy \(miner.article) \(miner.name)"),
                        localized("Mines \(CoinFormat.rate(rate(ofOneMore: miner))) a second · \(CoinFormat.short(price)) coins"),
                        progress: coins / price)
        }
        if miner.needsPrestige && stats.prestiges == 0 {
            return Goal(.miner, localized("Prestige to reveal the \(miner.name)"), localized("Three new miners appear after the first prestige"),
                        progress: Double(claimablePrestigePoints) / Double(prestigePointsToRecommend))
        }
        return nil
    }

    /// The owned miner closest (in units) to its next milestone, which doubles its output.
    private var milestoneGoal: Goal? {
        let candidates = MinerID.allCases.compactMap { miner -> (miner: MinerID, next: Int, left: Int)? in
            let count = owned(miner)
            guard count > 0, let next = nextMilestone(for: miner) else { return nil }
            return (miner, next, next - count)
        }
        guard let best = candidates.min(by: { $0.left < $1.left }) else { return nil }
        let count = owned(best.miner)
        let previous = Tuning.milestones.last { $0 <= count } ?? 0
        return Goal(.milestone, localized("Own \(CoinFormat.grouped(best.next)) \(best.miner.pluralName)"),
                    localized("\(CoinFormat.grouped(best.left)) more doubles what they mine"),
                    progress: Double(count - previous) / Double(max(1, best.next - previous)))
    }

    /// The cheapest upgrade on offer.
    private var upgradeGoal: Goal? {
        let offered = UpgradeID.allCases.filter { !upgrades.contains($0) && isRevealed($0) && $0.category != .steps }
        guard let upgrade = offered.min(by: { $0.cost < $1.cost }) else { return nil }
        return Goal(.upgrade, localized("Buy \(upgrade.name)"), localized("\(CoinFormat.short(upgrade.cost)) coins in the Shop"),
                    progress: coins / upgrade.cost)
    }

    /// The cheapest game still locked.
    private var gameGoal: Goal? {
        guard let game = MiniGame.allCases.filter({ !isUnlocked($0) }).min(by: { $0.unlockCost < $1.unlockCost }) else {
            return nil
        }
        return Goal(.game, localized("Unlock \(game.name)"), localized("\(CoinFormat.short(game.unlockCost)) coins in the Arcade"),
                    progress: coins / game.unlockCost)
    }

    /// The achievement closest to its next star. The arcade's wait until there's a game to play
    /// (Arcade Rank starts at 1, so it would otherwise look a third done on day one).
    private var achievementGoal: Goal? {
        let hasGames = !unlockedGames.isEmpty
        let candidates = AchievementCatalog.all.compactMap { achievement -> (achievement: Achievement, value: Double, share: Double)? in
            if !hasGames && AchievementCatalog.arcadeIDs.contains(achievement.id) { return nil }
            guard let next = nextThreshold(achievement), next > 0 else { return nil }
            let value = self.value(of: achievement.metric)
            return (achievement, value, value / next)
        }
        guard let closest = candidates.max(by: { $0.share < $1.share }) else { return nil }
        let achievement = closest.achievement
        let tier = AchievementCatalog.tierNames[min(tiersEarned(achievement), AchievementCatalog.tierNames.count - 1)]
        let next = nextThreshold(achievement) ?? closest.value
        return Goal(.achievement, "\(tier) star: \(achievement.name)",
                    localized("\(achievement.detail): \(CoinFormat.short(closest.value)) of \(CoinFormat.short(next))"),
                    progress: closest.share)
    }

    /// The next Arcade Rank, once a game is unlocked.
    private var arcadeRankGoal: Goal? {
        guard !unlockedGames.isEmpty else { return nil }
        let progress = arcadeRankProgress
        return Goal(.arcadeRank, localized("Arcade Rank \(arcadeRank + 1)"),
                    localized("\(CoinFormat.grouped(max(0, progress.needed - progress.xp))) XP to go · playing games earns XP"),
                    progress: Double(progress.xp) / Double(max(1, progress.needed)))
    }

    /// The next Token Swap level to win, once Token Swap is unlocked.
    private var tokenSwapGoal: Goal? {
        guard isUnlocked(.tokenSwap), tokenSwap.levelsWon < TokenSwapLevel.all.count,
              let level = TokenSwapLevel.number(tokenSwap.nextLevel) else { return nil }
        return Goal(.tokenSwap, localized("Win Token Swap level \(level.id)"), localized("\(level.name): its first star pays coins"),
                    progress: Double(tokenSwap.levelsWon) / Double(TokenSwapLevel.all.count))
    }

    /// Prestige points: the first one, then the prestige the Shop suggests.
    private var prestigeGoal: Goal? {
        if isPrestigeRecommended {
            return Goal(.prestige, localized("Prestige for \(CoinFormat.grouped(claimablePrestigePoints)) points"),
                        localized("Production \(CoinFormat.multiplier(prestigeSpeedUp)) as fast afterwards"), progress: 1)
        }
        if claimablePrestigePoints == 0 {
            return Goal(.prestige, prestigePoints == 0 ? localized("Your first prestige point") : localized("Your next prestige point"),
                        localized("At \(CoinFormat.short(nextPrestigePointAt)) coins mined in all"),
                        progress: stats.lifetimeCoins / nextPrestigePointAt)
        }
        return Goal(.prestige, localized("A prestige worth \(CoinFormat.grouped(prestigePointsToRecommend)) points"),
                    localized("\(CoinFormat.grouped(claimablePrestigePoints)) ready now; the Shop suggests prestiging at \(CoinFormat.grouped(prestigePointsToRecommend))"),
                    progress: Double(claimablePrestigePoints) / Double(prestigePointsToRecommend))
    }

    /// New points a prestige needs before the Shop suggests it: enough to speed production up by
    /// `recommendedPrestigeSpeedUp` (10 for the first, then 17 plus 85% of the points already
    /// earned). A hair is taken off before rounding up, so floating-point noise can't ask for one
    /// point too many.
    var prestigePointsToRecommend: Int {
        let needed = (recommendedPrestigeSpeedUp - 1)
            * (1 / Tuning.productionPerPrestigePoint + Double(prestigePoints))
        guard needed.isFinite else { return 1 }
        return max(1, Int(min(needed - 1e-6, Double(Tuning.maxPrestigePoints)).rounded(.up)))
    }

    /// What one more unit of `miner` adds to production, milestones aside.
    private func rate(ofOneMore miner: MinerID) -> Double {
        miner.baseRate * tierMultiplier(miner, owned: owned(miner) + 1) * globalMultiplier
    }
}

extension MinerID {
    /// "a" or "an", for "Buy an AI Miner".
    var article: String {
        let first = name.lowercased().first
        return first.map { "aeiou".contains($0) } == true ? "an" : "a"
    }
}
