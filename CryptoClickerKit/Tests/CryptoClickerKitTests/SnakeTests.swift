import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Snake")
struct SnakeTests {
    func p(_ x: Int, _ y: Int) -> GridPoint { GridPoint(x: x, y: y) }

    func game(body: [GridPoint], heading: SnakeDirection, food: GridPoint?) -> (SnakeGame, SeededGenerator) {
        var rng = SeededGenerator(seed: 1)
        var game = SnakeGame(using: &rng)
        game.load(body: body, heading: heading, food: food)
        return (game, rng)
    }

    @Test func aNewSnakeHeadsRightWithACoinToEat() throws {
        var rng = SeededGenerator(seed: 9)
        let game = SnakeGame(using: &rng)
        #expect(game.body == [p(4, 10), p(3, 10), p(2, 10)])
        #expect(game.heading == .right)
        let food = try #require(game.food)
        #expect(!game.body.contains(food))
        #expect(game.score == 0)
        #expect(!game.isOver)
    }

    @Test func movingShiftsTheWholeBody() {
        var (game, rng) = game(body: [p(5, 5), p(4, 5), p(3, 5)], heading: .right, food: p(0, 0))
        game.step(using: &rng)
        #expect(game.body == [p(6, 5), p(5, 5), p(4, 5)])
        #expect(game.eaten == 0)
    }

    @Test func eatingACoinGrowsTheSnakeAndScores() throws {
        var (game, rng) = game(body: [p(5, 5), p(4, 5), p(3, 5)], heading: .right, food: p(6, 5))
        game.step(using: &rng)
        #expect(game.body == [p(6, 5), p(5, 5), p(4, 5), p(3, 5)])
        #expect(game.eaten == 1)
        #expect(game.score == 10)
        let food = try #require(game.food)
        #expect(!game.body.contains(food))
    }

    @Test func turnsApplyInOrderAndNeverReverse() {
        var (game, rng) = game(body: [p(5, 5), p(4, 5), p(3, 5)], heading: .right, food: p(0, 0))
        game.turn(.left) // Straight back into the neck: ignored.
        game.turn(.right) // Already heading right: ignored.
        game.step(using: &rng)
        #expect(game.head == p(6, 5))
        game.turn(.up)
        game.turn(.left)
        game.step(using: &rng)
        #expect(game.head == p(6, 4))
        game.step(using: &rng)
        #expect(game.head == p(5, 4))
        #expect(game.heading == .left)
    }

    @Test func atMostTwoTurnsWait() {
        var (game, rng) = game(body: [p(5, 5), p(4, 5), p(3, 5)], heading: .right, food: p(0, 0))
        game.turn(.down)
        game.turn(.left)
        game.turn(.up) // A third queued turn is dropped.
        for _ in 0..<3 { game.step(using: &rng) }
        #expect(Array(game.body) == [p(3, 6), p(4, 6), p(5, 6)])
        #expect(game.heading == .left)
    }

    @Test func hittingAWallEndsTheGame() {
        var (game, rng) = game(body: [p(14, 3), p(13, 3), p(12, 3)], heading: .right, food: p(0, 0))
        game.step(using: &rng)
        #expect(game.isOver)
        #expect(game.head == p(14, 3))
        game.step(using: &rng)
        #expect(game.head == p(14, 3))
    }

    @Test func runningIntoItselfEndsTheGame() {
        var (game, rng) = game(body: [p(5, 5), p(5, 6), p(4, 6), p(4, 5), p(4, 4)], heading: .up, food: p(0, 0))
        game.turn(.left)
        game.step(using: &rng)
        #expect(game.isOver)
    }

    @Test func chasingTheTailIsSafe() {
        // The tail leaves its cell on the same tick the head arrives.
        var (game, rng) = game(body: [p(5, 5), p(5, 6), p(4, 6), p(4, 5)], heading: .up, food: p(0, 0))
        game.turn(.left)
        game.step(using: &rng)
        #expect(!game.isOver)
        #expect(game.body == [p(4, 5), p(5, 5), p(5, 6), p(4, 6)])
    }

    @Test func theSnakeSpeedsUpAsItEats() {
        var rng = SeededGenerator(seed: 2)
        var game = SnakeGame(using: &rng)
        #expect(approx(game.tickInterval, 0.18))
        var moves = 0
        while game.eaten < 5 && !game.isOver && moves < 10_000 {
            steer(&game)
            game.step(using: &rng)
            moves += 1
        }
        #expect(game.eaten == 5)
        #expect(game.tickInterval < 0.18)
        #expect(approx(game.tickInterval, 0.16))
    }

    /// Heads for the coin, sidestepping when the only useful move would be a reversal.
    func steer(_ game: inout SnakeGame) {
        guard let food = game.food else { return }
        let head = game.head
        let horizontal: SnakeDirection? = food.x > head.x ? .right : food.x < head.x ? .left : nil
        let vertical: SnakeDirection? = food.y > head.y ? .down : food.y < head.y ? .up : nil
        for wanted in [horizontal, vertical].compactMap({ $0 }) where wanted != game.heading.opposite {
            game.turn(wanted)
            return
        }
        let isHorizontal = game.heading == .left || game.heading == .right
        game.turn(isHorizontal ? (head.y > 0 ? .up : .down) : (head.x > 0 ? .left : .right))
    }

