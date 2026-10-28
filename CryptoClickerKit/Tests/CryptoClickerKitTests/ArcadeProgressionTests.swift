import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Arcade Rank")
struct ArcadeProgressionTests {
    let monday = "2026-10-26"

    func player(_ games: Set<MiniGame> = Set(MiniGame.allCases)) -> GameState {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        game.unlockedGames = games
        return game
    }

    /// Runs `action` the way the app does: snapshot, play, award.
    @discardableResult
    func play(_ game: inout GameState, on day: String, _ action: (inout GameState) -> Void) -> ArcadeAward? {
        let before = game.arcadeSnapshot
        action(&game)
        return game.awardArcadeProgress(since: before, today: day)
    }

    @Test func ranksNeedAHundredMoreXPEachTime() {
        #expect(ArcadeRank.xpNeeded(forRank: 1) == 0)
        #expect(ArcadeRank.xpNeeded(forRank: 2) == 100)
        #expect(ArcadeRank.xpNeeded(forRank: 3) == 300)
        #expect(ArcadeRank.xpNeeded(forRank: 10) == 4_500)
        #expect(ArcadeRank.rank(forXP: 0) == 1)
        #expect(ArcadeRank.rank(forXP: 99) == 1)
        #expect(ArcadeRank.rank(forXP: 100) == 2)
        #expect(ArcadeRank.rank(forXP: 299) == 2)
        #expect(ArcadeRank.rank(forXP: 300) == 3)
        #expect(ArcadeRank.rank(forXP: 4_500) == 10)
        for xp in stride(from: 0, through: 200_000, by: 37) {
            let rank = ArcadeRank.rank(forXP: xp)
            #expect(ArcadeRank.xpNeeded(forRank: rank) <= xp && xp < ArcadeRank.xpNeeded(forRank: rank + 1))
        }
        #expect(ArcadeRank.rank(forXP: Int.max) > 1)
        #expect(ArcadeRank.title(forRank: 1) == "Rookie")
        #expect(ArcadeRank.title(forRank: 10) == "Pro")
        #expect(ArcadeRank.title(forRank: 40) == "Legend")
    }

    @Test func aFinishedGameEarnsXPWithMoreForABestAndTheFirstOfTheDay() throws {
        var game = player()
        // The first Snake game today, and a best score: 10 + 20 + 15.
        let first = try #require(play(&game, on: monday) { $0.finishSnake(score: 200, length: 23) })
        #expect(first.xp == 45)
        // Another, below the best: just the game.
        let second = try #require(play(&game, on: monday) { $0.finishSnake(score: 100, length: 13) })
        #expect(second.xp == 10)
        // The next day, the first game of the day counts again.
        let tuesday = try #require(play(&game, on: "2026-10-27") { $0.finishSnake(score: 50, length: 8) })
        #expect(tuesday.xp == 25)
        #expect(game.arcade.xp == 80)
        // Nothing played, nothing awarded.
        #expect(play(&game, on: monday) { _ in } == nil)
    }

