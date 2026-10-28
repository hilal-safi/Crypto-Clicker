import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Mini-game rewards")
struct MiniGameRewardTests {
    /// 10 coins per second, so a full Blackjack bonus is 600 coins.
    func earner(upgrades: Set<UpgradeID> = []) -> GameState {
        var game = GameState.make(miners: [.desktop: 10], upgrades: upgrades)
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
        // A 1-token Shiba bet stakes 1,000 coins: half is 500, under the cap of a minute of income.
        #expect(game.blackjackBonus(bet: 1, token: .shibaInu) == 500)
        #expect(game.blackjackBonus(bet: 2, token: .shibaInu) == 600)
        var poor = GameState.make()
        poor.tokens = [.shibaInu: 1]
        #expect(poor.blackjackBonus(bet: 1, token: .shibaInu) == 60) // A minute at the 1 coin/s floor.
        var rich = GameState.make(miners: [.desktop: 50]) // 200 coins per second: cap 12,000.
        rich.tokens = [.shibaInu: 100]
        #expect(rich.blackjackBonus(bet: 3, token: .shibaInu) == 1_500)
        #expect(rich.blackjackBonus(bet: 60, token: .shibaInu) == 12_000)
        #expect(rich.blackjackBonus(bet: 60, token: .shibaInu, isNatural: true) == 18_000)
        #expect(rich.blackjackBetForFullBonus(.shibaInu) == 24)
        #expect(rich.blackjackBetForFullBonus(.bitcoin) == 1)
    }

    @Test func winningHandsPayTokensAndACoinBonus() {
        var game = earner()
        game.placeBlackjackBet(.dogecoin, amount: 4)
        let results = [BlackjackResult(outcome: .win, bet: 2, payout: 4),
                       BlackjackResult(outcome: .blackjack, bet: 2, payout: 5)]
        let bonus = game.settleBlackjack(results, token: .dogecoin)
        #expect(bonus == 600 + 900)
        #expect(game.coins == bonus)
        #expect(game.tokenCount(.dogecoin) == 1 + 9)
        #expect(game.blackjackStake == nil)
        #expect(game.stats.blackjackHands == 1)
        #expect(game.stats.blackjackWins == 2)
        #expect(game.stats.blackjackNaturals == 1)
        #expect(game.stats.earnedFromGames == bonus)
    }

    @Test func aRoundSettlesOnlyOnce() {
        var game = earner()
        game.placeBlackjackBet(.dogecoin, amount: 2)
        let results = [BlackjackResult(outcome: .win, bet: 2, payout: 4)]
        #expect(game.settleBlackjack(results, token: .dogecoin) == 600)
        let tokens = game.tokenCount(.dogecoin)
        // A second settlement of the same round (a double tap, a stale view) pays nothing.
        #expect(game.settleBlackjack(results, token: .dogecoin) == 0)
        #expect(game.tokenCount(.dogecoin) == tokens)
        #expect(game.stats.blackjackHands == 1)
        #expect(game.coins == 600)
    }

    @Test func theToughTablePaysABiggerBonus() {
        let game = earner()
        #expect(game.blackjackBonus(bet: 2, token: .dogecoin) == 600)
        #expect(game.blackjackBonus(bet: 2, token: .dogecoin, rules: .hitsSoft17) == 660)
        #expect(game.blackjackBonus(bet: 2, token: .dogecoin, isNatural: true, rules: .hitsSoft17) == 990)
        var tough = earner()
        tough.placeBlackjackBet(.dogecoin, amount: 2)
        #expect(tough.settleBlackjack([BlackjackResult(outcome: .win, bet: 2, payout: 4)], token: .dogecoin, rules: .hitsSoft17) == 660)
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
        #expect(game.blackjackBonus(bet: 1, token: .dogecoin) == 1_125) // The 600-coin cap × 1.875.
        #expect(game.blackjackBonus(bet: 1, token: .shibaInu) == 938) // 937.5, paid as a whole coin.
    }

