import Foundation
import Testing
@testable import CryptoClickerKit

/// Boards for these tests are drawn as rows of characters: a digit is a token of that kind, and
/// `.` is filler (kinds 1 to 5, laid out so no three ever line up and no square forms). Kind 0
/// appears only where a test puts it, so only those tokens can match.
enum SwapBoards {
    typealias Position = TokenSwapGame.Position

    static func at(_ row: Int, _ column: Int) -> Position { Position(row: row, column: column) }

    static func filler(_ row: Int, _ column: Int) -> Int { 1 + (row + 2 * column) % 5 }

    static func kinds(_ rows: [String]) -> [[Int]] {
        (0..<8).map { row in
            let line = row < rows.count ? Array(rows[row]) : []
            return (0..<8).map { column in
                let mark = column < line.count ? line[column] : "."
                if mark == "g" { return -1 }
                return mark.wholeNumberValue ?? filler(row, column)
            }
        }
    }

    /// A Classic game on a drawn board, with specials where asked.
    static func classic(_ rows: [String], powers: [Position: TokenSwapGame.Power] = [:], seed: UInt64 = 1) -> TokenSwapGame {
        var game = TokenSwapGame(seed: seed)
        game.place(kinds(rows), powers: powers)
        return game
    }

    /// A level game with these goals on a drawn board.
    static func level(_ rows: [String], goals: [TokenSwapGame.Goal], moves: Int = 20,
                      powers: [Position: TokenSwapGame.Power] = [:]) -> TokenSwapGame {
        let level = TokenSwapLevel(id: 1, name: "Test", difficulty: .easy, seed: 9, kinds: 6, moves: moves,
                                   goals: goals, starScores: [1_000, 2_000], tip: "")
        var game = TokenSwapGame(level: level, refillSeed: 3)
        game.place(kinds(rows), powers: powers)
        return game
    }

    static let plain: [String] = []
}

@Suite("Token Swap: matching")
struct TokenSwapMatchingTests {
    typealias Position = TokenSwapGame.Position
    let at = SwapBoards.at

    @Test func aNewBoardHasNoMatchesAndAMoveToMake() {
        for seed in 0..<40 {
            let game = TokenSwapGame(seed: UInt64(seed))
            #expect(!TokenSwapGame.hasMatch(in: game.cells))
            #expect(game.hasMove)
            #expect(Set(game.cells.joined().compactMap(\.tile?.id)).count == 64)
            #expect(game.score == 0 && game.timeLeft == TokenSwapGame.roundLength)
        }
        // The same seed deals the same board.
        #expect(TokenSwapGame(seed: 7).cells == TokenSwapGame(seed: 7).cells)
        // The filler used by these tests never matches by itself.
        #expect(!TokenSwapGame.hasMatch(in: SwapBoards.classic(SwapBoards.plain).cells))
    }

    @Test func onlyMovesAreAllowed() {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "00......"])
        let noMatch = game.swap(at(0, 0), at(0, 1))
        #expect(!noMatch)
        let notNeighbors = game.swap(at(6, 2), at(7, 3))
        #expect(!notNeighbors)
        let offBoard = game.swap(at(7, 7), at(7, 8))
        #expect(!offBoard)
        #expect(game.moves == 0)
        let before = game.cells
        let valid = game.swap(at(6, 2), at(7, 2))
        #expect(valid)
        #expect(game.moves == 1)
        #expect(game.isResolving)
        let whileResolving = game.swap(at(0, 0), at(1, 0))
        #expect(!whileResolving)
        // The swapped tiles traded places.
        #expect(game.cell(at: at(7, 2)).tile?.id == before[6][2].tile?.id)
        #expect(game.cell(at: at(6, 2)).tile?.id == before[7][2].tile?.id)
    }

    @Test func threeInARowClearsAndTheTilesAboveFall() throws {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "00......"])
        let above = game.cells[5]
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let firstWave = game.resolveStep()
        let first = try #require(firstWave)
        #expect(first.cleared == [at(7, 0), at(7, 1), at(7, 2)])
        #expect(first.chain == 1)
        #expect(first.points == 30)
        #expect(first.made.isEmpty)
        // Row 6 fell into row 7 (the filler swapped up to (6, 2) went too), and row 5 into row 6.
        #expect(game.cell(at: at(6, 0)).tile?.id == above[0].tile?.id)
        game.resolveAll()
        #expect(!game.isResolving)
        #expect(!TokenSwapGame.hasMatch(in: game.cells))
        #expect(game.hasMove)
        #expect(Set(game.cells.joined().compactMap(\.tile?.id)).count == 64)
        #expect(game.tokensCleared >= 3)
    }

    @Test func aSecondWaveDoublesItsPoints() throws {
        // Swapping a 0 into (6, 3) lines up column 3; the 1 above it then falls to (7, 3), between
        // the 1s at (7, 2) and (7, 4): a second wave, scoring double.
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "...1....",
                                       "...0....",
                                       "....0...",
                                       "..101..."])
        #expect(!TokenSwapGame.hasMatch(in: game.cells))
        let swapped = game.swap(at(6, 4), at(6, 3))
        #expect(swapped)
        let firstWave = game.resolveStep()
        let first = try #require(firstWave)
        #expect(first.cleared == [at(5, 3), at(6, 3), at(7, 3)])
        #expect(first.points == 30)
        let secondWave = game.resolveStep()
        let second = try #require(secondWave)
        #expect(second.chain == 2)
        #expect(Set([at(7, 2), at(7, 3), at(7, 4)]).isSubset(of: Set(second.cleared)))
        #expect(second.points == second.cleared.count * TokenSwapGame.pointsPerToken * 2)
        game.resolveAll()
        #expect(game.bestChain >= 2)
        #expect(game.score >= 30 + second.points)
    }
}

