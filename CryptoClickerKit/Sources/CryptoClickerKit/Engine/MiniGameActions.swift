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
    public mutating func payUnfinishedRun() -> (run: ArcadeRun, payout: ArcadePayout)? {
        guard let run = unfinishedRun else { return nil }
        let payout: ArcadePayout = switch run.game {
        case .tetris: finishTetris(score: run.score, lines: run.detail, challengeDay: run.challengeDay)
        case .snake: finishSnake(score: run.score)
        case .brickBreaker: finishBrickBreaker(score: run.score, bricks: run.detail)
        case .bubbleBlaster: finishBubbleBlaster(score: run.score, popped: run.detail)
        case .merge2048: finishMerge2048(score: run.score, bestTile: run.detail)
        case .blackjack, .slots: ArcadePayout(coins: 0, isNewBest: false, isChallengeBonus: false)
        }
        unfinishedRun = nil
        return (run, payout)
    }

    /// Coins an arcade game pays for `score` points, before any bonus.
    public func arcadeReward(score: Int, secondsPerPoint: Double, multiplier: Double = 1) -> Double {
        guard score > 0 else { return 0 }
        return Self.wholeCoins(Double(score) * secondsPerPoint * miniGameMultiplier * multiplier * rewardIncome)
    }

    /// Records a finished Tetris game and pays its reward once. `challengeDay` marks a daily
    /// challenge game: the day's first one that scores pays double.
    @discardableResult
    public mutating func finishTetris(score: Int, lines: Int, challengeDay: String? = nil) -> ArcadePayout {
        let isNewBest = score > stats.tetrisBestScore
        stats.tetrisGames += 1
        stats.tetrisLines += max(0, lines)
        stats.tetrisBestScore = max(stats.tetrisBestScore, score)
        var isChallengeBonus = false
        // A challenge from an earlier day than the latest one played (a game held overnight)
        // pays as an ordinary game.
        if let day = challengeDay, day >= (daily.challengeDay ?? "") {
            if daily.challengeDay != day {
                daily.challengeDay = day
                daily.challengeBest = 0
                daily.challengeRewarded = false
            }
            daily.challengeBest = max(daily.challengeBest, score)
            if !daily.challengeRewarded && score > 0 {
                daily.challengeRewarded = true
                isChallengeBonus = true
            }
        }
        return payArcade(score: score, secondsPerPoint: Tuning.tetrisSecondsPerPoint, isNewBest: isNewBest,
                         isChallengeBonus: isChallengeBonus)
    }

    @discardableResult
    public mutating func finishSnake(score: Int) -> ArcadePayout {
        let isNewBest = score > stats.snakeBestScore
        stats.snakeGames += 1
        stats.snakeBestScore = max(stats.snakeBestScore, score)
        stats.snakeCoinsEaten += max(0, score) / SnakeGame.pointsPerCoin
        return payArcade(score: score, secondsPerPoint: Tuning.snakeSecondsPerPoint, isNewBest: isNewBest)
    }

    @discardableResult
    public mutating func finishBrickBreaker(score: Int, bricks: Int) -> ArcadePayout {
        let isNewBest = score > stats.brickBreakerBestScore
        stats.brickBreakerGames += 1
        stats.brickBreakerBestScore = max(stats.brickBreakerBestScore, score)
        stats.bricksBroken += max(0, bricks)
        return payArcade(score: score, secondsPerPoint: Tuning.brickBreakerSecondsPerPoint, isNewBest: isNewBest)
    }

    @discardableResult
    public mutating func finishBubbleBlaster(score: Int, popped: Int) -> ArcadePayout {
        let isNewBest = score > stats.bubbleBestScore
        stats.bubbleGames += 1
        stats.bubbleBestScore = max(stats.bubbleBestScore, score)
        stats.bubblesPopped += max(0, popped)
        return payArcade(score: score, secondsPerPoint: Tuning.bubbleSecondsPerPoint, isNewBest: isNewBest)
    }

    /// Records a finished 2048 game and pays it once. Making a 2048 tile also pays a bonus of
    /// `Tuning.merge2048WinSeconds` of income.
    @discardableResult
    public mutating func finishMerge2048(score: Int, bestTile: Int) -> ArcadePayout {
        let isNewBest = score > stats.merge2048BestScore
        stats.merge2048Games += 1
        stats.merge2048BestScore = max(stats.merge2048BestScore, score)
        stats.merge2048BestTile = max(stats.merge2048BestTile, bestTile)
        // Stops at Int.max rather than trapping on a 32-bit watch.
        let (points, overflow) = stats.merge2048Points.addingReportingOverflow(max(0, score))
        stats.merge2048Points = overflow ? Int.max : points
        let payout = payArcade(score: score, secondsPerPoint: Tuning.merge2048SecondsPerPoint, isNewBest: isNewBest)
        guard bestTile >= Merge2048Game.winningValue else { return payout }
        let bonus = merge2048TileBonus
        credit(bonus, source: .games)
        return ArcadePayout(coins: payout.coins + bonus, isNewBest: payout.isNewBest,
                            isChallengeBonus: payout.isChallengeBonus, tileBonus: bonus)
    }

    /// The bonus for making a 2048 tile: `Tuning.merge2048WinSeconds` of income.
    public var merge2048TileBonus: Double {
        Self.wholeCoins(Tuning.merge2048WinSeconds * rewardIncome * miniGameMultiplier)
    }

    /// What ending a 2048 game now would pay, without paying it.
    public func merge2048Reward(score: Int, bestTile: Int) -> Double {
        let isNewBest = score > stats.merge2048BestScore
        let points = arcadeReward(score: score, secondsPerPoint: Tuning.merge2048SecondsPerPoint,
                                  multiplier: isNewBest ? 1 + Tuning.newBestBonus : 1)
        return points + (bestTile >= Merge2048Game.winningValue ? merge2048TileBonus : 0)
    }

    /// Pays a finished game: a new best score earns `Tuning.newBestBonus` more.
    private mutating func payArcade(score: Int, secondsPerPoint: Double, isNewBest: Bool,
                                    isChallengeBonus: Bool = false) -> ArcadePayout {
        unfinishedRun = nil // A finished game is never paid again from the hold.
        var multiplier = isNewBest ? 1 + Tuning.newBestBonus : 1
        if isChallengeBonus { multiplier *= Tuning.dailyChallengeMultiplier }
        let reward = arcadeReward(score: score, secondsPerPoint: secondsPerPoint, multiplier: multiplier)
        credit(reward, source: .games)
        return ArcadePayout(coins: reward, isNewBest: isNewBest, isChallengeBonus: isChallengeBonus)
    }
}

/// What a finished arcade game paid.
public struct ArcadePayout: Equatable, Sendable {
    public let coins: Double
    /// The score beat the previous best, so the reward includes the new-best bonus.
    public let isNewBest: Bool
    /// The reward was doubled as the day's first daily challenge.
    public let isChallengeBonus: Bool
    /// Coins included for making a 2048 tile.
    public internal(set) var tileBonus: Double = 0
}
