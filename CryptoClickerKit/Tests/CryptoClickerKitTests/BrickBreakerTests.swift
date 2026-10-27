import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Brick Breaker")
struct BrickBreakerTests {
    typealias Game = BrickBreakerGame
    /// A brick out of the way, so clearing a test brick doesn't finish the level.
    let faraway = Box(minX: 0.9, minY: 0.02, width: 0.08, height: 0.03)

    func overlaps(_ a: Box, _ b: Box) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }

    @Test func aNewGameServesFromThePaddle() {
        let game = Game()
        #expect(game.phase == .serving)
        #expect(game.lives == 3)
        #expect(game.level == 1)
        #expect(game.bricks.count == 5 * Game.columns)
        #expect(game.ball.x == game.paddleX)
        #expect(game.ball.y < Game.paddleTop)
        for (index, brick) in game.bricks.enumerated() {
            #expect(brick.frame.minX >= 0 && brick.frame.maxX <= Game.width)
            #expect(brick.maxHits == 1)
            for other in game.bricks[(index + 1)...] { #expect(!overlaps(brick.frame, other.frame)) }
        }
    }

    @Test func theServingBallRidesThePaddle() {
        var game = Game()
        game.movePaddle(to: 0.8)
        #expect(game.paddleX == 0.8)
        #expect(game.ball.x == 0.8)
        game.movePaddle(to: -3)
        #expect(game.paddleX == Game.paddleWidth / 2)
        game.movePaddle(to: 5)
        #expect(game.paddleX == Game.width - Game.paddleWidth / 2)
        let resting = game.ball
        game.update(by: 1)
        #expect(game.ball == resting)
    }

    @Test func launchingSendsTheBallUpAtFullSpeed() {
        var game = Game()
        game.launch()
        #expect(game.phase == .playing)
        #expect(game.velocity.y < 0)
        #expect(approx(game.velocity.length, game.speed))
        let velocity = game.velocity
        game.launch()
        #expect(game.velocity == velocity)
    }

    @Test func wallsAndCeilingBounceTheBall() {
        var game = Game()
        game.load(ball: Vector2(x: 0.03, y: 0.8), velocity: Vector2(x: -0.6, y: -0.5), bricks: [faraway])
        game.update(by: 0.05)
        #expect(game.velocity.x > 0)
        #expect(game.ball.x >= Game.ballRadius)
        game.load(ball: Vector2(x: 0.5, y: 0.03), velocity: Vector2(x: 0.2, y: -0.8), bricks: [faraway])
        game.update(by: 0.05)
        #expect(game.velocity.y > 0)
        #expect(game.ball.y >= Game.ballRadius)
    }

    @Test func theBallBreaksABrickAndBouncesBack() {
        var game = Game()
        let brick = Box(minX: 0.4, minY: 0.5, width: 0.2, height: 0.05)
        game.load(ball: Vector2(x: 0.5, y: 0.6), velocity: Vector2(x: 0, y: -0.8), bricks: [brick, faraway])
        game.update(by: 0.05)
        #expect(game.bricks.count == 1)
        #expect(game.bricksBroken == 1)
        #expect(game.score == 10)
        #expect(game.velocity.y > 0)
        #expect(game.ball.y >= brick.maxY)
    }

    @Test func aFastBallCannotSlipThroughAThinBrick() {
        var game = Game()
        let thin = Box(minX: 0, minY: 0.5, width: 1, height: 0.005)
        game.load(ball: Vector2(x: 0.5, y: 0.7), velocity: Vector2(x: 0, y: -1.5), bricks: [thin, faraway])
        for _ in 0..<10 { game.update(by: 0.05) }
        #expect(game.bricks.count == 1)
        #expect(game.ball.y > thin.maxY)
        #expect(game.velocity.y > 0)
    }

    @Test func thePaddleAimsTheBall() {
        var game = Game()
        game.load(ball: Vector2(x: 0.6, y: 1.36), velocity: Vector2(x: 0, y: 0.8), bricks: [faraway], paddleX: 0.5)
        game.update(by: 0.05)
        #expect(game.paddleHits == 1)
        #expect(game.velocity.y < 0)
        #expect(game.velocity.x > 0) // Right of center sends it right.
        game.load(ball: Vector2(x: 0.5, y: 1.36), velocity: Vector2(x: 0.1, y: 0.8), bricks: [faraway], paddleX: 0.5)
        game.update(by: 0.05)
        #expect(game.paddleHits == 2)
        #expect(abs(game.velocity.x) < 0.1) // The middle sends it nearly straight up.
        #expect(game.velocity.y < 0)
    }

    @Test func theBallNeverTravelsFlat() {
        var game = Game()
        game.load(ball: Vector2(x: 0.5, y: 0.8), velocity: Vector2(x: 1, y: 0.01), bricks: [faraway])
        game.update(by: 0.016)
        #expect(abs(game.velocity.y) >= 0.3 * game.speed - 1e-9)
        #expect(approx(game.velocity.length, game.speed))
    }

    @Test func missingTheBallCostsALifeAndTheThirdEndsTheGame() {
        var game = Game()
        for expected in [2, 1] {
            game.load(ball: Vector2(x: 0.1, y: 1.49), velocity: Vector2(x: 0, y: 0.8), bricks: [faraway], paddleX: 0.8)
            game.update(by: 0.05)
            #expect(game.lives == expected)
            #expect(game.phase == .serving)
            #expect(game.ball.x == game.paddleX)
        }
        game.load(ball: Vector2(x: 0.1, y: 1.49), velocity: Vector2(x: 0, y: 0.8), bricks: [faraway], paddleX: 0.8)
        game.update(by: 0.05)
        #expect(game.lives == 0)
        #expect(game.phase == .over)
        game.launch()
        #expect(game.phase == .over)
    }

    @Test func aSteadyPlayerClearsTheFirstWall() {
        // Meeting the ball a little off-center keeps changing its angle, so every brick gets hit.
        var game = Game()
        var frames = 0
        while game.level == 1 && game.phase != .over && frames < 30_000 {
            let offset = (frames / 600) % 2 == 0 ? 0.06 : -0.06
            game.movePaddle(to: game.ball.x + offset)
            if game.phase == .serving { game.launch() }
            game.update(by: 1.0 / 60)
            frames += 1
        }
        #expect(game.level == 2)
        #expect(game.lives == 3)
        #expect(game.bricksBroken == 5 * Game.columns)
    }

    @Test func clearingTheWallStartsAFasterLevelWithToughBricks() {
        var game = Game()
        let brick = Box(minX: 0.4, minY: 0.5, width: 0.2, height: 0.05)
        let startSpeed = game.speed
        for level in 2...3 {
            game.load(ball: Vector2(x: 0.5, y: 0.6), velocity: Vector2(x: 0, y: -0.8), bricks: [brick])
            game.update(by: 0.05)
            #expect(game.level == level)
            #expect(game.phase == .serving)
        }
        #expect(game.score == 10 + 100 + 10 + 200)
        #expect(game.speed > startSpeed)
        // Level 3: up to seven rows, with tough bricks making the wall take up to 56 hits.
        let hits = game.bricks.reduce(0) { $0 + $1.maxHits }
        #expect(game.bricks.count >= 2 * Game.columns)
        #expect(hits <= Game.fullWallHits(level: 3))
        #expect(hits >= min(Game.fullWallHits(level: 3), 2 * game.bricks.count))
        #expect(game.bricks.contains { $0.maxHits == 2 })
    }

    @Test func wallsTakeRandomShapesAfterLevelOne() {
        var shapes = Set<[Int]>()
        for seed in UInt64(1)...40 {
            var rng = SeededGenerator(seed: seed)
            let level1 = Game.cells(level: 1, rows: Game.rows(for: 1), using: &rng)
            #expect(level1.count == 5 * Game.columns)
            for level in 2...6 {
                let rows = Game.rows(for: level)
                let cells = Game.cells(level: level, rows: rows, using: &rng)
                #expect(cells.count >= 2 * Game.columns)
                #expect(cells.allSatisfy { (0..<rows).contains($0.row) && (0..<Game.columns).contains($0.column) })
                #expect(Set(cells.map { $0.row * Game.columns + $0.column }).count == cells.count)
                shapes.insert(cells.map { $0.row * Game.columns + $0.column })
            }
        }
        #expect(shapes.count >= 10)
        // A game's walls follow its seed, so the same seed plays the same game.
        #expect(Game(seed: 7).bricks.map(\.frame) == Game(seed: 7).bricks.map(\.frame))
    }

    @Test func everyWallFitsTheField() {
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            for level in 2...8 {
                let cells = Game.cells(level: level, rows: Game.rows(for: level), using: &rng)
                #expect(cells.count <= Game.rows(for: level) * Game.columns)
            }
        }
        var game = Game(seed: 3)
        for level in 2...5 {
            game.load(ball: Vector2(x: 0.5, y: 0.6), velocity: Vector2(x: 0, y: -0.8),
                      bricks: [Box(minX: 0.4, minY: 0.5, width: 0.2, height: 0.05)])
            game.update(by: 0.05)
            #expect(game.level == level)
            for (index, brick) in game.bricks.enumerated() {
                #expect(brick.frame.minX >= 0 && brick.frame.maxX <= Game.width)
                #expect(brick.frame.maxY < Game.paddleTop)
                #expect((1...2).contains(brick.maxHits))
                for other in game.bricks[(index + 1)...] { #expect(!overlaps(brick.frame, other.frame)) }
            }
        }
    }
}