@Suite("Token Swap: making specials")
struct TokenSwapPatternTests {
    typealias Position = TokenSwapGame.Position
    let at = SwapBoards.at

    @Test func fourAcrossMakesARocketAcrossWhereThePlayerMoved() throws {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "00.0...."])
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.made == [at(7, 2): .rocketAcross])
        #expect(step.cleared == [at(7, 0), at(7, 1), at(7, 3)])
        #expect(step.points == 30)
        let rocket = try #require(game.cell(at: at(7, 2)).tile)
        #expect(rocket.power == .rocketAcross)
        #expect(rocket.kind == 0)
        #expect(game.specialsMade == 1)
    }

    @Test func fourDownMakesARocketDown() throws {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "0.......",
                                       "0.......",
                                       ".0......",
                                       "0......."])
        let swapped = game.swap(at(6, 1), at(6, 0))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.made == [at(6, 0): .rocketDown])
        #expect(step.cleared == [at(4, 0), at(5, 0), at(7, 0)])
    }

    @Test func fiveInARowMakesAColorClear() throws {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "00.00..."])
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.made == [at(7, 2): .colorClear])
        #expect(step.cleared.count == 4)
        let clear = try #require(game.cell(at: at(7, 2)).tile)
        #expect(clear.power == .colorClear)
        #expect(clear.kind == nil) // A Color Clear has no color.
    }

    @Test func anLMakesABombAtTheCorner() throws {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "..0.....",
                                       "...00...",
                                       "..0....."])
        let swapped = game.swap(at(7, 2), at(6, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.made == [at(6, 2): .bomb])
        #expect(step.cleared == [at(4, 2), at(5, 2), at(6, 3), at(6, 4)])
    }

    @Test func aTMakesABomb() throws {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "..0.....",
                                       ".0.0....",
                                       "..0....."])
        let swapped = game.swap(at(7, 2), at(6, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.made == [at(6, 2): .bomb])
        #expect(step.cleared == [at(4, 2), at(5, 2), at(6, 1), at(6, 3)])
    }

    @Test func aSquareMakesAPropeller() throws {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "00......",
                                       "0.0....."])
        let swapped = game.swap(at(7, 2), at(7, 1))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.made == [at(7, 1): .propeller])
        #expect(step.cleared == [at(6, 0), at(6, 1), at(7, 0)])
    }

    @Test func aRowOfFourBeatsTheSquareItOverlaps() throws {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "00......",
                                       "0.00....",
                                       ".0......"])
        let swapped = game.swap(at(7, 1), at(6, 1))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.made == [at(6, 1): .rocketAcross])
        #expect(Set(step.cleared) == [at(5, 0), at(5, 1), at(6, 0), at(6, 2), at(6, 3)])
    }

    @Test func anLOfFourAndThreeStillMakesABomb() {
        // Four across crossing three down: the L or T beats the four.
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "..0.....",
                                       ".0.00...",
                                       "..0....."])
        #expect(!TokenSwapGame.hasMatch(in: game.cells))
        let swapped = game.swap(at(7, 2), at(6, 2))
        #expect(swapped)
        let step = game.resolveStep()
        #expect(step?.made == [at(6, 2): .bomb])
    }

    @Test func specialsFromFallingTokensAppearInTheMiddleOfTheMatch() {
        // No swap involved: the special goes to the middle of a run, the crossing of an L, and
        // the lower-left of a square.
        var game = SwapBoards.classic(SwapBoards.plain)
        game.place(SwapBoards.kinds(["0000....",
                                     "........",
                                     "..0.....",
                                     "..0.....",
                                     "000.....",
                                     "........",
                                     ".....00.",
                                     ".....00."]))
        let groups = TokenSwapGame.matchGroups(in: game.cells, swapped: [])
        var spots: [TokenSwapGame.Power: Position] = [:]
        for group in groups {
            if let power = group.power, let spot = group.spot { spots[power] = spot }
        }
        #expect(spots == [.rocketAcross: at(0, 2), .bomb: at(4, 2), .propeller: at(7, 5)])
        #expect(groups.count == 3)
    }

    @Test func aChainedTokenInAMatchStaysAndLosesItsChain() throws {
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "00......"])
        game.setObstacle(at: at(7, 1), chained: true)
        let chainedID = game.cell(at: at(7, 1)).tile?.id
        // A chained tile can't be swapped, even into a match.
        #expect(!game.isValidSwap(at(7, 1), at(6, 1)))
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.cleared == [at(7, 0), at(7, 2)])
        #expect(step.obstacles == [TokenSwapGame.ObstacleHit(position: at(7, 1), kind: .chain, layersLeft: 0)])
        #expect(game.cell(at: at(7, 1)).tile?.id == chainedID)
        #expect(!game.cell(at: at(7, 1)).isChained)
        #expect(game.chainsBroken == 1)
    }
}

