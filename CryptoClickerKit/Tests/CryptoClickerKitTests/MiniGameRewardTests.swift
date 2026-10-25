import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Mini-game rewards")
struct MiniGameRewardTests {
    /// 10 coins per second, so a full Blackjack bonus is 100 coins.
    func earner(upgrades: Set<UpgradeID> = []) -> GameState {
        var game = GameState.make(miners: [.desktop: 5], upgrades: upgrades)
        game.tokens = [.shibaInu: 50, .dogecoin: 5]
        return game
    }

    @Test func betsComeOutOfTheWalletAndAreRemembered() {
        var game = earner()
        #expect(game.placeBlackjackBet(.dogecoin, amount: 2) == true)
        #expect(game.tokenCount(.dogecoin) == 3)
        #expect(game.blackjackStake == BlackjackStake(token: .dogecoin, amount: 2))
        // Doubling or splitting adds to the same stake.
        #expect(game.placeBlackjackBet(.dogecoin, amount: 2) == true)
        #expect(game.blackjackStake?.amount == 4)
        #expect(game.placeBlackjackBet(.dogecoin, amount: 2) == false) // Only 1 left.
        #expect(game.placeBlackjackBet(.shibaInu, amount: 1) == false) // One token type per round.
        #expect(game.placeBlackjackBet(.dogecoin, amount: 0) == false)
        #expect(game.tokenCount(.dogecoin) == 1)
    }

    @Test func anUnfinishedRoundIsRefunded() {
        var game = earner()
        game.placeBlackjackBet(.shibaInu, amount: 7)
        #expect(game.refundBlackjackStake() == BlackjackStake(token: .shibaInu, amount: 7))
        #expect(game.tokenCount(.shibaInu) == 50)
        #expect(game.blackjackStake == nil)
        #expect(game.refundBlackjackStake() == nil)
    }

    @Test func theBonusFollowsTheStakeUpToAnIncomeCap() {
        let game = earner()
        // A 1-token Shiba bet stakes 1,000 coins: half is 500, capped at 10 seconds of income.
        #expect(game.blackjackBonus(bet: 1, token: .shibaInu) == 100)
        var poor = GameState.make()
        poor.tokens = [.shibaInu: 1]
        #expect(poor.blackjackBonus(bet: 1, token: .shibaInu) == 10) // 10 seconds at the 1 coin/s floor.
        var rich = GameState.make(miners: [.desktop: 50]) // 400 coins per second: cap 4,000.
        rich.tokens = [.shibaInu: 100]
        #expect(rich.blackjackBonus(bet: 3, token: .shibaInu) == 1_500)
        #expect(rich.blackjackBonus(bet: 8, token: .shibaInu) == 4_000)
        #expect(rich.blackjackBonus(bet: 8, token: .shibaInu, isNatural: true) == 6_000)
        #expect(rich.blackjackBetForFullBonus(.shibaInu) == 8)
        #expect(rich.blackjackBetForFullBonus(.bitcoin) == 1)
    }

    @Test func winningHandsPayTokensAndACoinBonus() {
        var game = earner()
        game.placeBlackjackBet(.dogecoin, amount: 4)
        let results = [BlackjackResult(outcome: .win, bet: 2, payout: 4),
                       BlackjackResult(outcome: .blackjack, bet: 2, payout: 5)]
        let bonus = game.settleBlackjack(results, token: .dogecoin)
        #expect(bonus == 100 + 150)
        #expect(game.coins == bonus)
        #expect(game.tokenCount(.dogecoin) == 1 + 9)
        #expect(game.blackjackStake == nil)
        #expect(game.stats.blackjackHands == 1)
        #expect(game.stats.blackjackWins == 2)
        #expect(game.stats.blackjackNaturals == 1)
        #expect(game.stats.earnedFromGames == bonus)
    }

    @Test func lostHandsPayNothing() {
        var game = earner()
        game.placeBlackjackBet(.shibaInu, amount: 4)
        #expect(game.settleBlackjack([BlackjackResult(outcome: .lose, bet: 4, payout: 0)], token: .shibaInu) == 0)
        #expect(game.coins == 0)
        #expect(game.tokenCount(.shibaInu) == 46)
        #expect(game.stats.blackjackHands == 1)
        game.placeBlackjackBet(.shibaInu, amount: 4)
        #expect(game.settleBlackjack([BlackjackResult(outcome: .push, bet: 4, payout: 4)], token: .shibaInu) == 0)
        #expect(game.tokenCount(.shibaInu) == 46)
    }

    @Test func bonusRewardUpgradesMultiplyMiniGames() {
        let game = earner(upgrades: [.bonusReward1, .bonusReward2])
        #expect(game.miniGameMultiplier == 1.875)
        #expect(approx(game.blackjackBonus(bet: 1, token: .dogecoin), 100 * 1.875))
    }

    @Test func tetrisPaysByScore() {
        var game = earner()
        let reward = game.finishTetris(score: 1_000, lines: 8)
        #expect(approx(reward, 1_000 * 0.02 * 10))
        #expect(game.stats.tetrisGames == 1)
        #expect(game.stats.tetrisLines == 8)
        #expect(game.stats.tetrisBestScore == 1_000)
        #expect(game.finishTetris(score: 0, lines: 0) == 0)
        #expect(game.stats.tetrisGames == 2)
        #expect(game.stats.tetrisBestScore == 1_000)
    }

    @Test func rewardsHaveAFloorOnDayOne() {
        var game = GameState.make()
        #expect(approx(game.finishTetris(score: 500, lines: 2), 10))
    }
}
