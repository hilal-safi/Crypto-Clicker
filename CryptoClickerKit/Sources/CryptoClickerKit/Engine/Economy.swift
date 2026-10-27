import Foundation

/// Prices, multipliers and income.
///
/// Coins are whole: prices are rounded up, and every payout (a tap, a step, a reward) is a whole
/// number of coins. Only income per second is fractional; it builds up between ticks, and the
/// balance is always shown rounded down.
extension GameState {
    // MARK: Ownership

    public func owned(_ miner: MinerID) -> Int { miners[miner, default: 0] }

    public func tokenCount(_ token: TokenID) -> Int { tokens[token, default: 0] }

    public var totalMiners: Int { miners.values.reduce(0, +) }

    public func hasPerk(_ perk: PerkID) -> Bool { perks.contains(perk) }

    /// Tiers appear one at a time: a miner shows once the tier before it is owned. The last
    /// tiers also wait for the first prestige.
    public func isRevealed(_ miner: MinerID) -> Bool {
        if owned(miner) > 0 { return true }
        if miner.needsPrestige && stats.prestiges == 0 { return false }
        guard let previous = miner.previous else { return true }
        return owned(previous) > 0
    }

    /// Upgrades appear once this run has earned a tenth of their price. Step upgrades also wait
    /// until steps are unlocked.
    public func isRevealed(_ upgrade: UpgradeID) -> Bool {
        if upgrades.contains(upgrade) { return true }
        if upgrade.category == .steps && !areStepsUnlocked { return false }
        return stats.runCoins >= upgrade.cost * 0.1
    }

    public func isUnlocked(_ game: MiniGame) -> Bool { unlockedGames.contains(game) }

    // MARK: Prices

    /// Miner prices after perks: Bulk Discount takes 10% off.
    var minerPriceFactor: Double { hasPerk(.bulkDiscount) ? 0.9 : 1 }

    /// Price of the unit at position `index` (0 is the first unit), in whole coins.
    public func unitPrice(_ miner: MinerID, index: Int) -> Double {
        Self.wholePrice(miner.baseCost * minerPriceFactor * pow(Tuning.costGrowth, Double(index)))
    }

    /// Total price of the next `quantity` units: the geometric series, rounded up to a whole coin.
    /// Closed-form, so the shop can price "Buy Max" for hundreds of units without looping.
    public func price(of miner: MinerID, quantity: Int) -> Double {
        guard quantity > 0 else { return 0 }
        let growth = Tuning.costGrowth
        let first = miner.baseCost * minerPriceFactor * pow(growth, Double(owned(miner)))
        return Self.wholePrice(first * (pow(growth, Double(quantity)) - 1) / (growth - 1))
    }

    /// How many units the current balance (or `budget`) can buy right now.
    public func maxAffordable(_ miner: MinerID, budget: Double? = nil) -> Int {
        let money = budget ?? coins
        let first = miner.baseCost * minerPriceFactor * pow(Tuning.costGrowth, Double(owned(miner)))
        guard money.isFinite, first > 0, money >= price(of: miner, quantity: 1) else { return 0 }
        let growth = Tuning.costGrowth
        let estimate = log(money * (growth - 1) / first + 1) / log(growth)
        var count = estimate.isFinite ? Int(min(max(estimate, 0), 100_000)) : 0
        // The closed form can be off by one either way after rounding.
        while count > 0 && price(of: miner, quantity: count) > money { count -= 1 }
        var guardSteps = 0
        while guardSteps < 8 && price(of: miner, quantity: count + 1) <= money {
            count += 1
            guardSteps += 1
        }
        return count
    }

    /// Rounds a price up to a whole coin, ignoring floating-point noise just above a whole number.
    static func wholePrice(_ value: Double) -> Double {
        guard value.isFinite, value < 0x1p52 else { return value } // Larger doubles are already whole.
        return max(0, (value - 1e-6).rounded(.up))
    }

    /// Rounds a payout to the nearest whole coin.
    static func wholeCoins(_ value: Double, minimum: Double = 0) -> Double {
        guard value.isFinite else { return minimum }
        return max(minimum, value.rounded())
    }

    // MARK: Miner Mk upgrades

    /// Mk upgrades bought for `miner` this run.
    public func minerUpgradeLevel(_ miner: MinerID) -> Int { minerUpgrades[miner, default: 0] }

    /// The units of `miner` that reveal its Mk upgrade at `level` (0 is Mk II), if one is left.
    public static func minerUpgradeThreshold(level: Int) -> Int? {
        Tuning.minerUpgradeThresholds.indices.contains(level) ? Tuning.minerUpgradeThresholds[level] : nil
    }

