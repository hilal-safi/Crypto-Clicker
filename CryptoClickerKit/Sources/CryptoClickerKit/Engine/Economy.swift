import Foundation

/// Prices, multipliers and income. Everything is closed-form, so the shop can
/// show "Buy Max" prices for hundreds of units without looping.
extension GameState {
    // MARK: Ownership

    public func owned(_ miner: MinerID) -> Int { miners[miner, default: 0] }

    public func tokenCount(_ token: TokenID) -> Int { tokens[token, default: 0] }

    public var totalMiners: Int { miners.values.reduce(0, +) }

    /// Tiers appear one at a time: a miner shows once the tier before it is owned.
    public func isRevealed(_ miner: MinerID) -> Bool {
        guard let previous = miner.previous else { return true }
        return owned(previous) > 0 || owned(miner) > 0
    }

    /// Upgrades appear once this run has earned a tenth of their price.
    public func isRevealed(_ upgrade: UpgradeID) -> Bool {
        upgrades.contains(upgrade) || stats.runCoins >= upgrade.cost * 0.1
    }

    public func isUnlocked(_ game: MiniGame) -> Bool { unlockedGames.contains(game) }

    // MARK: Prices

    /// Price of the unit at position `index` (0 is the first unit).
    public func unitPrice(_ miner: MinerID, index: Int) -> Double {
        miner.baseCost * pow(Tuning.costGrowth, Double(index))
    }

    /// Total price of the next `quantity` units (a geometric series).
    public func price(of miner: MinerID, quantity: Int) -> Double {
        guard quantity > 0 else { return 0 }
        let growth = Tuning.costGrowth
        let first = unitPrice(miner, index: owned(miner))
        return first * (pow(growth, Double(quantity)) - 1) / (growth - 1)
    }

    /// How many units the current balance (or `budget`) can buy right now.
    public func maxAffordable(_ miner: MinerID, budget: Double? = nil) -> Int {
        let money = budget ?? coins
        let first = unitPrice(miner, index: owned(miner))
        guard money.isFinite, first > 0, money >= first else { return 0 }
        let growth = Tuning.costGrowth
        let estimate = log(money * (growth - 1) / first + 1) / log(growth)
        var count = estimate.isFinite ? Int(min(max(estimate, 0), 100_000)) : 0
        // The closed form can be off by one either way after floating-point rounding.
        while count > 0 && price(of: miner, quantity: count) > money { count -= 1 }
        var guardSteps = 0
        while guardSteps < 8 && price(of: miner, quantity: count + 1) <= money {
            count += 1
            guardSteps += 1
        }
        return count
    }

    // MARK: Multipliers

    public static func milestoneMultiplier(owned: Int) -> Double {
        let reached = Tuning.milestones.lazy.filter { owned >= $0 }.count
        return pow(Tuning.milestoneMultiplier, Double(reached))
    }

    /// The next owned count that doubles this miner's output, if any remain.
    public func nextMilestone(for miner: MinerID) -> Int? {
        let count = owned(miner)
        return Tuning.milestones.first { $0 > count }
    }

    public var upgradeProductionMultiplier: Double {
        upgrades.reduce(1) { result, upgrade in
            if case .production(let factor) = upgrade.effect { return result * factor }
            return result
        }
    }

    public var forkBonus: Double { 1 + Double(forks) * Tuning.productionPerFork }

    public var earnedAchievementTiers: Int { achievementTiers.values.reduce(0, +) }

    public var achievementBonus: Double {
        1 + Double(earnedAchievementTiers) * Tuning.productionPerAchievementTier
    }

    /// Every permanent multiplier on miner production.
    public var globalMultiplier: Double {
        upgradeProductionMultiplier * forkBonus * achievementBonus * difficulty.productionMultiplier
    }

    public func boostMultiplier(at date: Date) -> Double {
        guard let boost, date < boost.endsAt else { return 1 }
        return boost.multiplier
    }

    public func activeBoost(at date: Date) -> Boost? {
        guard let boost, date < boost.endsAt else { return nil }
        return boost
    }

    // MARK: Production

    /// Coins per second from all units of one miner, without temporary boosts.
    public func rate(of miner: MinerID) -> Double {
        let count = owned(miner)
        guard count > 0 else { return 0 }
        return Double(count) * miner.baseRate * Self.milestoneMultiplier(owned: count) * globalMultiplier
    }

