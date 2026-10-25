import Foundation

/// Coins credited while the player was away.
public struct OfflineReport: Equatable, Sendable, Identifiable {
    public let elapsed: TimeInterval
    public let credited: TimeInterval
    public let earned: Double
    public var id: Double { elapsed }
    public var wasCapped: Bool { credited < elapsed }
}

/// What an airdrop paid out.
public enum AirdropReward: Equatable, Sendable {
    case coins(Double)
    case bullRun(multiplier: Double, duration: TimeInterval)
}

enum CreditSource {
    case tap, idle, offline, steps, games, airdrop
}

/// Every way the player can change the game. Each method validates its own rules,
/// so the UI can call them directly and simply ignore a `false` result.
extension GameState {
    // MARK: Time

    /// Credits income for the time since the last update. The live tick loop and a return
    /// from the background share this one path, so time is never paid twice or lost:
    /// short gaps are paid in full, longer ones (time away) up to the offline cap,
    /// with a report for the welcome-back screen.
    @discardableResult
    public mutating func advance(to now: Date) -> OfflineReport? {
        let elapsed = now.timeIntervalSince(lastUpdate)
        guard elapsed > 0 else {
            if elapsed < 0 { lastUpdate = now } // The clock moved backwards: re-anchor, pay nothing.
            return nil
        }
        let isAway = elapsed >= Tuning.awayThreshold
        let credited = isAway ? min(elapsed, offlineCap) : elapsed
        let earned = income(from: lastUpdate, seconds: credited)
        credit(earned, source: isAway ? .offline : .idle)
        lastUpdate = now
        expireBoost(at: now)
        stats.peakIncome = max(stats.peakIncome, idleIncome(at: now))
        return isAway ? OfflineReport(elapsed: elapsed, credited: credited, earned: earned) : nil
    }

    /// Idle income over `seconds` starting at `start`, honouring a boost that ends part-way.
    func income(from start: Date, seconds: TimeInterval) -> Double {
        guard seconds > 0 else { return 0 }
        let parts = incomeParts
        var boosted = 0.0
        var multiplier = 1.0
        if let boost {
            boosted = min(seconds, max(0, boost.endsAt.timeIntervalSince(start)))
            multiplier = boost.multiplier
        }
        return parts.fixed * seconds + parts.boostable * (seconds + (multiplier - 1) * boosted)
    }

    mutating func expireBoost(at now: Date) {
        if let boost, now >= boost.endsAt { self.boost = nil }
    }

    // MARK: Tapping

