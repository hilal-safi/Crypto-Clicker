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
    /// `Tuning.blackjackWinSeconds` of income, times mini-game upgrades. Naturals pay 1.5x, and the
    /// tough table pays `Tuning.blackjackToughTableBonus` more.
    public func blackjackBonus(bet: Int, token: TokenID, isNatural: Bool = false,
                               rules: BlackjackRules = .standsOnSoft17) -> Double {
        let stakeValue = Double(max(0, bet)) * token.price
        let bonus = min(stakeValue * Tuning.blackjackStakeShare, Tuning.blackjackWinSeconds * rewardIncome)
        let table = rules == .hitsSoft17 ? Tuning.blackjackToughTableBonus : 1
        return Self.wholeCoins(bonus * miniGameMultiplier * table * (isNatural ? Tuning.blackjackNaturalBonus : 1))
    }

    /// The smallest bet in `token` that earns the full coin bonus.
    public func blackjackBetForFullBonus(_ token: TokenID) -> Int {
        let needed = Tuning.blackjackWinSeconds * rewardIncome / Tuning.blackjackStakeShare / token.price
        return max(1, Int(min(needed.rounded(.up), 1e9))) // Fits a 32-bit Int on Apple Watch.
    }

    /// Pays a finished round: winnings back to the wallet, statistics, and a coin bonus per won hand.
    /// Pays only while a stake is open, so a round can never be paid twice.
    @discardableResult
    public mutating func settleBlackjack(_ results: [BlackjackResult], token: TokenID,
                                         rules: BlackjackRules = .standsOnSoft17) -> Double {
        guard blackjackStake != nil else { return 0 }
        blackjackStake = nil
        giveTokens(token, amount: results.reduce(0) { $0.addingCount($1.payout) })
        stats.blackjackHands += 1
        var bonus = 0.0
        var wins = 0
        var naturals = 0
        for result in results {
            switch result.outcome {
            case .blackjack:
                wins += 1
                naturals += 1
                stats.blackjackNaturals += 1
                bonus += blackjackBonus(bet: result.bet, token: token, isNatural: true, rules: rules)
            case .win:
                wins += 1
                bonus += blackjackBonus(bet: result.bet, token: token, rules: rules)
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
        // The natural challenge counts naturals; the usual one counts hands won.
        let counted = daily.challenge?.kind == .blackjackNatural ? naturals : wins
        recordChallenge(.blackjack, value: counted, scored: wins > 0)
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

    /// The coin prize for every `SlotMachine.bitcoinsPerPrize` Bitcoins collected.
    public var slotsCollectionPrize: Double {
        Self.wholeCoins(Tuning.slotsCollectionSeconds * rewardIncome * miniGameMultiplier)
    }

    /// Bitcoins collected toward the next prize.
    public var slotsBitcoinsTowardPrize: Int { stats.slotsBitcoins % SlotMachine.bitcoinsPerPrize }

    /// Takes the bet, spins and pays in one step, so closing the app mid-spin can't lose a bet.
    /// While free spins are waiting, the spin is one of them instead: at the bet and token that won
    /// them, taking nothing. Returns `nil` (and changes nothing) if the player can't cover the bet.
    @discardableResult
    public mutating func spinSlots<R: RandomNumberGenerator>(_ token: TokenID, bet: Int, using rng: inout R) -> SlotsSpin? {
        let free = slotsFreeSpins
        let token = free?.token ?? token
        let bet = free?.bet ?? bet
        guard bet > 0, free != nil || tokenCount(token) >= bet else { return nil }
        let stops = SlotMachine.spin(using: &rng)
        let line = SlotMachine.line(stops: stops)
        let multiple = SlotMachine.payout(for: line)
        let paid = SlotMachine.tokensPaid(bet: bet, multiple: multiple)
        if free == nil { tokens[token] = tokenCount(token) - bet }
        giveTokens(token, amount: paid)
        let bonus = slotsBonus(bet: bet, token: token, multiple: multiple)
        credit(bonus, source: .games)

        // Free spins: this one is used up, and a trio wins more.
        var freeLeft = max(0, (free?.left ?? 0) - 1)
        let won = SlotMachine.triggersFreeSpins(line) ? SlotMachine.freeSpinsAwarded : 0
        if won > 0 { stats.slotsFreeSpinRounds += 1 }
        freeLeft += won
        slotsFreeSpins = freeLeft > 0 ? SlotsFreeSpins(token: token, bet: bet, left: freeLeft) : nil

        // The Bitcoin collection pays a prize every `bitcoinsPerPrize`.
        let bitcoins = line.filter { $0 == .bitcoin }.count
        let before = stats.slotsBitcoins
        stats.slotsBitcoins = stats.slotsBitcoins.addingCount(bitcoins)
        let prizes = stats.slotsBitcoins / SlotMachine.bitcoinsPerPrize - before / SlotMachine.bitcoinsPerPrize
        let prize = Double(max(0, prizes)) * slotsCollectionPrize
        credit(prize, source: .games)

        stats.slotsSpins += 1
        if free != nil {
            stats.slotsFreeSpinsPlayed += 1
        } else {
            stats.slotsWagered += Double(bet) * token.price
        }
        stats.slotsPaidOut += Double(paid) * token.price
        stats.slotsBestMultiple = max(stats.slotsBestMultiple, multiple)
        if multiple >= 2 { stats.slotsWins += 1 }
        if multiple == SlotMachine.jackpot { stats.slotsJackpots += 1 }
        let net = Double(paid - (free == nil ? bet : 0)) * token.price + bonus
        stats.slotsBiggestWin = max(stats.slotsBiggestWin, net)
        recordChallenge(.slots, value: multiple >= 2 ? 1 : 0, scored: multiple >= 2)
        var spin = SlotsSpin(stops: stops, token: token, bet: bet, multiple: multiple, bonus: bonus)
        spin.isFree = free != nil
        spin.freeSpinsWon = won
        spin.freeSpinsLeft = freeLeft
        spin.bitcoins = bitcoins
        spin.collectionPrize = prize
        return spin
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
        moonRound?.state(after: seconds)
    }

    /// Ends the flight `seconds` after launch. While it is still flying, that's a cash-out at the
    /// current multiplier; after the automatic cash-out it pays that; after a crash the bet is lost.
    /// A cash-out pays the bet times the multiplier in whole tokens, plus a coin bonus.
    @discardableResult
    public mutating func settleMoon(after seconds: TimeInterval) -> MoonResult? {
        guard let round = moonRound else { return nil }
        moonRound = nil // Taken first: the flight can only be paid once.
        var result = round.outcome(after: seconds)
        guard let multiplier = result.cashedOutAt else {
            recordChallenge(.moon, value: 0, scored: false)
            return result
        }
        let won = result.tokensWon
        giveTokens(round.token, amount: won)
        let bonus = moonBonus(bet: round.bet, token: round.token, multiplier: multiplier)
        credit(bonus, source: .games)
        stats.moonCashOuts += 1
        stats.moonBestMultiplier = max(stats.moonBestMultiplier, multiplier)
        stats.moonPaidOut += Double(won) * round.token.price
        stats.moonBiggestWin = max(stats.moonBiggestWin, Double(won - round.bet) * round.token.price + bonus)
        recordChallenge(.moon, value: multiplier >= 2 ? 1 : 0, scored: true)
        result.bonus = bonus
        return result
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
        pokerRound = nil // Taken first: the hand can only be paid once.
        var result = round.outcome(holding: held)
        let hand = result.hand
        let won = result.tokensWon
        giveTokens(round.token, amount: won)
        let bonus = pokerBonus(bet: round.bet, token: round.token, hand: hand)
        credit(bonus, source: .games)
        result.bonus = bonus
        if won > 0 { stats.pokerWins += 1 }
        stats.pokerBestHand = max(stats.pokerBestHand, hand.rawValue)
        if hand == .royalFlush { stats.pokerRoyals += 1 }
        stats.pokerPaidOut += Double(won) * round.token.price
        stats.pokerBiggestWin = max(stats.pokerBiggestWin, Double(won - round.bet) * round.token.price + bonus)
        recordChallenge(.videoPoker, value: hand >= .twoPair ? 1 : 0, scored: hand >= .twoPair)
        return result
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
        case .snake: finishSnake(score: run.score, length: run.detail,
                                 mode: run.stage == ArcadeRun.coinRushStage ? .coinRush : .classic)
        case .brickBreaker: finishBrickBreaker(score: run.score, bricks: run.detail, level: run.extra)
        case .bubbleBlaster: finishBubbleBlaster(score: run.score, popped: run.detail, bestShot: run.extra, wave: run.stage)
        case .merge2048:
            run.stage == ArcadeRun.dailyStage
                ? finishMerge2048Daily(day: nil, score: run.score, bestTile: run.detail).payout
                : finishMerge2048(score: run.score, bestTile: run.detail)
        case .pumpDump: finishPumpDump(score: run.score, coinsHit: run.detail, bestCombo: run.extra, rounds: max(1, run.stage))
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
    /// A finished Sprint passes its time: Sprints keep their own record (the fastest), so the
    /// new-best bonus goes to a faster Sprint rather than a higher score.
    @discardableResult
    public mutating func finishTetris(score: Int, lines: Int, rewardPoints: Int, level: Int = 1, bestCombo: Int = 0,
                                      tetrises: Int = 0, sprintTime: TimeInterval? = nil) -> ArcadePayout {
        stats.tetrisGames += 1
        stats.tetrisLines = stats.tetrisLines.addingCount(lines)
        stats.tetrisBestLevel = max(stats.tetrisBestLevel, level)
        stats.tetrisBestCombo = max(stats.tetrisBestCombo, bestCombo)
        stats.tetrisTetrises = stats.tetrisTetrises.addingCount(tetrises)
        let isNewBest: Bool
        if let sprintTime, sprintTime.isFinite, sprintTime > 0 {
            isNewBest = stats.tetrisBestSprint == 0 || sprintTime < stats.tetrisBestSprint
            stats.tetrisSprints += 1
            stats.tetrisBestSprint = isNewBest ? sprintTime : stats.tetrisBestSprint
        } else {
            isNewBest = score > stats.tetrisBestScore
            stats.tetrisBestScore = max(stats.tetrisBestScore, score)
        }
        return payArcade(.tetris, score: score, paidPoints: rewardPoints, isNewBest: isNewBest, challengeValue: score)
    }

    /// `length` is how long the snake grew; `coins` how many it ate (by default the score's worth at
    /// 10 points a coin). Coin Rush keeps its own best score, so the new-best bonus compares like
    /// with like.
    @discardableResult
    public mutating func finishSnake(score: Int, length: Int, coins: Int? = nil, time: TimeInterval = 0, powerUps: Int = 0,
                                     mode: SnakeGame.Mode = .classic) -> ArcadePayout {
        let eaten = max(0, coins ?? max(0, score) / SnakeGame.pointsPerCoin)
        let isNewBest: Bool
        if mode == .coinRush {
            isNewBest = score > stats.snakeRushBestScore
            stats.snakeRushBestScore = max(stats.snakeRushBestScore, score)
            stats.snakeRushes += 1
        } else {
            isNewBest = score > stats.snakeBestScore
            stats.snakeBestScore = max(stats.snakeBestScore, score)
        }
        stats.snakeGames += 1
        stats.snakeCoinsEaten = stats.snakeCoinsEaten.addingCount(eaten)
        stats.snakeLongest = max(stats.snakeLongest, length)
        stats.snakeBestCoins = max(stats.snakeBestCoins, eaten)
        if time.isFinite { stats.snakeLongestTime = max(stats.snakeLongestTime, time) }
        stats.snakePowerUps = stats.snakePowerUps.addingCount(powerUps)
        let paid = mode == .coinRush ? Int((Double(max(0, score)) * Tuning.snakeCoinRushPay).rounded()) : score
        return payArcade(.snake, score: score, paidPoints: paid, isNewBest: isNewBest, challengeValue: eaten)
    }

    /// `level` is the level the game reached (so `level - 1` were cleared).
    @discardableResult
    public mutating func finishBrickBreaker(score: Int, bricks: Int, level: Int, bosses: Int = 0, powerUps: Int = 0,
                                            bestStreak: Int = 0) -> ArcadePayout {
        let isNewBest = score > stats.brickBreakerBestScore
        stats.brickBreakerGames += 1
        stats.brickBreakerBestScore = max(stats.brickBreakerBestScore, score)
        stats.bricksBroken = stats.bricksBroken.addingCount(bricks)
        stats.brickBreakerBestLevel = max(stats.brickBreakerBestLevel, level)
        stats.brickBreakerLevelsCleared = stats.brickBreakerLevelsCleared.addingCount(level - 1)
        stats.brickBreakerBosses = stats.brickBreakerBosses.addingCount(bosses)
        stats.brickBreakerPowerUps = stats.brickBreakerPowerUps.addingCount(powerUps)
        stats.brickBreakerBestStreak = max(stats.brickBreakerBestStreak, bestStreak)
        return payArcade(.brickBreaker, score: score, isNewBest: isNewBest, challengeValue: bricks)
    }

    /// `bestShot` is the most bubbles one shot cleared, `wave` the wave the game reached, `bestStreak`
    /// the most popping shots in a row and `bonuses` the gold bonus bubbles cleared.
    @discardableResult
    public mutating func finishBubbleBlaster(score: Int, popped: Int, bestShot: Int, wave: Int = 0, bestStreak: Int = 0,
                                             bonuses: Int = 0) -> ArcadePayout {
        let isNewBest = score > stats.bubbleBestScore
        stats.bubbleGames += 1
        stats.bubbleBestScore = max(stats.bubbleBestScore, score)
        stats.bubblesPopped = stats.bubblesPopped.addingCount(popped)
        stats.bubbleBestShot = max(stats.bubbleBestShot, bestShot)
        stats.bubbleBestWave = max(stats.bubbleBestWave, wave)
        stats.bubbleBestStreak = max(stats.bubbleBestStreak, bestStreak)
        stats.bubbleBonuses = stats.bubbleBonuses.addingCount(bonuses)
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
        stats.merge2048Points = stats.merge2048Points.addingCount(score)
        stats.merge2048Goals = stats.merge2048Goals.addingCount(Merge2048Game.goalsReached(bestTile: bestTile))
        let bonus = bestTile >= Merge2048Game.winningValue ? merge2048TileBonus : 0
        credit(bonus, source: .games)
        return payArcade(.merge2048, score: score, isNewBest: isNewBest, challengeValue: bestTile, tileBonus: bonus)
    }

    /// Records a finished daily 2048 puzzle and pays it: its points (it doesn't count toward the
    /// Classic best score, so there's no new-best bonus), plus `merge2048DailyStarReward` for each
    /// star earned for the first time that day, so replaying the puzzle can't pay a star twice.
    /// A puzzle the app closed in the middle of comes back without its day, and pays its points only.
    @discardableResult
    public mutating func finishMerge2048Daily(day: String?, score: Int, bestTile: Int) -> Merge2048DailyPayout {
        stats.merge2048Games += 1
        stats.merge2048BestTile = max(stats.merge2048BestTile, bestTile)
        stats.merge2048Points = stats.merge2048Points.addingCount(score)
        stats.merge2048Goals = stats.merge2048Goals.addingCount(Merge2048Game.goalsReached(bestTile: bestTile))
        let stars = Merge2048Game.dailyStars(score: score)
        let newStars = day.map { merge2048Daily.record(day: $0, score: score, stars: stars) } ?? 0
        let starCoins = Double(newStars) * merge2048DailyStarReward
        credit(starCoins, source: .games)
        let paid = payArcade(.merge2048, score: score, isNewBest: false, challengeValue: bestTile)
        let payout = ArcadePayout(coins: paid.coins + starCoins, isNewBest: false, challenge: paid.challenge)
        return Merge2048DailyPayout(stars: stars, newStars: newStars, starCoins: starCoins, payout: payout)
    }

    /// One daily 2048 star: `Tuning.merge2048DailyStarSeconds` of income.
    public var merge2048DailyStarReward: Double {
        Self.wholeCoins(Tuning.merge2048DailyStarSeconds * rewardIncome * miniGameMultiplier)
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

    /// `rounds` is the round the run reached.
    @discardableResult
    public mutating func finishPumpDump(score: Int, coinsHit: Int, bestCombo: Int, scamsHit: Int = 0, rounds: Int = 1) -> ArcadePayout {
        let isNewBest = score > stats.pumpDumpBestScore
        stats.pumpDumpGames += 1
        stats.pumpDumpBestScore = max(stats.pumpDumpBestScore, score)
        stats.pumpDumpCoinsHit = stats.pumpDumpCoinsHit.addingCount(coinsHit)
        stats.pumpDumpScamsHit = stats.pumpDumpScamsHit.addingCount(scamsHit)
        stats.pumpDumpBestCombo = max(stats.pumpDumpBestCombo, bestCombo)
        stats.pumpDumpBestRound = max(stats.pumpDumpBestRound, rounds)
        // The run ended in the round it reached, so the ones before it were cleared.
        stats.pumpDumpRoundsCleared = stats.pumpDumpRoundsCleared.addingCount(rounds - 1)
        return payArcade(.pumpDump, score: score, isNewBest: isNewBest, challengeValue: score)
    }

    /// `tokens` is how many tokens were matched; `bestChain` the most waves one swap set off.
    @discardableResult
    public mutating func finishTokenSwap(score: Int, tokens: Int, bestChain: Int, blasts: Int = 0) -> ArcadePayout {
        let isNewBest = score > stats.tokenSwapBestScore
        stats.tokenSwapGames += 1
        stats.tokenSwapBestScore = max(stats.tokenSwapBestScore, score)
        stats.tokenSwapTokens = stats.tokenSwapTokens.addingCount(tokens)
        stats.tokenSwapBestChain = max(stats.tokenSwapBestChain, bestChain)
        stats.tokenSwapBlasts = stats.tokenSwapBlasts.addingCount(blasts)
        return payArcade(.tokenSwap, score: score, isNewBest: isNewBest, challengeValue: score)
    }

    // MARK: Token Swap levels

    /// Coins a level's star pays the first time it's earned (`star` is 1, 2 or 3).
    public func tokenSwapStarReward(_ level: TokenSwapLevel, star: Int) -> Double {
        guard Tuning.tokenSwapStarSeconds.indices.contains(star - 1) else { return 0 }
        return Self.wholeCoins(Tuning.tokenSwapStarSeconds[star - 1] * level.difficulty.rewardMultiplier
                               * rewardIncome * miniGameMultiplier)
    }

    /// Coins winning today's puzzle pays (once a day).
    public var tokenSwapDailyReward: Double {
        Self.wholeCoins(Tuning.tokenSwapDailySeconds * rewardIncome * miniGameMultiplier)
    }

    /// Records a finished level: the best stars and score, and the tokens and specials toward the
    /// statistics. Each star pays once, the first time it's earned, so replaying a level can't
    /// pay twice. A loss pays nothing.
    @discardableResult
    public mutating func finishTokenSwapLevel(_ level: TokenSwapLevel, won: Bool, score: Int, tokens: Int,
                                              bestChain: Int, specials: Int) -> TokenSwapLevelPayout {
        let before = tokenSwap.stars(for: level.id)
        let wasBest = tokenSwap.bestScore(for: level.id)
        let stars = level.stars(won: won, score: score)
        recordTokenSwapPlay(tokens: tokens, bestChain: bestChain, specials: specials)
        stats.tokenSwapLevelsPlayed += 1
        guard won else { return TokenSwapLevelPayout(stars: 0, newStars: 0, coins: 0, isNewBest: false) }
        stats.tokenSwapLevelWins = stats.tokenSwapLevelWins.addingCount(1)
        tokenSwap.record(level: level.id, stars: stars, score: score)
        var coins = 0.0
        if stars > before {
            for star in (before + 1)...stars { coins += tokenSwapStarReward(level, star: star) }
        }
        credit(coins, source: .games)
        return TokenSwapLevelPayout(stars: stars, newStars: max(0, stars - before), coins: coins,
                                    isNewBest: wasBest > 0 && score > wasBest)
    }

    /// Records a finished daily puzzle; a win pays `tokenSwapDailyReward` the first time that day.
    @discardableResult
    public mutating func finishTokenSwapDaily(day: String, won: Bool, tokens: Int, bestChain: Int, specials: Int) -> Double {
        recordTokenSwapPlay(tokens: tokens, bestChain: bestChain, specials: specials)
        // The daily puzzle counts as a level played (and won).
        stats.tokenSwapLevelsPlayed = stats.tokenSwapLevelsPlayed.addingCount(1)
        if won { stats.tokenSwapLevelWins = stats.tokenSwapLevelWins.addingCount(1) }
        guard won, !tokenSwap.hasWonDaily(day: day) else { return 0 }
        tokenSwap.dailyWonDay = day
        tokenSwap.dailyWins += 1
        let coins = tokenSwapDailyReward
        credit(coins, source: .games)
        return coins
    }

    private mutating func recordTokenSwapPlay(tokens: Int, bestChain: Int, specials: Int) {
        stats.tokenSwapTokens = stats.tokenSwapTokens.addingCount(tokens)
        stats.tokenSwapBestChain = max(stats.tokenSwapBestChain, bestChain)
        stats.tokenSwapBlasts = stats.tokenSwapBlasts.addingCount(specials)
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

/// What a finished Token Swap level earned.
public struct TokenSwapLevelPayout: Equatable, Sendable {
    /// Stars this game earned (0 for a loss).
    public let stars: Int
    /// Stars earned for the first time, which paid.
    public let newStars: Int
    public let coins: Double
    /// Beat the level's best score.
    public let isNewBest: Bool
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
