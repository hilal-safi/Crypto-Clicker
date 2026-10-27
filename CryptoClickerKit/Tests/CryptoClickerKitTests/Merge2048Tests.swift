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
        var game = Merge2048Game(rows: rows)
        var rng = SeededGenerator(seed: seed)
        game.slide(direction, using: &rng)
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
        var rng = SeededGenerator(seed: 3)
        game.slide(.right, using: &rng)
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
        var game = Merge2048Game(rows: [[2, 4, 0, 0], [8, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        var rng = SeededGenerator(seed: 5)
        let before = game.tiles
        #expect(game.slide(.left, using: &rng) == false)
        #expect(game.slide(.up, using: &rng) == false)
        #expect(game.tiles == before)
        #expect(game.moves == 0)
        #expect(game.slide(.right, using: &rng) == true)
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
        var rng = SeededGenerator(seed: 7)
        for direction in SlideDirection.allCases { #expect(game.slide(direction, using: &rng) == false) }
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
                game.slide(SlideDirection.allCases.randomElement(using: &rng)!, using: &rng)
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

@Suite("2048 rewards")
struct Merge2048RewardTests {
    @Test func scoresPayLikeTheOtherArcadeGames() {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        let first = game.finishMerge2048(score: 2_000, bestTile: 256)
        #expect(first == ArcadePayout(coins: 1_200, isNewBest: true, isChallengeBonus: false)) // 2,000 × 0.04 × 10 × 1.5
        #expect(game.stats.merge2048Games == 1)
        #expect(game.stats.merge2048BestScore == 2_000)
        #expect(game.stats.merge2048BestTile == 256)
        #expect(game.stats.merge2048Points == 2_000)
        #expect(game.merge2048Reward(score: 1_000, bestTile: 128) == 400) // Not a new best.
        let second = game.finishMerge2048(score: 1_000, bestTile: 128)
        #expect(second.coins == 400)
        #expect(game.stats.merge2048BestTile == 256)
        #expect(game.stats.merge2048Points == 3_000)
        #expect(game.coins == 1_600)
        #expect(game.stats.earnedFromGames == 1_600)
    }

    @Test func makingA2048TilePaysTenMinutesMore() {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        #expect(game.merge2048TileBonus == 6_000)
        #expect(game.merge2048Reward(score: 20_000, bestTile: 1_024) == 12_000)
        #expect(game.merge2048Reward(score: 20_000, bestTile: 2_048) == 18_000)
        let payout = game.finishMerge2048(score: 20_000, bestTile: 2_048)
        #expect(payout.tileBonus == 6_000)
        #expect(payout.coins == 12_000 + 6_000)
        #expect(game.coins == 18_000)
        #expect(game.stats.merge2048BestTile == 2_048)
    }

    @Test func aGameLeftOpenIsPaidWithItsBestTile() {
        var game = GameState.make(miners: [.desktop: 5])
        game.holdArcadeRun(ArcadeRun(game: .merge2048, score: 500, detail: 64))
        let paid = game.payUnfinishedRun()
        #expect(paid?.payout.coins == 300)
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
