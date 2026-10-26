import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Daily quests")
struct DailyQuestTests {
    /// 10 coins per second.
    func player() -> GameState { GameState.make(miners: [.desktop: 5]) }

    @Test func threeDifferentQuestsAreIssuedOncePerDay() {
        var game = player()
        game.refreshDaily(today: "2026-10-24", canWalk: false, at: t0)
        let quests = game.daily.quests
        #expect(quests.count == 3)
        #expect(Set(quests.map(\.kind)).count == 3)
        #expect(game.daily.questDay == "2026-10-24")
        // A brand-new game has no mini-games or steps, so only the basic quests can appear.
        #expect(Set(quests.map(\.kind)).isSubset(of: [.tapCoin, .buyMiners, .earnCoins, .catchAirdrops]))
        // Refreshing again the same day changes nothing...
        #expect(game.refreshDaily(today: "2026-10-24", canWalk: false, at: at(60)).isEmpty)
        #expect(game.daily.quests == quests)
        // ...and the same day always gets the same quests.
        var again = player()
        again.refreshDaily(today: "2026-10-24", canWalk: false, at: at(500))
        #expect(again.daily.quests.map(\.kind) == quests.map(\.kind))
        #expect(again.daily.quests.map(\.target) == quests.map(\.target))
    }

    @Test func unlockedGamesAndStepsWidenThePool() {
        var game = player()
        game.unlockedGames = Set(MiniGame.allCases)
        game.steps.isConnected = true
        game.stats.tokensBought = [.shibaInu: 1]
        #expect(game.eligibleQuestKinds(canWalk: true) == QuestKind.allCases)
        #expect(!game.eligibleQuestKinds(canWalk: false).contains(.walkSteps))
        var seen = Set<QuestKind>()
        for day in 1...28 {
            var copy = game
            copy.refreshDaily(today: String(format: "2026-11-%02d", day), canWalk: true, at: t0)
            seen.formUnion(copy.daily.quests.map(\.kind))
        }
        #expect(seen.count >= 10) // Different days bring different quests.
    }

    @Test func progressCountsFromWhenTheQuestWasIssued() throws {
        var game = player()
        game.stats.taps = 1_000
        game.daily.quests = [Quest(kind: .tapCoin, target: 200, baseline: 1_000, reward: .coins(seconds: 600))]
        game.daily.questDay = "2026-10-24"
        let quest = try #require(game.daily.quests.first)
        #expect(game.progress(of: quest) == 0)
        game.tap(count: 150, at: t0)
        #expect(game.progress(of: quest) == 150)
        #expect(!game.isComplete(quest))
        #expect(game.claimQuest(quest.id, at: t0) == nil) // Not finished yet.
        game.tap(count: 80, at: t0)
        #expect(game.progress(of: quest) == 200) // Never past the target.
        #expect(game.claimableQuestCount == 1)
        let coins = game.coins
        #expect(game.claimQuest(quest.id, at: t0) == .coins(6_000)) // 10 minutes of income.
        #expect(game.coins == coins + 6_000)
        #expect(game.stats.earnedFromDaily == 6_000)
        #expect(game.stats.questsCompleted == 1)
        #expect(game.claimQuest(quest.id, at: t0) == nil) // Only once.
        #expect(game.claimableQuestCount == 0)
    }

    @Test func finishedQuestsLeftUnclaimedArePaidAtMidnight() {
        var game = player()
        game.stats.airdrops = 3
        game.daily.quests = [
            Quest(kind: .catchAirdrops, target: 2, baseline: 1, reward: .coins(seconds: 1_200)), // Done.
            Quest(kind: .tapCoin, target: 500, baseline: 0, reward: .coins(seconds: 600)), // Not done.
        ]
        game.daily.questDay = "2026-10-24"
        let paid = game.refreshDaily(today: "2026-10-25", canWalk: false, at: t0)
        #expect(paid == [.coins(12_000)])
        #expect(game.stats.questsCompleted == 1)
        #expect(game.daily.questDay == "2026-10-25")
        #expect(game.daily.quests.count == 3)
        #expect(game.daily.quests.allSatisfy { !$0.isClaimed })
    }

