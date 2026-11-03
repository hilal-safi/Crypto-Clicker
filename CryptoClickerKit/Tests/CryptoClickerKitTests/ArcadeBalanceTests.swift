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
            case .invaders: InvadersBot.pointsPerMinute(seed: seed)
            case .blackjack, .slots, .moon, .videoPoker: 0
            }
        }
        return rates.reduce(0, +) / Double(rates.count)
    }

    /// Seconds of idle income a minute of skilled play pays (before the new-best bonus).
    static func incomePerMinute(_ game: MiniGame) -> Double {
        pointsPerMinute(game) * game.secondsPerPoint
    }

    /// Snake's Coin Rush and its walled arenas pay about what Classic in the open does.
    @Test func snakeModesPayAboutTheSame() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let seeds: [UInt64] = [11, 22, 33, 44]
        func income(_ mode: SnakeGame.Mode, _ arena: SnakeGame.Arena) -> Double {
            let points = seeds.map { SnakeBot.pointsPerMinute(seed: $0, mode: mode, arena: arena) }.reduce(0, +) / Double(seeds.count)
            return points * MiniGame.snake.secondsPerPoint * (mode == .coinRush ? Tuning.snakeCoinRushPay : 1)
        }
        for arena in SnakeGame.Arena.allCases {
            let classic = income(.classic, arena)
            print("Balance: Snake", arena.name, "| income seconds/min", Int(classic.rounded()))
            #expect((90...160).contains(classic), "Snake in \(arena.name) pays \(classic)")
        }
        let rush = income(.coinRush, .open)
        print("Balance: Snake Coin Rush | income seconds/min", Int(rush.rounded()))
        #expect((90...160).contains(rush), "Coin Rush pays \(rush)")
    }

    /// Brick Breaker's random walls pay about what the classic ones do, and the Speed option moves
    /// the pay a little either way: Fast scores quicker, Slow slower.
    @Test func brickBreakerOptionsPayAboutTheSame() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let seeds: [UInt64] = [11, 22, 33, 44, 55, 66]
        func income(_ levels: BrickBreakerGame.LevelStyle, _ speed: GameSpeed) -> Double {
            let points = seeds.map { BrickBot.pointsPerMinute(seed: $0, levels: levels, speed: speed) }.reduce(0, +) / Double(seeds.count)
            return points * MiniGame.brickBreaker.secondsPerPoint
        }
        let classic = income(.classic, .normal)
        let random = income(.generated, .normal)
        let slow = income(.classic, .slow)
        let fast = income(.classic, .fast)
        print("Balance: Brick Breaker | classic", Int(classic), "random", Int(random), "slow", Int(slow), "fast", Int(fast))
        #expect((90...160).contains(random), "Random walls pay \(random)")
        #expect(abs(random - classic) <= 0.25 * classic)
        #expect(slow < classic && fast > classic)
        #expect(fast <= 1.5 * classic)
    }

    /// Scam Invaders' Speed option moves the pay a little either way, like Brick Breaker's.
    @Test func invadersSpeedsPayAboutTheSame() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let seeds: [UInt64] = [11, 22, 33, 44]
        func income(_ speed: GameSpeed) -> Double {
            let points = seeds.map { InvadersBot.pointsPerMinute(seed: $0, speed: speed) }.reduce(0, +) / Double(seeds.count)
            return points * MiniGame.invaders.secondsPerPoint
        }
        let normal = income(.normal), slow = income(.slow), fast = income(.fast)
        print("Balance: Scam Invaders | normal", Int(normal), "slow", Int(slow), "fast", Int(fast))
        #expect(slow < normal && fast > normal * 0.9)
        #expect(fast <= 1.6 * normal)
    }

    @Test(arguments: [MiniGame.tetris, .merge2048, .snake, .brickBreaker, .bubbleBlaster, .pumpDump, .tokenSwap, .invaders])
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
            game.slide(direction)
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
/// Heads for the nearest coin by the shortest path that leaves the snake room, steering like a quick
/// thumb: two swipes in a row at most (the game queues them), then one more every 0.2 s. With no
/// coin in reach it heads for the most open space.
enum SnakeBot {
    static let turnGap = 0.2
    static let swipeBurst = 2.0

