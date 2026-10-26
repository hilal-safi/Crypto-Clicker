import Foundation

/// Coins credited while the player was away, and how they were made.
public struct OfflineReport: Equatable, Sendable, Identifiable {
    /// How long the app was closed.
    public let elapsed: TimeInterval
    /// How much of that time was paid: up to the Offline Mining limit.
    public let credited: TimeInterval
    public let earned: Double
    /// What earned the coins, largest first: each miner type, then automatic taps.
    /// The amounts add up to `earned`.
    public let sources: [Source]
    /// Paid seconds that ran during a Bull Run, and its multiplier (1 when there was none).
    public let boostedSeconds: TimeInterval
    public let boostMultiplier: Double
    /// The permanent multipliers on production while the player was away.
    public let multipliers: Multipliers
    /// The Offline Mining limit at the time (0 without the power-up).
    public let offlineCap: TimeInterval

    public var id: Double { elapsed }
    public var wasCapped: Bool { credited < elapsed }

    public struct Source: Equatable, Sendable, Identifiable {
        public enum Kind: Equatable, Sendable {
            case miner(MinerID)
            case autoTaps
        }

        public let kind: Kind
        /// Units owned, or automatic taps per second.
        public let count: Double
        public let coins: Double

        public var id: String {
            switch kind {
            case .miner(let miner): miner.rawValue
            case .autoTaps: "autoTaps"
            }
        }
    }

    public struct Multipliers: Equatable, Sendable {
        public let upgrades: Double
        public let prestige: Double
        public let achievements: Double
        public let difficulty: Double

        public var total: Double { upgrades * prestige * achievements * difficulty }
    }
}

/// What an airdrop holds, decided when it appears so a whale can look different.
public enum AirdropKind: Equatable, Sendable {
    case coins, bullRun, whale
}

/// What an airdrop paid out.
public enum AirdropReward: Equatable, Sendable {
    case coins(Double)
    case bullRun(multiplier: Double, duration: TimeInterval)
    /// A rare whale: about an hour of income at once.
    case whale(Double)
}

enum CreditSource {
    case tap, idle, offline, steps, games, airdrop, daily
}

/// Every way the player can change the game. Each method validates its own rules,
/// so the UI can call them directly and simply ignore a `false` result.
/// Mini-game actions live in `MiniGameActions.swift`.
extension GameState {
    // MARK: Time

    /// Credits income for the time since the last update. The live tick loop and a return
    /// from the background share this one path, so time is never paid twice or lost:
    /// short gaps are paid in full, longer ones (time away) up to the Offline Mining limit,
    /// with a report for the welcome-back screen.
    @discardableResult
    public mutating func advance(to now: Date) -> OfflineReport? {
        let elapsed = now.timeIntervalSince(lastUpdate)
        guard elapsed > 0 else {
            if elapsed < 0 { lastUpdate = now } // The clock moved backwards: re-anchor, pay nothing.
            return nil
        }
        let isAway = elapsed >= Tuning.awayThreshold
        let credited = min(elapsed, timeAwayLimit)
        let earned = income(from: lastUpdate, seconds: credited)
        let report = isAway ? offlineReport(elapsed: elapsed, credited: credited, earned: earned) : nil
        credit(earned, source: isAway ? .offline : .idle)
        lastUpdate = now
        expireBoost(at: now)
        stats.peakIncome = max(stats.peakIncome, idleIncome(at: now))
        return report
    }

    /// Breaks down `credited` seconds of income from `lastUpdate`, before it is paid.
    func offlineReport(elapsed: TimeInterval, credited: TimeInterval, earned: Double) -> OfflineReport {
        var boostedSeconds = 0.0
        var multiplier = 1.0
        if let boost {
            boostedSeconds = min(credited, max(0, boost.endsAt.timeIntervalSince(lastUpdate)))
            if boostedSeconds > 0 { multiplier = boost.multiplier }
        }
        let normalSeconds = credited - boostedSeconds
        var sources: [OfflineReport.Source] = MinerID.allCases.compactMap { miner in
            let rate = rate(of: miner)
            guard rate > 0 else { return nil }
            return .init(kind: .miner(miner), count: Double(owned(miner)),
                         coins: rate * (normalSeconds + boostedSeconds * multiplier))
        }
        let autoTaps = autoTapsPerSecond
        if autoTaps > 0 {
            let base = baseProduction
            let coins = autoTapIncome(production: base) * normalSeconds
                + autoTapIncome(production: base * multiplier) * boostedSeconds
            if coins > 0 { sources.append(.init(kind: .autoTaps, count: autoTaps, coins: coins)) }
        }
        sources.sort { $0.coins > $1.coins }
        return OfflineReport(
            elapsed: elapsed, credited: credited, earned: earned, sources: sources,
            boostedSeconds: boostedSeconds, boostMultiplier: multiplier,
            multipliers: .init(upgrades: upgradeProductionMultiplier, prestige: prestigeBonus,
                               achievements: achievementBonus, difficulty: difficulty.productionMultiplier),
            offlineCap: offlineCap)
    }