@Suite("Token Swap: specials going off")
struct TokenSwapSpecialTests {
    typealias Position = TokenSwapGame.Position
    let at = SwapBoards.at

    /// Swaps the special at (3, 3) right, into (3, 4), and returns the first wave.
    func swapRight(_ power: TokenSwapGame.Power, extra: [Position: TokenSwapGame.Power] = [:],
                   rows: [String] = SwapBoards.plain) throws -> (TokenSwapGame, TokenSwapGame.Step) {
        var powers = extra
        powers[at(3, 3)] = power
        var game = SwapBoards.classic(rows, powers: powers)
        #expect(game.isValidSwap(at(3, 3), at(3, 4))) // Swapping a special is always a move.
        let swapped = game.swap(at(3, 3), at(3, 4))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        return (game, step)
    }

    @Test func aRocketAcrossClearsItsRow() throws {
        let (game, step) = try swapRight(.rocketAcross)
        #expect(Set(step.cleared) == Set((0..<8).map { at(3, $0) }))
        #expect(step.blastList.map(\.power) == [.rocketAcross])
        #expect(step.blastList.first?.origin == at(3, 4))
        #expect(step.points == 80)
        #expect(game.setOff[.rocketAcross] == 1)
    }

    @Test func aRocketDownClearsItsColumn() throws {
        let (_, step) = try swapRight(.rocketDown)
        // The rocket now sits at (3, 4); the filler it traded with moved to (3, 3).
        #expect(Set(step.cleared) == Set((0..<8).map { at($0, 4) }))
    }

    @Test func aBombClearsTheSquareAroundIt() throws {
        let (_, step) = try swapRight(.bomb)
        #expect(Set(step.cleared) == Set(TokenSwapGame.square(around: at(3, 4), radius: 2)))
        #expect(step.cleared.count == 25)
    }

    @Test func aPropellerClearsBesideItThenFliesToATarget() throws {
        let (_, step) = try swapRight(.propeller)
        let blast = try #require(step.blastList.first)
        #expect(blast.power == .propeller)
        let target = try #require(blast.target)
        let beside: Set<Position> = [at(2, 4), at(4, 4), at(3, 3), at(3, 5)]
        #expect(!beside.contains(target) && target != at(3, 4))
        #expect(Set(step.cleared) == beside.union([at(3, 4), target]))
    }

