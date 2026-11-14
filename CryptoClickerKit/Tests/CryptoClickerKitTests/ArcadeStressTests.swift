import Foundation
import Testing
@testable import CryptoClickerKit

/// Scam Invaders and Hash Smash played by a careless thumb: random moves, random firing, and
/// frames of every length (dropped frames, a long stall coming back from the background, and zero).
/// Whatever happens, every frame keeps the rules' invariants: nothing leaves the field or turns
/// into NaN, the score only climbs, lives and health stay in range, and a finished game stays
/// finished.
@Suite("Arcade stress")
struct ArcadeStressTests {
    /// A frame length: mostly 60 Hz, some 30 Hz, now and then a long stall or nothing at all.
    static func frame(_ rng: inout SeededGenerator) -> Double {
        switch Int.random(in: 0..<100, using: &rng) {
        case 0: 0
        case 1: 2.5
        case 2...4: 0.25
        case 5...25: 1.0 / 30
        default: 1.0 / 60
        }
    }

    static func finite(_ v: Vector2) -> Bool { v.x.isFinite && v.y.isFinite }

    @Test(arguments: ArcadeDifficulty.allCases)
    func scamInvadersHoldsTogether(difficulty: ArcadeDifficulty) {
        for style in InvadersGame.WaveStyle.allCases {
            for seed in UInt64(1)...12 {
                var rng = SeededGenerator(seed: seed &* 31 &+ 7)
                var game = InvadersGame(seed: seed, difficulty: difficulty, waves: style, startWave: Int(seed % 4) + 1)
                let label = "\(difficulty) \(style) seed \(seed)"
                var lastScore = 0, lastWave = game.wave, over = false, clock = 0.0
                var target = 0.5
                while clock < 600 {
                    if Int.random(in: 0..<30, using: &rng) == 0 { target = Double.random(in: -0.2...1.2, using: &rng) }
                    game.moveShip(to: target)
                    game.isFiring = Int.random(in: 0..<10, using: &rng) < 7
                    let dt = Self.frame(&rng)
                    game.update(by: dt)
                    clock += dt
                    #expect(game.score >= lastScore, "\(label): score fell")
                    #expect(game.wave >= lastWave, "\(label): wave went back")
                    #expect((0...InvadersGame.startingLives).contains(game.lives), "\(label): \(game.lives) lives")
                    #expect((0...(game.maxHealth + 1)).contains(game.health), "\(label): health \(game.health)")
                    #expect(game.shipX >= 0 && game.shipX <= InvadersGame.width, "\(label)")
                    #expect(game.shots.allSatisfy { Self.finite($0.position) && $0.position.y > -0.5 && $0.position.y < 2 }, "\(label)")
                    #expect(game.enemyShots.allSatisfy { Self.finite($0.position) && $0.position.y > -0.5 && $0.position.y < 2 }, "\(label)")
                    #expect(game.capsules.allSatisfy { Self.finite($0.position) }, "\(label)")
                    #expect(game.invaders.allSatisfy { game.frame(of: $0).minX.isFinite }, "\(label)")
                    #expect(game.firewalls.allSatisfy { $0.blocks.count == $0.rows * $0.columns }, "\(label)")
                    if over { #expect(game.phase == .over && game.score == lastScore, "\(label): came back after the end") }
                    if game.phase == .over {
                        over = true
                    } else {
                        #expect(game.health >= 1, "\(label): flying with no health")
                    }
                    lastScore = game.score
                    lastWave = game.wave
                    if over && Int.random(in: 0..<120, using: &rng) == 0 { break }
                }
            }
        }
    }

    @Test(arguments: ArcadeDifficulty.allCases)
    func hashSmashHoldsTogether(difficulty: ArcadeDifficulty) {
        for style in BrickBreakerGame.LevelStyle.allCases {
            for seed in UInt64(1)...12 {
                var rng = SeededGenerator(seed: seed &* 17 &+ 3)
                var game = BrickBreakerGame(seed: seed, difficulty: difficulty, levels: style, startLevel: Int(seed % 6) + 1)
                let label = "\(difficulty) \(style) seed \(seed)"
                var lastScore = 0, lastLevel = game.level, clock = 0.0, wasOver = false
                // A thumb that mostly follows the ball, and sometimes wanders off.
                while clock < 600 {
                    let follow = Int.random(in: 0..<10, using: &rng) < 8
                    game.movePaddle(to: follow ? game.ball.x + Double.random(in: -0.05...0.05, using: &rng)
                                               : Double.random(in: -0.2...1.2, using: &rng))
                    if game.phase == .serving && Int.random(in: 0..<20, using: &rng) == 0 { game.launch() }
                    let dt = Self.frame(&rng)
                    game.update(by: dt)
                    clock += dt
                    #expect(game.score >= lastScore, "\(label): score fell")
                    #expect(game.level >= lastLevel, "\(label): level went back")
                    #expect((0...BrickBreakerGame.startingLives).contains(game.lives), "\(label)")
                    #expect(game.balls.allSatisfy { Self.finite($0.position) && Self.finite($0.velocity) }, "\(label): NaN ball")
                    #expect(game.balls.allSatisfy { $0.position.x >= -0.01 && $0.position.x <= BrickBreakerGame.width + 0.01 && $0.position.y >= -0.01 },
                            "\(label): ball outside the field")
                    #expect(game.bricks.allSatisfy { (1...$0.maxHits).contains($0.hitsLeft) }, "\(label)")
                    #expect(game.paddle.minX >= -0.001 && game.paddle.maxX <= BrickBreakerGame.width + 0.001, "\(label): paddle off the field")
                    if wasOver { #expect(game.phase == .over && game.score == lastScore, "\(label): came back after the end") }
                    wasOver = game.phase == .over
                    lastScore = game.score
                    lastLevel = game.level
                    if wasOver { break }
                }
            }
        }
    }

    // The other arcade games, with random input: they run to the end without trouble, the score
    // only climbs (but for Pump and Dump's scams), and a finished game stays finished.

    @Test func hashChainHoldsTogether() {
        for mode in [SnakeGame.Mode.classic, .coinRush] {
            for arena in [SnakeGame.Arena.open, .pillars, .rooms, .cross] {
                for seed in UInt64(1)...6 {
                    var rng = SeededGenerator(seed: seed)
                    var game = SnakeGame(mode: mode, arena: arena, using: &rng)
                    var last = 0, wasOver = false
                    for _ in 0..<3_000 {
                        if Int.random(in: 0..<4, using: &rng) == 0 { game.turn(SnakeDirection.allCases.randomElement(using: &rng)!) }
                        game.step(using: &rng)
                        #expect(game.score >= last)
                        if wasOver { #expect(game.isOver && game.score == last) }
                        wasOver = game.isOver
                        last = game.score
                        if wasOver { break }
                    }
                }
            }
        }
    }

    @Test func blockChainHoldsTogether() {
        for seed in UInt64(1)...10 {
            var rng = SeededGenerator(seed: seed)
            var game = TetrisGame(mode: seed % 2 == 0 ? .endless : .sprint(lines: 20), using: &rng)
            var last = 0, moves = 0
            while !game.isOver && moves < 20_000 {
                moves += 1
                switch Int.random(in: 0..<10, using: &rng) {
                case 0...2: _ = game.moveLeft()
                case 3...5: _ = game.moveRight()
                case 6: _ = game.rotate(clockwise: Bool.random(using: &rng))
                case 7: game.softDrop(using: &rng)
                case 8: _ = game.hold(using: &rng)
                default: game.tick(using: &rng)
                }
                #expect(game.score >= last)
                last = game.score
            }
            #expect(game.isOver, "seed \(seed) never ended")
        }
    }

    @Test func bubbleMarketHoldsTogether() {
        for mode in [BubbleShooterGame.Mode.waves, .flash] {
            for seed in UInt64(1)...8 {
                var rng = SeededGenerator(seed: seed)
                var game = BubbleShooterGame(mode: mode, using: &rng)
                let cellCount = game.cells.count
                var last = 0, clock = 0.0, wasOver = false
                while clock < 900 {
                    if Int.random(in: 0..<20, using: &rng) == 0 { game.fire(angle: Double.random(in: -1.5...1.5, using: &rng), using: &rng) }
                    if Int.random(in: 0..<200, using: &rng) == 0 { game.swapBubbles() }
                    let dt = Self.frame(&rng)
                    game.update(by: dt, using: &rng)
                    clock += dt
                    #expect(game.score >= last && game.cells.count == cellCount)
                    if wasOver { #expect(game.isOver && game.score == last) }
                    wasOver = game.isOver
                    last = game.score
                    if wasOver { break }
                }
            }
        }
    }

    @Test func mergeMiningHoldsTogether() {
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            var game = Merge2048Game(seed: seed)
            var moves = 0
            while !game.isOver && moves < 5_000 {
                moves += 1
                let before = game.score
                if Int.random(in: 0..<40, using: &rng) == 0 {
                    _ = game.undo()
                } else {
                    _ = game.slide(SlideDirection.allCases.randomElement(using: &rng)!)
                    #expect(game.score >= before)
                }
                #expect(game.tiles.allSatisfy { $0.value > 0 })
                #expect(Set(game.tiles.map { "\($0.row),\($0.column)" }).count == game.tiles.count, "two tiles in one cell")
            }
        }
    }

    @Test func pumpAndDumpHoldsTogether() {
        for board in PumpDumpGame.Board.allCases {
            for speed in GameSpeed.allCases {
                var rng = SeededGenerator(seed: UInt64(board.rawValue) * 10 + UInt64(speed.factor * 10))
                var game = PumpDumpGame(board: board, speed: speed)
                var last = 0, clock = 0.0
                while !game.isOver && clock < 900 {
                    if Int.random(in: 0..<8, using: &rng) == 0 { _ = game.tap(hole: Int.random(in: -1...(board.rawValue * board.rawValue), using: &rng)) }
                    let dt = Self.frame(&rng)
                    game.advance(by: dt, using: &rng)
                    clock += dt
                    if game.phase != .playing && !game.isOver { game.startNextRound() }
                    // A scam costs its penalty (never below zero); nothing else takes points away.
                    #expect(game.score >= 0 && game.score >= last - PumpDumpGame.scamPenalty)
                    last = game.score
                }
                #expect(game.isOver, "\(board) \(speed) never ended")
            }
        }
    }

    @Test func tokenSwapHoldsTogether() {
        let size = TokenSwapGame.size
        func random(_ rng: inout SeededGenerator) -> (TokenSwapGame.Position, TokenSwapGame.Position) {
            let a = TokenSwapGame.Position(row: Int.random(in: 0..<size, using: &rng), column: Int.random(in: 0..<size, using: &rng))
            let horizontal = Bool.random(using: &rng)
            let b = TokenSwapGame.Position(row: min(size - 1, a.row + (horizontal ? 0 : 1)), column: min(size - 1, a.column + (horizontal ? 1 : 0)))
            return (a, b)
        }
        var games = (UInt64(1)...6).map { TokenSwapGame(seed: $0) }
        games += TokenSwapLevel.all.prefix(12).map { TokenSwapGame(level: $0, refillSeed: 9) }
        for (index, start) in games.enumerated() {
            var game = start
            var rng = SeededGenerator(seed: UInt64(index) + 50)
            var last = 0, tries = 0
            while !game.isOver && tries < 3_000 {
                tries += 1
                let (a, b) = random(&rng)
                _ = game.swap(a, b)
                _ = game.resolveAll()
                game.advance(by: Double.random(in: 0...2, using: &rng))
                #expect(game.score >= last, "game \(index)")
                #expect(game.cells.count == size && game.cells.allSatisfy { $0.count == size }, "game \(index)")
                last = game.score
            }
        }
    }
}
