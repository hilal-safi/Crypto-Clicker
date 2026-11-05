import SwiftUI
import CryptoClickerKit

// Playing the mini-games: the casino's bets and payouts, each arcade game's finish, and the
// run held while a game is in the background.
extension GameStore {
    // MARK: Mini-games

    /// Stakes tokens on the current Blackjack round. Saved at once, so a hand cut short by the
    /// app closing is refunded on the next launch.
    @discardableResult
    func placeBet(_ token: TokenID, amount: Int) -> Bool {
        let placed = perform { game, _ in game.placeBlackjackBet(token, amount: amount) }
        if placed { save() }
        return placed
    }

    @discardableResult
    func settleBlackjack(_ results: [BlackjackResult], token: TokenID, rules: BlackjackRules) -> Double {
        let bonus = perform { game, _ in game.settleBlackjack(results, token: token, rules: rules) }
        save()
        return bonus
    }

    /// Spins Crypto Slots: the bet, the spin and the payout happen in one saved step.
    @discardableResult
    func spinSlots(_ token: TokenID, bet: Int) -> SlotsSpin? {
        let spin = perform { game, _ in
            var rng = SystemRandomNumberGenerator()
            return game.spinSlots(token, bet: bet, using: &rng)
        }
        if spin != nil { save() }
        return spin
    }

    /// Launches a To the Moon flight: the bet is taken and the flight saved at once, so a flight
    /// cut short by the app closing is refunded on the next launch.
    @discardableResult
    func launchMoon(_ token: TokenID, bet: Int, autoCashOut: Double?) -> Bool {
        let launched = perform { game, _ in
            var rng = SystemRandomNumberGenerator()
            return game.launchMoon(token, bet: bet, autoCashOut: autoCashOut, using: &rng)
        }
        if launched { save() }
        return launched
    }

    /// Returns the bet of a flight left without its screen (it can't be watched, so it can't be won).
    func refundMoonRound() {
        guard game.moonRound != nil else { return }
        perform { game, _ in game.refundMoonRound() }
        save()
    }

    /// Ends the flight `seconds` after launch: a cash-out, or a crash.
    @discardableResult
    func settleMoon(after seconds: TimeInterval) -> MoonResult? {
        let result = perform { game, _ in game.settleMoon(after: seconds) }
        if result != nil { save() }
        return result
    }

    /// Deals a Video Poker hand: the bet is taken and the hand saved at once, so a hand cut short
    /// by the app closing is played out (with the suggested holds) on the next launch.
    @discardableResult
    func dealPoker(_ token: TokenID, bet: Int) -> PokerRound? {
        let round = perform { game, _ in
            var rng = SystemRandomNumberGenerator()
            return game.dealPoker(token, bet: bet, using: &rng)
        }
        if round != nil { save() }
        return round
    }

    /// Replaces the cards not held and pays the hand.
    @discardableResult
    func drawPoker(holding held: Set<Int>) -> PokerResult? {
        let result = perform { game, _ in game.drawPoker(holding: held) }
        if result != nil { save() }
        return result
    }

    @discardableResult
    func finishTokenSwap(score: Int, tokens: Int, bestChain: Int, blasts: Int) -> ArcadePayout {
        let payout = perform { game, _ in
            game.finishTokenSwap(score: score, tokens: tokens, bestChain: bestChain, blasts: blasts)
        }
        save()
        return payout
    }

    /// Records a finished Token Swap level; stars earned for the first time pay.
    @discardableResult
    func finishTokenSwapLevel(_ level: TokenSwapLevel, game result: TokenSwapGame) -> TokenSwapLevelPayout {
        let payout = perform { game, _ in
            game.finishTokenSwapLevel(level, won: result.phase == .won, score: result.score, tokens: result.tokensCleared,
                                      bestChain: result.bestChain, specials: result.specialsSetOff)
        }
        save()
        return payout
    }

    /// Records a finished random level; every point pays, and a win more.
    @discardableResult
    func finishTokenSwapRandom(_ level: TokenSwapLevel, game result: TokenSwapGame) -> Double {
        let coins = perform { game, _ in
            game.finishTokenSwapRandom(level, won: result.phase == .won, score: result.score, tokens: result.tokensCleared,
                                       bestChain: result.bestChain, specials: result.specialsSetOff)
        }
        save()
        return coins
    }

