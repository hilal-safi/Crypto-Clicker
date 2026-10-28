import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Bubble Blaster")
struct BubbleShooterTests {
    typealias Game = BubbleShooterGame

    func game(_ rows: [[Int]], shifted: Bool = false, current: Int = 1, next: Int = 1) -> (Game, SeededGenerator) {
        var rng = SeededGenerator(seed: 5)
        var game = Game(using: &rng)
        game.load(rows: rows, topRowShifted: shifted, current: current, next: next)
        return (game, rng)
    }

    func index(_ row: Int, _ column: Int) -> Int { row * Game.columns + column }

    /// The aim angle from the launcher to a point.
    func angle(to target: Vector2) -> Double {
        atan2(Game.launcher.y - target.y, target.x - Game.launcher.x)
    }

    func fly(_ game: inout Game, _ rng: inout SeededGenerator) {
        var frames = 0
        while game.shot != nil && frames < 1_000 {
            game.update(by: 1.0 / 60, using: &rng)
            frames += 1
        }
    }

    @Test func aNewGameStartsWithFiveRowsInFourColors() {
        var rng = SeededGenerator(seed: 1)
        let game = Game(using: &rng)
        for row in 0..<Game.deadRow + 1 {
            for column in 0..<Game.columns where game.isValid(row: row, column: column) {
                let color = game.color(row: row, column: column)
                if row < 5 {
                    #expect(color.map { (1...4).contains($0) } == true)
                } else {
                    #expect(color == nil)
                }
            }
        }
        #expect(game.colorCount == 4)
        #expect((1...4).contains(game.current))
        #expect((1...4).contains(game.next))
    }

    @Test func rowsAlternateBetweenEightAndSevenBubbles() {
        let (game, _) = game([])
        #expect(!game.isShifted(row: 0))
        #expect(game.isShifted(row: 1))
        #expect(game.isValid(row: 0, column: 7))
        #expect(!game.isValid(row: 1, column: 7))
        #expect(game.center(row: 0, column: 0) == Vector2(x: 0.5, y: 0.5))
        #expect(approx(game.center(row: 1, column: 0).x, 1))
        #expect(approx(game.center(row: 1, column: 0).y, 0.5 + Game.rowHeight))
    }

    @Test func neighborsAreExactlyOneBubbleApart() {
        let (game, _) = game([])
        for row in 0...Game.deadRow {
            for column in 0..<Game.columns where game.isValid(row: row, column: column) {
                let cell = index(row, column)
                let neighbors = game.neighbors(of: cell)
                #expect(neighbors.count <= 6)
                for neighbor in neighbors {
                    #expect(approx(game.center(of: cell).distance(to: game.center(of: neighbor)), 1))
                }
            }
        }
        #expect(game.neighbors(of: index(2, 3)).count == 6)
        #expect(game.neighbors(of: index(3, 3)).count == 6)
    }

    @Test func threeOfAColorPop() {
        var (game, rng) = game([[1, 1, 0, 2, 2, 3, 3, 4]], current: 1, next: 2)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        #expect(game.shot != nil)
        fly(&game, &rng)
        #expect(game.color(row: 0, column: 0) == nil)
        #expect(game.color(row: 0, column: 1) == nil)
        #expect(game.color(row: 0, column: 2) == nil)
        #expect(game.color(row: 0, column: 3) == 2)
        #expect(game.score == 30)
        #expect(game.popped == 3)
        #expect(game.clears == 1)
        #expect(game.lastCleared.count == 3)
        #expect(game.misses == 0)
    }

    @Test func twoOfAColorStickAndCountAsAMiss() {
        var (game, rng) = game([[1, 0, 2, 2, 3, 3, 4, 4]], current: 1, next: 2)
        game.fire(angle: angle(to: game.center(row: 0, column: 1)), using: &rng)
        fly(&game, &rng)
        #expect(game.color(row: 0, column: 1) == 1)
        #expect(game.score == 0)
        #expect(game.misses == 1)
    }