    @Test func fillingTheBoardEndsTheGame() {
        // A path through every cell, row by row; the snake covers all but the last one, where the coin is.
        var path: [GridPoint] = []
        for y in 0..<SnakeGame.height {
            let columns = Array(0..<SnakeGame.width)
            for x in (y % 2 == 0 ? columns : columns.reversed()) { path.append(p(x, y)) }
        }
        let last = path.removeLast()
        var (game, rng) = game(body: path.reversed(), heading: .left, food: last)
        game.step(using: &rng)
        #expect(game.eaten == 1)
        #expect(game.body.count == SnakeGame.width * SnakeGame.height)
        #expect(game.food == nil)
        #expect(game.isOver)
    }

    // MARK: Arenas, Coin Rush and power-ups

    @Test(arguments: SnakeGame.Arena.allCases)
    func arenasWallOffCellsAwayFromTheStart(_ arena: SnakeGame.Arena) {
        var rng = SeededGenerator(seed: 4)
        let game = SnakeGame(arena: arena, using: &rng)
        #expect(game.arena == arena)
        #expect(arena == .open ? game.walls.isEmpty : game.walls.count >= 12)
        // The starting row ahead of the snake is clear, and no coin starts inside a wall.
        #expect((0..<SnakeGame.width).allSatisfy { !game.walls.contains(p($0, 10)) })
        #expect(game.coins.allSatisfy { !game.walls.contains($0) })
        #expect(game.walls.allSatisfy { (0..<SnakeGame.width).contains($0.x) && (0..<SnakeGame.height).contains($0.y) })
    }

    @Test func hittingAnObstacleEndsTheGame() {
        var rng = SeededGenerator(seed: 1)
        var game = SnakeGame(arena: .pillars, using: &rng)
        game.load(body: [p(2, 3), p(1, 3), p(0, 3)], heading: .right, food: p(0, 0))
        game.turn(.down)
        game.step(using: &rng) // (2, 4)
        game.turn(.right)
        game.step(using: &rng) // (3, 4) is a pillar.
        #expect(game.isOver)
    }