    /// Idle income over `seconds` starting at `start`, honouring a boost that ends part-way.
    func income(from start: Date, seconds: TimeInterval) -> Double {
        guard seconds > 0 else { return 0 }
        let rates = incomeRates
        var boosted = 0.0
        if let boost { boosted = min(seconds, max(0, boost.endsAt.timeIntervalSince(start))) }
        return rates.normal * (seconds - boosted) + rates.boosted * boosted
    }

    mutating func expireBoost(at now: Date) {
        if let boost, now >= boost.endsAt { self.boost = nil }
    }

    /// Starts a Bull Run, or keeps a longer one that is already running.
    mutating func startBullRun(duration: TimeInterval, at now: Date) {
        let ends = now.addingTimeInterval(duration)
        boost = Boost(multiplier: Tuning.bullRunMultiplier, endsAt: max(ends, activeBoost(at: now)?.endsAt ?? ends))
    }

    /// Records idle income for the income chart, at most once per `Tuning.incomeSampleInterval`,
    /// keeping a week of samples.
    public mutating func recordIncomeSample(at now: Date) {
        incomeHistory.removeAll { $0.date > now } // The clock moved backwards.
        if let last = incomeHistory.last, now.timeIntervalSince(last.date) < Tuning.incomeSampleInterval { return }
        incomeHistory.append(IncomeSample(date: now, income: baseIdleIncome))
        let overflow = incomeHistory.count - Tuning.maxIncomeSamples
        if overflow > 0 { incomeHistory.removeFirst(overflow) }
    }

    // MARK: Tapping

    /// Credits `count` taps and returns the coins earned. `combo` is this tap's place in a run of
    /// quick taps (1 for a lone tap): longer runs multiply its value, up to the combo maximum.
    @discardableResult
    public mutating func tap(count: Int = 1, at now: Date, combo: Int = 1) -> Double {
        guard count > 0 else { return 0 }
        let value = combo > 1 ? Self.wholeCoins(tapValue(at: now) * comboMultiplier(streak: combo), minimum: 1)
                              : tapValue(at: now)
        let earned = value * Double(count)
        credit(earned, source: .tap)
        stats.taps += count
        stats.bestTap = max(stats.bestTap, value)
        stats.bestCombo = max(stats.bestCombo, combo)
        return earned
    }

    /// Applies a batch of taps made on Apple Watch exactly once.
    /// Returns `nil` when the batch was already applied.
    @discardableResult
    public mutating func applyWatchTaps(_ batch: WatchTapBatch, at now: Date) -> Double? {
        guard !recentWatchBatches.contains(batch.id) else { return nil }
        recentWatchBatches.append(batch.id)
        let overflow = recentWatchBatches.count - Tuning.rememberedWatchBatches
        if overflow > 0 { recentWatchBatches.removeFirst(overflow) }
        let taps = min(max(batch.taps, 0), Tuning.maxWatchTapsPerBatch)
        return tap(count: taps, at: now)
    }

    // MARK: Shopping

    @discardableResult
    public mutating func buy(_ miner: MinerID, quantity: Int) -> Bool {
        guard quantity > 0, isRevealed(miner) else { return false }
        let cost = price(of: miner, quantity: quantity)
        guard cost.isFinite, cost <= coins else { return false }
        spend(cost)
        let count = owned(miner) + quantity
        miners[miner] = count
        stats.minersBought += quantity
        stats.maxOwned[miner] = max(stats.maxOwned[miner, default: 0], count)
        stats.maxTotalMiners = max(stats.maxTotalMiners, totalMiners)
        return true
    }

    /// Buys the miner's next Mk upgrade, which doubles its output for the rest of the run.
    @discardableResult
    public mutating func buyMinerUpgrade(_ miner: MinerID) -> Bool {
        guard let next = availableMinerUpgrade(miner), next.price <= coins else { return false }
        spend(next.price)
        minerUpgrades[miner] = next.level + 1
        stats.minerUpgradesBought += 1
        return true
    }

    @discardableResult
    public mutating func buy(_ upgrade: UpgradeID) -> Bool {
        guard !upgrades.contains(upgrade), isRevealed(upgrade), upgrade.cost <= coins else { return false }
        spend(upgrade.cost)
        upgrades.insert(upgrade)
        stats.maxUpgrades = max(stats.maxUpgrades, upgrades.count)
        return true
    }