    /// Price of the Mk upgrade at `level` for `miner`: about ten units at the count that reveals it.
    public func minerUpgradePrice(_ miner: MinerID, level: Int) -> Double? {
        guard let threshold = Self.minerUpgradeThreshold(level: level) else { return nil }
        return Self.wholePrice(miner.baseCost * minerPriceFactor * pow(Tuning.costGrowth, Double(threshold))
                               * Tuning.minerUpgradeUnits)
    }

    /// The next Mk upgrade for `miner`, once enough units are owned to reveal it.
    public func availableMinerUpgrade(_ miner: MinerID) -> (level: Int, price: Double)? {
        let level = minerUpgradeLevel(miner)
        guard let threshold = Self.minerUpgradeThreshold(level: level), owned(miner) >= threshold,
              let price = minerUpgradePrice(miner, level: level) else { return nil }
        return (level, price)
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

    /// Production multiplier from every prestige point ever earned (spent or not).
    public var prestigeBonus: Double { 1 + Double(prestigePoints) * Tuning.productionPerPrestigePoint }

    public var earnedAchievementTiers: Int { achievementTiers.values.reduce(0, +) }

    /// Production per achievement star: Compound Interest doubles it.
    public var productionPerAchievementTier: Double {
        Tuning.productionPerAchievementTier * (hasPerk(.compoundInterest) ? 2 : 1)
    }

    public var achievementBonus: Double {
        1 + Double(earnedAchievementTiers) * productionPerAchievementTier
    }

    /// Every permanent multiplier on miner production.
    public var globalMultiplier: Double {
        upgradeProductionMultiplier * prestigeBonus * achievementBonus * difficulty.productionMultiplier
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

    /// Output multiplier for one miner tier: its milestones and its Mk upgrades.
    func tierMultiplier(_ miner: MinerID, owned count: Int) -> Double {
        Self.milestoneMultiplier(owned: count)
            * pow(Tuning.minerUpgradeMultiplier, Double(minerUpgradeLevel(miner)))
    }

    /// Coins per second from all units of one miner, without temporary boosts.
    public func rate(of miner: MinerID) -> Double {
        let count = owned(miner)
        guard count > 0 else { return 0 }
        return Double(count) * miner.baseRate * tierMultiplier(miner, owned: count) * globalMultiplier
    }

    /// Coins per second one more unit would add right now (ignores the milestone it might reach).
    public func ratePerUnit(of miner: MinerID) -> Double {
        miner.baseRate * tierMultiplier(miner, owned: owned(miner)) * globalMultiplier
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

    /// Share of a second's production each tap also earns.
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

    /// The flat part of a tap, which grows with prestige and achievements.
    public var tapBase: Double { tapFlatTotal * prestigeBonus * achievementBonus }

    /// Strong Fingers makes every tap earn 50% more.
    public var tapPerkMultiplier: Double { hasPerk(.strongFingers) ? 1.5 : 1 }

    /// Coins one tap earns with `production` coins per second: the flat part plus a share of
    /// production, rounded to a whole coin and never less than one.
    func tapValue(production: Double) -> Double {
        Self.wholeCoins((tapBase + tapShare * production) * tapPerkMultiplier, minimum: 1)
    }

    public func tapValue(at date: Date) -> Double { tapValue(production: production(at: date)) }

    /// What an automatic tap is worth, as a share of a tap: Auto Clicker Pro doubles it.
    public var autoTapStrength: Double {
        Tuning.autoTapStrength * (hasPerk(.autoClickerPro) ? 2 : 1)
    }

    /// Coins per second from automatic taps.
    func autoTapIncome(production: Double) -> Double {
        autoTapsPerSecond * autoTapStrength * tapValue(production: production)
    }

    /// Income that arrives without any input: miners plus automatic taps.
    public func idleIncome(at date: Date) -> Double {
        let production = production(at: date)
        return production + autoTapIncome(production: production)
    }

    /// Idle income per second without a boost, and while the current boost (if any) runs.
    var incomeRates: (normal: Double, boosted: Double) {
        let base = baseProduction
        let normal = base + autoTapIncome(production: base)
        guard let boost else { return (normal, normal) }
        let boostedProduction = base * boost.multiplier
        return (normal, boostedProduction + autoTapIncome(production: boostedProduction))
    }

    // MARK: Combos

    /// Quick taps in a row needed for the biggest combo: Combo Master halves it.
    public var comboTapsToMax: Int { hasPerk(.comboMaster) ? Tuning.comboTapsToMax / 2 : Tuning.comboTapsToMax }

    /// The biggest combo multiplier: Combo Master raises it to ×3.
    public var comboMaxMultiplier: Double { hasPerk(.comboMaster) ? 3 : Tuning.comboMaxMultiplier }

    /// The multiplier for a tap that is the `streak`-th quick tap in a row (the first is 1).
    /// It climbs evenly from ×1 to the maximum.
    public func comboMultiplier(streak: Int) -> Double {
        let progress = Double(min(max(0, streak - 1), comboTapsToMax)) / Double(comboTapsToMax)
        return 1 + (comboMaxMultiplier - 1) * progress
    }

    // MARK: Offline Mining

    /// Time away that Offline Mining pays for at `level`: 30 minutes per level up to a day,
    /// then an hour per level, up to three days.
    public static func offlineCap(level: Int) -> TimeInterval {
        let level = min(max(0, level), Tuning.offlineMiningMaxLevel)
        let halfHours = min(level, Tuning.offlineMiningDayLevel)
        let hours = level - halfHours
        return Double(halfHours) * Tuning.offlineMiningStep + Double(hours) * Tuning.offlineMiningLateStep
    }

    /// How long miners keep earning while the app is closed: nothing until Offline Mining is bought.
    public var offlineCap: TimeInterval { Self.offlineCap(level: offlineMiningLevel) }

    /// The most time away one absence pays: the Offline Mining limit, but never less than the
    /// first minute, so leaving for longer never pays less than a quick app switch.
    public var timeAwayLimit: TimeInterval { max(offlineCap, Tuning.awayThreshold) }

    /// Price of the next Offline Mining level, or `nil` once it is at the maximum.
    public var offlineMiningPrice: Double? {
        guard offlineMiningLevel < Tuning.offlineMiningMaxLevel else { return nil }
        return Self.wholePrice(Tuning.offlineMiningBaseCost
                               * pow(Tuning.offlineMiningCostGrowth, Double(offlineMiningLevel)))
    }

    // MARK: Airdrops

    /// Seconds between airdrops: Airdrop Radar makes them more frequent.
    public var airdropInterval: ClosedRange<TimeInterval> {
        hasPerk(.airdropRadar) ? Tuning.radarAirdropInterval : Tuning.airdropInterval
    }

    /// How long an airdrop stays on screen.
    public var airdropLifetime: TimeInterval {
        hasPerk(.airdropRadar) ? Tuning.radarAirdropLifetime : Tuning.airdropLifetime
    }

    public var bullRunDuration: TimeInterval {
        hasPerk(.bullMarket) ? Tuning.bullMarketDuration : Tuning.bullRunDuration
    }

    /// Chance that an airdrop is a whale: Whale Watcher triples it.
    public var whaleChance: Double { Tuning.whaleChance * (hasPerk(.whaleWatcher) ? 3 : 1) }

    // MARK: Side rewards

    public var stepMultiplier: Double {
        let upgradeFactor = upgrades.reduce(1.0) { result, upgrade in
            if case .steps(let factor) = upgrade.effect { return result * factor }
            return result
        }
        return upgradeFactor * (hasPerk(.marathon) ? 2 : 1)
    }

    public var miniGameMultiplier: Double {
        let upgradeFactor = upgrades.reduce(1.0) { result, upgrade in
            if case .miniGames(let factor) = upgrade.effect { return result * factor }
            return result
        }
        return upgradeFactor * (hasPerk(.arcadeChampion) ? 1.5 : 1)
    }

    /// Daily quest and streak rewards: Lucky Streak doubles them.
    public var dailyRewardMultiplier: Double { hasPerk(.luckyStreak) ? 2 : 1 }

    /// Share of a sale kept by the market: Market Insider removes the fee.
    public var marketSellRate: Double { hasPerk(.marketInsider) ? 1 : 1 - Tuning.marketSellFee }

    /// Idle income without temporary boosts.
    public var baseIdleIncome: Double { incomeRates.normal }

    /// Income that sizes step, mini-game and airdrop rewards, so they keep pace with progress.
    /// Boosts are left out so rewards stay predictable, and a floor keeps them worthwhile on day one.
    public var rewardIncome: Double { max(baseIdleIncome, Tuning.minimumRewardIncome) }

    /// Coins paid per step: a slice of idle income times step upgrades, in whole coins, never under one.
    public var stepValue: Double {
        Self.wholeCoins(max(Tuning.minimumStepValue, Tuning.stepSeconds * rewardIncome) * stepMultiplier, minimum: 1)
    }

    // MARK: Steps

    /// Steps open up after enough taps, so early coins come from tapping and building.
    /// Anyone who has connected steps before keeps them.
    public var areStepsUnlocked: Bool {
        steps.isConnected || steps.startDay != nil || stats.taps >= Tuning.stepsUnlockTaps
    }

    /// Taps still needed before steps unlock.
    public var tapsUntilSteps: Int { max(0, Tuning.stepsUnlockTaps - stats.taps) }
}
