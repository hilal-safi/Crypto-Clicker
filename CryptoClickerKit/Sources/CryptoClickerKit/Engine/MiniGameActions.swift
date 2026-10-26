import Foundation

/// Unlocking mini-games, betting tokens at the casino games, and paying arcade scores.
/// Every reward is a whole number of coins sized by `rewardIncome`, so it keeps pace with progress.
extension GameState {
    @discardableResult
    public mutating func unlock(_ game: MiniGame) -> Bool {
        guard !unlockedGames.contains(game), game.unlockCost <= coins else { return false }
        spend(game.unlockCost)
        unlockedGames.insert(game)
        return true
    }

    // MARK: Blackjack

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
        return Self.wholeCoins(bonus * miniGameMultiplier * (isNatural ? Tuning.blackjackNaturalBonus : 1))
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

    // MARK: Crypto Slots

    /// Coins a winning spin pays on top of its tokens: a share of the stake's coin value for each
    /// multiple of the bet, up to `Tuning.slotsWinSeconds` of income per multiple.
    public func slotsBonus(bet: Int, token: TokenID, multiple: Int) -> Double {
        guard multiple >= 2 else { return 0 }
        let stakeValue = Double(max(0, bet)) * token.price
        let perMultiple = min(stakeValue * Tuning.slotsStakeShare, Tuning.slotsWinSeconds * rewardIncome)
        return Self.wholeCoins(perMultiple * Double(multiple) * miniGameMultiplier)
    }

    /// Takes the bet, spins and pays in one step, so closing the app mid-spin can't lose a bet.
    /// Returns `nil` (and changes nothing) if the player can't cover the bet.
    @discardableResult
    public mutating func spinSlots<R: RandomNumberGenerator>(_ token: TokenID, bet: Int, using rng: inout R) -> SlotsSpin? {
        guard bet > 0, tokenCount(token) >= bet else { return nil }
        let stops = SlotMachine.spin(using: &rng)
        let multiple = SlotMachine.payout(for: SlotMachine.line(stops: stops))
        tokens[token] = tokenCount(token) - bet
        giveTokens(token, amount: bet * multiple)
        let bonus = slotsBonus(bet: bet, token: token, multiple: multiple)
        credit(bonus, source: .games)
        stats.slotsSpins += 1
        if multiple >= 2 { stats.slotsWins += 1 }
        if multiple == SlotMachine.jackpot { stats.slotsJackpots += 1 }
        return SlotsSpin(stops: stops, token: token, bet: bet, multiple: multiple, bonus: bonus)
    }

    // MARK: Arcade games

    /// Remembers a game in progress as the app goes to the background (replacing an older one).
    public mutating func holdArcadeRun(_ run: ArcadeRun) {
        guard !run.game.isCasino else { return }
        unfinishedRun = run
    }

    /// Forgets the held game, once the player is back and still playing it.
    public mutating func releaseArcadeRun() {
        unfinishedRun = nil
    }

    /// Pays a game the app closed in the middle of, as if it had just ended.
    @discardableResult
    public mutating func payUnfinishedRun() -> (run: ArcadeRun, reward: Double)? {
        guard let run = unfinishedRun else { return nil }
        let reward: Double = switch run.game {
        case .tetris: finishTetris(score: run.score, lines: run.detail)
        case .snake: finishSnake(score: run.score)
        case .brickBreaker: finishBrickBreaker(score: run.score, bricks: run.detail)
        case .bubbleBlaster: finishBubbleBlaster(score: run.score, popped: run.detail)
        case .blackjack, .slots: 0
        }
        unfinishedRun = nil
        return (run, reward)
    }

    /// Coins an arcade game pays for `score` points.
    public func arcadeReward(score: Int, secondsPerPoint: Double) -> Double {
        guard score > 0 else { return 0 }
        return Self.wholeCoins(Double(score) * secondsPerPoint * miniGameMultiplier * rewardIncome)
    }

    /// Records a finished Tetris game and pays its reward once.
    @discardableResult
    public mutating func finishTetris(score: Int, lines: Int) -> Double {
        stats.tetrisGames += 1
        stats.tetrisLines += max(0, lines)
        stats.tetrisBestScore = max(stats.tetrisBestScore, score)
        return payArcade(score: score, secondsPerPoint: Tuning.tetrisSecondsPerPoint)
    }

    @discardableResult
    public mutating func finishSnake(score: Int) -> Double {
        stats.snakeGames += 1
        stats.snakeBestScore = max(stats.snakeBestScore, score)
        return payArcade(score: score, secondsPerPoint: Tuning.snakeSecondsPerPoint)
    }

    @discardableResult
    public mutating func finishBrickBreaker(score: Int, bricks: Int) -> Double {
        stats.brickBreakerGames += 1
        stats.brickBreakerBestScore = max(stats.brickBreakerBestScore, score)
        stats.bricksBroken += max(0, bricks)
        return payArcade(score: score, secondsPerPoint: Tuning.brickBreakerSecondsPerPoint)
    }

    @discardableResult
    public mutating func finishBubbleBlaster(score: Int, popped: Int) -> Double {
        stats.bubbleGames += 1
        stats.bubbleBestScore = max(stats.bubbleBestScore, score)
        stats.bubblesPopped += max(0, popped)
        return payArcade(score: score, secondsPerPoint: Tuning.bubbleSecondsPerPoint)
    }

    private mutating func payArcade(score: Int, secondsPerPoint: Double) -> Double {
        unfinishedRun = nil // A finished game is never paid again from the hold.
        let reward = arcadeReward(score: score, secondsPerPoint: secondsPerPoint)
        credit(reward, source: .games)
        return reward
    }
}