    @Test func aFasterSprintCountsAsABest() throws {
        var game = player()
        let first = try #require(play(&game, on: monday) {
            $0.finishTetris(score: 900, lines: 40, rewardPoints: 900, sprintTime: 90)
        })
        #expect(first.xp == 10 + 20 + 15)
        let faster = try #require(play(&game, on: monday) {
            $0.finishTetris(score: 900, lines: 40, rewardPoints: 900, sprintTime: 80)
        })
        #expect(faster.xp == 10 + 20)
    }

    @Test func casinoRoundsGiveALittleXPUpToADailyCap() {
        var game = player()
        game.tokens = [.shibaInu: 1_000]
        var rng = SeededGenerator(seed: 4)
        var total = 0
        for _ in 0..<100 {
            total += play(&game, on: monday) { $0.spinSlots(.shibaInu, bet: 1, using: &rng) }?.xp ?? 0
        }
        // 15 for the first game of the day, then 2 a spin up to the cap.
        #expect(total == Tuning.arcadeXPFirstPlayToday + Tuning.arcadeCasinoXPPerDay)
        let tomorrow = play(&game, on: "2026-10-27") { $0.spinSlots(.shibaInu, bet: 1, using: &rng) }
        #expect(tomorrow?.xp == Tuning.arcadeXPFirstPlayToday + Tuning.arcadeXPPerCasinoRound)
    }

    @Test func challengesAndStarsGiveXP() throws {
        var game = player()
        game.daily.challenge = DailyChallenge(day: monday, kind: .snake, target: 5)
        let award = try #require(play(&game, on: monday) { $0.finishSnake(score: 60, length: 9) })
        #expect(award.xp == 45 + Tuning.arcadeXPChallenge)
        let stars = try #require(play(&game, on: monday) {
            $0.finishMerge2048Daily(day: monday, score: Merge2048Game.dailyStarScores[1], bestTile: 128)
        })
        // A 2048 game (not a best: the daily keeps out of it), the first today, and two stars.
        #expect(stars.xp == 10 + 15 + 2 * Tuning.arcadeXPPerStar)
    }

    @Test func gameAchievementTiersGiveXP() {
        var game = player()
        game.stats.bubblesPopped = 100
        game.stats.taps = 100 // Tapper: not a game achievement.
        let earned = game.refreshAchievements()
        #expect(earned.contains { $0.achievement.id == "bubble-popper" })
        #expect(earned.contains { $0.achievement.id == "tapper" })
        #expect(game.arcade.xp == Tuning.arcadeXPPerAchievementTier)
        #expect(AchievementCatalog.arcadeIDs.contains("sprinter"))
        #expect(!AchievementCatalog.arcadeIDs.contains("exchanger"))
    }

    @Test func playingSixDifferentGamesInAWeekPaysOnce() throws {
        var game = player()
        game.tokens = [.shibaInu: 100]
        var rng = SeededGenerator(seed: 9)
        let days = ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30"]
        var paid: [Double] = []
        func finish(_ index: Int, _ day: String) {
            let award = play(&game, on: day) { state in
                switch index {
                case 0: state.finishSnake(score: 10, length: 4)
                case 1: state.finishTetris(score: 100, lines: 1, rewardPoints: 100)
                case 2: state.finishBrickBreaker(score: 50, bricks: 5, level: 1)
                case 3: state.finishBubbleBlaster(score: 30, popped: 3, bestShot: 3)
                case 4: _ = state.spinSlots(.shibaInu, bet: 1, using: &rng)
                default: state.finishMerge2048(score: 40, bestTile: 16)
                }
            }
            paid.append(award?.weeklyReward ?? 0)
        }
        for index in 0..<5 { finish(index, days[index]) }
        #expect(game.gamesPlayed(inWeekOf: monday).count == 5)
        #expect(paid.allSatisfy { $0 == 0 })
        finish(5, "2026-10-30")
        #expect(paid.last == game.weeklyVarietyReward)
        #expect(game.weeklyVarietyReward == 18_000) // 30 minutes.
        #expect(game.isWeeklyGoalPaid(inWeekOf: "2026-11-01"))
        #expect(game.arcade.weeklyGoals == 1)
        // More games that week pay nothing more.
        finish(0, "2026-11-01")
        #expect(paid.last == 0)
        // The next week starts over.
        finish(0, "2026-11-02")
        #expect(game.gamesPlayed(inWeekOf: "2026-11-02") == [.snake])
        #expect(!game.isWeeklyGoalPaid(inWeekOf: "2026-11-02"))
    }

    @Test func cosmeticsUnlockByRankAndAchievement() {
        var game = player()
        #expect(game.equipped(.cardBack) == .cardBackClassic)
        #expect(game.isUnlocked(.cardBackClassic))
        #expect(!game.isUnlocked(.cardBackMidnight))
        let locked = game.equip(.cardBackMidnight)
        #expect(!locked)
        #expect(game.equipped(.cardBack) == .cardBackClassic)
        game.arcade.xp = ArcadeRank.xpNeeded(forRank: 3)
        #expect(game.isUnlocked(.cardBackMidnight))
        let equipped = game.equip(.cardBackMidnight)
        #expect(equipped)
        #expect(game.equipped(.cardBack) == .cardBackMidnight)
        // An achievement tier unlocks one too.
        #expect(!game.isUnlocked(.reelsNeon))
        game.stats.slotsWins = 10
        game.refreshAchievements()
        #expect(game.isUnlocked(.reelsNeon))
        #expect(game.unlockText(.cardBackGold) == "Card Shark · Silver")
        #expect(game.unlockText(.reelsGold) == "Arcade Rank 10")
        // Going back to the default clears the pick.
        game.equip(.cardBackClassic)
        #expect(game.arcade.equipped[.cardBack] == nil)
    }

    @Test func everySlotHasAFreeDefaultAndEveryUnlockIsReal() {
        for slot in CosmeticSlot.allCases {
            let looks = Cosmetic.all(in: slot)
            #expect(looks.first == slot.standard)
            #expect(slot.standard.unlock == .free)
            #expect(looks.count >= 3)
        }
        let ids = Set(AchievementCatalog.all.map(\.id))
        for cosmetic in Cosmetic.allCases {
            if case .achievement(let id, let tier) = cosmetic.unlock {
                #expect(ids.contains(id), "\(cosmetic) needs \(id)")
                #expect((0...3).contains(tier))
            }
        }
        #expect(Cosmetic.unlocked(atRank: 3) == [.cardBackMidnight])
    }

    @Test func progressSurvivesASaveAndOldSavesStartFresh() throws {
        var game = player()
        game.arcade.xp = 1_234
        game.arcade.equipped = [.snake: .snakeGold, .reels: .reelsNeon]
        game.arcade.week = "2026-10-26"
        game.arcade.gamesThisWeek = [.snake, .slots]
        let decoded = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(decoded.arcade == game.arcade)
        let fresh = try JSONDecoder().decode(ArcadeProgress.self, from: Data("{}".utf8))
        #expect(fresh == ArcadeProgress())
        // A cosmetic saved in the wrong slot, or one a later version renamed, falls back.
        let odd = try JSONDecoder().decode(ArcadeProgress.self, from: Data(#"{"equipped": {"snake": "reelsNeon", "reels": "laser"}}"#.utf8))
        #expect(odd.equipped.isEmpty)
    }

    @Test func newQuestsCountLevelsRoundsAndGoals() {
        var game = player()
        #expect(game.eligibleQuestKinds(canWalk: false).contains(.winTokenSwapLevels))
        #expect(QuestKind.winTokenSwapLevels.title(target: 1) == "Win a Token Swap level")
        #expect(QuestKind.clearPumpRounds.title(target: 5) == "Clear 5 rounds in Pump and Dump")
        let levels = Quest(kind: .winTokenSwapLevels, target: 2, baseline: game.questMetric(.winTokenSwapLevels), reward: .coins(seconds: 600))
        let level = TokenSwapLevel.all[0]
        game.finishTokenSwapLevel(level, won: true, score: 5_000, tokens: 40, bestChain: 2, specials: 0)
        game.finishTokenSwapLevel(level, won: false, score: 500, tokens: 10, bestChain: 1, specials: 0)
        #expect(!game.isComplete(levels))
        game.finishTokenSwapDaily(day: monday, won: true, tokens: 30, bestChain: 2, specials: 1)
        #expect(game.isComplete(levels))
        game.finishPumpDump(score: 900, coinsHit: 40, bestCombo: 9, rounds: 4)
        #expect(game.stats.pumpDumpRoundsCleared == 3)
        game.finishMerge2048(score: 3_000, bestTile: 512)
        #expect(game.stats.merge2048Goals == 3)
        #expect(Merge2048Game.goalsReached(bestTile: 64) == 0)
    }

    @Test func aSaveFromBeforeArcadeRankStartsWithXPForPastPlay() throws {
        var veteran = player()
        veteran.finishSnake(score: 100, length: 13)
        veteran.finishTetris(score: 900, lines: 8, rewardPoints: 900)
        veteran.stats.challengesCompleted = 2
        veteran.achievementTiers = ["bubble-popper": 2, "tapper": 4]
        var json = try JSONSerialization.jsonObject(with: GameCoding.encoder().encode(veteran)) as? [String: Any] ?? [:]
        json["arcade"] = nil // As saved by the version before.
        let old = try GameCoding.decoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        // Two games, two game achievement tiers (Tapper isn't one) and two challenges.
        #expect(old.arcade.xp == 2 * 10 + 2 * 25 + 2 * 50)
        #expect(old.arcadeRank == 2)
        // A save that has Arcade Rank keeps what it has.
        var current = veteran
        current.arcade.xp = 7
        let kept = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(current))
        #expect(kept.arcade.xp == 7)
    }
}

