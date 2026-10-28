import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("2048")
struct Merge2048Tests {
    /// The board after a slide, without the tile that appeared after it.
    func settled(_ game: Merge2048Game) -> [[Int]] {
        var rows = Array(repeating: Array(repeating: 0, count: Merge2048Game.size), count: Merge2048Game.size)
        for tile in game.tiles where !tile.isNew { rows[tile.row][tile.column] = tile.value }
        return rows
    }

    func slid(_ rows: [[Int]], _ direction: SlideDirection, seed: UInt64 = 1) -> Merge2048Game {
        var game = Merge2048Game(rows: rows, seed: seed)
        game.slide(direction)
        return game
    }

    @Test func aNewGameStartsWithTwoSmallTiles() {
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            let game = Merge2048Game(using: &rng)
            #expect(game.tiles.count == 2)
            #expect(game.tiles.allSatisfy { $0.value == 2 || $0.value == 4 })
            #expect(Set(game.tiles.map { [$0.row, $0.column] }).count == 2)
            #expect(game.score == 0)
            #expect(!game.isOver)
        }
    }

    @Test func matchingTilesMergeAndScoreTheirSum() {
        let game = slid([[2, 2, 0, 0], [0, 4, 0, 4], [8, 0, 0, 0], [0, 0, 0, 0]], .left)
        #expect(settled(game) == [[4, 0, 0, 0], [8, 0, 0, 0], [8, 0, 0, 0], [0, 0, 0, 0]])
        #expect(game.score == 4 + 8)
        #expect(game.merges == 2)
        #expect(game.moves == 1)
    }

    @Test func aTileMergesOnlyOncePerSlide() {
        let four = slid([[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left)
        #expect(settled(four)[0] == [4, 4, 0, 0])
        #expect(four.score == 8)
        // The new 8 doesn't merge with the 8 already there.
        let chain = slid([[4, 4, 8, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left)
        #expect(settled(chain)[0] == [8, 8, 0, 0])
        #expect(chain.score == 8)
    }

    @Test func tilesNearestTheEdgeMergeFirst() {
        #expect(settled(slid([[2, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left))[0] == [4, 2, 0, 0])
        #expect(settled(slid([[2, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .right))[0] == [0, 0, 2, 4])
    }

    @Test func columnsSlideUpAndDown() {
        let rows = [[2, 0, 0, 0], [2, 0, 0, 4], [0, 0, 0, 4], [4, 0, 0, 2]]
        #expect(settled(slid(rows, .up)) == [[4, 0, 0, 8], [4, 0, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0]])
        #expect(settled(slid(rows, .down)) == [[0, 0, 0, 0], [0, 0, 0, 0], [4, 0, 0, 8], [4, 0, 0, 2]])
    }

    @Test func aMergedTileKeepsTheLeadingTilesID() throws {
        var game = Merge2048Game(rows: [[0, 0, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        let leading = try #require(game.tile(row: 0, column: 3)).id
        game.slide(.right)
        let merged = try #require(game.tile(row: 0, column: 3))
        #expect(merged.id == leading)
        #expect(merged.value == 4)
        #expect(merged.isMerged)
        // The other 2 is gone, last seen where it merged.
        #expect(game.mergedAway.count == 1)
        #expect(game.mergedAway.first.map { [$0.row, $0.column, $0.value] } == [0, 3, 2])
        #expect(!game.tiles.contains { $0.id == game.mergedAway.first?.id })
    }

    @Test func aSlideThatChangesNothingAddsNoTile() {
        var game = Merge2048Game(rows: [[2, 4, 0, 0], [8, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], seed: 5)
        let before = game.tiles
        #expect(game.slide(.left) == false)
        #expect(game.slide(.up) == false)
        #expect(game.tiles == before)
        #expect(game.moves == 0)
        #expect(game.slide(.right) == true)
        #expect(game.tiles.count == 4)
        let new = game.tiles.filter(\.isNew)
        #expect(new.count == 1)
        #expect(new[0].value == 2 || new[0].value == 4)
        #expect(game.moves == 1)
    }

    @Test func theGameEndsWhenNoSlideCanChangeTheBoard() {
        let full = [[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]]
        var game = Merge2048Game(rows: full)
        #expect(game.isOver)
        #expect(!game.canSlide)
        for direction in SlideDirection.allCases { #expect(game.slide(direction) == false) }
        #expect(game.rows == full)
        // A full board with a pair left can still move.
        #expect(!Merge2048Game(rows: [[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 4]]).isOver)
    }

    @Test func makingA2048TileWinsAndPlayCarriesOn() {
        let game = slid([[1_024, 1_024, 0, 0], [2, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], .left)
        #expect(game.hasWon)
        #expect(game.bestTile == 2_048)
        #expect(game.score == 2_048)
        #expect(!game.isOver)
    }

    @Test func randomPlayAlwaysEndsWithAConsistentBoard() {
        for seed in UInt64(1)...30 {
            var rng = SeededGenerator(seed: seed)
            var game = Merge2048Game(using: &rng)
            var slides = 0
            while !game.isOver && slides < 5_000 {
                game.slide(SlideDirection.allCases.randomElement(using: &rng)!)
                slides += 1
                #expect(Set(game.tiles.map { [$0.row, $0.column] }).count == game.tiles.count)
                #expect(Set(game.tiles.map(\.id)).count == game.tiles.count)
            }
            #expect(game.isOver)
            #expect(game.tiles.count == 16)
            // Every point came from a merge, and every value on the board is a power of two.
            #expect(game.score > 0)
            #expect(game.tiles.allSatisfy { $0.value >= 2 && $0.value & ($0.value - 1) == 0 })
        }
    }
}

@Suite("2048 undo, goals and the daily puzzle")
struct Merge2048ModeTests {
    @Test func undoTakesBackTheLastSlideItsPointsAndItsTile() {
        var game = Merge2048Game(rows: [[2, 2, 0, 0], [0, 4, 0, 4], [0, 0, 0, 0], [0, 0, 0, 0]], seed: 9)
        let before = game.tiles
        #expect(!game.canUndo) // Nothing to take back yet.
        let slid = game.slide(.left)
        #expect(slid)
        #expect(game.score == 12)
        #expect(game.canUndo)
        let undone = game.undo()
        #expect(undone)
        #expect(game.tiles == before)
        #expect(game.score == 0)
        #expect(game.moves == 0)
        #expect(game.merges == 0)
        #expect(game.mergedAway.isEmpty)
        #expect(game.undosLeft == Merge2048Game.undosPerGame - 1)
        #expect(game.undosUsed == 1)
        // Only one slide back.
        #expect(!game.canUndo)
        let again = game.undo()
        #expect(!again)
    }

    @Test func undoingThenSlidingTheSameWayBringsTheSameTile() throws {
        var game = Merge2048Game(seed: 42)
        game.slide(.left)
        let direction = try #require(SlideDirection.allCases.first { direction in
            var copy = game
            return copy.slide(direction)
        })
        game.slide(direction)
        let first = game.tiles.filter(\.isNew)
        let score = game.score
        let undone = game.undo()
        let slid = game.slide(direction)
        #expect(undone && slid)
        #expect(game.tiles.filter(\.isNew).map { [$0.row, $0.column, $0.value] } == first.map { [$0.row, $0.column, $0.value] })
        #expect(game.score == score)
    }

    @Test func undosRunOut() {
        var game = Merge2048Game(seed: 7)
        var used = 0
        for _ in 0..<10 {
            guard SlideDirection.allCases.contains(where: { game.slide($0) }) else { break }
            if game.undo() { used += 1 }
        }
        #expect(used == Merge2048Game.undosPerGame)
        #expect(game.undosLeft == 0)
        #expect(!game.canUndo)
    }

    @Test func nothingMovesOrUndoesOnceTheGameIsOver() {
        // Sliding right leaves one empty corner; whatever lands there, nothing can merge.
        var game = Merge2048Game(rows: [[2, 4, 2, 4], [4, 2, 4, 2], [64, 4, 2, 4], [8, 16, 32, 0]], seed: 3)
        #expect(!game.isOver)
        let slid = game.slide(.right)
        #expect(slid)
        #expect(game.isOver)
        #expect(!game.canUndo)
        let undone = game.undo()
        #expect(!undone)
        let board = game.rows
        let score = game.score
        for direction in SlideDirection.allCases { #expect(game.slide(direction) == false) }
        #expect(game.rows == board)
        #expect(game.score == score)
    }

    @Test func goalsClimbTileByTile() {
        #expect(Merge2048Game(rows: [[2, 0, 0, 0]]).nextGoal == 128)
        #expect(Merge2048Game(rows: [[128, 0, 0, 0]]).nextGoal == 256)
        #expect(Merge2048Game(rows: [[512, 64, 0, 0]]).nextGoal == 1_024)
        #expect(Merge2048Game(rows: [[2_048, 0, 0, 0]]).nextGoal == 4_096)
        #expect(Merge2048Game.goalTiles == Merge2048Game.goalTiles.sorted())
    }

    @Test func theDailyPuzzleIsTheSameForEveryoneThatDay() {
        let first = Merge2048Game.daily(day: "2026-10-28")
        let second = Merge2048Game.daily(day: "2026-10-28")
        #expect(first.rows == second.rows)
        #expect(first.isDaily)
        #expect(first.day == "2026-10-28")
        #expect(first.moveLimit == Merge2048Game.dailyMoves)
        #expect(first.movesLeft == Merge2048Game.dailyMoves)
        // The same slides bring the same tiles.
        var a = first, b = second
        for direction in [SlideDirection.left, .down, .right, .down, .left, .up] {
            a.slide(direction)
            b.slide(direction)
        }
        #expect(a.rows == b.rows)
        #expect(a.score == b.score)
        // Other days start differently.
        let days = (1...9).map { Merge2048Game.daily(day: "2026-11-0\($0)").rows }
        #expect(Set(days.map { $0.description }).count > 5)
        #expect(Merge2048Game(seed: 1).moveLimit == nil)
        #expect(Merge2048Game(seed: 1).day == nil)
    }

    @Test func theDailyPuzzleEndsWhenItsMovesRunOut() {
        var game = Merge2048Game.daily(day: "2026-10-29")
        var order = SlideDirection.allCases.makeIterator()
        var guardCount = 0
        while !game.isOver && guardCount < 10_000 {
            guardCount += 1
            if let direction = order.next() {
                game.slide(direction)
            } else {
                order = SlideDirection.allCases.makeIterator()
            }
        }
        #expect(game.isOver)
        #expect(game.moves <= Merge2048Game.dailyMoves)
        if game.canSlide { #expect(game.movesLeft == 0) }
        for direction in SlideDirection.allCases { #expect(game.slide(direction) == false) }
    }

    @Test func dailyStarsFollowTheScore() {
        let scores = Merge2048Game.dailyStarScores
        #expect(Merge2048Game.dailyStars(score: 0) == 0)
        #expect(Merge2048Game.dailyStars(score: scores[0] - 1) == 0)
        #expect(Merge2048Game.dailyStars(score: scores[0]) == 1)
        #expect(Merge2048Game.dailyStars(score: scores[1]) == 2)
        #expect(Merge2048Game.dailyStars(score: scores[2] + 5_000) == 3)
    }
}

@Suite("2048 rewards")
struct Merge2048RewardTests {
    @Test func scoresPayLikeTheOtherArcadeGames() {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        let first = game.finishMerge2048(score: 2_000, bestTile: 256)
        #expect(first == ArcadePayout(coins: 1_650, isNewBest: true)) // 2,000 × 0.055 × 10 × 1.5
        #expect(game.stats.merge2048Games == 1)
        #expect(game.stats.merge2048BestScore == 2_000)
        #expect(game.stats.merge2048BestTile == 256)
        #expect(game.stats.merge2048Points == 2_000)
        #expect(game.merge2048Reward(score: 1_000, bestTile: 128) == 550) // Not a new best.
        let second = game.finishMerge2048(score: 1_000, bestTile: 128)
        #expect(second.coins == 550)
        #expect(game.stats.merge2048BestTile == 256)
        #expect(game.stats.merge2048Points == 3_000)
        #expect(game.coins == 2_200)
        #expect(game.stats.earnedFromGames == 2_200)
    }

    @Test func makingA2048TilePaysTenMinutesMore() {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        #expect(game.merge2048TileBonus == 6_000)
        #expect(game.merge2048Reward(score: 20_000, bestTile: 1_024) == 16_500)
        #expect(game.merge2048Reward(score: 20_000, bestTile: 2_048) == 22_500)
        let payout = game.finishMerge2048(score: 20_000, bestTile: 2_048)
        #expect(payout.tileBonus == 6_000)
        #expect(payout.coins == 16_500 + 6_000)
        #expect(game.coins == 22_500)
        #expect(game.stats.merge2048BestTile == 2_048)
    }

    @Test func aGameLeftOpenIsPaidWithItsBestTile() {
        var game = GameState.make(miners: [.desktop: 5])
        game.holdArcadeRun(ArcadeRun(game: .merge2048, score: 400, detail: 64))
        let paid = game.payUnfinishedRun()
        #expect(paid?.payout.coins == 330) // 400 × 0.055 × 10 × 1.5
        #expect(game.stats.merge2048BestTile == 64)
        #expect(game.unfinishedRun == nil)
    }

    @Test func bigTilesEarnTheMergeMasterAchievement() throws {
        var game = GameState.make()
        let achievement = try #require(AchievementCatalog.all.first { $0.id == "merge-master" })
        game.finishMerge2048(score: 3_000, bestTile: 512)
        let earned = game.refreshAchievements().filter { $0.achievement.id == "merge-master" }
        #expect(earned.map(\.tier) == [0, 1]) // 128 and 512.
        #expect(game.tiersEarned(achievement) == 2)
    }

    @Test func dailyStarsPayOnceADay() {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        let star = game.merge2048DailyStarReward
        #expect(star == 2_000) // 200 seconds.
        let scores = Merge2048Game.dailyStarScores
        // Two stars: the points (no new-best bonus) and two stars.
        let first = game.finishMerge2048Daily(day: "2026-10-28", score: scores[1], bestTile: 128)
        let points = game.arcadeReward(.merge2048, score: scores[1])
        #expect(first.stars == 2)
        #expect(first.newStars == 2)
        #expect(first.starCoins == 2 * star)
        #expect(first.payout.coins == points + 2 * star)
        #expect(!first.payout.isNewBest)
        #expect(game.stats.merge2048BestScore == 0) // The daily keeps out of the Classic best.
        #expect(game.merge2048Daily.stars(on: "2026-10-28") == 2)
        #expect(game.merge2048Daily.wins == 1)
        // Replaying for two stars pays only the points; a third star pays one more.
        let again = game.finishMerge2048Daily(day: "2026-10-28", score: scores[1] + 10, bestTile: 128)
        #expect(again.newStars == 0)
        #expect(again.starCoins == 0)
        let third = game.finishMerge2048Daily(day: "2026-10-28", score: scores[2], bestTile: 256)
        #expect(third.newStars == 1)
        #expect(third.starCoins == star)
        #expect(game.merge2048Daily.stars(on: "2026-10-28") == 3)
        #expect(game.merge2048Daily.bestScore(on: "2026-10-28") == scores[2])
        #expect(game.merge2048Daily.totalStars == 3)
        #expect(game.merge2048Daily.wins == 1)
        // A new day starts over.
        #expect(game.merge2048Daily.stars(on: "2026-10-29") == 0)
        let next = game.finishMerge2048Daily(day: "2026-10-29", score: scores[0], bestTile: 128)
        #expect(next.newStars == 1)
        #expect(game.merge2048Daily.wins == 2)
        #expect(game.merge2048Daily.totalStars == 4)
        #expect(game.stats.merge2048Games == 4)
    }

    @Test func aDailyPuzzleLeftOpenPaysItsPointsOnly() {
        var game = GameState.make(miners: [.desktop: 5])
        game.holdArcadeRun(ArcadeRun(game: .merge2048, score: 2_000, detail: 256, stage: ArcadeRun.dailyStage))
        let paid = game.payUnfinishedRun()
        #expect(paid?.payout.coins == game.arcadeReward(.merge2048, score: 2_000))
        #expect(game.merge2048Daily.totalStars == 0)
        #expect(game.stats.merge2048BestScore == 0)
    }

    @Test func dailyProgressSurvivesASave() throws {
        var game = GameState.make()
        game.finishMerge2048Daily(day: "2026-10-28", score: Merge2048Game.dailyStarScores[2], bestTile: 256)
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(game))
        #expect(decoded.merge2048Daily == game.merge2048Daily)
        #expect(decoded.merge2048Daily.stars(on: "2026-10-28") == 3)
        // Older saves have none.
        let fresh = try JSONDecoder().decode(Merge2048DailyProgress.self, from: Data("{}".utf8))
        #expect(fresh == Merge2048DailyProgress())
    }

    @Test func the2048QuestNeedsTheGameUnlocked() {
        var game = GameState.make()
        #expect(!game.eligibleQuestKinds(canWalk: false).contains(.score2048))
        game.unlockedGames.insert(.merge2048)
        #expect(game.eligibleQuestKinds(canWalk: false).contains(.score2048))
        let quest = Quest(kind: .score2048, target: 2_000, baseline: game.questMetric(.score2048), reward: .coins(seconds: 600))
        game.finishMerge2048(score: 1_500, bestTile: 128)
        #expect(!game.isComplete(quest))
        game.finishMerge2048(score: 700, bestTile: 64)
        #expect(game.isComplete(quest))
    }
}