    static func pointsPerMinute(seed: UInt64, games: Int = 3, mode: SnakeGame.Mode = .classic,
                                arena: SnakeGame.Arena = .open) -> Double {
        var rng = SeededGenerator(seed: seed)
        var points = 0
        var elapsed = 0.0
        for _ in 0..<games {
            var game = SnakeGame(mode: mode, arena: arena, using: &rng)
            var time = 0.0
            var swipes = swipeBurst
            while !game.isOver && time < 180 {
                let path = route(in: game)
                if swipes >= 1, let first = path.first, first != game.heading {
                    game.turn(first)
                    swipes -= 1
                    if swipes >= 1, path.count > 1, path[1] != first {
                        game.turn(path[1])
                        swipes -= 1
                    }
                }
                let tick = game.tickInterval
                time += tick
                swipes = min(swipeBurst, swipes + tick / turnGap)
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

    /// The first move toward the nearest coin, or toward the most open space.
    static func nextMove(in game: SnakeGame) -> SnakeDirection? {
        route(in: game).first
    }

    /// The moves along the shortest path to the nearest coin, or one move toward the most open space.
    static func route(in game: SnakeGame) -> [SnakeDirection] {
        let blocked = Set(game.body.dropLast()).union(game.walls)
        let moves = SnakeDirection.allCases.filter { $0 != game.heading.opposite }
        let coins = Set(game.coins)
        if !coins.isEmpty {
            // Breadth-first search, remembering how each cell was reached.
            var cameFrom: [GridPoint: (GridPoint, SnakeDirection)] = [:]
            var queue: [GridPoint] = []
            var seen: Set<GridPoint> = [game.head]
            for move in moves {
                let next = neighbor(game.head, move)
                if isOpen(next, blocked: blocked) && seen.insert(next).inserted {
                    cameFrom[next] = (game.head, move)
                    queue.append(next)
                }
            }
            var index = 0
            while index < queue.count {
                let point = queue[index]
                index += 1
                if coins.contains(point) { // The nearest coin: walk back to the head.
                    var path: [SnakeDirection] = []
                    var cell = point
                    while let (previous, move) = cameFrom[cell] {
                        path.append(move)
                        cell = previous
                    }
                    path.reverse()
                    // Only if the first step leaves room for the whole snake; otherwise find space.
                    guard let first = path.first,
                          space(from: neighbor(game.head, first), blocked: blocked) >= game.body.count else { break }
                    return path
                }
                for direction in SnakeDirection.allCases {
                    let next = neighbor(point, direction)
                    if isOpen(next, blocked: blocked) && seen.insert(next).inserted {
                        cameFrom[next] = (point, direction)
                        queue.append(next)
                    }
                }
            }
        }
        let open = moves.filter { isOpen(neighbor(game.head, $0), blocked: blocked) }
            .max { space(from: neighbor(game.head, $0), blocked: blocked) < space(from: neighbor(game.head, $1), blocked: blocked) }
        return open.map { [$0] } ?? []
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
    static func pointsPerMinute(seed: UInt64, minutes: Double = 3, levels: BrickBreakerGame.LevelStyle = .classic,
                                speed: GameSpeed = .normal) -> Double {
        var rng = SeededGenerator(seed: seed)
        var game = BrickBreakerGame(seed: seed, speed: speed, levels: levels)
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
/// rug pulls alone. Plays whole runs, round after round until one falls short of its goal. A round
/// takes 30 seconds, plus about 3 to start the next.
enum PumpDumpBot {
    static let reaction = 0.35
    static let tapGap = 0.2
    static let secondsBetweenRounds = 3.0

    static func pointsPerMinute(seed: UInt64, runs: Int = 2, maxRounds: Int = 12) -> Double {
        var rng = SeededGenerator(seed: seed)
        var total = 0
        var rounds = 0
        for _ in 0..<runs {
            let game = play(using: &rng, maxRounds: maxRounds)
            total += game.score
            rounds += game.round
        }
        let minutes = Double(rounds) * (PumpDumpGame.roundLength + secondsBetweenRounds) / 60
        return Double(total) / minutes
    }

    static func play<R: RandomNumberGenerator>(using rng: inout R, maxRounds: Int = 12) -> PumpDumpGame {
        var game = PumpDumpGame()
        while true {
            var nextTap = 0.0
            while game.phase == .playing {
                game.advance(by: 1.0 / 60, using: &rng)
                guard game.phase == .playing, game.time >= nextTap else { continue }
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
            guard game.phase == .roundCleared, game.round < maxRounds else { return game }
            game.startNextRound()
        }
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
            let made = Double(wave.made.count) * 4
            let value = Double(wave.cleared.count) + made + Double(max(a.row, b.row)) * 0.1
            if value > best?.value ?? -1 { best = ((a, b), value) }
        }
        return best?.swap
    }
}

/// Moves under the column whose lowest invader is nearest to landing (or leads the whale when one
/// is crossing), fires while something is overhead with no firewall in the way, and sidesteps shots
/// about to land on it, holding the dodge until they've passed. It picks a new target five times a
/// second and drags the ship at a finger's pace.
enum InvadersBot {
    static let shipSpeed = 1.4
    static let thinkEvery = 0.2
    static let dodgeTime = 0.45

    static func pointsPerMinute(seed: UInt64, minutes: Double = 3, speed: GameSpeed = .normal) -> Double {
        var game = InvadersGame(seed: seed, speed: speed)
        let time = play(&game, seconds: minutes * 60)
        return Double(game.score) / (time / 60)
    }

    /// Plays until the game ends or `seconds` have passed, and returns the seconds played.
    @discardableResult
    static func play(_ game: inout InvadersGame, seconds: Double) -> Double {
        let frame = 1.0 / 60
        var time = 0.0
        var target = 0.5
        var think = 0.0
        var dodge: (x: Double, until: Double)?
        while game.phase != .over && time < seconds {
            think -= frame
            if think <= 0 {
                think = thinkEvery
                target = aim(in: game)
            }
            if let current = dodge, current.until <= time { dodge = nil }
            if dodge == nil, let escape = escape(in: game) { dodge = (escape, time + dodgeTime) }
            let goal = dodge?.x ?? target
            let dx = goal - game.shipX
            game.moveShip(to: game.shipX + (dx < 0 ? -1 : 1) * min(abs(dx), shipSpeed * frame))
            game.isFiring = hasTarget(above: game.shipX, in: game) && !isBlocked(game.shipX, in: game)
            game.update(by: frame)
            time += frame
        }
        return time
    }

    /// Where to line up: ahead of a crossing whale, or under the lowest invader, at a spot where no
    /// firewall block is in the way (if there is one).
    static func aim(in game: InvadersGame) -> Double {
        if let whale = game.whale {
            let lead = whale.position.x + whale.speedX * game.gameSpeed.factor * flightTime(to: whale.position.y, in: game)
            if (0.08...0.92).contains(lead) { return lead }
        }
        let lowest = Dictionary(grouping: game.invaders, by: \.column).compactMap { $0.value.max { $0.row < $1.row } }
            .sorted { $0.column < $1.column }
        let pick = lowest.max { a, b in
            let fa = game.frame(of: a), fb = game.frame(of: b)
            return fa.maxY == fb.maxY ? abs(fa.midX - game.shipX) > abs(fb.midX - game.shipX) : fa.maxY < fb.maxY
        }
        if let pick {
            let frame = game.frame(of: pick)
            for offset in [0, -0.018, 0.018, -0.009, 0.009] where !isBlocked(frame.midX + offset, in: game) {
                return frame.midX + offset
            }
            return frame.midX
        }
        if let boss = game.boss { return boss.frame.midX }
        return 0.5
    }

    static func flightTime(to y: Double, in game: InvadersGame) -> Double {
        (InvadersGame.shipTop - y) / (InvadersGame.shotSpeed * game.gameSpeed.factor)
    }

    /// Something a shot fired from `x` now would hit: an invader overhead, the boss, or the whale
    /// where it will be when the shot gets there.
    static func hasTarget(above x: Double, in game: InvadersGame) -> Bool {
        if game.invaders.contains(where: { let f = game.frame(of: $0); return x > f.minX + 0.008 && x < f.maxX - 0.008 }) {
            return true
        }
        if let boss = game.boss, x > boss.frame.minX, x < boss.frame.maxX { return true }
        if let whale = game.whale {
            let there = whale.position.x + whale.speedX * game.gameSpeed.factor * flightTime(to: whale.position.y, in: game)
            if abs(there - x) < InvadersGame.Whale.size.width / 2 - 0.01 { return true }
        }
        return false
    }

    static func isBlocked(_ x: Double, in game: InvadersGame) -> Bool {
        game.firewalls.contains { wall in
            (0..<InvadersGame.Firewall.rows).contains { row in
                (0..<InvadersGame.Firewall.columns).contains { column in
                    let block = wall.blockFrame(row: row, column: column)
                    return wall.isStanding(row: row, column: column) && x + 0.005 > block.minX && x - 0.005 < block.maxX
                }
            }
        }
    }

    /// A spot to the side when an invader's shot is about to land on the ship, away from the shot
    /// and clear of any other.
    static func escape(in game: InvadersGame) -> Double? {
        let incoming = game.enemyShots.filter { $0.position.y > 0.95 && $0.position.y < InvadersGame.shipTop + 0.02 }
        func landing(_ shot: InvadersGame.EnemyShot) -> Double {
            shot.position.x + shot.velocity.x * max(0, InvadersGame.shipTop - shot.position.y) / max(shot.velocity.y, 0.01)
        }
        func isSafe(_ x: Double) -> Bool { incoming.allSatisfy { abs(landing($0) - x) > 0.08 } }
        guard !isSafe(game.shipX) else { return nil }
        let options = [0.13, -0.13, 0.22, -0.22, 0.3, -0.3].map { game.shipX + $0 }.filter { (0.06...0.94).contains($0) }
        return options.first(where: isSafe) ?? options.first
    }
}