    /// Coins per second one more unit would add right now (ignores the milestone it might reach).
    public func ratePerUnit(of miner: MinerID) -> Double {
        miner.baseRate * Self.milestoneMultiplier(owned: owned(miner)) * globalMultiplier
    }

    /// Miner production without temporary boosts.
    public var baseProduction: Double {
        MinerID.allCases.reduce(0) { $0 + rate(of: $1) }
    }

    public func production(at date: Date) -> Double { baseProduction * boostMultiplier(at: date) }

    // MARK: Tapping

    var tapFlatTotal: Double {
        upgrades.reduce(1) { result, upgrade in
            if case .tapFlat(let value) = upgrade.effect { return result + value }
            return result
        }
    }

    /// Share of production each tap also earns.
    public var tapShare: Double {
        upgrades.reduce(0) { result, upgrade in
            if case .tapPercent(let share) = upgrade.effect { return result + share }
            return result
        }
    }

    public var autoTapsPerSecond: Double {
        upgrades.reduce(0) { result, upgrade in
            if case .autoTaps(let rate) = upgrade.effect { return result + rate }
            return result
        }
    }

    /// The flat part of a tap, which grows with forks and achievements.
    var tapBase: Double { tapFlatTotal * forkBonus * achievementBonus }

    public func tapValue(at date: Date) -> Double { tapBase + tapShare * production(at: date) }

    /// Income that arrives without any input: miners plus automatic taps.
    public func idleIncome(at date: Date) -> Double {
        production(at: date) + autoTapsPerSecond * tapValue(at: date)
    }

    /// Idle income split into the part a boost multiplies and the part it does not:
    /// `idleIncome = boostable * boostMultiplier + fixed`.
    var incomeParts: (boostable: Double, fixed: Double) {
        let autoTaps = autoTapsPerSecond
        return (baseProduction * (1 + autoTaps * tapShare), autoTaps * tapBase)
    }

    // MARK: Caps and side rewards

    public var offlineCap: TimeInterval {
        upgrades.reduce(Tuning.baseOfflineCap) { result, upgrade in
            if case .offlineCap(let seconds) = upgrade.effect { return max(result, seconds) }
            return result
        }
    }

    public var stepMultiplier: Double {
        upgrades.reduce(1) { result, upgrade in
            if case .steps(let factor) = upgrade.effect { return result * factor }
            return result
        }
    }

    public var miniGameMultiplier: Double {
        upgrades.reduce(1) { result, upgrade in
            if case .miniGames(let factor) = upgrade.effect { return result * factor }
            return result
        }
    }

    /// Idle income without temporary boosts.
    public var baseIdleIncome: Double {
        let parts = incomeParts
        return parts.boostable + parts.fixed
    }

    /// Income that sizes step, mini-game and airdrop rewards, so they keep pace with progress.
    /// Boosts are left out so rewards stay predictable, and a floor keeps them worthwhile on day one.
    public var rewardIncome: Double { max(baseIdleIncome, Tuning.minimumRewardIncome) }

    /// Coins paid per step: a slice of idle income, never under one coin, times step upgrades.
    public var stepValue: Double {
        max(Tuning.minimumStepValue, Tuning.stepSeconds * rewardIncome) * stepMultiplier
    }

    // MARK: Prestige

    /// Fork points earned so far: the cube root of lifetime coins over the fork scale.
    public var forkPoints: Int {
        let scaled = max(0, stats.lifetimeCoins) / Tuning.forkScale
        let root = cbrt(scaled)
        guard root.isFinite else { return 0 }
        guard root < Double(Tuning.maxForkPoints) else { return Tuning.maxForkPoints }
        var points = Int(root.rounded(.down))
        // `cbrt` can land a hair either side of an exact cube: settle on the largest p with p³ <= scaled.
        while points > 0 && pow(Double(points), 3) > scaled { points -= 1 }
        while points < Tuning.maxForkPoints && pow(Double(points + 1), 3) <= scaled { points += 1 }
        return points
    }

    /// Forks a Hard Fork would award right now.
    public var claimableForks: Int {
        let points = max(0, forkPoints - forkPointsClaimed)
        return Int((Double(points) * runForkMultiplier).rounded(.down))
    }

    /// Lifetime coins at which the next fork point is earned.
    public var nextForkPointAt: Double {
        pow(Double(forkPoints + 1), 3) * Tuning.forkScale
    }

    /// Production bonus that `forks` more forks would add, as a share (0.1 = +10%).
    public func forkGain(_ forks: Int) -> Double { Double(forks) * Tuning.productionPerFork }
}