    @Test func rewardsCanBeTokensOrABullRun() {
        var game = GameState.make(miners: [.server: 100]) // Tens of thousands of coins per second.
        #expect(game.tokenReward(worth: 4_000) == nil) // Not even five Shiba Inu.
        #expect(game.tokenReward(worth: 5_000) == .tokens(.shibaInu, 5))
        #expect(game.tokenReward(worth: 2e6) == .tokens(.dogecoin, 20))
        #expect(game.tokenReward(worth: 1e40) == .tokens(.bitcoin, 500))
        game.daily.quests = [Quest(kind: .tapCoin, target: 1, baseline: 0, reward: .bullRun)]
        game.tap(at: t0)
        #expect(game.claimQuest(QuestKind.tapCoin.rawValue, at: at(10)) == .bullRun(multiplier: 7, duration: 60))
        #expect(game.boost?.endsAt == at(70))
    }

    @Test func coinTargetsAreRoundNumbers() {
        #expect(GameState.roundTarget(12) == 1_000)
        #expect(GameState.roundTarget(18_000) == 18_000)
        #expect(GameState.roundTarget(18_250) == 19_000)
        #expect(GameState.roundTarget(3.14159e12) == 3.2e12)
    }
}

@Suite("Daily reward")
struct DailyRewardTests {
    func player() -> GameState { GameState.make(miners: [.desktop: 5]) } // 10 coins per second.

    @Test func theStreakGrowsOnConsecutiveDaysAndRestartsAfterAGap() {
        var game = player()
        #expect(game.isDailyRewardReady(today: "2026-10-01"))
        #expect(game.claimDailyReward(today: "2026-10-01", yesterday: "2026-09-30", at: t0) == .coins(3_000))
        #expect(game.daily.streak == 1)
        #expect(!game.isDailyRewardReady(today: "2026-10-01"))
        #expect(game.claimDailyReward(today: "2026-10-01", yesterday: "2026-09-30", at: t0) == nil)
        #expect(game.claimDailyReward(today: "2026-10-02", yesterday: "2026-10-01", at: t0) == .coins(6_000))
        #expect(game.daily.streak == 2)
        #expect(game.currentStreak(today: "2026-10-03", yesterday: "2026-10-02") == 2)
        // Missing a day breaks the streak.
        #expect(game.currentStreak(today: "2026-10-04", yesterday: "2026-10-03") == 0)
        #expect(game.streakIfClaimed(today: "2026-10-04", yesterday: "2026-10-03") == 1)
        game.claimDailyReward(today: "2026-10-04", yesterday: "2026-10-03", at: t0)
        #expect(game.daily.streak == 1)
        #expect(game.stats.longestStreak == 2)
    }

    @Test func theWeekBuildsUpToABigSeventhDayAndRepeats() {
        var game = player()
        #expect(GameState.streakCycleDay(1) == 1)
        #expect(GameState.streakCycleDay(7) == 7)
        #expect(GameState.streakCycleDay(8) == 1)
        #expect(game.streakReward(day: 5) == .bullRun)
        #expect(game.streakReward(day: 7) == .coins(seconds: 3_600))
        #expect(game.streakReward(day: 14) == .coins(seconds: 3_600))
        // Day 3 pays a quarter of an hour of income in tokens, once that buys five or more.
        #expect(game.streakReward(day: 3) == .tokens(.shibaInu, 9))
        #expect(GameState.make().streakReward(day: 3) == .coins(seconds: 900))
        game.daily.streak = 9
        game.daily.lastRewardDay = "2026-10-01"
        #expect(game.claimDailyReward(today: "2026-10-02", yesterday: "2026-10-01", at: t0) == .tokens(.shibaInu, 9))
        #expect(game.tokenCount(.shibaInu) == 9)
    }

