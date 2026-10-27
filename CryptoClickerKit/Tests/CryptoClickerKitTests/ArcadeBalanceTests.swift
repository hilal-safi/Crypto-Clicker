import Foundation
import Testing
@testable import CryptoClickerKit

/// Simulated skilled players for every arcade game, to compare what a minute of play pays.
///
/// Each bot plays at a human pace (a Tetris piece a second, two 2048 moves a second, a Snake turn at
/// most every 0.2 s, a tap every 0.2 s with a 0.35 s reaction in Pump and Dump), so the numbers are
/// a strong player's, not a machine's. Token Swap's bot makes a swap every 1.2 s, and waits a quarter
/// second for each wave to clear. Pay is measured in seconds of idle income per minute played:
/// 60 means a minute of play earns as much again as a minute of mining (which carries on while you
/// play). Slower, less careful play earns roughly a quarter to a half as much.
///
/// The bots take a few minutes in a debug build, so they only run when asked:
/// `RUN_BALANCE_TESTS=1 swift test --filter ArcadeBalanceTests`.
@Suite("Arcade balance")
struct ArcadeBalanceTests {
    /// Points a skilled player scores per minute of play, averaged over a few games.
    static func pointsPerMinute(_ game: MiniGame) -> Double {
        let seeds: [UInt64] = [11, 22, 33, 44]
        let rates: [Double] = seeds.map { seed in
            switch game {
            case .tetris: TetrisBot.pointsPerMinute(seed: seed)
            case .merge2048: Merge2048Bot.pointsPerMinute(seed: seed)
            case .snake: SnakeBot.pointsPerMinute(seed: seed)
            case .brickBreaker: BrickBot.pointsPerMinute(seed: seed)
            case .bubbleBlaster: BubbleBot.pointsPerMinute(seed: seed)
            case .pumpDump: PumpDumpBot.pointsPerMinute(seed: seed)
            case .tokenSwap: TokenSwapBot.pointsPerMinute(seed: seed)
            case .blackjack, .slots, .moon, .videoPoker: 0
            }
        }
        return rates.reduce(0, +) / Double(rates.count)
    }

    /// Seconds of idle income a minute of skilled play pays (before the new-best bonus).
    static func incomePerMinute(_ game: MiniGame) -> Double {
        pointsPerMinute(game) * game.secondsPerPoint
    }

    @Test(arguments: [MiniGame.tetris, .merge2048, .snake, .brickBreaker, .bubbleBlaster, .pumpDump, .tokenSwap])
    func everyArcadeGamePaysAboutTheSame(_ game: MiniGame) {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let points = Self.pointsPerMinute(game)
        let income = points * game.secondsPerPoint
        print("Balance:", game.name, "| points/min", Int(points.rounded()), "| income seconds/min", Int(income.rounded()))
        // Every game pays a skilled player about two minutes of income for each minute played.
        #expect((90...160).contains(income), "\(game.name) pays \(income) seconds of income a minute")
    }
}

// MARK: - Bots

/// Places each piece where a classic heuristic likes it best (low, flat, few holes, lines cleared),
/// one piece a second.
enum TetrisBot {
    static let secondsPerPiece = 1.0

    static func pointsPerMinute(seed: UInt64, minutes: Double = 4) -> Double {
        var rng = SeededGenerator(seed: seed)
        var game = TetrisGame(using: &rng)
        var placed = 0
        while !game.isOver, Double(placed) * secondsPerPiece < minutes * 60 {
            guard let plan = bestPlacement(in: game) else { break }
            perform(plan, on: &game)
            game.hardDrop(using: &rng)
            placed += 1
        }
        return Double(game.rewardPoints) / (max(1, Double(placed)) * secondsPerPiece / 60)
    }

    struct Plan { let rotations: Int; let shift: Int }

    static func perform(_ plan: Plan, on game: inout TetrisGame) {
        for _ in 0..<plan.rotations { game.rotate() }
        for _ in 0..<abs(plan.shift) { _ = plan.shift < 0 ? game.moveLeft() : game.moveRight() }
    }

    static func bestPlacement(in game: TetrisGame) -> Plan? {
        var best: (plan: Plan, value: Double)?
        for rotations in 0..<4 {
            for shift in -6...6 {
                var copy = game
                var ok = true
                for _ in 0..<rotations where !copy.rotate() { ok = false }
                for _ in 0..<abs(shift) where !(shift < 0 ? copy.moveLeft() : copy.moveRight()) { ok = false }
                guard ok else { continue }
                var scratch = SeededGenerator(seed: 0)
                let linesBefore = copy.lines
                copy.hardDrop(using: &scratch)
                let value = copy.isOver ? -1e9 : evaluate(copy.board, lines: copy.lines - linesBefore)
                if value > (best?.value ?? -.infinity) { best = (Plan(rotations: rotations, shift: shift), value) }
            }
        }
        return best?.plan
    }