    @Test func bubblesCutOffFromTheTopFallForDoublePoints() {
        // The 2 in row 1 hangs only from the two 1s above it.
        var (game, rng) = game([[1, 1, 0, 0, 0, 0, 0, 4], [2]], current: 1, next: 4)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.color(row: 1, column: 0) == nil)
        #expect(game.color(row: 0, column: 7) == 4)
        #expect(game.score == 3 * 10 + 20)
        #expect(game.popped == 4)
        #expect(game.lastCleared.filter(\.dropped).count == 1)
    }

    @Test func everySixthMissPushesANewRow() {
        var (game, rng) = game([[1, 2, 3, 4, 1, 2, 3, 4]], current: 2, next: 2)
        game.misses = Game.missesPerRow - 1
        game.fire(angle: .pi / 2, using: &rng)
        fly(&game, &rng)
        #expect(game.misses == 0)
        #expect(game.topRowShifted)
        // The old top row moved down a row, and a full new row of seven arrived above it.
        #expect((0..<8).map { game.color(row: 1, column: $0) } == [1, 2, 3, 4, 1, 2, 3, 4])
        #expect((0..<7).allSatisfy { game.color(row: 0, column: $0) != nil })
        #expect(game.color(row: 2, column: 3) == 2) // The shot moved down with it.
    }

    @Test func aBubblePushedIntoTheBottomRowEndsTheGame() {
        // A chain down the left edge reaches row 10; the next new row pushes it into row 11.
        let chain = (0...10).map { row in [row % 2 == 0 ? 1 : 2] }
        var (game, rng) = game(chain, current: 3, next: 3)
        game.misses = Game.missesPerRow - 1
        game.fire(angle: 1.25, using: &rng) // Up and to the right, well away from the chain.
        fly(&game, &rng)
        #expect(game.isOver)
        #expect(game.color(row: Game.deadRow, column: 0) != nil)
        game.fire(angle: .pi / 2, using: &rng)
        #expect(game.shot == nil)
    }

    @Test func clearingTheFieldStartsTheNextWave() {
        var (game, rng) = game([[1, 1]], current: 1, next: 1)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.wave == 2)
        #expect(game.colorCount == 5)
        #expect(game.score == 30 + 500)
        #expect((0..<5).allSatisfy { row in game.color(row: row, column: 0) != nil })
        #expect(game.color(row: 5, column: 0) == nil)
    }

    @Test func theLauncherOnlyLoadsColorsStillInPlay() {
        var (game, rng) = game([[1, 1, 0, 2, 2, 0, 3, 3]], current: 1, next: 1)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.color(row: 0, column: 0) == nil)
        #expect([2, 3].contains(game.current))
        #expect([2, 3].contains(game.next))
    }

    @Test func swappingExchangesTheLoadedBubbles() {
        var (game, _) = game([[1, 2]], current: 1, next: 2)
        game.swapBubbles()
        #expect(game.current == 2)
        #expect(game.next == 1)
    }

    @Test func shotsLandWhereTheGuideSaysAtAnyFrameRate() throws {
        // A field of one color; the shots are another, so nothing ever pops.
        let rows = (0..<5).map { row in Array(repeating: 1, count: row % 2 == 0 ? 8 : 7) }
        for (index, angle) in stride(from: 0.25, through: Double.pi - 0.25, by: 0.07).enumerated() {
            var (game, rng) = game(rows, current: 2, next: 2)
            let guide = game.trajectory(angle: angle, maxBounces: 20)
            let end = try #require(guide.last)
            let expected = try #require(game.snapCell(near: end))
            game.fire(angle: angle, using: &rng)
            let frame = [1.0 / 30, 1.0 / 60, 1.0 / 120, 0.023][index % 4]
            var frames = 0
            while game.shot != nil && frames < 2_000 {
                game.update(by: frame, using: &rng)
                frames += 1
            }
            #expect(game.cells[expected] == 2, "angle \(angle)")
        }
    }

    @Test func theAimGuideBouncesOffTheWalls() throws {
        let (game, _) = game([[1, 2, 3, 4, 1, 2, 3, 4]])
        let path = game.trajectory(angle: .pi * 0.75)
        #expect(path.first == Game.launcher)
        #expect(path.count >= 3)
        #expect(path.allSatisfy { $0.x >= 0.5 - 1e-9 && $0.x <= Game.width - 0.5 + 1e-9 })
        let end = try #require(path.last)
        #expect(end.y < 2) // It reaches the top rows.
    }

    @Test func popsInARowScoreMoreEachTime() {
        var (game, rng) = game([[1, 1, 0, 2, 2, 0, 3, 3]], current: 1, next: 2)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.score == 30)
        #expect(game.streak == 1)
        #expect(game.nextMultiplierTenths == 11)
        // The 2 lands where the 1s were, next to the two 2s: 30 points, plus 10%.
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.color(row: 0, column: 3) == nil)
        #expect(game.score == 30 + 33)
        #expect(game.streak == 2)
        #expect(game.bestStreak == 2)
    }

    @Test func theStreakBonusStopsAtDouble() {
        var (game, rng) = game([[1, 1, 0, 2, 2, 0, 3, 3]], current: 1, next: 2)
        game.set(streak: 25)
        #expect(game.nextMultiplierTenths == 20)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.score == 60)
    }

    @Test func aMissEndsTheStreak() {
        var (game, rng) = game([[1, 0, 2, 2, 3, 3, 4, 4]], current: 1, next: 2)
        game.set(streak: 4)
        game.fire(angle: angle(to: game.center(row: 0, column: 1)), using: &rng)
        fly(&game, &rng)
        #expect(game.streak == 0)
        #expect(game.nextMultiplierTenths == 10)
        #expect(game.misses == 1)
    }

    @Test func everyThirdPopInARowEarnsASpecialRainbowFirst() {
        var (game, rng) = game([[1, 1, 0, 2, 2, 0, 3, 3]], current: 1, next: 2)
        game.set(streak: 2)
        #expect(game.shotsToSpecial == 1)
        #expect(game.nextSpecialEarned == .rainbow)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.streak == 3)
        #expect(game.nextSpecial == .rainbow)
        #expect(game.currentSpecial == nil)
        #expect(game.lastEarned == .rainbow)
        #expect(game.specialsEarned == 1)
        #expect(game.nextSpecialEarned == .bomb)
        #expect(game.shotsToSpecial == 3)
    }

    @Test func theSixthPopInARowEarnsABombBesideAWaitingSpecial() {
        var (game, rng) = game([[1, 1, 0, 2, 2, 0, 3, 3]], current: 1, next: 2)
        game.load(special: nil, next: .rainbow)
        game.set(streak: 5)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        // Firing moved the waiting Rainbow into the launcher.
        #expect(game.currentSpecial == .rainbow)
        fly(&game, &rng)
        #expect(game.streak == 6)
        #expect(game.currentSpecial == .rainbow)
        #expect(game.nextSpecial == .bomb)
        #expect(game.lastEarned == .bomb)
    }

    @Test func specialsSwapAndFireLikeAnyBubble() throws {
        var (game, rng) = game([[1, 2, 3, 4, 1, 2, 3, 4]], current: 1, next: 2)
        game.load(special: .bomb)
        game.swapBubbles()
        #expect(game.currentSpecial == nil)
        #expect(game.nextSpecial == .bomb)
        #expect(game.current == 2)
        game.swapBubbles()
        game.fire(angle: .pi / 2, using: &rng)
        let shot = try #require(game.shot)
        #expect(shot.special == .bomb)
        #expect(game.currentSpecial == nil)
        #expect(game.current == 2)
    }

    @Test func aRainbowTakesTheColorThatMakesTheBiggestGroup() {
        // Touching two 1s on one side and three 2s on the other, it turns 2 and pops four.
        var (game, rng) = game([[1, 1, 0, 2, 2, 2, 3, 3]], current: 4, next: 4)
        game.load(special: .rainbow)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.color(row: 0, column: 2) == nil)
        #expect((3...5).allSatisfy { game.color(row: 0, column: $0) == nil })
        #expect(game.color(row: 0, column: 0) == 1)
        #expect(game.score == 40)
        #expect(game.specialsFired == 1)
    }

    @Test func aRainbowThatCannotMakeThreeStaysAsAColor() {
        var (game, rng) = game([[1, 0, 2, 3, 4, 1, 2, 3]], current: 4, next: 4)
        game.load(special: .rainbow)
        game.fire(angle: angle(to: game.center(row: 0, column: 1)), using: &rng)
        fly(&game, &rng)
        // It touches a 1 and a 2; both make pairs, so it takes the lower color and counts as a miss.
        #expect(game.color(row: 0, column: 1) == 1)
        #expect(game.misses == 1)
        #expect(game.score == 0)
    }

    @Test func aBombBlowsUpEveryBubbleWithinTwoOfWhereItLands() throws {
        // Three full rows with no matches anywhere; the bomb flies straight up the middle.
        let rows = [[1, 2, 3, 4, 1, 2, 3, 4], [3, 4, 1, 2, 3, 4, 1], [2, 1, 4, 3, 2, 1, 4, 3]]
        var (game, rng) = game(rows, current: 1, next: 1)
        game.load(special: .bomb)
        game.fire(angle: .pi / 2, using: &rng)
        fly(&game, &rng)
        let blast = try #require(game.lastBomb)
        var inBlast = 0
        for row in 0..<3 {
            for column in 0..<Game.columns where game.isValid(row: row, column: column) {
                let near = game.center(row: row, column: column).distance(to: blast) <= Game.bombRadius
                if near { inBlast += 1 }
                #expect((game.color(row: row, column: column) == nil) == near, "row \(row), column \(column)")
            }
        }
        #expect(inBlast == 7)
        #expect(game.lastCleared.count == 7)
        #expect(game.score == 70)
        #expect(game.streak == 1)
        #expect(game.specialsFired == 1)
    }

    @Test func goldBonusBubblesPayExtraWhenPopped() {
        var (game, rng) = game([[1, 1, 0, 2, 2, 0, 3, 3]], current: 1, next: 2)
        game.markBonus([index(0, 0)])
        #expect(game.isBonus(row: 0, column: 0))
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.score == 30 + Game.bonusPoints)
        #expect(game.bonusesCollected == 1)
        #expect(game.lastCleared.filter(\.isBonus).count == 1)
        #expect(!game.isBonus(row: 0, column: 0))
    }

    @Test func goldBonusBubblesPayExtraWhenTheyFall() {
        var (game, rng) = game([[1, 1, 0, 0, 0, 0, 0, 4], [2]], current: 1, next: 4)
        game.markBonus([index(1, 0)])
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.score == 3 * 10 + 20 + Game.bonusPoints)
        #expect(game.bonusesCollected == 1)
    }

    @Test func goldBonusBubblesMoveDownWithANewRow() {
        var (game, rng) = game([[1, 2, 3, 4, 1, 2, 3, 4]], current: 2, next: 2)
        game.markBonus([index(0, 5)])
        game.misses = Game.missesPerRow - 1
        game.fire(angle: .pi / 2, using: &rng)
        fly(&game, &rng)
        #expect(game.isBonus(row: 1, column: 5))
        #expect(!game.isBonus(row: 0, column: 5) || game.color(row: 0, column: 5) != nil)
    }

    @Test func laterWavesStartDeeperAndDropRowsSooner() {
        var (game, _) = game([])
        #expect(game.startingRows == 5)
        #expect(game.missesBeforeRow == Game.missesPerRow)
        #expect(game.colorCount == 4)
        game.set(wave: 2)
        #expect(game.startingRows == 5)
        #expect(game.missesBeforeRow == 6)
        #expect(game.colorCount == 5)
        game.set(wave: 3)
        #expect(game.startingRows == 6)
        #expect(game.missesBeforeRow == 5)
        #expect(game.colorCount == 6)
        game.set(wave: 5)
        #expect(game.startingRows == 7)
        #expect(game.missesBeforeRow == 4)
        game.set(wave: 40)
        #expect(game.startingRows == Game.mostStartingRows)
        #expect(game.missesBeforeRow == Game.fewestMissesPerRow)
        #expect(game.colorCount == Game.maxColors)
    }

    @Test func aDeeperWaveStartsAfterClearingTheThirdField() {
        var (game, rng) = game([[1, 1]], current: 1, next: 1)
        game.set(wave: 2)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.wave == 3)
        #expect(game.score == 30 + 2 * Game.wavePoints)
        #expect((0..<6).allSatisfy { row in game.color(row: row, column: 0) != nil })
        #expect(game.color(row: 6, column: 0) == nil)
    }

    @Test func theLandingSpotIsWhereTheShotSticks() throws {
        let rows = (0..<4).map { row in Array(repeating: 1, count: row % 2 == 0 ? 8 : 7) }
        for angle in stride(from: 0.3, through: Double.pi - 0.3, by: 0.11) {
            var (game, rng) = game(rows, current: 2, next: 2)
            let path = game.trajectory(angle: angle, maxBounces: 50)
            let end = try #require(path.last)
            let spot = try #require(game.landingSpot(for: end))
            game.fire(angle: angle, using: &rng)
            fly(&game, &rng)
            let cell = try #require(game.cells.indices.first { game.center(of: $0) == spot })
            #expect(game.cells[cell] == 2, "angle \(angle)")
        }
    }

    @Test func aNewFieldHidesSomeGoldBonusBubbles() {
        var found = 0
        for seed in 1...40 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let game = Game(using: &rng)
            found += game.bonusCells.count
            #expect(game.bonusCells.allSatisfy { game.cells[$0] != 0 })
        }
        // About 4% of 38 bubbles a field: around 60 in 40 fields.
        #expect((25...110).contains(found))
    }

    @Test func shotsAlwaysGoUp() {
        #expect(Game.clampAngle(0) > 0)
        #expect(Game.clampAngle(-1) > 0)
        #expect(Game.clampAngle(-1) < .pi / 2) // Below and to the right: low to the right.
        #expect(Game.clampAngle(-3) > .pi / 2) // Below and to the left: low to the left.
        #expect(Game.clampAngle(.pi) < .pi)
        #expect(Game.clampAngle(.pi / 2) == .pi / 2)
        #expect(Game.clampAngle(.nan) == .pi / 2)
    }
}