    @Test func luckyStreakDoublesDailyRewards() {
        var game = player()
        game.perks = [.luckyStreak]
        #expect(game.claimDailyReward(today: "2026-10-01", yesterday: "2026-09-30", at: t0) == .coins(6_000))
        game.daily.quests = [Quest(kind: .tapCoin, target: 1, baseline: 0, reward: .tokens(.shibaInu, 5))]
        game.tap(at: t0)
        #expect(game.claimQuest(QuestKind.tapCoin.rawValue, at: t0) == .tokens(.shibaInu, 10))
        #expect(game.tokenCount(.shibaInu) == 10)
    }
}

@Suite("Daily challenge")
struct DailyChallengeTests {
    func player() -> GameState { GameState.make(miners: [.desktop: 5]) } // 10 coins per second.

    @Test func theFirstScoringGameOfTheDayPaysDouble() {
        var game = player()
        #expect(game.isDailyChallengeBonusAvailable(today: "2026-10-24"))
        // A game that scores nothing doesn't use up the bonus.
        #expect(game.finishTetris(score: 0, lines: 0, challengeDay: "2026-10-24").isChallengeBonus == false)
        let first = game.finishTetris(score: 1_000, lines: 8, challengeDay: "2026-10-24")
        #expect(first == ArcadePayout(coins: 1_800, isNewBest: true, isChallengeBonus: true)) // 600 × 1.5 × 2
        #expect(!game.isDailyChallengeBonusAvailable(today: "2026-10-24"))
        let second = game.finishTetris(score: 1_200, lines: 9, challengeDay: "2026-10-24")
        #expect(second == ArcadePayout(coins: 1_080, isNewBest: true, isChallengeBonus: false))
        #expect(game.dailyChallengeBest(today: "2026-10-24") == 1_200)
        // A new day brings a new challenge.
        #expect(game.isDailyChallengeBonusAvailable(today: "2026-10-25"))
        #expect(game.dailyChallengeBest(today: "2026-10-25") == 0)
        #expect(game.finishTetris(score: 500, lines: 3, challengeDay: "2026-10-25").isChallengeBonus)
        #expect(game.dailyChallengeBest(today: "2026-10-25") == 500)
    }

    @Test func aChallengeHeldOvernightPaysAsAnOrdinaryGame() {
        var game = player()
        game.finishTetris(score: 100, lines: 1, challengeDay: "2026-10-25")
        game.holdArcadeRun(ArcadeRun(game: .tetris, score: 400, detail: 2, challengeDay: "2026-10-24"))
        let paid = game.payUnfinishedRun()
        #expect(paid?.payout.isChallengeBonus == false)
        #expect(game.daily.challengeDay == "2026-10-25")
        #expect(game.dailyChallengeBest(today: "2026-10-25") == 100)
    }

    @Test func everyoneGetsTheSamePiecesAllDay() {
        #expect(GameState.dailyChallengeSeed(day: "2026-10-24") == GameState.dailyChallengeSeed(day: "2026-10-24"))
        #expect(GameState.dailyChallengeSeed(day: "2026-10-24") != GameState.dailyChallengeSeed(day: "2026-10-25"))
    }
}

@Suite("Income history")
struct IncomeHistoryTests {
    @Test func samplesAreTakenEveryHalfHourForAWeek() {
        var game = GameState.make(miners: [.desktop: 5])
        game.recordIncomeSample(at: t0)
        game.recordIncomeSample(at: at(60))
        #expect(game.incomeHistory == [IncomeSample(date: t0, income: 10)])
        game.recordIncomeSample(at: at(1_800))
        #expect(game.incomeHistory.count == 2)
        for half in 2...400 { game.recordIncomeSample(at: at(Double(half) * 1_800)) }
        #expect(game.incomeHistory.count == Tuning.maxIncomeSamples)
        #expect(game.incomeHistory.last?.date == at(400 * 1_800))
        // A clock that jumps back drops the samples from the "future".
        game.recordIncomeSample(at: at(100 * 1_800))
        #expect(game.incomeHistory.last?.date == at(100 * 1_800))
        #expect(game.incomeHistory.allSatisfy { $0.date <= at(100 * 1_800) })
    }
}