    static func evaluate(_ board: [Int], lines: Int) -> Double {
        let width = TetrisGame.width, height = TetrisGame.height
        var heights = Array(repeating: 0, count: width)
        var holes = 0
        for x in 0..<width {
            var seenBlock = false
            for y in 0..<height {
                if board[y * width + x] != 0 {
                    if !seenBlock { heights[x] = height - y; seenBlock = true }
                } else if seenBlock {
                    holes += 1
                }
            }
        }
        let bumpiness = zip(heights, heights.dropFirst()).reduce(0) { $0 + abs($1.0 - $1.1) }
        return -0.510066 * Double(heights.reduce(0, +)) + 0.760666 * Double(lines)
            - 0.35663 * Double(holes) - 0.184483 * Double(bumpiness)
    }
}

/// Plays 2048 by looking two moves ahead (expectimax over where the next tile appears), keeping big
/// tiles in a snake down the board toward the bottom-left corner. Two moves a second.
enum Merge2048Bot {
    static let movesPerSecond = 2.0
    typealias Board = [[Int]]
    static let weights: [[Double]] = [[0, 1, 2, 3], [7, 6, 5, 4], [8, 9, 10, 11], [15, 14, 13, 12]]
        .map { $0.map { pow(2.0, $0 / 2) } }

    static func pointsPerMinute(seed: UInt64, maxMoves: Int = 2_400) -> Double {
        var rng = SeededGenerator(seed: seed)
        var game = Merge2048Game(using: &rng)
        while !game.isOver && game.moves < maxMoves {
            guard let direction = bestMove(game.rows) else { break }
            game.slide(direction, using: &rng)
        }
        return Double(game.score) / (max(1, Double(game.moves)) / movesPerSecond / 60)
    }

    /// One row slid left: the new row and the points its merges scored.
    static func slideLeft(_ row: [Int]) -> ([Int], Int) {
        let tiles = row.filter { $0 != 0 }
        var result: [Int] = []
        var points = 0
        var index = 0
        while index < tiles.count {
            if index + 1 < tiles.count && tiles[index] == tiles[index + 1] {
                result.append(tiles[index] * 2)
                points += tiles[index] * 2
                index += 2
            } else {
                result.append(tiles[index])
                index += 1
            }
        }
        return (result + Array(repeating: 0, count: 4 - result.count), points)
    }

    static func transpose(_ board: Board) -> Board { (0..<4).map { column in (0..<4).map { board[$0][column] } } }

    static func slide(_ board: Board, _ direction: SlideDirection) -> (Board, Int)? {
        var rows: Board
        switch direction {
        case .left: rows = board
        case .right: rows = board.map { Array($0.reversed()) }
        case .up: rows = transpose(board)
        case .down: rows = transpose(board).map { Array($0.reversed()) }
        }
        var points = 0
        rows = rows.map { let (row, gained) = slideLeft($0); points += gained; return row }
        let result: Board = switch direction {
        case .left: rows
        case .right: rows.map { Array($0.reversed()) }
        case .up: transpose(rows)
        case .down: transpose(rows.map { Array($0.reversed()) })
        }
        return result == board ? nil : (result, points)
    }

    static func evaluate(_ board: Board) -> Double {
        var value = 0.0
        var empty = 0
        for row in 0..<4 {
            for column in 0..<4 {
                value += Double(board[row][column]) * weights[row][column]
                if board[row][column] == 0 { empty += 1 }
            }
        }
        return value + Double(empty) * 600
    }

    static func bestMove(_ board: Board) -> SlideDirection? {
        var best: (SlideDirection, Double)?
        for direction in SlideDirection.allCases {
            guard let (next, points) = slide(board, direction) else { continue }
            let value = chance(next, depth: 1) + Double(points)
            if value > (best?.1 ?? -.infinity) { best = (direction, value) }
        }
        return best?.0
    }

    /// The average value over where the next tile could appear, then the best move from there.
    static func chance(_ board: Board, depth: Int) -> Double {
        var cells: [(Int, Int)] = []
        for row in 0..<4 { for column in 0..<4 where board[row][column] == 0 { cells.append((row, column)) } }
        guard !cells.isEmpty else { return evaluate(board) }
        let sample = cells.count > 6 ? Array(cells.prefix(6)) : cells
        var total = 0.0
        for (row, column) in sample {
            for (value, odds) in [(2, 0.9), (4, 0.1)] {
                var next = board
                next[row][column] = value
                var bestValue = -1e12 // No move left: as bad as it gets.
                if depth > 0 {
                    for direction in SlideDirection.allCases {
                        guard let (after, points) = slide(next, direction) else { continue }
                        bestValue = max(bestValue, evaluate(after) + Double(points))
                    }
                } else {
                    bestValue = evaluate(next)
                }
                total += odds * bestValue
            }
        }
        return total / Double(sample.count)
    }
}