    @Test func coinRushPutsThreeCoinsOutAndEndsAfterAMinute() {
        var rng = SeededGenerator(seed: 2)
        var game = SnakeGame(mode: .coinRush, arena: .rooms, using: &rng)
        #expect(game.arena == .open) // Coin Rush is always in the open.
        #expect(game.coins.count == SnakeGame.coinRushCoins)
        #expect(Set(game.coins).count == 3)
        #expect(game.timeLeft == SnakeGame.coinRushLength)
        var steps = 0
        while !game.isOver && steps < 10_000 {
            // Circle in a safe loop: right along row 10, then around.
            if steps % 20 == 9 { game.turn(.down) }
            if steps % 20 == 10 { game.turn(.left) }
            if steps % 20 == 19 { game.turn(.up) }
            if steps % 20 == 0 { game.turn(.right) }
            game.step(using: &rng)
            steps += 1
            if !game.isOver { #expect(game.coins.count == SnakeGame.coinRushCoins) }
        }
        #expect(game.isOver)
        var timed = SnakeGame(mode: .coinRush, using: &rng)
        timed.load(body: [p(5, 5), p(4, 5), p(3, 5)], heading: .right, food: nil)
        for index in 0..<2_000 where !timed.isOver {
            timed.turn([.down, .left, .up, .right][(index / 2) % 4]) // A tight square: never crashes.
            timed.step(using: &rng)
        }
        #expect(timed.isOver)
        #expect(timed.time >= SnakeGame.coinRushLength)
        #expect(timed.timeLeft == 0)
    }

    @Test func aSpeedBoostIsFasterAndDoublesCoinsUntilItRunsOut() {
        var (game, rng) = game(body: [p(5, 5), p(4, 5), p(3, 5)], heading: .right, food: p(8, 5))
        let normal = game.tickInterval
        game.place(.speedBoost, at: p(6, 5))
        game.step(using: &rng)
        #expect(game.isActive(.speedBoost))
        #expect(game.powerUpsCollected == 1)
        #expect(game.tickInterval < normal)
        #expect(game.coinValue == 20)
        game.step(using: &rng)
        game.step(using: &rng) // Eats the coin at (8, 5).
        #expect(game.score == 20)
        // Slow Motion replaces it.
        game.place(.slowMotion, at: p(9, 5))
        game.step(using: &rng)
        #expect(game.isActive(.slowMotion) && !game.isActive(.speedBoost))
        #expect(game.tickInterval > normal)
        // Effects run out with time.
        game.turn(.down)
        var ticks = 0
        while game.isActive(.slowMotion) && ticks < 200 {
            game.step(using: &rng)
            ticks += 1
            if game.head.y >= SnakeGame.height - 2 { game.turn(game.heading == .down ? .left : .up) }
            if game.head.y <= 1 { game.turn(.down) }
        }
        #expect(!game.isActive(.slowMotion))
        #expect(game.tickInterval < normal * 1.1)
    }

    @Test func aShieldForgivesOneCrashAndWaitsForATurn() {
        var (game, rng) = game(body: [p(13, 3), p(12, 3), p(11, 3)], heading: .right, food: p(0, 0))
        game.place(.shield, at: p(14, 3))
        game.step(using: &rng) // Picks up the shield at the wall.
        #expect(game.hasShield)
        game.step(using: &rng) // Would hit the wall: forgiven.
        #expect(!game.isOver)
        #expect(!game.hasShield)
        #expect(game.head == p(14, 3))
        #expect(game.graceTicks == SnakeGame.shieldGraceTicks)
        game.turn(.down)
        game.step(using: &rng)
        #expect(game.head == p(14, 4))
        #expect(game.graceTicks == 0)
        // Without a shield the next crash counts; waiting too long does too.
        var waiting = game
        waiting.turn(.right)
        waiting.step(using: &rng)
        #expect(waiting.isOver)
        var stuck = SnakeTests().game(body: [p(13, 3), p(12, 3), p(11, 3)], heading: .right, food: p(0, 0)).0
        stuck.place(.shield, at: p(14, 3))
        stuck.step(using: &rng)
        for _ in 0...SnakeGame.shieldGraceTicks { stuck.step(using: &rng) }
        #expect(!stuck.isOver) // Forgiven, then waiting four ticks.
        stuck.step(using: &rng)
        #expect(stuck.isOver)
    }

    @Test func theMagnetPullsInNearbyCoins() {
        var (game, rng) = game(body: [p(5, 5), p(4, 5), p(3, 5)], heading: .right, food: p(7, 7))
        game.place(.magnet, at: p(6, 5))
        game.step(using: &rng) // Head at (6, 5): the coin at (7, 7) is three steps away.
        #expect(game.isActive(.magnet))
        #expect(game.eaten == 0)
        game.placeCoins([p(8, 6)])
        game.step(using: &rng) // Head at (7, 5): (8, 6) is two steps away.
        #expect(game.eaten == 1)
        let length = game.body.count
        game.step(using: &rng)
        #expect(game.body.count == length + 1) // It still grows.
    }

    @Test func powerUpsAppearEverySixCoinsAndDontWaitForever() {
        var rng = SeededGenerator(seed: 8)
        var game = SnakeGame(using: &rng)
        var steps = 0
        while game.eaten < SnakeGame.coinsPerPowerUp && !game.isOver && steps < 5_000 {
            SnakeTests().steer(&game)
            game.step(using: &rng)
            steps += 1
        }
        #expect(game.eaten >= SnakeGame.coinsPerPowerUp)
        let item = game.item
        #expect(item != nil)
        if let item {
            #expect(!game.body.contains(item.position) && !game.coins.contains(item.position))
        }
        // Left alone, it disappears after its lifetime.
        var ignored = game
        var waited: TimeInterval = 0
        while ignored.item != nil && !ignored.isOver && waited < 20 {
            waited += ignored.tickInterval
            SnakeTests().steer(&ignored)
            ignored.step(using: &rng)
        }
        #expect(ignored.item == nil || ignored.isOver)
    }

    @Test func coinRushKeepsItsOwnRecord() {
        var state = GameState.make(miners: [.desktop: 5])
        let classic = state.finishSnake(score: 300, length: 33, coins: 30, time: 95, powerUps: 2)
        #expect(classic.isNewBest)
        let rush = state.finishSnake(score: 250, length: 28, coins: 22, time: 60, powerUps: 3, mode: .coinRush)
        #expect(rush.isNewBest) // The first Coin Rush, though below Classic's best.
        #expect(state.stats.snakeBestScore == 300)
        #expect(state.stats.snakeRushBestScore == 250)
        #expect(state.stats.snakeRushes == 1)
        #expect(state.stats.snakeBestCoins == 30)
        #expect(state.stats.snakeLongestTime == 95)
        #expect(state.stats.snakePowerUps == 5)
        #expect(state.stats.snakeCoinsEaten == 52)
        #expect(state.stats.snakeGames == 2)
    }

    @Test func coinRushPointsPayLessBecauseTheyComeFaster() {
        var classic = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        var rush = GameState.make(miners: [.desktop: 5])
        #expect(classic.finishSnake(score: 200, length: 23).coins == 900) // 200 × 0.3 × 10 × 1.5
        #expect(rush.finishSnake(score: 200, length: 23, mode: .coinRush).coins == 540) // 60% of that.
    }

    @Test func aCoinRushLeftOpenIsPaidAsOne() {
        var state = GameState.make(miners: [.desktop: 5])
        state.holdArcadeRun(ArcadeRun(game: .snake, score: 200, detail: 23, stage: ArcadeRun.coinRushStage))
        #expect(state.payUnfinishedRun()?.payout.coins == 540)
        #expect(state.stats.snakeRushes == 1)
        #expect(state.stats.snakeRushBestScore == 200)
        #expect(state.stats.snakeBestScore == 0)
    }
}