    @Test func aPropellerFliesToWhatTheLevelNeeds() throws {
        // With ice to crack, the propeller goes for the frozen token, wherever it is.
        var game = SwapBoards.level(SwapBoards.plain, goals: [.ice(1)], powers: [at(3, 3): .propeller])
        game.setObstacle(at: at(7, 7), ice: 1)
        let swapped = game.swap(at(3, 3), at(3, 4))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.blastList.first?.target == at(7, 7))
        #expect(game.iceFreed == 1)
        // With tokens of one color to collect, it goes for one of those.
        var collecting = SwapBoards.level(SwapBoards.plain, goals: [.tokens(kind: 5, count: 30)], powers: [at(3, 3): .propeller])
        let moved = collecting.swap(at(3, 3), at(3, 4))
        #expect(moved)
        let waveWave = collecting.resolveStep()
        let wave = try #require(waveWave)
        let target = try #require(wave.blastList.first?.target)
        #expect(SwapBoards.filler(target.row, target.column) == 5)
    }

    @Test func aColorClearSwappedWithATokenClearsThatColor() throws {
        let kinds = SwapBoards.kinds(SwapBoards.plain)
        let partner = kinds[3][4]
        let sameColor = Set(TokenSwapGame.allPositions.filter { kinds[$0.row][$0.column] == partner && $0 != at(3, 4) })
        let (game, step) = try swapRight(.colorClear)
        // The partner moved to (3, 3), the Color Clear to (3, 4).
        #expect(Set(step.cleared) == sameColor.union([at(3, 3), at(3, 4)]))
        #expect(game.setOff[.colorClear] == 1)
    }

    @Test func aBlastSetsOffTheSpecialsItReachesOnceEach() throws {
        // A rocket's row reaches a bomb, which goes off in the same wave; nothing clears twice.
        let (_, step) = try swapRight(.rocketAcross, extra: [at(3, 7): .bomb])
        #expect(step.blastList.map(\.power) == [.rocketAcross, .bomb])
        let expected = Set((0..<8).map { at(3, $0) }).union(TokenSwapGame.square(around: at(3, 7), radius: 2))
        #expect(Set(step.cleared) == expected)
        #expect(step.cleared.count == expected.count)
    }

    @Test func aMatchedSpecialGoesOff() throws {
        // A rocket lined up with two of its color goes off when they match.
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "00......"], powers: [at(7, 0): .rocketDown])
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.blastList.map(\.power) == [.rocketDown])
        #expect(Set(step.cleared) == Set((0..<8).map { at($0, 0) }).union([at(7, 1), at(7, 2)]))
    }

    @Test func aBlastSkipsTheSpecialAMatchJustMade() throws {
        // The rocket made by four across sits out the wave that made it, even if a blast crosses it.
        var game = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "..0.....",
                                       "00.0...."], powers: [at(6, 2): .rocketDown])
        // Swapping the rocket down into (7, 2) sets it off and lines up four 0s at once.
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.blastList.map(\.power) == [.rocketDown])
        // The rocket that went off can't hold the new one, so it goes to the first token of the run.
        #expect(step.made == [at(7, 0): .rocketAcross])
        #expect(!step.cleared.contains(at(7, 0)))
        #expect(Set((0..<8).map { at($0, 2) }).union([at(7, 1), at(7, 3)]) == Set(step.cleared))
        #expect(game.cell(at: at(7, 0)).tile?.power == .rocketAcross)
    }

    // MARK: Combinations

    @Test func twoRocketsClearARowAndAColumn() throws {
        let (_, step) = try swapRight(.rocketAcross, extra: [at(3, 4): .rocketDown])
        let expected = Set((0..<8).map { at(3, $0) } + (0..<8).map { at($0, 4) })
        #expect(Set(step.cleared) == expected)
        #expect(step.blastList.allSatisfy { $0.isCombo })
    }

    @Test func aRocketAndABombClearThreeRowsAndThreeColumns() throws {
        let (_, step) = try swapRight(.rocketAcross, extra: [at(3, 4): .bomb])
        var expected = Set<Position>()
        for row in 2...4 { for column in 0..<8 { expected.insert(at(row, column)) } }
        for column in 3...5 { for row in 0..<8 { expected.insert(at(row, column)) } }
        #expect(Set(step.cleared) == expected)
    }

    @Test func twoBombsClearASevenBySevenSquare() throws {
        let (_, step) = try swapRight(.bomb, extra: [at(3, 4): .bomb])
        #expect(Set(step.cleared) == Set(TokenSwapGame.square(around: at(3, 4), radius: 3)))
    }

    @Test func twoColorClearsClearTheBoard() throws {
        let (_, step) = try swapRight(.colorClear, extra: [at(3, 4): .colorClear])
        #expect(step.cleared.count == 64)
    }

    @Test func aColorClearAndARocketTurnAColorIntoRockets() throws {
        let kinds = SwapBoards.kinds(SwapBoards.plain)
        let rocketKind = kinds[3][4]
        let (_, step) = try swapRight(.colorClear, extra: [at(3, 4): .rocketAcross])
        let converted = TokenSwapGame.allPositions.filter { kinds[$0.row][$0.column] == rocketKind && $0 != at(3, 4) }
        let rockets = step.blastList.filter { $0.power.isRocket }
        #expect(rockets.count == converted.count)
        // Every row or column with one of those rockets is cleared.
        for blast in rockets {
            #expect(Set(blast.reach).isSubset(of: Set(step.cleared)))
        }
    }

    @Test func aPropellerCarriesARocketToItsTarget() throws {
        let (_, step) = try swapRight(.propeller, extra: [at(3, 4): .rocketDown])
        let propeller = try #require(step.blastList.first)
        #expect(propeller.power == .propeller && propeller.isCombo)
        let target = try #require(propeller.target)
        let rocket = try #require(step.blastList.last)
        #expect(rocket.power == .rocketDown && rocket.origin == target)
        #expect(Set((0..<8).map { at($0, target.column) }).isSubset(of: Set(step.cleared)))
    }

    @Test func twoPropellersSendThreeFlying() throws {
        let (_, step) = try swapRight(.propeller, extra: [at(3, 4): .propeller])
        let targets = step.blastList.compactMap(\.target)
        #expect(targets.count == 3)
        #expect(Set(targets).count == 3)
    }

    @Test func aBlastHitsEachObstacleOnlyOncePerWave() throws {
        // A rocket and a bomb swapped together clear three rows and three columns; where they
        // overlap, each obstacle still loses only one layer.
        var game = SwapBoards.classic(SwapBoards.plain, powers: [at(3, 3): .rocketAcross, at(3, 4): .bomb])
        game.setObstacle(at: at(2, 3), crate: 2)
        game.setObstacle(at: at(4, 5), ice: 2)
        let swapped = game.swap(at(3, 3), at(3, 4))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.obstacles.count == 2)
        #expect(game.cell(at: at(2, 3)).crate == 1)
        #expect(game.cell(at: at(4, 5)).ice == 1)
    }
}

@Suite("Token Swap: obstacles and falling")
struct TokenSwapObstacleTests {
    typealias Position = TokenSwapGame.Position
    let at = SwapBoards.at
    /// A match on row 7 (0 0 _, filled from (6, 2)).
    let bottomMatch = ["........",
                       "........",
                       "........",
                       "........",
                       "........",
                       "........",
                       "..0.....",
                       "00......"]

