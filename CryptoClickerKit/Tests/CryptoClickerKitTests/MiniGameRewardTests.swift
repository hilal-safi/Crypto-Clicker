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
        #expect(game.blackjackBonus(bet: 1, token: .dogecoin) == 188) // 187.5, paid as a whole coin.
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

    @Test func arcadeGamesPayWholeCoinsForTheirScores() {
        var game = earner() // 10 coins per second.
        #expect(game.finishSnake(score: 120) == 180) // 120 × 0.15 × 10
        #expect(game.stats.snakeGames == 1)
        #expect(game.stats.snakeBestScore == 120)
        #expect(game.finishBrickBreaker(score: 450, bricks: 35) == 270) // 450 × 0.06 × 10
        #expect(game.stats.brickBreakerGames == 1)
        #expect(game.stats.brickBreakerBestScore == 450)
        #expect(game.stats.bricksBroken == 35)
        #expect(game.finishBubbleBlaster(score: 333, popped: 21) == 83) // 83.25, paid as 83.
        #expect(game.stats.bubbleGames == 1)
        #expect(game.stats.bubbleBestScore == 333)
        #expect(game.stats.bubblesPopped == 21)
        #expect(game.finishSnake(score: 0) == 0)
        #expect(game.stats.snakeGames == 2)
        #expect(game.stats.snakeBestScore == 120)
        #expect(game.coins == 180 + 270 + 83)
        #expect(game.stats.earnedFromGames == 180 + 270 + 83)
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
        #expect(paid.reward == 180)
        #expect(reloaded.stats.snakeGames == 1)
        #expect(reloaded.unfinishedRun == nil)
        #expect(reloaded.payUnfinishedRun() == nil)
    }

    @Test func finishingOrReturningClearsTheHeldRun() {
        var game = earner()
        game.holdArcadeRun(ArcadeRun(game: .tetris, score: 900, detail: 4))
        game.finishTetris(score: 1_200, lines: 6)
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
        #expect(MiniGame.allCases.filter(\.isCasino) == [.blackjack, .slots])
    }

    @Test func rewardsHaveAFloorOnDayOne() {
        var game = GameState.make()
        #expect(approx(game.finishTetris(score: 500, lines: 2), 10))
    }
}