    @Test func tetrisPaysByScoreWithABonusForANewBest() {
        var game = earner()
        let first = game.finishTetris(score: 1_000, lines: 8, rewardPoints: 1_000)
        #expect(first == ArcadePayout(coins: 375, isNewBest: true)) // 1,000 × 0.025 × 10 × 1.5
        #expect(game.stats.tetrisGames == 1)
        #expect(game.stats.tetrisLines == 8)
        #expect(game.stats.tetrisBestScore == 1_000)
        let second = game.finishTetris(score: 800, lines: 5, rewardPoints: 800)
        #expect(second == ArcadePayout(coins: 200, isNewBest: false))
        #expect(game.finishTetris(score: 0, lines: 0, rewardPoints: 0).coins == 0)
        #expect(game.stats.tetrisGames == 3)
        #expect(game.stats.tetrisBestScore == 1_000)
    }

    @Test func arcadeGamesPayWholeCoinsForTheirScores() {
        var game = earner() // 10 coins per second. Every first score is a new best: +50%.
        #expect(game.finishSnake(score: 120, length: 15).coins == 540) // 120 × 0.3 × 10 × 1.5
        #expect(game.stats.snakeGames == 1)
        #expect(game.stats.snakeBestScore == 120)
        #expect(game.stats.snakeCoinsEaten == 12)
        #expect(game.finishBrickBreaker(score: 400, bricks: 35, level: 2).coins == 2_160) // 400 × 0.36 × 10 × 1.5
        #expect(game.stats.brickBreakerGames == 1)
        #expect(game.stats.brickBreakerBestScore == 400)
        #expect(game.stats.bricksBroken == 35)
        #expect(game.finishBubbleBlaster(score: 333, popped: 21, bestShot: 7).coins == 549) // 549.45, paid as 549.
        #expect(game.stats.bubbleGames == 1)
        #expect(game.stats.bubbleBestScore == 333)
        #expect(game.stats.bubblesPopped == 21)
        #expect(game.finishSnake(score: 0, length: 3) == ArcadePayout(coins: 0, isNewBest: false))
        #expect(game.stats.snakeGames == 2)
        #expect(game.stats.snakeBestScore == 120)
        #expect(game.coins == 540 + 2_160 + 549)
        #expect(game.stats.earnedFromGames == 540 + 2_160 + 549)
    }

    @Test func aGameLeftOpenIsPaidOnceAfterTheAppCloses() throws {
        var game = earner() // 10 coins per second.
        game.holdArcadeRun(ArcadeRun(game: .snake, score: 120, detail: 15))
        // iOS closed the app in the background: the run comes back with the save.
        let data = try GameCoding.encoder().encode(game)
        var reloaded = try GameCoding.decoder().decode(GameState.self, from: data)
        #expect(reloaded.unfinishedRun == ArcadeRun(game: .snake, score: 120, detail: 15))
        let payment = reloaded.payUnfinishedRun()
        let paid = try #require(payment)
        #expect(paid.payout.coins == 540)
        #expect(reloaded.stats.snakeGames == 1)
        #expect(reloaded.unfinishedRun == nil)
        #expect(reloaded.payUnfinishedRun() == nil)
    }

    @Test func finishingOrReturningClearsTheHeldRun() {
        var game = earner()
        game.holdArcadeRun(ArcadeRun(game: .tetris, score: 900, detail: 4))
        game.finishTetris(score: 1_200, lines: 6, rewardPoints: 1_200)
        #expect(game.unfinishedRun == nil)
        game.holdArcadeRun(ArcadeRun(game: .brickBreaker, score: 300, detail: 30))
        game.releaseArcadeRun()
        #expect(game.unfinishedRun == nil)
        game.holdArcadeRun(ArcadeRun(game: .blackjack, score: 5, detail: 0)) // Casino rounds settle on their own.
        #expect(game.unfinishedRun == nil)
    }

    @Test func everyMiniGameCanBeUnlocked() {
        var game = GameState.make(coins: MiniGame.allCases.reduce(0) { $0 + $1.unlockCost })
        for miniGame in MiniGame.allCases {
            let unlocked = game.unlock(miniGame)
            #expect(unlocked)
            #expect(game.isUnlocked(miniGame))
        }
        #expect(game.coins == 0)
        #expect(MiniGame.allCases.filter(\.isCasino) == [.blackjack, .slots, .moon, .videoPoker])
    }

    @Test func rewardsHaveAFloorOnDayOne() {
        var game = GameState.make()
        #expect(game.finishTetris(score: 900, lines: 2, rewardPoints: 600).coins == 23) // 600 × 0.025 × 1 coin/s × 1.5 = 22.5.
    }
}