    /// Records a finished daily puzzle; the first win of the day pays.
    @discardableResult
    func finishTokenSwapDaily(day: String, game result: TokenSwapGame) -> Double {
        let coins = perform { game, _ in
            game.finishTokenSwapDaily(day: day, won: result.phase == .won, tokens: result.tokensCleared,
                                      bestChain: result.bestChain, specials: result.specialsSetOff)
        }
        save()
        return coins
    }

    @discardableResult
    func finishTetris(score: Int, lines: Int, rewardPoints: Int, level: Int, bestCombo: Int, tetrises: Int,
                      sprintTime: TimeInterval?) -> ArcadePayout {
        let payout = perform { game, _ in
            game.finishTetris(score: score, lines: lines, rewardPoints: rewardPoints, level: level, bestCombo: bestCombo,
                              tetrises: tetrises, sprintTime: sprintTime)
        }
        save()
        return payout
    }

    @discardableResult
    func finishSnake(score: Int, length: Int, coins: Int, time: TimeInterval, powerUps: Int, mode: SnakeGame.Mode) -> ArcadePayout {
        let payout = perform { game, _ in
            game.finishSnake(score: score, length: length, coins: coins, time: time, powerUps: powerUps, mode: mode)
        }
        save()
        return payout
    }

    @discardableResult
    func finishInvaders(score: Int, destroyed: Int, wave: Int, whales: Int, bosses: Int, powerUps: Int, bestStreak: Int,
                        volleys: Int, volleysHit: Int) -> ArcadePayout {
        let payout = perform { game, _ in
            game.finishInvaders(score: score, destroyed: destroyed, wave: wave, whales: whales, bosses: bosses,
                                powerUps: powerUps, bestStreak: bestStreak, volleys: volleys, volleysHit: volleysHit)
        }
        save()
        return payout
    }

    func finishBrickBreaker(score: Int, bricks: Int, level: Int, bosses: Int, powerUps: Int, bestStreak: Int) -> ArcadePayout {
        let payout = perform { game, _ in
            game.finishBrickBreaker(score: score, bricks: bricks, level: level, bosses: bosses, powerUps: powerUps,
                                    bestStreak: bestStreak)
        }
        save()
        return payout
    }

    @discardableResult
    func finishBubbleBlaster(score: Int, popped: Int, bestShot: Int, wave: Int, bestStreak: Int, bonuses: Int,
                             mode: BubbleShooterGame.Mode) -> ArcadePayout {
        let payout = perform { game, _ in
            game.finishBubbleBlaster(score: score, popped: popped, bestShot: bestShot, wave: wave, bestStreak: bestStreak,
                                     bonuses: bonuses, mode: mode)
        }
        save()
        return payout
    }

    @discardableResult
    func finishPumpDump(score: Int, coinsHit: Int, bestCombo: Int, scamsHit: Int, rounds: Int,
                        board: PumpDumpGame.Board) -> ArcadePayout {
        let payout = perform { game, _ in
            game.finishPumpDump(score: score, coinsHit: coinsHit, bestCombo: bestCombo, scamsHit: scamsHit, rounds: rounds,
                                board: board)
        }
        save()
        return payout
    }

    @discardableResult
    func finishMerge2048(score: Int, bestTile: Int) -> ArcadePayout {
        let payout = perform { game, _ in game.finishMerge2048(score: score, bestTile: bestTile) }
        save()
        return payout
    }

    @discardableResult
    func finishMerge2048Daily(day: String, score: Int, bestTile: Int) -> Merge2048DailyPayout {
        let payout = perform { game, _ in game.finishMerge2048Daily(day: day, score: score, bestTile: bestTile) }
        save()
        return payout
    }

    /// Saves an arcade game in progress as the app goes to the background, so its points are
    /// paid on the next launch if iOS closes the app.
    func holdArcadeRun(_ run: ArcadeRun) {
        perform { game, _ in game.holdArcadeRun(run) }
        save()
    }

    /// The player is back in the held game.
    func releaseArcadeRun() {
        guard game.unfinishedRun != nil else { return }
        perform { game, _ in game.releaseArcadeRun() }
    }
}