    @Test func frozenTokensDontMoveOrMatchAndCrackBesideAMatch() throws {
        var game = SwapBoards.classic(bottomMatch)
        game.setObstacle(at: at(6, 1), ice: 2)
        let frozen = game.cell(at: at(6, 1)).tile?.id
        #expect(!game.isValidSwap(at(6, 1), at(5, 1)))
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.obstacles == [TokenSwapGame.ObstacleHit(position: at(6, 1), kind: .ice, layersLeft: 1)])
        // The frozen token held still while the tokens beside it fell.
        #expect(game.cell(at: at(6, 1)).tile?.id == frozen)
        #expect(game.cell(at: at(6, 1)).ice == 1)
        #expect(game.iceFreed == 0)
        // A frozen token can't be part of a line.
        var line = SwapBoards.classic(["........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "........",
                                       "000....."])
        line.setObstacle(at: at(7, 1), ice: 1)
        #expect(TokenSwapGame.matchGroups(in: line.cells, swapped: []).isEmpty)
    }

    @Test func thinIceBreaksInOneHitAndFreesTheToken() throws {
        var game = SwapBoards.level(bottomMatch, goals: [.ice(1)])
        game.setObstacle(at: at(6, 0), ice: 1)
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let wave = game.resolveStep()
        #expect(wave != nil)
        #expect(game.iceFreed == 1)
        #expect(game.cell(at: at(6, 0)).ice == 0 || game.cell(at: at(6, 0)).tile != nil)
        game.resolveAll()
        #expect(game.progress(.ice(1)) == 1)
    }

    @Test func cratesBreakALayerAtATimeAndTheCellRefills() throws {
        var game = SwapBoards.classic(bottomMatch)
        game.setObstacle(at: at(6, 0), crate: 2)
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.obstacles.contains(TokenSwapGame.ObstacleHit(position: at(6, 0), kind: .crate, layersLeft: 1)))
        #expect(game.cell(at: at(6, 0)).crate == 1)
        #expect(game.cell(at: at(6, 0)).tile == nil)
        // The token above the crate stayed above it, and the bottom row under it was refilled.
        #expect(game.cell(at: at(7, 0)).tile != nil)
        #expect(game.cratesBroken == 0)
        // A blast breaks the last layer.
        var blasted = SwapBoards.classic(SwapBoards.plain, powers: [at(3, 3): .rocketAcross])
        blasted.setObstacle(at: at(3, 6), crate: 1)
        let fired = blasted.swap(at(3, 3), at(3, 4))
        #expect(fired)
        let wave = blasted.resolveStep()
        #expect(wave != nil)
        #expect(blasted.cratesBroken == 1)
        #expect(blasted.cell(at: at(3, 6)).crate == 0)
        #expect(blasted.cell(at: at(3, 6)).tile != nil) // Refilled from above.
    }

    @Test func tilesFallOnlyAsFarAsTheObstacleBelow() throws {
        // A chained token in the middle of column 0 holds still; the cells under it are refilled
        // with new tiles and the tiles above it stay above.
        var game = SwapBoards.classic(bottomMatch)
        game.setObstacle(at: at(4, 0), chained: true)
        let chained = game.cell(at: at(4, 0)).tile?.id
        let aboveIDs = (0..<4).map { game.cell(at: at($0, 0)).tile?.id }
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let wave = game.resolveStep()
        #expect(wave != nil)
        #expect(game.cell(at: at(4, 0)).tile?.id == chained)
        #expect((0..<4).map { game.cell(at: at($0, 0)).tile?.id } == aboveIDs)
        // (5, 0) and (6, 0) moved down a row; (5, 0) got a new tile from under the chain.
        let newIDs = [game.cell(at: at(5, 0)).tile?.id]
        #expect(newIDs.allSatisfy { id in id.map { !aboveIDs.contains($0) && $0 != chained } ?? false })
    }

    @Test func goldBarsFallAndAreCollectedOnTheBottomRow() throws {
        var game = SwapBoards.level(["........",
                                     "........",
                                     "........",
                                     "........",
                                     "........",
                                     "........",
                                     "g.0.....",
                                     "00......"], goals: [.gold(1)])
        // A gold bar can't be matched, so it can't be swapped for nothing.
        #expect(!game.isValidSwap(at(6, 0), at(5, 0)))
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.goldCollected == [0])
        #expect(step.points == 30 + TokenSwapGame.goldPoints)
        #expect(game.goldCollected == 1)
        #expect(game.cells.joined().allSatisfy { $0.tile?.isGold != true })
        game.resolveAll()
        #expect(game.phase == .won)
    }

    @Test func goldDropsInWhileTheLevelNeedsIt() {
        let level = TokenSwapLevel(id: 1, name: "Test", difficulty: .easy, seed: 4, kinds: 5, moves: 40,
                                   goals: [.gold(3)], goldToDrop: 3, starScores: [1, 2], tip: "")
        var game = TokenSwapGame(level: level, refillSeed: 8)
        var seen = Set<Int>()
        var moves = 0
        while game.phase == .playing && moves < 40 {
            guard let (a, b) = game.hint else { break }
            _ = game.swap(a, b)
            game.resolveAll()
            moves += 1
            for tile in game.cells.joined().compactMap(\.tile) where tile.isGold { seen.insert(tile.id) }
            #expect(game.cells.joined().filter { $0.tile?.isGold == true }.count <= TokenSwapGame.goldOnBoardLimit)
        }
        #expect(!seen.isEmpty || game.goldCollected > 0)
        #expect(seen.count <= 3 && game.goldCollected <= 3)
    }

    @Test func aStuckBoardIsShuffledIntoOneWithAMove() {
        var game = TokenSwapGame(seed: 4)
        game.shuffle()
        #expect(game.shuffles == 1)
        #expect(!TokenSwapGame.hasMatch(in: game.cells))
        #expect(game.hasMove)
        // Obstacles stay where they are.
        var blocked = TokenSwapGame(seed: 5)
        blocked.setObstacle(at: at(2, 2), crate: 2)
        blocked.setObstacle(at: at(5, 5), ice: 1)
        let frozen = blocked.cell(at: at(5, 5)).tile
        blocked.shuffle()
        #expect(blocked.cell(at: at(2, 2)).crate == 2)
        #expect(blocked.cell(at: at(5, 5)).tile == frozen)
    }

    @Test func randomPlayKeepsTheBoardWhole() {
        var rng = SeededGenerator(seed: 11)
        for level in TokenSwapLevel.all.prefix(18) {
            var game = TokenSwapGame(level: level, refillSeed: UInt64(level.id))
            for _ in 0..<12 where game.phase == .playing {
                let swaps = game.validSwaps
                #expect(!swaps.isEmpty)
                guard let (a, b) = swaps.randomElement(using: &rng) else { break }
                let swapped = game.swap(a, b)
                #expect(swapped)
                let before = game.score
                let points = game.resolveAll().reduce(0) { $0 + $1.points }
                #expect(game.score == before + points + game.bonusPoints)
                #expect(!TokenSwapGame.hasMatch(in: game.cells))
                // Every cell holds a tile unless a crate fills it; no tile is in two places.
                #expect(game.cells.joined().allSatisfy { ($0.crate > 0) == ($0.tile == nil) })
                let ids = game.cells.joined().compactMap(\.tile?.id)
                #expect(Set(ids).count == ids.count)
            }
        }
    }
}