/// Heads for the coin along the shortest safe path, or for the most open space when there isn't one,
/// but like a person it can only turn once every 0.2 seconds, so the fastest snake catches it out.
/// Each life lasts until a crash or three minutes; a few seconds pass between games.
enum SnakeBot {
    static let turnGap = 0.2

    static func pointsPerMinute(seed: UInt64, games: Int = 3) -> Double {
        var rng = SeededGenerator(seed: seed)
        var points = 0
        var elapsed = 0.0
        for _ in 0..<games {
            var game = SnakeGame(using: &rng)
            var time = 0.0
            var lastTurn = -1.0
            while !game.isOver && time < 180 {
                if time - lastTurn >= turnGap, let direction = nextMove(in: game), direction != game.heading {
                    game.turn(direction)
                    lastTurn = time
                }
                time += game.tickInterval
                game.step(using: &rng)
            }
            points += game.score
            elapsed += time + 3
        }
        return Double(points) / (elapsed / 60)
    }

    static func neighbor(_ point: GridPoint, _ direction: SnakeDirection) -> GridPoint {
        switch direction {
        case .up: GridPoint(x: point.x, y: point.y - 1)
        case .down: GridPoint(x: point.x, y: point.y + 1)
        case .left: GridPoint(x: point.x - 1, y: point.y)
        case .right: GridPoint(x: point.x + 1, y: point.y)
        }
    }

    static func isOpen(_ point: GridPoint, blocked: Set<GridPoint>) -> Bool {
        (0..<SnakeGame.width).contains(point.x) && (0..<SnakeGame.height).contains(point.y) && !blocked.contains(point)
    }

    static func nextMove(in game: SnakeGame) -> SnakeDirection? {
        let blocked = Set(game.body.dropLast())
        let moves = SnakeDirection.allCases.filter { $0 != game.heading.opposite }
        if let food = game.food {
            // Breadth-first search from each first step.
            var queue: [(GridPoint, SnakeDirection)] = []
            var seen: Set<GridPoint> = [game.head]
            for move in moves {
                let next = neighbor(game.head, move)
                if isOpen(next, blocked: blocked) && seen.insert(next).inserted { queue.append((next, move)) }
            }
            var index = 0
            while index < queue.count {
                let (point, first) = queue[index]
                index += 1
                if point == food { return first }
                for direction in SnakeDirection.allCases {
                    let next = neighbor(point, direction)
                    if isOpen(next, blocked: blocked) && seen.insert(next).inserted { queue.append((next, first)) }
                }
            }
        }
        return moves.filter { isOpen(neighbor(game.head, $0), blocked: blocked) }
            .max { space(from: neighbor(game.head, $0), blocked: blocked) < space(from: neighbor(game.head, $1), blocked: blocked) }
    }

    static func space(from start: GridPoint, blocked: Set<GridPoint>) -> Int {
        var seen: Set<GridPoint> = [start]
        var stack = [start]
        while let point = stack.popLast() {
            for direction in SnakeDirection.allCases {
                let next = neighbor(point, direction)
                if isOpen(next, blocked: blocked) && seen.insert(next).inserted { stack.append(next) }
            }
        }
        return seen.count
    }
}

/// Keeps the paddle under the ball and meets it off center, sending it at a brick picked from those
/// left each time the ball comes down.
enum BrickBot {
    static func pointsPerMinute(seed: UInt64, minutes: Double = 3) -> Double {
        var rng = SeededGenerator(seed: seed)
        var game = BrickBreakerGame(seed: seed)
        let frame = 1.0 / 60
        var time = 0.0
        var target: Vector2?
        while game.phase != .over && time < minutes * 60 {
            if game.phase == .serving { game.launch() }
            if game.velocity.y < 0 {
                target = nil
            } else if target == nil, let brick = game.bricks.randomElement(using: &rng) {
                target = Vector2(x: brick.frame.minX + brick.frame.width / 2, y: brick.frame.minY + brick.frame.height / 2)
            }
            let aim = target ?? Vector2(x: 0.5, y: 0.3)
            // The angle that carries the ball from the paddle to the target, and the spot on the paddle that gives it.
            let angle = atan2(aim.x - game.ball.x, BrickBreakerGame.paddleTop - aim.y)
            let offset = min(max(angle / (Double.pi / 3), -0.85), 0.85)
            game.movePaddle(to: game.ball.x - offset * BrickBreakerGame.paddleWidth / 2)
            game.update(by: frame)
            time += frame
        }
        return Double(game.score) / (time / 60)
    }
}