    @discardableResult
    public mutating func tap(count: Int = 1, at now: Date) -> Double {
        guard count > 0 else { return 0 }
        let value = tapValue(at: now)
        let earned = value * Double(count)
        credit(earned, source: .tap)
        stats.taps += count
        stats.bestTap = max(stats.bestTap, value)
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
        stats.maxOwned[miner] = max(stats.maxOwned[miner, default: 0], count)
        stats.maxTotalMiners = max(stats.maxTotalMiners, totalMiners)
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

    /// Price of `quantity` tokens.
    public func price(of token: TokenID, quantity: Int) -> Double {
        token.price * Double(max(0, quantity))
    }

    @discardableResult
    public mutating func buyTokens(_ token: TokenID, quantity: Int) -> Bool {
        let cost = price(of: token, quantity: quantity)
        guard quantity > 0, cost <= coins else { return false }
        spend(cost)
        tokens[token, default: 0] += quantity
        stats.tokensBought[token, default: 0] += quantity
        return true
    }

    @discardableResult
    public mutating func unlock(_ game: MiniGame) -> Bool {
        guard !unlockedGames.contains(game), game.unlockCost <= coins else { return false }
        spend(game.unlockCost)
        unlockedGames.insert(game)
        return true
    }

    // MARK: Settings

    /// Changing difficulty never raises the current run's fork reward,
    /// unless the run has barely started (no miners yet).
    public mutating func setDifficulty(_ newValue: Difficulty) {
        difficulty = newValue
        if totalMiners == 0 && stats.runCoins < 1_000 {
            runForkMultiplier = newValue.forkMultiplier
        } else {
            runForkMultiplier = min(runForkMultiplier, newValue.forkMultiplier)
        }
    }

    // MARK: Prestige

    /// Resets coins, miners, upgrades and boosts for permanent forks.
    /// Tokens, unlocked games, achievements and lifetime stats carry over.
    /// Returns the number of forks gained (0 if a fork is not available yet).
    @discardableResult
    public mutating func hardFork(at now: Date) -> Int {
        let gained = claimableForks
        guard gained > 0 else { return 0 }
        forks += gained
        forkPointsClaimed = forkPoints
        stats.forksPerformed += 1
        stats.runCoins = 0
        coins = 0
        miners = [:]
        upgrades = []
        boost = nil
        runForkMultiplier = difficulty.forkMultiplier
        runStart = now
        lastUpdate = now
        return gained
    }

    // MARK: Airdrops

    /// Pays an airdrop. `roll` is a random number in `0..<1` (injected for testing).
    @discardableResult
    public mutating func claimAirdrop(roll: Double, at now: Date) -> AirdropReward {
        stats.airdrops += 1
        if roll < Tuning.bullRunChance {
            let ends = now.addingTimeInterval(Tuning.bullRunDuration)
            boost = Boost(multiplier: Tuning.bullRunMultiplier, endsAt: max(ends, boost?.endsAt ?? ends))
            return .bullRun(multiplier: Tuning.bullRunMultiplier, duration: Tuning.bullRunDuration)
        }
        let income = rewardIncome
        let amount = max(min(coins * Tuning.airdropBankShare, income * Tuning.airdropIncomeSeconds), income * 30)
        credit(amount, source: .airdrop)
        return .coins(amount)
    }

    // MARK: Steps

    public mutating func connectSteps(today: String) {
        steps.isConnected = true
        if steps.startDay == nil { steps.startDay = today }
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

    // MARK: Mini-games

    /// Stakes tokens on the current Blackjack round: the opening bet, a double or a split.
    /// A round uses one token type. Fails if the player does not hold enough.
    @discardableResult
    public mutating func placeBlackjackBet(_ token: TokenID, amount: Int) -> Bool {
        guard amount > 0, tokenCount(token) >= amount else { return false }
        if let open = blackjackStake, open.token != token { return false }
        tokens[token] = tokenCount(token) - amount
        blackjackStake = BlackjackStake(token: token, amount: (blackjackStake?.amount ?? 0) + amount)
        return true
    }

    /// Returns the stake of a round that never finished because the app closed mid-hand.
    @discardableResult
    public mutating func refundBlackjackStake() -> BlackjackStake? {
        guard let stake = blackjackStake else { return nil }
        blackjackStake = nil
        giveTokens(stake.token, amount: stake.amount)
        return stake
    }

    /// Coins a winning hand pays on top of its tokens: half the stake's coin value, up to
    /// `Tuning.blackjackWinSeconds` of income, times mini-game upgrades. Naturals pay 1.5x.
    public func blackjackBonus(bet: Int, token: TokenID, isNatural: Bool = false) -> Double {
        let stakeValue = Double(max(0, bet)) * token.price
        let bonus = min(stakeValue * Tuning.blackjackStakeShare, Tuning.blackjackWinSeconds * rewardIncome)
        return bonus * miniGameMultiplier * (isNatural ? Tuning.blackjackNaturalBonus : 1)
    }

    /// The smallest bet in `token` that earns the full coin bonus.
    public func blackjackBetForFullBonus(_ token: TokenID) -> Int {
        let needed = Tuning.blackjackWinSeconds * rewardIncome / Tuning.blackjackStakeShare / token.price
        return max(1, Int(min(needed.rounded(.up), 1e9))) // Fits a 32-bit Int on Apple Watch.
    }

    /// Pays a finished round: winnings back to the wallet, statistics, and a coin bonus per won hand.
    @discardableResult
    public mutating func settleBlackjack(_ results: [BlackjackResult], token: TokenID) -> Double {
        blackjackStake = nil
        giveTokens(token, amount: results.reduce(0) { $0 + $1.payout })
        stats.blackjackHands += 1
        var bonus = 0.0
        for result in results {
            switch result.outcome {
            case .blackjack:
                stats.blackjackWins += 1
                stats.blackjackNaturals += 1
                bonus += blackjackBonus(bet: result.bet, token: token, isNatural: true)
            case .win:
                stats.blackjackWins += 1
                bonus += blackjackBonus(bet: result.bet, token: token)
            case .push, .lose:
                break
            }
        }
        credit(bonus, source: .games)
        return bonus
    }

    mutating func giveTokens(_ token: TokenID, amount: Int) {
        guard amount > 0 else { return }
        tokens[token, default: 0] += amount
    }

    /// Records a finished Tetris game and pays its reward once.
    @discardableResult
    public mutating func finishTetris(score: Int, lines: Int) -> Double {
        stats.tetrisGames += 1
        stats.tetrisLines += max(0, lines)
        stats.tetrisBestScore = max(stats.tetrisBestScore, score)
        guard score > 0 else { return 0 }
        let reward = Double(score) * Tuning.tetrisSecondsPerPoint * miniGameMultiplier * rewardIncome
        credit(reward, source: .games)
        return reward
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
        }
    }

    mutating func spend(_ amount: Double) {
        coins = max(0, coins - amount)
        stats.spent += amount
    }
}
