import Foundation

/// Unlocking mini-games, betting tokens at the casino games, and paying arcade scores.
/// Every reward is a whole number of coins sized by `rewardIncome`, so it keeps pace with progress.
/// Every finished game also counts toward the daily challenge.
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
        var wins = 0
        for result in results {
            switch result.outcome {
            case .blackjack:
                wins += 1
                stats.blackjackNaturals += 1
                bonus += blackjackBonus(bet: result.bet, token: token, isNatural: true)
            case .win:
                wins += 1
                bonus += blackjackBonus(bet: result.bet, token: token)
            case .lose:
                stats.blackjackStreak = 0
            case .push:
                break
            }
            if result.outcome == .win || result.outcome == .blackjack {
                stats.blackjackStreak += 1
                stats.blackjackBestStreak = max(stats.blackjackBestStreak, stats.blackjackStreak)
            }
        }
        stats.blackjackWins += wins
        credit(bonus, source: .games)
        let net = Double(results.reduce(0) { $0 + $1.net }) * token.price + bonus
        stats.blackjackBiggestWin = max(stats.blackjackBiggestWin, net)
        recordChallenge(.blackjack, value: wins, scored: wins > 0)
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
        stats.slotsWagered += Double(bet) * token.price
        stats.slotsPaidOut += Double(bet) * Double(multiple) * token.price
        stats.slotsBestMultiple = max(stats.slotsBestMultiple, multiple)
        if multiple >= 2 { stats.slotsWins += 1 }
        if multiple == SlotMachine.jackpot { stats.slotsJackpots += 1 }
        recordChallenge(.slots, value: multiple >= 2 ? 1 : 0, scored: multiple >= 2)
        return SlotsSpin(stops: stops, token: token, bet: bet, multiple: multiple, bonus: bonus)
    }

    // MARK: To the Moon

    /// Coins a cash-out pays on top of its tokens: a share of the stake's coin value for each
    /// multiple above 1×, up to `Tuning.moonWinSeconds` of income per multiple.
    public func moonBonus(bet: Int, token: TokenID, multiplier: Double) -> Double {
        guard multiplier > 1, multiplier.isFinite else { return 0 }
        let stakeValue = Double(max(0, bet)) * token.price
        let perMultiple = min(stakeValue * Tuning.moonStakeShare, Tuning.moonWinSeconds * rewardIncome)
        return Self.wholeCoins(perMultiple * (multiplier - 1) * miniGameMultiplier)
    }

    /// Takes the bet and launches a flight, drawing where it will crash. `autoCashOut` cashes out
    /// by itself on reaching that multiplier. Fails if a flight is already in the air or the
    /// player can't cover the bet.
    @discardableResult
    public mutating func launchMoon<R: RandomNumberGenerator>(_ token: TokenID, bet: Int, autoCashOut: Double?,
                                                                using rng: inout R) -> Bool {
        guard moonRound == nil, bet > 0, tokenCount(token) >= bet else { return false }
        let target = autoCashOut.flatMap { $0.isFinite ? max(MoonFlight.hundredths($0), 1.01) : nil }
        tokens[token] = tokenCount(token) - bet
        let crash = MoonFlight.crashPoint(roll: Double.random(in: 0..<1, using: &rng))
        moonRound = MoonRound(token: token, bet: bet, crashPoint: crash, autoCashOut: target)
        stats.moonFlights += 1
        stats.moonWagered += Double(bet) * token.price
        return true
    }

    /// Where the flight in the air stands `seconds` after launch. The automatic cash-out is checked
    /// first, so a target equal to the crash point still pays.
    public func moonState(after seconds: TimeInterval) -> MoonState? {
        guard let round = moonRound else { return nil }
        let multiplier = MoonFlight.multiplier(after: seconds)
        if let target = round.autoCashOut, target <= round.crashPoint, multiplier >= target {
            return .autoCashedOut(multiplier: target)
        }
        if multiplier >= round.crashPoint { return .crashed(at: round.crashPoint) }
        return .flying(multiplier: multiplier)
    }

    /// Ends the flight `seconds` after launch. While it is still flying, that's a cash-out at the
    /// current multiplier; after the automatic cash-out it pays that; after a crash the bet is lost.
    /// A cash-out pays the bet times the multiplier in whole tokens, plus a coin bonus.
    @discardableResult
    public mutating func settleMoon(after seconds: TimeInterval) -> MoonResult? {
        guard let round = moonRound, let state = moonState(after: seconds) else { return nil }
        moonRound = nil
        let multiplier: Double
        switch state {
        case .flying(let current), .autoCashedOut(let current):
            multiplier = current
        case .crashed:
            recordChallenge(.moon, value: 0, scored: false)
            return MoonResult(token: round.token, bet: round.bet, cashedOutAt: nil, crashPoint: round.crashPoint,
                              tokensWon: 0, bonus: 0)
        }
        let won = Int(min((Double(round.bet) * multiplier).rounded(.down), Double(Int32.max)))
        giveTokens(round.token, amount: won)
        let bonus = moonBonus(bet: round.bet, token: round.token, multiplier: multiplier)
        credit(bonus, source: .games)
        stats.moonCashOuts += 1
        stats.moonBestMultiplier = max(stats.moonBestMultiplier, multiplier)
        stats.moonPaidOut += Double(won) * round.token.price
        stats.moonBiggestWin = max(stats.moonBiggestWin, Double(won - round.bet) * round.token.price + bonus)
        recordChallenge(.moon, value: multiplier >= 2 ? 1 : 0, scored: true)
        return MoonResult(token: round.token, bet: round.bet, cashedOutAt: multiplier, crashPoint: round.crashPoint,
                          tokensWon: won, bonus: bonus)
    }

    /// Returns the bet of a flight that never finished because the app closed mid-flight. (Leaving
    /// the screen or the app normally cashes out first, so this only happens after a crash of the app.)
    @discardableResult
    public mutating func refundMoonRound() -> MoonRound? {
        guard let round = moonRound else { return nil }
        moonRound = nil
        giveTokens(round.token, amount: round.bet)
        return round
    }

    // MARK: Video Poker

    /// Coins a hand pays on top of its tokens for two pair or better: a share of the stake's coin
    /// value for each multiple of the bet, up to `Tuning.pokerWinSeconds` of income per multiple.
    public func pokerBonus(bet: Int, token: TokenID, hand: PokerHand) -> Double {
        let multiple = hand.payout
        guard multiple >= 2 else { return 0 }
        let stakeValue = Double(max(0, bet)) * token.price
        let perMultiple = min(stakeValue * Tuning.pokerStakeShare, Tuning.pokerWinSeconds * rewardIncome)
        return Self.wholeCoins(perMultiple * Double(multiple) * miniGameMultiplier)
    }

    /// The smallest bet in `token` that earns the full coin bonus.
    public func pokerBetForFullBonus(_ token: TokenID) -> Int {
        let needed = Tuning.pokerWinSeconds * rewardIncome / Tuning.pokerStakeShare / token.price
        return max(1, Int(min(needed.rounded(.up), 1e9))) // Fits a 32-bit Int on Apple Watch.
    }

    /// Takes the bet and deals five cards. Fails if a hand is already dealt or the player can't
    /// cover the bet.
    @discardableResult
    public mutating func dealPoker<R: RandomNumberGenerator>(_ token: TokenID, bet: Int, using rng: inout R) -> PokerRound? {
        guard pokerRound == nil, bet > 0, tokenCount(token) >= bet else { return nil }
        tokens[token] = tokenCount(token) - bet
        let dealt = VideoPoker.deal(using: &rng)
        let round = PokerRound(token: token, bet: bet, cards: dealt.cards, drawPile: dealt.drawPile)
        pokerRound = round
        stats.pokerHands += 1
        stats.pokerWagered += Double(bet) * token.price
        return round
    }

    /// Replaces every card not in `held` (positions 0 to 4) and pays the hand: the bet times the pay
    /// table in tokens, plus a coin bonus for two pair or better.
    @discardableResult
    public mutating func drawPoker(holding held: Set<Int>) -> PokerResult? {
        guard let round = pokerRound else { return nil }
        pokerRound = nil
        let cards = VideoPoker.draw(round.cards, holding: held, from: round.drawPile)
        let hand = VideoPoker.evaluate(cards)
        let won = Int(min(Double(round.bet) * Double(hand.payout), Double(Int32.max)))
        giveTokens(round.token, amount: won)
        let bonus = pokerBonus(bet: round.bet, token: round.token, hand: hand)
        credit(bonus, source: .games)
        if won > 0 { stats.pokerWins += 1 }
        stats.pokerBestHand = max(stats.pokerBestHand, hand.rawValue)
        if hand == .royalFlush { stats.pokerRoyals += 1 }
        stats.pokerPaidOut += Double(won) * round.token.price
        stats.pokerBiggestWin = max(stats.pokerBiggestWin, Double(won - round.bet) * round.token.price + bonus)
        recordChallenge(.videoPoker, value: hand >= .twoPair ? 1 : 0, scored: hand >= .twoPair)
        return PokerResult(token: round.token, bet: round.bet, cards: cards, hand: hand, tokensWon: won, bonus: bonus)
    }

    /// Finishes a hand the app closed in the middle of, holding what the suggested strategy holds.
    @discardableResult
    public mutating func finishPokerRound() -> PokerResult? {
        guard let round = pokerRound else { return nil }
        return drawPoker(holding: VideoPoker.suggestedHolds(round.cards))
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
        case .tetris: finishTetris(score: run.score, lines: run.detail, rewardPoints: run.extra)
        case .snake: finishSnake(score: run.score, length: run.detail)
        case .brickBreaker: finishBrickBreaker(score: run.score, bricks: run.detail, level: run.extra)
        case .bubbleBlaster: finishBubbleBlaster(score: run.score, popped: run.detail, bestShot: run.extra)
        case .merge2048: finishMerge2048(score: run.score, bestTile: run.detail)
        case .pumpDump: finishPumpDump(score: run.score, coinsHit: run.detail, bestCombo: run.extra)
        case .tokenSwap: finishTokenSwap(score: run.score, tokens: run.detail, bestChain: run.extra)
        case .blackjack, .slots, .moon, .videoPoker: ArcadePayout(coins: 0, isNewBest: false)
        }
        unfinishedRun = nil
        return (run, payout)
    }

    /// Coins an arcade game pays for `score` points, before any bonus.
    public func arcadeReward(_ game: MiniGame, score: Int, multiplier: Double = 1) -> Double {
        guard score > 0 else { return 0 }
        return Self.wholeCoins(Double(score) * game.secondsPerPoint * miniGameMultiplier * multiplier * rewardIncome)
    }

    /// Tetris pays on `rewardPoints`, the score without its level multiplier (see `TetrisGame`).
    @discardableResult
    public mutating func finishTetris(score: Int, lines: Int, rewardPoints: Int) -> ArcadePayout {
        let isNewBest = score > stats.tetrisBestScore
        stats.tetrisGames += 1
        stats.tetrisLines += max(0, lines)
        stats.tetrisBestScore = max(stats.tetrisBestScore, score)
        return payArcade(.tetris, score: score, paidPoints: rewardPoints, isNewBest: isNewBest, challengeValue: score)
    }

    /// `length` is how long the snake grew.
    @discardableResult
    public mutating func finishSnake(score: Int, length: Int) -> ArcadePayout {
        let isNewBest = score > stats.snakeBestScore
        let eaten = max(0, score) / SnakeGame.pointsPerCoin
        stats.snakeGames += 1
        stats.snakeBestScore = max(stats.snakeBestScore, score)
        stats.snakeCoinsEaten += eaten
        stats.snakeLongest = max(stats.snakeLongest, length)
        return payArcade(.snake, score: score, isNewBest: isNewBest, challengeValue: eaten)
    }

    /// `level` is the level the game reached.
    @discardableResult
    public mutating func finishBrickBreaker(score: Int, bricks: Int, level: Int) -> ArcadePayout {
        let isNewBest = score > stats.brickBreakerBestScore
        stats.brickBreakerGames += 1
        stats.brickBreakerBestScore = max(stats.brickBreakerBestScore, score)
        stats.bricksBroken += max(0, bricks)
        stats.brickBreakerBestLevel = max(stats.brickBreakerBestLevel, level)
        return payArcade(.brickBreaker, score: score, isNewBest: isNewBest, challengeValue: bricks)
    }

    /// `bestShot` is the most bubbles one shot cleared.
    @discardableResult
    public mutating func finishBubbleBlaster(score: Int, popped: Int, bestShot: Int) -> ArcadePayout {
        let isNewBest = score > stats.bubbleBestScore
        stats.bubbleGames += 1
        stats.bubbleBestScore = max(stats.bubbleBestScore, score)
        stats.bubblesPopped += max(0, popped)
        stats.bubbleBestShot = max(stats.bubbleBestShot, bestShot)
        return payArcade(.bubbleBlaster, score: score, isNewBest: isNewBest, challengeValue: popped)
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
        let bonus = bestTile >= Merge2048Game.winningValue ? merge2048TileBonus : 0
        credit(bonus, source: .games)
        return payArcade(.merge2048, score: score, isNewBest: isNewBest, challengeValue: bestTile, tileBonus: bonus)
    }

    /// The bonus for making a 2048 tile: `Tuning.merge2048WinSeconds` of income.
    public var merge2048TileBonus: Double {
        Self.wholeCoins(Tuning.merge2048WinSeconds * rewardIncome * miniGameMultiplier)
    }

    /// What ending a 2048 game now would pay, without paying it.
    public func merge2048Reward(score: Int, bestTile: Int) -> Double {
        let isNewBest = score > stats.merge2048BestScore
        let points = arcadeReward(.merge2048, score: score, multiplier: isNewBest ? 1 + Tuning.newBestBonus : 1)
        return points + (bestTile >= Merge2048Game.winningValue ? merge2048TileBonus : 0)
    }

    @discardableResult
    public mutating func finishPumpDump(score: Int, coinsHit: Int, bestCombo: Int, scamsHit: Int = 0) -> ArcadePayout {
        let isNewBest = score > stats.pumpDumpBestScore
        stats.pumpDumpGames += 1
        stats.pumpDumpBestScore = max(stats.pumpDumpBestScore, score)
        stats.pumpDumpCoinsHit += max(0, coinsHit)
        stats.pumpDumpScamsHit += max(0, scamsHit)
        stats.pumpDumpBestCombo = max(stats.pumpDumpBestCombo, bestCombo)
        return payArcade(.pumpDump, score: score, isNewBest: isNewBest, challengeValue: score)
    }

    /// `tokens` is how many tokens were matched; `bestChain` the most waves one swap set off.
    @discardableResult
    public mutating func finishTokenSwap(score: Int, tokens: Int, bestChain: Int, blasts: Int = 0) -> ArcadePayout {
        let isNewBest = score > stats.tokenSwapBestScore
        stats.tokenSwapGames += 1
        stats.tokenSwapBestScore = max(stats.tokenSwapBestScore, score)
        stats.tokenSwapTokens += max(0, tokens)
        stats.tokenSwapBestChain = max(stats.tokenSwapBestChain, bestChain)
        stats.tokenSwapBlasts += max(0, blasts)
        return payArcade(.tokenSwap, score: score, isNewBest: isNewBest, challengeValue: score)
    }

    /// Pays a finished game for `paidPoints` (its score, unless the game says otherwise): a new best
    /// score earns `Tuning.newBestBonus` more. `challengeValue` is what the game counts for its daily
    /// challenge (a score, coins eaten, a tile).
    private mutating func payArcade(_ game: MiniGame, score: Int, paidPoints: Int? = nil, isNewBest: Bool,
                                    challengeValue: Int, tileBonus: Double = 0) -> ArcadePayout {
        unfinishedRun = nil // A finished game is never paid again from the hold.
        let reward = arcadeReward(game, score: paidPoints ?? score, multiplier: isNewBest ? 1 + Tuning.newBestBonus : 1)
        credit(reward, source: .games)
        let challenge = recordChallenge(game, value: challengeValue, scored: score > 0)
        return ArcadePayout(coins: reward + tileBonus, isNewBest: isNewBest, tileBonus: tileBonus, challenge: challenge)
    }
}

/// What a finished arcade game paid.
public struct ArcadePayout: Equatable, Sendable {
    /// Coins for the score, including any new-best and 2048 bonus (not the daily challenge).
    public let coins: Double
    /// The score beat the previous best, so the reward includes the new-best bonus.
    public let isNewBest: Bool
    /// Coins included for making a 2048 tile.
    public internal(set) var tileBonus: Double = 0
    /// This game completed the daily challenge, which paid this.
    public internal(set) var challenge: ChallengeReward?
}
