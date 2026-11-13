import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Best purchase")
struct SuggestionTests {
    @Test func theQuickestPaybackWins() throws {
        let game = GameState.make(coins: 10_000, miners: [.chromebook: 10, .desktop: 1])
        let best = try #require(game.bestPurchase)
        // A Desktop (2 coins a second for 1,079) beats a Chromebook (a quarter coin for 361) and a GPU Rig.
        #expect(best.purchase == .miner(.desktop))
        #expect(best.name == "Desktop")
        #expect(best.price == game.price(of: .miner(.desktop)))
        #expect(best.price == 1_079)
        #expect(best.incomeGain == 2)
        #expect(abs(best.payback - best.price / 2) < 1e-9)
    }

    @Test func milestonesCount() throws {
        // The 25th Chromebook doubles all of them.
        let game = GameState.make(coins: 5_000, miners: [.chromebook: 24, .desktop: 3])
        let best = try #require(game.bestPurchase)
        #expect(best.purchase == .miner(.chromebook))
        #expect(best.incomeGain == 6.5) // 25 × 0.25 × 2, up from 24 × 0.25.
    }

    @Test func onlyAffordableThingsThatAddIncomeAreSuggested() {
        #expect(GameState.make(coins: 10).bestPurchase == nil)
        #expect(GameState.make(coins: 0, miners: [.chromebook: 3]).bestPurchase == nil)
    }

    @Test func theBestValueMinerMovesUpTheLadder() {
        // With one Chromebook, another is the cheapest way to add production.
        var game = GameState.make(miners: [.chromebook: 1])
        #expect(game.bestValueMiner == .chromebook)
        // Two Chromebooks in, a third costs 83 × 1.15² ≈ 110 for a quarter coin a second (439 a
        // coin), and a Desktop 823 for two (412 a coin): the Desktop is the better buy.
        game.miners[.chromebook] = 2
        #expect(game.bestValueMiner == .desktop)
        #expect(game.nextUnitGain(.desktop) == 2)
        // The 25th Chromebook doubles all of them, which makes it worth it again.
        game.miners = [.chromebook: 24, .desktop: 20]
        #expect(game.nextUnitGain(.chromebook) == 6.5)
        #expect(game.bestValueMiner == .chromebook)
        // Nothing revealed adds production: no suggestion.
        #expect(GameState.make().bestValueMiner == .chromebook)
    }

    @Test func aSuggestionCanBeBought() throws {
        var game = GameState.make(coins: 10_000, miners: [.chromebook: 10, .desktop: 1])
        let best = try #require(game.bestPurchase)
        let bought = game.buy(best.purchase)
        #expect(bought)
        #expect(game.owned(.desktop) == 2)
        #expect(game.coins == 10_000 - best.price)
        #expect(game.price(of: .upgrade(.overclocking)) == nil) // Not revealed yet.
    }
}

@Suite("Game records")
struct GameRecordTests {
    @Test func theArcadeListsCasinoThenArcadeGamesCheapestFirst() {
        // Merge Mining comes before Pump and Dump, and Bubble Market before Hash Smash (and To the
        // Moon last of the casino).
        #expect(MiniGame.byPrice == [.blackjack, .videoPoker, .slots, .moon, .tetris, .snake, .tokenSwap, .merge2048, .pumpDump,
                                     .bubbleBlaster, .brickBreaker, .invaders])
        for game in MiniGame.allCases {
            #expect(game.isCasino == (game.secondsPerPoint == 0))
            #expect(!game.info.pitch.isEmpty)
        }
    }

    @Test func recordsReadTheStatistics() {
        var game = GameState.make(miners: minersEarning(10))
        #expect(game.recordLine(for: .snake) == "Best 0 · Chain 0")
        #expect(game.recordLine(for: .moon) == "Best – · Cash-outs 0")
        // Every game's record is two facts, so the Arcade's rows read alike.
        #expect(MiniGame.allCases.allSatisfy { game.record(for: $0).count == 2 })
        game.finishSnake(score: 250, length: 28)
        game.finishBrickBreaker(score: 900, bricks: 60, level: 3)
        game.finishTetris(score: 1_234, lines: 9, rewardPoints: 1_234)
        #expect(game.recordLine(for: .snake) == "Best 250 · Chain 28")
        #expect(game.recordLine(for: .brickBreaker) == "Best 900 · Level 3")
        #expect(game.recordLine(for: .tetris) == "Best 1,234 · Rush –")
        #expect(game.timesPlayed(.snake) == 1)
        #expect(game.bestScore(.brickBreaker) == 900)
        #expect(game.arcadeGamesPlayed == 3)
    }

    @Test func casinoStatisticsTrackWinsAndStreaks() {
        var game = GameState.make(miners: minersEarning(10))
        game.tokens = [.shibaInu: 50]
        let win = BlackjackResult(outcome: .win, bet: 2, payout: 4)
        let loss = BlackjackResult(outcome: .lose, bet: 2, payout: 0)
        let push = BlackjackResult(outcome: .push, bet: 2, payout: 2)
        game.placeBlackjackBet(.shibaInu, amount: 4)
        game.settleBlackjack([win, win], token: .shibaInu)
        game.placeBlackjackBet(.shibaInu, amount: 2)
        game.settleBlackjack([push], token: .shibaInu)
        game.placeBlackjackBet(.shibaInu, amount: 2)
        game.settleBlackjack([win], token: .shibaInu)
        #expect(game.stats.blackjackStreak == 3) // A push doesn't end the streak.
        game.placeBlackjackBet(.shibaInu, amount: 2)
        game.settleBlackjack([loss], token: .shibaInu)
        #expect(game.stats.blackjackStreak == 0)
        #expect(game.stats.blackjackBestStreak == 3)
        // Two winning hands: 4 tokens (4,000 coins) plus a 600-coin bonus each.
        #expect(game.stats.blackjackBiggestWin == 5_200)
        #expect(game.recordLine(for: .blackjack) == "Wins 3 · Best streak 3")

        var rng = SeededGenerator(seed: 3)
        let before = game.tokenCount(.shibaInu)
        for _ in 0..<30 { game.spinSlots(.shibaInu, bet: 1, using: &rng) }
        #expect(game.stats.slotsWagered == 30_000)
        #expect(game.stats.slotsPaidOut == Double(game.tokenCount(.shibaInu) - before + 30) * 1_000)
        #expect(game.stats.slotsBestMultiple >= (game.stats.slotsWins > 0 ? 2 : 0))
    }
}
