import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Token Swap: random levels")
struct TokenSwapRandomLevelTests {
    static let difficulties: [TokenSwapLevel.Difficulty] = [.easy, .medium, .hard]

    @Test func randomLevelsAreWellFormed() {
        for difficulty in Self.difficulties {
            for seed in UInt64(1)...150 {
                let level = TokenSwapLevel.generated(seed: seed, difficulty: difficulty)
                let label = "\(difficulty.name) \(seed): \(level.name)"
                #expect(level.difficulty == difficulty, "\(label)")
                #expect((5...6).contains(level.kinds), "\(label)")
                #expect((14...36).contains(level.moves), "\(label)")
                #expect(level.layout.isEmpty || (level.layout.count == 8 && level.layout.allSatisfy { $0.count == 8 }), "\(label)")
                #expect(level.layout.joined().allSatisfy { ".iIcxX#g".contains($0) }, "\(label)")
                // Mirrored left to right, like the hand-made boards.
                #expect(level.layout.allSatisfy { String($0.reversed()) == $0 }, "\(label)")
                #expect(level.starScores.count == 2 && level.starScores[0] < level.starScores[1], "\(label)")
                #expect(!level.goals.isEmpty && level.goals.count <= 2 && !level.tip.isEmpty, "\(label)")
                if difficulty == .easy { #expect(level.goals.count == 1, "\(label)") }
                if difficulty == .hard { #expect(level.goals.count == 2, "\(label)") }
                let counts = level.obstacleCounts
                for goal in level.goals {
                    #expect(goal.target > 0, "\(label)")
                    switch goal {
                    case .ice(let count): #expect(counts.ice == count, "\(label)")
                    case .chains(let count): #expect(counts.chains == count, "\(label)")
                    case .crates(let count): #expect(counts.crates == count, "\(label)")
                    case .gold(let count): #expect(counts.gold + level.goldToDrop == count && counts.gold >= 1, "\(label)")
                    case .tokens(let kind, _): #expect(kind < level.kinds, "\(label)")
                    case .specials, .score: break
                    }
                }
            }
        }
    }

    @Test func theSameSeedMakesTheSameLevelAndSeedsDiffer() {
        let one = TokenSwapLevel.generated(seed: 42, difficulty: .medium)
        #expect(one == TokenSwapLevel.generated(seed: 42, difficulty: .medium))
        // A hundred seeds make plenty of different levels: goals, boards and move counts.
        let levels = (UInt64(1)...100).map { TokenSwapLevel.generated(seed: $0, difficulty: .medium) }
        let shapes = Set(levels.map { "\($0.goals)|\($0.layout)|\($0.moves)" })
        // (Every seed also deals its own starting board, so even these differ in play.)
        #expect(shapes.count >= 80)
        let goalKinds = Set(levels.flatMap(\.goals).map { goal -> String in
            switch goal {
            case .tokens: "tokens"
            case .ice: "ice"
            case .chains: "chains"
            case .crates: "crates"
            case .gold: "gold"
            case .specials: "specials"
            case .score: "score"
            }
        })
        #expect(goalKinds.count == 7)
        // The same seed at another difficulty is another level.
        #expect(TokenSwapLevel.generated(seed: 42, difficulty: .hard) != one)
    }

    /// A player who always takes the hint wins most easy levels and a fair share of hard ones.
    @Test(arguments: [TokenSwapLevel.Difficulty.easy, .medium, .hard])
    func randomLevelsCanBeWon(difficulty: TokenSwapLevel.Difficulty) {
        var wins = 0, twoStars = 0
        let seeds = UInt64(1)...24
        for seed in seeds {
            let level = TokenSwapLevel.generated(seed: seed, difficulty: difficulty)
            let game = TokenSwapLevelBalanceTests.playByHints(level, seed: seed &* 7_919)
            #expect(game.phase != .playing)
            if game.phase == .won {
                wins += 1
                if level.stars(won: true, score: game.score) >= 2 { twoStars += 1 }
            }
        }
        print("Random \(difficulty.name): won \(wins) of \(seeds.count), \(twoStars) with two stars or more")
        let needed = switch difficulty {
        case .easy: 18
        case .medium: 14
        case .hard: 9
        }
        #expect(wins >= needed, "\(difficulty.name) won \(wins) of \(seeds.count)")
        #expect(twoStars >= 1)
    }

    @Test func aRandomLevelPaysItsPointsAndAWinBonus() {
        var game = GameState.make(miners: minersEarning(10)) // 10 coins a second.
        let level = TokenSwapLevel.generated(seed: 3, difficulty: .hard)
        let points = (2_000 * Tuning.tokenSwapSecondsPerPoint * 10).rounded()
        let bonus = game.tokenSwapRandomWinBonus(.hard)
        #expect(bonus == (Tuning.tokenSwapRandomWinSeconds * 2 * 10).rounded())
        let won = game.finishTokenSwapRandom(level, won: true, score: 2_000, tokens: 90, bestChain: 3, specials: 2)
        #expect(won == points + bonus)
        // A loss pays its points, with no bonus.
        let lost = game.finishTokenSwapRandom(level, won: false, score: 2_000, tokens: 40, bestChain: 1, specials: 0)
        #expect(lost == points)
        #expect(game.stats.tokenSwapRandomPlayed == 2 && game.stats.tokenSwapRandomWins == 1)
        #expect(game.stats.tokenSwapLevelsPlayed == 2 && game.stats.tokenSwapLevelWins == 1)
        #expect(game.stats.tokenSwapTokens == 130)
        // Random levels never touch the hand-made levels' stars.
        #expect(game.tokenSwap.totalStars == 0)
        #expect(game.stats.earnedFromGames == won + lost)
    }
}

@Suite("Brick Breaker: options")
struct BrickBreakerOptionTests {
    @Test func theSpeedOptionScalesTheBall() {
        let normal = BrickBreakerGame(seed: 1)
        let slow = BrickBreakerGame(seed: 1, speed: .slow)
        let fast = BrickBreakerGame(seed: 1, speed: .fast)
        #expect(abs(slow.speed - normal.speed * 0.75) < 1e-9)
        #expect(abs(fast.speed - normal.speed * 1.3) < 1e-9)
        var launched = fast
        launched.launch()
        #expect(abs(launched.velocity.length - fast.speed) < 1e-9)
    }

    @Test func randomWallsAreMirroredWallsOfAFairSize() {
        var classicHits = 0, generatedHits = 0
        var bonusCounts = Set<Int>(), firstLevelBonus = Set<Int>()
        for seed in UInt64(1)...40 {
            var game = BrickBreakerGame(seed: seed, levels: .generated)
            var classic = BrickBreakerGame(seed: seed)
            for level in 1...12 where level % BrickBreakerGame.bossEvery != 0 {
                game.jump(toLevel: level)
                classic.jump(toLevel: level)
                let cells = Set(game.bricks.map { "\($0.row),\($0.column)" })
                #expect(game.bricks.count >= 2 * BrickBreakerGame.columns, "seed \(seed) level \(level)")
                #expect(game.bricks.allSatisfy { (0..<8).contains($0.row) && (0..<BrickBreakerGame.columns).contains($0.column) })
                #expect(game.bricks.allSatisfy { cells.contains("\($0.row),\(BrickBreakerGame.columns - 1 - $0.column)") },
                        "seed \(seed) level \(level) isn't mirrored")
                // Specials from the very first level: one to a few bonus bricks.
                let bonus = game.bricks.filter { $0.kind == .bonus }.count
                #expect((1...max(3, 2 + level / 2)).contains(bonus), "seed \(seed) level \(level): \(bonus) bonus")
                bonusCounts.insert(bonus)
                if level == 1 { firstLevelBonus.insert(bonus) }
                let hits = game.bricks.reduce(0) { $0 + $1.maxHits }
                if level > 1 { #expect(Double(hits) >= 0.45 * Double(BrickBreakerGame.fullWallHits(level: level)), "seed \(seed) level \(level)") }
                generatedHits += hits
                classicHits += classic.bricks.reduce(0) { $0 + $1.maxHits }
            }
        }
        // Made-up walls take about as many hits as the classic ones, level for level.
        print("Hits: generated \(generatedHits), classic \(classicHits)")
        #expect(Double(generatedHits) >= 0.9 * Double(classicHits) && Double(generatedHits) <= 1.2 * Double(classicHits))
        #expect(firstLevelBonus == [1, 2, 3])
        #expect(bonusCounts.count >= 6)
    }

    @Test func randomWallsAreRarelyTheSame() {
        var layouts = Set<String>()
        for seed in UInt64(1)...30 {
            var game = BrickBreakerGame(seed: seed, levels: .generated)
            game.jump(toLevel: 3)
            layouts.insert(game.bricks.map { "\($0.row),\($0.column)" }.sorted().joined(separator: " "))
        }
        #expect(layouts.count >= 25)
        // Classic walls are the same every game.
        var classic = Set<String>()
        for seed in UInt64(1)...30 {
            var game = BrickBreakerGame(seed: seed)
            game.jump(toLevel: 3)
            classic.insert(game.bricks.map { "\($0.row),\($0.column)" }.sorted().joined(separator: " "))
        }
        #expect(classic.count == 1)
        // Bosses stay bosses.
        var boss = BrickBreakerGame(seed: 5, levels: .generated)
        boss.jump(toLevel: 5)
        #expect(boss.boss != nil)
    }
}

@Suite("Game speed")
struct GameSpeedTests {
    @Test func snakeAndTetrisFollowTheSpeedOption() {
        var rng = SeededGenerator(seed: 1)
        let normal = SnakeGame(using: &rng)
        let slow = SnakeGame(speed: .slow, using: &rng)
        let fast = SnakeGame(speed: .fast, using: &rng)
        #expect(abs(slow.tickInterval - normal.tickInterval / 0.75) < 1e-9)
        #expect(abs(fast.tickInterval - normal.tickInterval / 1.3) < 1e-9)
        #expect(fast.tickInterval >= 0.065)
        let tetris = TetrisGame(using: &rng)
        let quick = TetrisGame(speed: .fast, using: &rng)
        let relaxed = TetrisGame(speed: .slow, using: &rng)
        #expect(abs(quick.gravityInterval - tetris.gravityInterval / 1.3) < 1e-9)
        #expect(abs(relaxed.gravityInterval - tetris.gravityInterval / 0.75) < 1e-9)
        #expect(GameSpeed.allCases.map(\.factor) == [0.75, 1, 1.3])
    }
}
