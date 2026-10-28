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

    // MARK: Brick types, power-ups and bosses

    /// A brick's center, for a ball aimed at it from below.
    func center(row: Int, column: Int) -> Vector2 {
        let width = Game.brickWidth
        return Vector2(x: Game.sideMargin + Double(column) * (width + Game.brickGap) + width / 2,
                       y: Game.brickTop + Double(row) * (Game.brickHeight + Game.brickGap) + Game.brickHeight / 2)
    }

    /// Plays on with the paddle under the first ball, relaunching after a lost ball.
    func play(_ game: inout Game, seconds: Double, until done: (Game) -> Bool = { _ in false }) {
        var time = 0.0
        while time < seconds && game.phase != .over && !done(game) {
            if game.phase == .serving { game.launch() }
            game.movePaddle(to: game.ball.x + 0.03)
            game.update(by: 1.0 / 60)
            time += 1.0 / 60
        }
    }

    @Test func anExplosiveBrickBreaksTheBricksAroundIt() {
        var game = Game()
        let target = center(row: 2, column: 1)
        game.load(ball: Vector2(x: target.x, y: 0.5), velocity: Vector2(x: 0, y: -0.8), bricks: [])
        game.load(bricks: [(2, 1, .explosive, 1), (1, 0, .normal, 1), (1, 1, .armored, 3), (1, 2, .normal, 1),
                           (2, 0, .normal, 1), (2, 2, .explosive, 1), (2, 3, .normal, 1), (0, 6, .normal, 1)])
        for _ in 0..<20 { game.update(by: 0.05) }
        // The first explosion set off the second, which broke (2, 3) too; the armored brick next to
        // both lost a hit to each.
        #expect(game.explosions == 2)
        #expect(game.bricksBroken == 6)
        #expect(Set(game.bricks.map { "\($0.row),\($0.column)" }) == ["1,1", "0,6"])
        #expect(game.bricks.first { $0.row == 1 }?.hitsLeft == 1)
    }

    @Test func aBonusBrickDropsAPowerUpForThePaddle() {
        var game = Game()
        let target = center(row: 2, column: 3)
        game.load(ball: Vector2(x: target.x, y: 0.5), velocity: Vector2(x: 0, y: -0.8), bricks: [faraway])
        game.load(bricks: [(2, 3, .bonus, 1), (0, 6, .normal, 1)])
        for _ in 0..<30 where game.capsules.isEmpty { game.update(by: 0.05) }
        #expect(game.capsules.count == 1)
        let capsule = game.capsules[0]
        // Caught: the paddle under it.
        play(&game, seconds: 5) { $0.capsules.isEmpty }
        if game.powerUpsCaught == 0 {
            // The paddle followed the ball instead; drop one straight onto it.
            if game.phase == .serving { game.launch() }
            game.dropCapsule(capsule.kind, at: Vector2(x: game.paddleX, y: Game.paddleTop - 0.01))
            for _ in 0..<4 { game.update(by: 0.05) }
        }
        #expect(game.powerUpsCaught == 1)
        // One that misses falls away.
        var missed = Game()
        missed.load(ball: Vector2(x: 0.1, y: 0.5), velocity: Vector2(x: 0, y: -0.8), bricks: [faraway], paddleX: 0.85)
        missed.dropCapsule(.laser, at: Vector2(x: 0.2, y: 1.3))
        for _ in 0..<20 { missed.update(by: 0.05) }
        #expect(missed.capsules.isEmpty)
        #expect(missed.powerUpsCaught == 0)
    }

    @Test func aWidePaddleIsWiderUntilItRunsOut() {
        var game = Game()
        game.load(ball: Vector2(x: 0.5, y: 0.8), velocity: Vector2(x: 0.3, y: -0.7), bricks: [faraway])
        game.dropCapsule(.widePaddle, at: Vector2(x: 0.5, y: Game.paddleTop - 0.02))
        game.update(by: 0.05)
        #expect(game.isActive(.widePaddle))
        #expect(approx(game.paddle.width, Game.paddleWidth * 1.5))
        play(&game, seconds: 13)
        #expect(!game.isActive(.widePaddle))
        #expect(approx(game.paddle.width, Game.paddleWidth))
    }

    @Test func multiBallSplitsEveryBallAndOnlyTheLastOneCostsALife() {
        var game = Game()
        game.load(ball: Vector2(x: 0.5, y: 0.8), velocity: Vector2(x: 0.2, y: -0.75), bricks: [faraway])
        game.give(.multiBall)
        #expect(game.balls.count == 3)
        #expect(Set(game.balls.map(\.id)).count == 3)
        #expect(game.isActive(.multiBall))
        game.give(.multiBall)
        #expect(game.balls.count == 6) // Capped.
        // Let them all fall: the paddle hides in a corner.
        var lostAt: Int?
        for frame in 0..<2_000 where game.phase == .playing {
            game.movePaddle(to: 0)
            game.update(by: 1.0 / 60)
            if game.balls.count < 6 && lostAt == nil { lostAt = frame }
        }
        #expect(lostAt != nil)
        #expect(game.lives == 2) // One life for all six.
        #expect(game.balls.count == 1 && game.phase == .serving)
    }

    @Test func aSlowBallMovesSlower() {
        var game = Game()
        game.load(ball: Vector2(x: 0.5, y: 0.8), velocity: Vector2(x: 0.2, y: -0.75), bricks: [faraway])
        let normal = game.speed
        game.give(.slowBall)
        game.update(by: 0.02)
        #expect(approx(game.speed, normal * 0.7))
        #expect(approx(game.velocity.length, game.speed))
    }

    @Test func theLaserFiresBoltsThatBreakBricks() {
        var game = Game()
        let brick = Box(minX: 0.35, minY: 0.5, width: 0.3, height: 0.04)
        game.load(ball: Vector2(x: 0.1, y: 1.0), velocity: Vector2(x: 0, y: -0.8), bricks: [brick, faraway])
        game.give(.laser)
        for _ in 0..<12 { game.update(by: 0.05) }
        #expect(game.bricksBroken == 1)
        #expect(game.bricks.count == 1)
        #expect(!game.bolts.isEmpty || game.bricksBroken == 1)
    }

    @Test func everyFifthLevelIsABoss() throws {
        var game = Game(seed: 4)
        game.jump(toLevel: 5)
        let boss = try #require(game.boss)
        #expect(game.isBossLevel)
        #expect(boss.maxHits == 16)
        #expect(game.bricks.allSatisfy { $0.frame.minY > boss.frame.maxY })
        #expect(game.bricks.contains { $0.kind == .bonus })
        // It slides, and drops debris.
        let start = boss.frame.minX
        play(&game, seconds: Game.bossDropInterval(level: 5) + 0.1)
        #expect(game.boss?.frame.minX != start)
        #expect(!game.debris.isEmpty || game.shrunkFor > 0)
        // Debris that lands on the paddle shrinks it for a while.
        var shrunk = Game(seed: 4)
        shrunk.jump(toLevel: 5)
        shrunk.launch()
        shrunk.dropDebris(at: Vector2(x: shrunk.paddleX, y: Game.paddleTop - 0.01))
        shrunk.update(by: 0.05)
        #expect(shrunk.debris.isEmpty)
        #expect(approx(shrunk.shrunkFor, 5 - 0.05, tolerance: 0.01))
        #expect(approx(shrunk.paddle.width, Game.paddleWidth * 0.65))
        // Beating it (and its wall) clears the level.
        game.clearBricks()
        var time = 0.0
        while game.boss != nil && time < 300 && game.phase != .over {
            if game.phase == .serving { game.launch() }
            if !game.isActive(.laser) { game.give(.laser) }
            game.movePaddle(to: game.boss?.frame.midX ?? 0.5)
            game.update(by: 1.0 / 60)
            time += 1.0 / 60
        }
        #expect(game.bossesDefeated == 1)
        #expect(game.level == 6)
        #expect(game.boss == nil)
        #expect(game.bricks.contains { $0.maxHits == 3 }) // Level 6 brings three-hit armor.
    }

    @Test func aBallStuckOnAnEmptyPathIsNudgedOffIt() {
        var game = Game()
        game.load(ball: Vector2(x: 0.5, y: 1.2), velocity: Vector2(x: 0, y: -0.8), bricks: [faraway])
        var frames = 0
        while abs(game.velocity.x) < 0.01 && frames < 60 * 20 && game.phase == .playing {
            game.movePaddle(to: game.ball.x) // Returned dead center: straight up, forever.
            game.update(by: 1.0 / 60)
            frames += 1
        }
        #expect(abs(game.velocity.x) >= 0.01)
        #expect(frames > 60 * 11)
    }

    @Test func gamesRecordTheirLevelsBossesAndPowerUps() {
        var state = GameState.make(miners: [.desktop: 10])
        state.finishBrickBreaker(score: 4_000, bricks: 120, level: 6, bosses: 1, powerUps: 7, bestStreak: 3)
        state.finishBrickBreaker(score: 900, bricks: 30, level: 2, bosses: 0, powerUps: 1, bestStreak: 1)
        #expect(state.stats.brickBreakerLevelsCleared == 6)
        #expect(state.stats.brickBreakerBosses == 1)
        #expect(state.stats.brickBreakerPowerUps == 8)
        #expect(state.stats.brickBreakerBestStreak == 3)
        #expect(state.stats.brickBreakerBestLevel == 6)
        #expect(state.stats.bricksBroken == 150)
    }
}