    // MARK: Power-ups

    /// Buys the next Offline Mining level. Like every power-up it is permanent: prestiges keep it.
    @discardableResult
    public mutating func buyOfflineMining() -> Bool {
        guard let price = offlineMiningPrice, price <= coins else { return false }
        spend(price)
        offlineMiningLevel += 1
        return true
    }

    // MARK: Settings

    /// Changing difficulty never raises the current run's prestige reward,
    /// unless the run has barely started (no miners yet).
    public mutating func setDifficulty(_ newValue: Difficulty) {
        difficulty = newValue
        if totalMiners == 0 && stats.runCoins < 1_000 {
            runPrestigeMultiplier = newValue.prestigeMultiplier
        } else {
            runPrestigeMultiplier = min(runPrestigeMultiplier, newValue.prestigeMultiplier)
        }
    }

    // MARK: Airdrops

    /// What a new airdrop holds. `roll` is a random number in `0..<1` (injected for testing).
    public func airdropKind(roll: Double) -> AirdropKind {
        if roll < whaleChance { return .whale }
        if roll < whaleChance + Tuning.bullRunChance { return .bullRun }
        return .coins
    }

    /// Pays an airdrop the player caught.
    @discardableResult
    public mutating func claimAirdrop(_ kind: AirdropKind, at now: Date) -> AirdropReward {
        stats.airdrops += 1
        let income = rewardIncome
        switch kind {
        case .bullRun:
            startBullRun(duration: bullRunDuration, at: now)
            return .bullRun(multiplier: Tuning.bullRunMultiplier, duration: bullRunDuration)
        case .whale:
            stats.whaleAirdrops += 1
            let amount = Self.wholeCoins(income * Tuning.whaleIncomeSeconds, minimum: 1)
            credit(amount, source: .airdrop)
            return .whale(amount)
        case .coins:
            let amount = Self.wholeCoins(max(min(coins * Tuning.airdropBankShare, income * Tuning.airdropIncomeSeconds),
                                             income * Tuning.airdropMinimumSeconds), minimum: 1)
            credit(amount, source: .airdrop)
            return .coins(amount)
        }
    }

    // MARK: Steps

    /// Starts rewarding steps from today. Fails until steps are unlocked by tapping.
    @discardableResult
    public mutating func connectSteps(today: String) -> Bool {
        guard areStepsUnlocked else { return false }
        steps.isConnected = true
        if steps.startDay == nil { steps.startDay = today }
        return true
    }

    public mutating func disconnectSteps() {
        steps.isConnected = false
    }

    /// Pays for steps not yet rewarded. `days` are HealthKit daily totals for the sync window.
    /// Safe to call repeatedly: already-paid steps are never paid again.
    @discardableResult
    public mutating func creditSteps(_ days: [StepDay], today: String, at now: Date) -> StepCredit {
        guard steps.isConnected else { return StepCredit(steps: 0, coins: 0) }
        var newSteps = 0
        for day in days {
            let unpaid = steps.unpaid(day)
            guard unpaid > 0 else { continue }
            newSteps += unpaid
            steps.credited[day.key] = day.steps
            stats.bestDaySteps = max(stats.bestDaySteps, day.steps)
        }
        steps.todayKey = today
        steps.todaySteps = days.first { $0.key == today }?.steps ?? 0
        steps.lastSync = now
        if let oldest = days.map(\.key).min() {
            steps.credited = steps.credited.filter { $0.key >= oldest }
        }
        guard newSteps > 0 else { return StepCredit(steps: 0, coins: 0) }
        stats.lifetimeSteps += newSteps
        let coins = Double(newSteps) * stepValue
        credit(coins, source: .steps)
        return StepCredit(steps: newSteps, coins: coins)
    }

    // MARK: Ledger

    mutating func credit(_ amount: Double, source: CreditSource) {
        guard amount.isFinite, amount > 0 else { return }
        coins += amount
        stats.lifetimeCoins += amount
        stats.runCoins += amount
        switch source {
        case .tap: stats.earnedFromTaps += amount
        case .idle: stats.earnedFromIdle += amount
        case .offline: stats.earnedOffline += amount
        case .steps: stats.earnedFromSteps += amount
        case .games: stats.earnedFromGames += amount
        case .airdrop: stats.earnedFromAirdrops += amount
        case .daily: stats.earnedFromDaily += amount
        }
    }

    mutating func spend(_ amount: Double) {
        coins = max(0, coins - amount)
        stats.spent += amount
    }

    mutating func giveTokens(_ token: TokenID, amount: Int) {
        guard amount > 0 else { return }
        tokens[token, default: 0] += amount
    }
}
