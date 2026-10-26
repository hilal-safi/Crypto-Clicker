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

    @Test func clearingTheFieldStartsTheNextLevel() {
        var (game, rng) = game([[1, 1]], current: 1, next: 1)
        game.fire(angle: angle(to: game.center(row: 0, column: 2)), using: &rng)
        fly(&game, &rng)
        #expect(game.level == 2)
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