@Suite("Token Swap: modes")
struct TokenSwapModeTests {
    typealias Position = TokenSwapGame.Position
    let at = SwapBoards.at
    let bottomMatch = ["........",
                       "........",
                       "........",
                       "........",
                       "........",
                       "........",
                       "..0.....",
                       "00......"]

    @Test func classicTimeRunsOutButFallingWavesStillCount() {
        var game = SwapBoards.classic(bottomMatch)
        game.advance(by: 59.9)
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        game.advance(by: 5)
        #expect(game.isTimeUp)
        #expect(!game.isOver) // Waves are still falling.
        game.resolveAll()
        #expect(game.isOver)
        #expect(game.score > 0)
        var late = TokenSwapGame(seed: 3)
        late.advance(by: 60)
        let (a, b) = late.hint!
        let refused = late.swap(a, b) // No swaps once time is up.
        #expect(!refused)
        late.advance(by: -5)
        late.advance(by: .nan)
        #expect(late.timeLeft == 0)
    }

    @Test func aLevelIsWonWhenItsGoalsAreMetWithMovesLeftAsBonus() {
        var game = SwapBoards.level(bottomMatch, goals: [.tokens(kind: 0, count: 3)], moves: 10)
        #expect(game.movesLeft == 10)
        #expect(game.timeLeft == 0 && !game.isTimeUp)
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        #expect(game.movesLeft == 9)
        game.resolveAll()
        #expect(game.phase == .won)
        #expect(game.isOver)
        #expect(game.bonusPoints == 9 * TokenSwapGame.pointsPerMoveLeft)
        #expect(game.score >= 30 + game.bonusPoints)
        // Nothing more once it's won.
        let after = game.swap(at(0, 0), at(0, 1))
        #expect(!after)
    }

    @Test func runningOutOfMovesLosesTheLevel() {
        var game = SwapBoards.level(bottomMatch, goals: [.crates(5)], moves: 1)
        let swapped = game.swap(at(6, 2), at(7, 2))
        #expect(swapped)
        #expect(game.movesLeft == 0)
        game.resolveAll()
        #expect(game.phase == .lost)
        #expect(game.bonusPoints == 0)
        #expect(!game.validSwaps.isEmpty) // Moves exist, but none are left to make.
        let refused = game.swap(game.validSwaps[0].0, game.validSwaps[0].1)
        #expect(!refused)
    }

    @Test func goalsCountTheRightThings() {
        var game = SwapBoards.level(SwapBoards.plain, goals: [.specials(.rocket, 1), .score(50)],
                                    powers: [at(3, 3): .rocketAcross])
        #expect(game.progress(.specials(.rocket, 1)) == 0)
        let swapped = game.swap(at(3, 3), at(3, 4))
        #expect(swapped)
        game.resolveAll()
        #expect(game.progress(.specials(.rocket, 1)) == 1)
        #expect(game.progress(.specials(.bomb, 1)) == 0)
        #expect(game.progress(.specials(.any, 5)) >= 1)
        #expect(game.progress(.score(50)) == 50) // Never past the target.
        #expect(game.phase == .won)
    }

    @Test func aLevelStartsFromTheSameBoardEveryTime() {
        for level in TokenSwapLevel.all {
            let first = TokenSwapGame(level: level, refillSeed: 1)
            let second = TokenSwapGame(level: level, refillSeed: 99)
            #expect(first.cells.map { $0.map { $0.tile?.kind } } == second.cells.map { $0.map { $0.tile?.kind } })
            #expect(!TokenSwapGame.hasMatch(in: first.cells))
            #expect(first.hasMove)
            // The layout's obstacles are in place.
            let counts = level.obstacleCounts
            #expect(first.cells.joined().filter { $0.ice > 0 }.count == counts.ice)
            #expect(first.cells.joined().filter(\.isChained).count == counts.chains)
            #expect(first.cells.joined().filter { $0.crate > 0 }.count == counts.crates)
            #expect(first.cells.joined().filter { $0.tile?.isGold == true }.count == counts.gold)
        }
    }

