import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Mini-game rewards")
struct MiniGameRewardTests {
    /// 10 coins per second, so a full Blackjack bonus is 500 coins.
    func earner(upgrades: Set<UpgradeID> = []) -> GameState {
        var game = GameState.make(miners: minersEarning(10), upgrades: upgrades)
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
        // A 1-token Shiba bet stakes 1,000 coins: 42% is 420, under the cap of 50 seconds of income.
        #expect(game.blackjackBonus(bet: 1, token: .shibaInu) == 420)
        #expect(game.blackjackBonus(bet: 2, token: .shibaInu) == 500)
        var poor = GameState.make()
        poor.tokens = [.shibaInu: 1]
        #expect(poor.blackjackBonus(bet: 1, token: .shibaInu) == 50) // 50 seconds at the 1 coin/s floor.
        var rich = GameState.make(miners: [.desktop: 50]) // 400 coins per second: cap 20,000.
        rich.tokens = [.shibaInu: 100]
        #expect(rich.blackjackBonus(bet: 3, token: .shibaInu) == 1_260)
        #expect(rich.blackjackBonus(bet: 60, token: .shibaInu) == 20_000)
        #expect(rich.blackjackBonus(bet: 60, token: .shibaInu, isNatural: true) == 30_000)
        #expect(rich.blackjackBetForFullBonus(.shibaInu) == 48)
        #expect(rich.blackjackBetForFullBonus(.bitcoin) == 1)
    }

    @Test func winningHandsPayTokensAndACoinBonus() {
        var game = earner()
        game.placeBlackjackBet(.dogecoin, amount: 4)
        let results = [BlackjackResult(outcome: .win, bet: 2, payout: 4),
                       BlackjackResult(outcome: .blackjack, bet: 2, payout: 5)]
        let bonus = game.settleBlackjack(results, token: .dogecoin)
        #expect(bonus == 500 + 750)
        #expect(game.coins == bonus)
        #expect(game.tokenCount(.dogecoin) == 1 + 9)
        #expect(game.blackjackStake == nil)
        #expect(game.stats.blackjackHands == 1)
        #expect(game.stats.blackjackWins == 2)
        #expect(game.stats.blackjackNaturals == 1)
        #expect(game.stats.earnedFromGames == bonus)
    }

    @Test func insuranceIsPaidWithTheHands() {
        var game = earner()
        game.placeBlackjackBet(.dogecoin, amount: 3) // A bet of 2 and insurance of 1.
        let lost = [BlackjackResult(outcome: .lose, bet: 2, payout: 0)]
        #expect(game.settleBlackjack(lost, insurance: BlackjackInsurance(stake: 1, payout: 3), token: .dogecoin) == 0)
        #expect(game.tokenCount(.dogecoin) == 5 - 3 + 3) // Insurance paid the bet back.
        #expect(game.stats.blackjackWins == 0)
        #expect(game.stats.blackjackBiggestWin == 0)
    }

    @Test func aRoundSettlesOnlyOnce() {
        var game = earner()
        game.placeBlackjackBet(.dogecoin, amount: 2)
        let results = [BlackjackResult(outcome: .win, bet: 2, payout: 4)]
        #expect(game.settleBlackjack(results, token: .dogecoin) == 500)
        let tokens = game.tokenCount(.dogecoin)
        // A second settlement of the same round (a double tap, a stale view) pays nothing.
        #expect(game.settleBlackjack(results, token: .dogecoin) == 0)
        #expect(game.tokenCount(.dogecoin) == tokens)
        #expect(game.stats.blackjackHands == 1)
        #expect(game.coins == 500)
    }

