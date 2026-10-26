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
}
