import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Daily quests")
struct DailyQuestTests {
    /// 10 coins per second.
    func player() -> GameState { GameState.make(miners: [.desktop: 10]) }

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
    func player() -> GameState { GameState.make(miners: [.desktop: 10]) } // 10 coins per second.

    @Test func dailiesStartOnTheGamesSecondDay() throws {
        var game = GameState(now: t0)
        let first = StepDay.key(for: t0)
        let second = StepDay.key(for: at(86_400))
        #expect(game.daily.firstDay == first)
        #expect(game.isFirstDay(first))
        // No reward, quests or challenge on the first day, even with a game unlocked...
        game.unlockedGames = [.tetris]
        #expect(!game.isDailyRewardReady(today: first))
        #expect(game.claimDailyReward(today: first, yesterday: "2000-01-01", at: t0) == nil)
        #expect(!game.needsDailyRefresh(today: first))
        #expect(game.refreshDaily(today: first, canWalk: false, at: t0).isEmpty)
        #expect(game.daily.quests.isEmpty && game.dailyChallenge(today: first) == nil)
        // ...then all of them from the next day on.
        #expect(game.isDailyRewardReady(today: second))
        #expect(game.needsDailyRefresh(today: second))
        game.refreshDaily(today: second, canWalk: false, at: at(86_400))
        #expect(game.daily.quests.count == 3)
        #expect(game.dailyChallenge(today: second) != nil)
        #expect(game.claimDailyReward(today: second, yesterday: first, at: at(86_400)) == .coins(300))
        #expect(game.daily.streak == 1)
        // The day is saved, and games begun before it was (with no first day) are never held back.
        let saved = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(saved.daily.firstDay == first)
        let older = try GameCoding.decoder().decode(DailyProgress.self, from: Data(#"{"streak": 3}"#.utf8))
        #expect(older.firstDay == nil)
        #expect(player().isDailyRewardReady(today: StepDay.key(for: t0)) == false)
        var veteran = player()
        veteran.daily = older
        #expect(veteran.isDailyRewardReady(today: StepDay.key(for: t0)))
    }

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
    func player(_ games: Set<MiniGame> = []) -> GameState {
        var game = GameState.make(miners: [.desktop: 10]) // 10 coins per second.
        game.unlockedGames = games
        return game
    }

    func with(_ kind: DailyChallengeKind, target: Int, day: String = "2026-10-26", games: Set<MiniGame> = []) -> GameState {
        var game = player(games)
        game.daily.challenge = DailyChallenge(day: day, kind: kind, target: target)
        return game
    }

    @Test func aChallengeArrivesOnceAGameIsUnlocked() throws {
        var game = player()
        game.refreshDaily(today: "2026-10-26", canWalk: false, at: t0)
        #expect(game.daily.challenge == nil)
        #expect(!game.needsDailyRefresh(today: "2026-10-26"))
        game.unlockedGames.insert(.snake)
        #expect(game.needsDailyRefresh(today: "2026-10-26"))
        game.refreshDaily(today: "2026-10-26", canWalk: false, at: t0)
        let challenge = try #require(game.dailyChallenge(today: "2026-10-26"))
        #expect(challenge.kind == .snake)
        #expect(DailyChallengeKind.snake.targets.contains(challenge.target))
        #expect(challenge.goal == "Eat \(challenge.target) coins in one Snake game")
        // Asking again the same day changes nothing, even with more games unlocked.
        game.unlockedGames.insert(.tetris)
        #expect(!game.needsDailyRefresh(today: "2026-10-26"))
        game.refreshDaily(today: "2026-10-26", canWalk: false, at: t0)
        #expect(game.daily.challenge == challenge)
        #expect(game.dailyChallenge(today: "2026-10-27") == nil)
    }

    @Test func challengesRotateAndDontRepeatTheDayBefore() {
        var game = player([.tetris, .snake, .merge2048, .blackjack])
        var kinds: [DailyChallengeKind] = []
        for day in 20...30 {
            game.refreshDaily(today: "2026-10-\(day)", canWalk: false, at: t0)
            kinds.append(game.daily.challenge?.kind ?? .arcadeMix)
        }
        for (yesterday, today) in zip(kinds, kinds.dropFirst()) {
            #expect(yesterday != today)
            #expect(yesterday.game == nil || yesterday.game != today.game) // Not even Blackjack's other one.
        }
        #expect(Set(kinds).count >= 3)
        // The arcade mix is possible with three arcade games unlocked.
        #expect(Set(kinds).isSubset(of: [.tetris, .snake, .merge2048, .blackjack, .blackjackNatural, .arcadeMix]))
        #expect(!player([.tetris, .snake, .blackjack]).eligibleChallengeKinds().contains(.arcadeMix))
    }

    @Test func aBestOfOneGameChallengeCountsTheBestGame() throws {
        var game = with(.snake, target: 12, games: [.snake])
        let first = game.finishSnake(score: 100, length: 13) // 10 coins.
        #expect(first.challenge == nil)
        #expect(game.daily.challenge?.progress == 10)
        let second = game.finishSnake(score: 50, length: 8)
        #expect(second.challenge == nil)
        #expect(game.daily.challenge?.progress == 10)
        let coinsBefore = game.coins
        let third = game.finishSnake(score: 120, length: 15)
        let reward = try #require(third.challenge)
        #expect(reward == ChallengeReward(coins: 9_000, weeklyBonus: 0)) // 15 minutes at 10 coins per second.
        #expect(game.coins == coinsBefore + third.coins + 9_000)
        #expect(game.daily.challenge?.isComplete == true)
        #expect(game.stats.challengesCompleted == 1)
        #expect(game.stats.earnedFromDaily == 9_000)
        // It pays once.
        #expect(game.finishSnake(score: 300, length: 33).challenge == nil)
        #expect(game.stats.challengesCompleted == 1)
    }

    @Test func otherGamesDontCount() {
        var game = with(.tetris, target: 2_000, games: [.tetris, .snake])
        game.finishSnake(score: 5_000, length: 400)
        #expect(game.daily.challenge?.progress == 0)
        game.finishTetris(score: 2_500, lines: 12, rewardPoints: 2_500)
        #expect(game.daily.challenge?.isComplete == true)
    }

    @Test func theNaturalChallengeCountsNaturalsOnly() {
        var game = with(.blackjackNatural, target: 1, games: [.blackjack])
        game.tokens = [.dogecoin: 20]
        game.placeBlackjackBet(.dogecoin, amount: 2)
        game.settleBlackjack([BlackjackResult(outcome: .win, bet: 1, payout: 2), BlackjackResult(outcome: .win, bet: 1, payout: 2)],
                             token: .dogecoin)
        #expect(game.daily.challenge?.progress == 0)
        game.placeBlackjackBet(.dogecoin, amount: 1)
        game.settleBlackjack([BlackjackResult(outcome: .blackjack, bet: 1, payout: 3)], token: .dogecoin)
        #expect(game.daily.challenge?.isComplete == true)
        #expect(DailyChallengeKind.blackjackNatural.game == .blackjack)
        #expect(DailyChallengeKind.blackjackNatural.goal(target: 1) == "Deal yourself a natural blackjack today")
    }

    @Test func blackjackDaysAskForWinsOrANaturalButNoMoreOftenThanOtherGames() {
        var kinds: [DailyChallengeKind: Int] = [:]
        for day in 1...28 {
            var game = player([.blackjack, .slots])
            game.refreshDaily(today: String(format: "2026-11-%02d", day), canWalk: false, at: t0)
            if let kind = game.daily.challenge?.kind { kinds[kind, default: 0] += 1 }
        }
        let blackjackDays = kinds[.blackjack, default: 0] + kinds[.blackjackNatural, default: 0]
        #expect(blackjackDays > 0 && kinds[.slots, default: 0] > 0)
        #expect(kinds[.blackjackNatural, default: 0] > 0)
        // Two games, so about half the days each, whichever Blackjack challenge it is.
        #expect((7...21).contains(blackjackDays))
        #expect(!game(eligibleFor: [.blackjack]).contains(.blackjackNatural))
    }

    func game(eligibleFor games: Set<MiniGame>) -> [DailyChallengeKind] {
        player(games).eligibleChallengeKinds()
    }

    @Test func casinoChallengesAddUpOverTheDay() {
        var blackjack = with(.blackjack, target: 3, games: [.blackjack])
        blackjack.tokens = [.dogecoin: 20]
        blackjack.placeBlackjackBet(.dogecoin, amount: 2)
        blackjack.settleBlackjack([BlackjackResult(outcome: .win, bet: 1, payout: 2), BlackjackResult(outcome: .lose, bet: 1, payout: 0)],
                                  token: .dogecoin)
        blackjack.placeBlackjackBet(.dogecoin, amount: 1)
        blackjack.settleBlackjack([BlackjackResult(outcome: .push, bet: 1, payout: 1)], token: .dogecoin)
        #expect(blackjack.daily.challenge?.progress == 1)
        blackjack.placeBlackjackBet(.dogecoin, amount: 2)
        blackjack.settleBlackjack([BlackjackResult(outcome: .win, bet: 1, payout: 2), BlackjackResult(outcome: .blackjack, bet: 1, payout: 3)],
                                  token: .dogecoin)
        #expect(blackjack.daily.challenge?.isComplete == true)
        #expect(blackjack.stats.challengesCompleted == 1)

        var moon = with(.moon, target: 2, games: [.moon])
        moon.tokens = [.dogecoin: 100]
        var rng = SeededGenerator(seed: 1)
        for _ in 0..<40 where moon.daily.challenge?.isComplete == false {
            moon.launchMoon(.dogecoin, bet: 1, autoCashOut: 2, using: &rng)
            moon.settleMoon(after: 60)
        }
        #expect(moon.daily.challenge?.isComplete == true)
        #expect(moon.daily.challenge?.progress == 2)
    }

    @Test func theArcadeMixNeedsThreeDifferentGames() {
        var game = with(.arcadeMix, target: 3, games: [.tetris, .snake, .merge2048])
        game.finishSnake(score: 10, length: 4)
        game.finishSnake(score: 20, length: 5)
        game.finishTetris(score: 0, lines: 0, rewardPoints: 0) // Scoring nothing doesn't count.
        #expect(game.daily.challenge?.progress == 1)
        game.finishTetris(score: 300, lines: 1, rewardPoints: 300)
        #expect(game.finishMerge2048(score: 16, bestTile: 8).challenge != nil)
        #expect(game.daily.challenge?.gamesScored == [.snake, .tetris, .merge2048])
    }

    @Test func theFifthChallengeOfAWeekPaysTheWeeklyBonus() {
        var game = player([.snake])
        var bonuses: [Double] = []
        // Monday 19 October to Monday 26 October 2026.
        for day in 19...26 {
            game.daily.challenge = DailyChallenge(day: "2026-10-\(day)", kind: .snake, target: 1)
            bonuses.append(game.finishSnake(score: 10, length: 4).challenge?.weeklyBonus ?? -1)
        }
        #expect(bonuses == [0, 0, 0, 0, 72_000, 0, 0, 0]) // Two hours at 10 coins per second, on the fifth.
        #expect(game.challengesCompleted(inWeekOf: "2026-10-26") == 1)
        #expect(game.challengesCompleted(inWeekOf: "2026-10-25") == 0)
        #expect(game.stats.challengesCompleted == 8)
    }

    @Test func luckyStreakDoublesTheReward() {
        var game = with(.tetris, target: 100, games: [.tetris])
        game.perks = [.luckyStreak]
        #expect(game.finishTetris(score: 100, lines: 1, rewardPoints: 100).challenge?.coins == 18_000)
    }

    @Test func weeksStartOnMonday() {
        #expect(StepDay.weekKey(of: "2026-10-26") == "2026-10-26") // A Monday.
        #expect(StepDay.weekKey(of: "2026-10-25") == "2026-10-19") // A Sunday.
        #expect(StepDay.weekKey(of: "2026-10-21") == "2026-10-19")
        #expect(StepDay.weekKey(of: "2027-01-01") == "2026-12-28") // Across the new year.
        #expect(StepDay.weekKey(of: "2024-03-01") == "2024-02-26") // Across a leap day.
        #expect(StepDay.weekKey(of: "not a day") == "not a day")
    }

    @Test func anOlderSavesTetrisChallengeMakesWayForANewOne() throws {
        let json = #"{"streak": 2, "lastRewardDay": "2026-10-25", "challengeDay": "2026-10-25", "challengeBest": 900, "challengeRewarded": true}"#
        let daily = try GameCoding.decoder().decode(DailyProgress.self, from: Data(json.utf8))
        #expect(daily.challenge == nil)
        #expect(daily.streak == 2)
    }

    @Test func everyoneGetsTheSameTetrisPiecesAllDay() {
        #expect(GameState.dailyChallengeSeed(day: "2026-10-24") == GameState.dailyChallengeSeed(day: "2026-10-24"))
        #expect(GameState.dailyChallengeSeed(day: "2026-10-24") != GameState.dailyChallengeSeed(day: "2026-10-25"))
    }
}

@Suite("Income history")
struct IncomeHistoryTests {
    @Test func samplesAreTakenEveryHalfHourForAWeek() {
        var game = GameState.make(miners: [.desktop: 10])
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