    @Test func theToughTablePaysABiggerBonus() {
        let game = earner()
        #expect(game.blackjackBonus(bet: 2, token: .dogecoin) == 500)
        #expect(game.blackjackBonus(bet: 2, token: .dogecoin, rules: .hitsSoft17) == 550)
        #expect(game.blackjackBonus(bet: 2, token: .dogecoin, isNatural: true, rules: .hitsSoft17) == 825)
        var tough = earner()
        tough.placeBlackjackBet(.dogecoin, amount: 2)
        #expect(tough.settleBlackjack([BlackjackResult(outcome: .win, bet: 2, payout: 4)], token: .dogecoin, rules: .hitsSoft17) == 550)
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
        #expect(game.blackjackBonus(bet: 1, token: .dogecoin) == 938) // The 500-coin cap × 1.875, 937.5 paid as a whole coin.
        #expect(game.blackjackBonus(bet: 1, token: .shibaInu) == 788) // 420 × 1.875 = 787.5.
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

    @Test func flashMarketKeepsItsOwnBestAndPaysItsShare() throws {
        var game = earner()
        let waves = game.finishBubbleBlaster(score: 2_000, popped: 90, bestShot: 9, wave: 3)
        #expect(waves.isNewBest && game.stats.bubbleBestScore == 2_000)
        // A Flash Market game below the Waves best is still a new best of its own.
        let flash = game.finishBubbleBlaster(score: 1_000, popped: 70, bestShot: 12, wave: 2, mode: .flash)
        #expect(flash.isNewBest)
        #expect(flash.coins == game.arcadeReward(.bubbleBlaster, score: 650, multiplier: 1 + Tuning.newBestBonus)) // 65% of its points.
        #expect(game.stats.bubbleFlashBestScore == 1_000 && game.stats.bubbleFlashes == 1)
        #expect(game.stats.bubbleBestScore == 2_000 && game.stats.bubbleGames == 2)
        #expect(game.stats.bubblesPopped == 160 && game.stats.bubbleBestShot == 12)
        // A held run remembers its mode.
        game.holdArcadeRun(ArcadeRun(game: .bubbleBlaster, score: 1_500, detail: 80, extra: 5, stage: 2,
                                     records: .init(mode: 1)))
        let held = game.payUnfinishedRun()
        #expect(held?.payout.isNewBest == true && game.stats.bubbleFlashBestScore == 1_500 && game.stats.bubbleFlashes == 2)
        #expect(game.stats.bubbleBestScore == 2_000)
        // And it all survives a save.
        let records = ArcadeRun.Records(bestStreak: 4, mode: 1)
        let run = ArcadeRun(game: .bubbleBlaster, score: 10, detail: 3, extra: 3, records: records)
        #expect(try JSONDecoder().decode(ArcadeRun.self, from: JSONEncoder().encode(run)) == run)
        let reloaded = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(reloaded.stats == game.stats)
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

    @Test func scamInvadersPaysForItsPointsAndKeepsItsRecords() {
        var game = earner()
        game.unlockedGames.insert(.invaders)
        let first = game.finishInvaders(score: 1_000, destroyed: 60, wave: 3, whales: 2, bosses: 0, powerUps: 3,
                                        bestStreak: 14, volleys: 80, volleysHit: 50)
        // Every point pays its share of income, and a new best half as much again.
        #expect(first.isNewBest)
        #expect(first.coins == game.arcadeReward(.invaders, score: 1_000, multiplier: 1 + Tuning.newBestBonus))
        #expect(first.coins == (1_000 * Tuning.invadersSecondsPerPoint * 10 * 1.5).rounded(.down))
        let second = game.finishInvaders(score: 500, destroyed: 25, wave: 2, volleys: 30, volleysHit: 40)
        #expect(!second.isNewBest && second.coins == game.arcadeReward(.invaders, score: 500))
        let s = game.stats
        #expect(s.invadersGames == 2 && s.invadersBestScore == 1_000 && s.invadersBestWave == 3)
        #expect(s.invadersDestroyed == 85 && s.invadersWhales == 2 && s.invadersPowerUps == 3 && s.invadersBestStreak == 14)
        // Hits can't outnumber volleys.
        #expect(s.invadersVolleys == 110 && s.invadersVolleysHit == 80)
        #expect(game.recordLine(for: .invaders) == "Best 1,000 · Wave 3")
        #expect(game.timesPlayed(.invaders) == 2 && game.bestScore(.invaders) == 1_000)
        // A held run comes back with every record.
        game.holdArcadeRun(ArcadeRun(game: .invaders, score: 2_000, detail: 70, extra: 6,
                                     records: .init(powerUps: 2, bosses: 1, bestStreak: 30, bonuses: 1, volleys: 90, volleysHit: 70)))
        game.payUnfinishedRun()
        #expect(game.stats.invadersBestWave == 6 && game.stats.invadersBosses == 1 && game.stats.invadersBestStreak == 30)
        #expect(game.stats.invadersWhales == 3 && game.stats.invadersVolleys == 200 && game.stats.invadersVolleysHit == 150)
        // And everything survives a save.
        let saved = try? GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(saved?.stats == game.stats)
    }

    @Test func aHeldRunKeepsEveryRecordAndEarnsItsArcadeXP() throws {
        var game = earner()
        let records = ArcadeRun.Records(powerUps: 5, bosses: 2, bestStreak: 3)
        game.holdArcadeRun(ArcadeRun(game: .brickBreaker, score: 900, detail: 80, extra: 11, records: records))
        // Saved and loaded with the game, records included.
        var reloaded = try GameCoding.decoder().decode(GameState.self, from: try GameCoding.encoder().encode(game))
        #expect(reloaded.unfinishedRun?.records == records)
        // Paid the way the app pays it on launch: through the same award as a finished game.
        let before = reloaded.arcadeSnapshot
        let payment = reloaded.payUnfinishedRun()
        let paid = try #require(payment)
        #expect(paid.payout.coins > 0)
        let award = reloaded.awardArcadeProgress(since: before, today: "2026-10-24")
        #expect(award.map { $0.xp > 0 } == true)
        #expect(reloaded.stats.brickBreakerBosses == 2)
        #expect(reloaded.stats.brickBreakerPowerUps == 5)
        #expect(reloaded.stats.brickBreakerBestStreak == 3)
        #expect(reloaded.stats.brickBreakerBestLevel == 11)
    }

    @Test func everyGamesRecordsSurviveTheTripThroughAHeldRun() {
        var game = earner()
        game.holdArcadeRun(ArcadeRun(game: .tetris, score: 3_000, detail: 12, extra: 2_400,
                                     records: .init(level: 3, bestCombo: 4, tetrises: 2)))
        game.payUnfinishedRun()
        #expect(game.stats.tetrisBestLevel == 3 && game.stats.tetrisBestCombo == 4 && game.stats.tetrisTetrises == 2)
        game.holdArcadeRun(ArcadeRun(game: .snake, score: 150, detail: 18, records: .init(coins: 14, seconds: 95, powerUps: 2)))
        game.payUnfinishedRun()
        #expect(game.stats.snakeBestCoins == 14 && game.stats.snakePowerUps == 2 && game.stats.snakeLongestTime == 95)
        game.holdArcadeRun(ArcadeRun(game: .bubbleBlaster, score: 400, detail: 40, extra: 6, stage: 3,
                                     records: .init(bestStreak: 7, bonuses: 2)))
        game.payUnfinishedRun()
        #expect(game.stats.bubbleBestStreak == 7 && game.stats.bubbleBonuses == 2 && game.stats.bubbleBestWave == 3)
        game.holdArcadeRun(ArcadeRun(game: .pumpDump, score: 800, detail: 60, extra: 9, stage: 2, records: .init(scamsHit: 3)))
        game.payUnfinishedRun()
        #expect(game.stats.pumpDumpScamsHit == 3)
        game.holdArcadeRun(ArcadeRun(game: .tokenSwap, score: 900, detail: 70, extra: 4, records: .init(specials: 5)))
        game.payUnfinishedRun()
        #expect(game.stats.tokenSwapBlasts == 5)
        // A run saved by an earlier version, without records, still pays.
        let old = try? GameCoding.decoder().decode(ArcadeRun.self, from: Data(#"{"game":"tetris","score":100,"detail":1,"extra":100}"#.utf8))
        #expect(old?.records == ArcadeRun.Records())
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