    @Test func theDailyPuzzleIsTheSameForEveryoneAndChangesDaily() {
        let monday = TokenSwapLevel.daily(day: "2026-10-26")
        #expect(monday == TokenSwapLevel.daily(day: "2026-10-26"))
        let a = TokenSwapGame(level: monday, mode: .daily("2026-10-26"), refillSeed: TokenSwapLevel.dailyRefillSeed(day: "2026-10-26"))
        let b = TokenSwapGame(level: monday, mode: .daily("2026-10-26"), refillSeed: TokenSwapLevel.dailyRefillSeed(day: "2026-10-26"))
        #expect(a.cells == b.cells)
        #expect(a.mode == .daily("2026-10-26"))
        let days = (1...28).map { String(format: "2026-11-%02d", $0) }
        let puzzles = days.map(TokenSwapLevel.daily(day:))
        #expect(Set(puzzles.map(\.seed)).count == days.count)
        #expect(Set(puzzles.map(\.name)).count == TokenSwapLevel.dailyTemplates.count) // Every kind of puzzle turns up.
    }

    @Test func theLevelsAreWellFormed() {
        let levels = TokenSwapLevel.all
        #expect(levels.map(\.id) == Array(1...levels.count))
        #expect((12...24).contains(levels.count))
        for level in levels + TokenSwapLevel.dailyTemplates {
            #expect((4...6).contains(level.kinds), "\(level.name)")
            #expect(level.layout.isEmpty || (level.layout.count == 8 && level.layout.allSatisfy { $0.count == 8 }), "\(level.name)")
            #expect(level.layout.joined().allSatisfy { ".iIcxX#g<^*%@".contains($0) }, "\(level.name)")
            #expect(level.starScores.count == 2 && level.starScores[0] < level.starScores[1], "\(level.name)")
            #expect(!level.goals.isEmpty && !level.tip.isEmpty, "\(level.name)")
            // Enough of each obstacle to meet its goal.
            let counts = level.obstacleCounts
            for goal in level.goals {
                switch goal {
                case .ice(let count): #expect(counts.ice >= count, "\(level.name)")
                case .chains(let count): #expect(counts.chains >= count, "\(level.name)")
                case .crates(let count): #expect(counts.crates >= count, "\(level.name)")
                case .gold(let count): #expect(counts.gold + level.goldToDrop >= count, "\(level.name)")
                case .tokens(let kind, _): #expect(kind < level.kinds, "\(level.name)")
                case .specials, .score: break
                }
            }
        }
        // Difficulty never goes down.
        #expect(zip(levels.dropFirst(), levels).allSatisfy { $0.difficulty >= $1.difficulty })
        #expect(levels[0].stars(won: false, score: 99_999) == 0)
        #expect(levels[0].stars(won: true, score: 0) == 1)
        #expect(levels[0].stars(won: true, score: levels[0].starScores[0]) == 2)
        #expect(levels[0].stars(won: true, score: levels[0].starScores[1]) == 3)
    }
}

@Suite("Token Swap: level balance")
struct TokenSwapLevelBalanceTests {
    /// Plays a level making the move `hint` suggests every time.
    static func playByHints(_ level: TokenSwapLevel, mode: TokenSwapGame.Mode? = nil, seed: UInt64) -> TokenSwapGame {
        var game = TokenSwapGame(level: level, mode: mode, refillSeed: seed)
        while game.phase == .playing {
            guard let (a, b) = game.hint, game.swap(a, b) else { break }
            game.resolveAll()
        }
        return game
    }

    @Test(arguments: TokenSwapLevel.all.map(\.id))
    func everyLevelCanBeWon(id: Int) throws {
        let level = try #require(TokenSwapLevel.number(id))
        // A player who always takes the hint wins most attempts, and never runs out of moves to make.
        let games = (1...6).map { Self.playByHints(level, seed: UInt64($0)) }
        let wins = games.filter { $0.phase == .won }
        #expect(wins.count >= 3, "\(level.name) won \(wins.count) of 6")
        #expect(games.allSatisfy { $0.phase != .playing })
        // Winning well reaches the stars; nobody gets three by just winning.
        #expect(wins.contains { level.stars(won: true, score: $0.score) >= 2 } || wins.isEmpty)
    }

    @Test func everyKindOfDailyPuzzleCanBeWon() {
        var wonNames = Set<String>()
        for day in 1...40 {
            let key = String(format: "2027-01-%02d", (day - 1) % 28 + 1) + (day > 28 ? "b" : "")
            let level = TokenSwapLevel.daily(day: key)
            let game = Self.playByHints(level, mode: .daily(key), seed: TokenSwapLevel.dailyRefillSeed(day: key))
            if game.phase == .won { wonNames.insert(level.name) }
        }
        #expect(wonNames == Set(TokenSwapLevel.dailyTemplates.map(\.name)))
    }
}