/// Tries every aim and fires the shot that scores most, a shot every 1.8 seconds (aiming plus flight).
enum BubbleBot {
    static let secondsPerShot = 1.8

    static func pointsPerMinute(seed: UInt64, minutes: Double = 4) -> Double {
        var rng = SeededGenerator(seed: seed)
        var game = BubbleShooterGame(using: &rng)
        var shots = 0
        while !game.isOver && Double(shots) * secondsPerShot < minutes * 60 {
            let angle = bestAngle(in: game, using: &rng)
            game.fire(angle: angle, using: &rng)
            land(&game, using: &rng)
            shots += 1
        }
        return Double(game.score) / (max(1, Double(shots)) * secondsPerShot / 60)
    }

    static func land(_ game: inout BubbleShooterGame, using rng: inout SeededGenerator) {
        for _ in 0..<200 where game.shot != nil { game.update(by: 0.1, using: &rng) }
    }

    static func bestAngle(in game: BubbleShooterGame, using rng: inout SeededGenerator) -> Double {
        let low = BubbleShooterGame.minimumAngle, high = Double.pi - BubbleShooterGame.minimumAngle
        var best: [Double] = []
        var bestGain = -1
        for step in 0...40 {
            let angle = low + (high - low) * Double(step) / 40
            var copy = game
            var scratch = SeededGenerator(seed: 0)
            copy.fire(angle: angle, using: &scratch)
            land(&copy, using: &scratch)
            let gain = copy.isOver ? -2 : copy.score - game.score
            if gain > bestGain { best = [angle]; bestGain = gain } else if gain == bestGain { best.append(angle) }
        }
        return best.randomElement(using: &rng) ?? Double.pi / 2
    }
}

/// Taps coins 0.35 s after they appear, at most one tap every 0.2 s, and leaves scams and shaking
/// rug pulls alone. A round takes 30 seconds, plus about 3 to start the next.
enum PumpDumpBot {
    static let reaction = 0.35
    static let tapGap = 0.2
    static let secondsBetweenRounds = 3.0

    static func pointsPerMinute(seed: UInt64, rounds: Int = 4) -> Double {
        var rng = SeededGenerator(seed: seed)
        var total = 0
        for _ in 0..<rounds {
            var game = PumpDumpGame()
            var nextTap = 0.0
            while !game.isOver {
                game.advance(by: 1.0 / 60, using: &rng)
                guard game.time >= nextTap else { continue }
                let now = game.time
                let safe = game.targets.filter { target in
                    !target.isScam(at: now) && now - target.appearedAt >= reaction
                        && (target.turnsAt.map { $0 - now > reaction } ?? true)
                }
                if let target = safe.min(by: { $0.leavesAt < $1.leavesAt }) {
                    game.tap(hole: target.hole)
                    nextTap = now + tapGap
                }
            }
            total += game.score
        }
        let minutes = Double(rounds) * (PumpDumpGame.roundLength + secondsBetweenRounds) / 60
        return Double(total) / minutes
    }
}

/// Swaps where the board shows the biggest match (long and crossing matches first, lower on the
/// board for more falling waves), judged from the board alone, at a human pace: 1.2 seconds to spot
/// and make a swap, and a quarter second for each wave to clear.
enum TokenSwapBot {
    typealias Position = TokenSwapGame.Position
    static let secondsPerSwap = 1.2
    static let secondsPerWave = 0.25
    static let secondsBetweenRounds = 3.0

    static func pointsPerMinute(seed: UInt64, rounds: Int = 2) -> Double {
        var total = 0
        for round in 0..<rounds {
            var game = TokenSwapGame(seed: seed &* 31 &+ UInt64(round))
            while !game.isTimeUp {
                guard let (a, b) = bestSwap(in: game) else { break }
                game.advance(by: secondsPerSwap)
                guard game.swap(a, b) else { break }
                let waves = game.resolveAll()
                game.advance(by: Double(waves.count) * secondsPerWave)
            }
            total += game.score
        }
        let minutes = Double(rounds) * (TokenSwapGame.roundLength + secondsBetweenRounds) / 60
        return Double(total) / minutes
    }

    static func bestSwap(in game: TokenSwapGame) -> (Position, Position)? {
        var best: (swap: (Position, Position), value: Double)?
        for (a, b) in game.validSwaps {
            var copy = game
            guard copy.swap(a, b), let wave = copy.resolveStep() else { continue }
            let value = Double(wave.cleared.count) + Double(wave.madeBlasts.count) * 4 + Double(max(a.row, b.row)) * 0.1
            if value > best?.value ?? -1 { best = ((a, b), value) }
        }
        return best?.swap
    }
}