@Suite("Token Swap: rewards")
struct TokenSwapRewardTests {
    @Test func aClassicRoundPaysForEveryPoint() {
        var game = GameState.make(miners: [.desktop: 10]) // 10 coins a second.
        let payout = game.finishTokenSwap(score: 2_000, tokens: 180, bestChain: 4, blasts: 3)
        #expect(payout.isNewBest)
        #expect(payout.coins == (2_000 * Tuning.tokenSwapSecondsPerPoint * 10 * 1.5).rounded())
        #expect(game.stats.tokenSwapGames == 1)
        #expect(game.stats.tokenSwapTokens == 180)
        #expect(game.stats.tokenSwapBestChain == 4)
        #expect(game.stats.tokenSwapBlasts == 3)
        #expect(game.bestScore(.tokenSwap) == 2_000)
        #expect(game.record(for: .tokenSwap) == "Best 2,000 · chain of 4")
        // A round held when the app went away is paid on the next launch.
        game.holdArcadeRun(ArcadeRun(game: .tokenSwap, score: 500, detail: 40, extra: 2))
        let held = game.payUnfinishedRun()
        #expect(held?.payout.coins == (500 * Tuning.tokenSwapSecondsPerPoint * 10).rounded())
        #expect(game.stats.tokenSwapTokens == 220)
    }

    @Test func eachStarPaysOnceAndTheNextLevelOpens() {
        var game = GameState.make(miners: [.desktop: 10])
        let level = TokenSwapLevel.all[0]
        #expect(game.tokenSwap.isUnlocked(1) && !game.tokenSwap.isUnlocked(2))
        let one = game.finishTokenSwapLevel(level, won: true, score: 10, tokens: 30, bestChain: 2, specials: 1)
        #expect(one.stars == 1 && one.newStars == 1)
        #expect(one.coins == game.tokenSwapStarReward(level, star: 1))
        #expect(one.coins == (Tuning.tokenSwapStarSeconds[0] * 10).rounded())
        #expect(game.tokenSwap.isUnlocked(2))
        // The same result again pays nothing.
        let again = game.finishTokenSwapLevel(level, won: true, score: 10, tokens: 30, bestChain: 2, specials: 0)
        #expect(again.coins == 0 && again.newStars == 0)
        // Three stars pays the two not yet earned.
        let three = game.finishTokenSwapLevel(level, won: true, score: level.starScores[1], tokens: 30, bestChain: 2, specials: 0)
        #expect(three.stars == 3 && three.newStars == 2)
        #expect(three.coins == game.tokenSwapStarReward(level, star: 2) + game.tokenSwapStarReward(level, star: 3))
        #expect(three.isNewBest)
        // A loss pays nothing and changes no stars.
        let lost = game.finishTokenSwapLevel(TokenSwapLevel.all[1], won: false, score: 9_999, tokens: 5, bestChain: 1, specials: 0)
        #expect(lost.coins == 0 && lost.stars == 0)
        #expect(game.tokenSwap.stars(for: 2) == 0)
        #expect(!game.tokenSwap.isUnlocked(3))
        #expect(game.tokenSwap.totalStars == 3)
        #expect(game.tokenSwap.levelsWon == 1)
        #expect(game.tokenSwap.nextLevel == 2)
        #expect(game.stats.tokenSwapTokens == 95)
        #expect(game.stats.tokenSwapLevelsPlayed == 4)
        // Harder levels pay more per star.
        let hard = TokenSwapLevel.all.last!
        #expect(game.tokenSwapStarReward(hard, star: 1) == game.tokenSwapStarReward(level, star: 1) * 2)
    }

    @Test func theDailyPuzzlePaysOnceADay() {
        var game = GameState.make(miners: [.desktop: 10])
        #expect(game.finishTokenSwapDaily(day: "2026-10-26", won: false, tokens: 50, bestChain: 1, specials: 0) == 0)
        let first = game.finishTokenSwapDaily(day: "2026-10-26", won: true, tokens: 50, bestChain: 1, specials: 0)
        #expect(first == (Tuning.tokenSwapDailySeconds * 10).rounded())
        #expect(game.finishTokenSwapDaily(day: "2026-10-26", won: true, tokens: 50, bestChain: 1, specials: 0) == 0)
        #expect(game.tokenSwap.hasWonDaily(day: "2026-10-26"))
        #expect(game.finishTokenSwapDaily(day: "2026-10-27", won: true, tokens: 50, bestChain: 1, specials: 0) == first)
        #expect(game.tokenSwap.dailyWins == 2)
    }

    @Test func levelProgressIsSavedAndSurvivesPrestige() throws {
        var game = GameState.make(miners: [.desktop: 10])
        game.finishTokenSwapLevel(TokenSwapLevel.all[0], won: true, score: 99_999, tokens: 30, bestChain: 2, specials: 1)
        game.finishTokenSwapDaily(day: "2026-10-26", won: true, tokens: 1, bestChain: 1, specials: 0)
        let data = try GameCoding.encoder().encode(game)
        let loaded = try GameCoding.decoder().decode(GameState.self, from: data)
        #expect(loaded.tokenSwap == game.tokenSwap)
        #expect(loaded.tokenSwap.stars(for: 1) == 3)
        // Saves from before levels load with none won.
        let old = try GameCoding.decoder().decode(TokenSwapProgress.self, from: Data(#"{"stars":[5,-1]}"#.utf8))
        #expect(old.stars == [3, 0])
        #expect(old.dailyWonDay == nil)
        var prestiged = game
        prestiged.stats.lifetimeCoins = 1e11
        #expect(prestiged.prestige(at: Date()) > 0)
        #expect(prestiged.tokenSwap == game.tokenSwap)
    }
}
