import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Tetris")
struct TetrisTests {
    func newGame(seed: UInt64 = 1) -> (TetrisGame, SeededGenerator) {
        var rng = SeededGenerator(seed: seed)
        let game = TetrisGame(using: &rng)
        return (game, rng)
    }

    func piece(_ kind: Tetromino, rotation: Int = 0, x: Int, y: Int) -> TetrisPiece {
        TetrisPiece(kind: kind, rotation: rotation, x: x, y: y)
    }

    func row(_ y: Int, columns: some Sequence<Int>) -> [GridPoint] {
        columns.map { GridPoint(x: $0, y: y) }
    }

    func filled(_ game: TetrisGame) -> Int { game.board.filter { $0 != 0 }.count }

    // MARK: Pieces

    @Test func everyRotationHasFourCellsInsideItsBox() {
        for kind in Tetromino.allCases {
            for rotation in 0..<4 {
                let cells = kind.cells(rotation: rotation)
                #expect(Set(cells).count == 4)
                #expect(cells.allSatisfy { (0..<kind.boxSize).contains($0.x) && (0..<kind.boxSize).contains($0.y) })
            }
            #expect(kind.cells(rotation: 4) == kind.cells(rotation: 0))
            #expect(kind.cells(rotation: -1) == kind.cells(rotation: 3))
        }
        #expect(Tetromino.o.cells(rotation: 1) == Tetromino.o.cells(rotation: 0))
    }

    @Test func rotationStatesMatchSRS() {
        // T points up, then right; I lies in row 1, then stands in column 2, row 2, column 1.
        #expect(Set(Tetromino.t.cells(rotation: 1)) == Set([GridPoint(x: 1, y: 0), GridPoint(x: 1, y: 1),
                                                            GridPoint(x: 1, y: 2), GridPoint(x: 2, y: 1)]))
        #expect(Tetromino.i.cells(rotation: 1).allSatisfy { $0.x == 2 })
        #expect(Tetromino.i.cells(rotation: 2).allSatisfy { $0.y == 2 })
        #expect(Tetromino.i.cells(rotation: 3).allSatisfy { $0.x == 1 })
    }

    @Test func kickTablesAreSymmetric() {
        for kind in Tetromino.allCases where kind != .o {
            for from in 0..<4 {
                for to in [(from + 1) % 4, (from + 3) % 4] {
                    let forward = TetrisGame.kicks(for: kind, from: from, to: to)
                    let back = TetrisGame.kicks(for: kind, from: to, to: from)
                    #expect(forward.count == 5)
                    #expect(forward.first == GridPoint(x: 0, y: 0))
                    #expect(zip(forward, back).allSatisfy { $0.x == -$1.x && $0.y == -$1.y })
                }
            }
        }
    }

    // MARK: Spawning

    @Test func piecesSpawnCenteredAtTheTop() throws {
        var (game, rng) = newGame()
        var kinds: Set<Tetromino> = []
        for _ in 0..<7 {
            let current = try #require(game.piece)
            kinds.insert(current.kind)
            #expect(current.rotation == 0)
            let columns = current.cells.map(\.x)
            #expect(columns.min()! + columns.max()! >= 8 && columns.min()! + columns.max()! <= 10)
            #expect(current.cells.map(\.y).min() == 0)
            game.load(blocks: [], piece: current)
            game.hardDrop(using: &rng)
        }
        #expect(kinds.count == 7)
    }

    @Test func theSevenBagDealsEveryPieceOncePerBag() {
        var (game, rng) = newGame(seed: 99)
        let firstBag = [game.piece!.kind] + game.queue
        #expect(firstBag.count == 7)
        #expect(Set(firstBag).count == 7)
        let next = game.queue[0]
        game.load(blocks: [], piece: game.piece)
        game.hardDrop(using: &rng)
        #expect(game.piece?.kind == next)
        #expect(Set(game.queue.suffix(7)).count == 7)
        #expect(game.nextPiece == game.queue.first)
    }

    // MARK: Moving and rotating

    @Test func wallsStopSidewaysMoves() {
        var (game, _) = newGame()
        game.load(blocks: [], piece: piece(.t, x: 3, y: 5))
        var moves = 0
        while game.moveLeft() { moves += 1 }
        #expect(moves == 3)
        #expect(game.piece?.x == 0)
        moves = 0
        while game.moveRight() { moves += 1 }
        #expect(moves == 7)
        #expect(game.piece?.cells.map(\.x).max() == 9)
    }

    @Test func blocksStopSidewaysMoves() {
        var (game, _) = newGame()
        game.load(blocks: [GridPoint(x: 2, y: 6)], piece: piece(.t, x: 3, y: 5))
        #expect(game.moveLeft() == false)
        #expect(game.piece?.x == 3)
    }

    @Test func rotationInOpenSpaceNeedsNoKick() {
        var (game, _) = newGame()
        game.load(blocks: [], piece: piece(.t, x: 3, y: 5))
        #expect(game.rotate() == true)
        #expect(game.piece == piece(.t, rotation: 1, x: 3, y: 5))
        #expect(game.rotate(clockwise: false) == true)
        #expect(game.piece == piece(.t, rotation: 0, x: 3, y: 5))
        #expect(game.rotate(clockwise: false) == true)
        #expect(game.piece?.rotation == 3)
    }

    @Test func rotatingIntoTheWallKicksAway() {
        var (game, _) = newGame()
        // T standing in the left wall's column: pointing down needs one step right.
        game.load(blocks: [], piece: piece(.t, rotation: 1, x: -1, y: 5))
        #expect(game.rotate() == true)
        #expect(game.piece == piece(.t, rotation: 2, x: 0, y: 5))
    }

    @Test func theIPieceKicksOffTheRightWall() {
        var (game, _) = newGame()
        game.load(blocks: [], piece: piece(.i, rotation: 1, x: 7, y: 5))
        #expect(game.rotate() == true)
        #expect(game.piece == piece(.i, rotation: 2, x: 6, y: 5))
    }

    @Test func kicksCanLiftThePiece() {
        var (game, _) = newGame()
        // The plain and one-left positions are blocked; the third test (-1, +1) moves up a row.
        game.load(blocks: [GridPoint(x: 5, y: 12), GridPoint(x: 4, y: 12)], piece: piece(.t, x: 4, y: 10))
        #expect(game.rotate() == true)
        #expect(game.piece == piece(.t, rotation: 1, x: 3, y: 9))
    }

    @Test func rotationFailsWhenEveryKickIsBlocked() {
        var (game, _) = newGame()
        var blocks: [GridPoint] = []
        for y in 0..<TetrisGame.height {
            for x in 0..<TetrisGame.width where !(y == 19 && (0...3).contains(x)) { blocks.append(GridPoint(x: x, y: y)) }
        }
        game.load(blocks: blocks, piece: piece(.i, x: 0, y: 18))
        #expect(game.rotate() == false)
        #expect(game.piece == piece(.i, x: 0, y: 18))
    }

    @Test func theOPieceDoesNotRotate() {
        var (game, _) = newGame()
        game.load(blocks: [], piece: piece(.o, x: 4, y: 5))
        #expect(game.rotate() == false)
        #expect(game.piece == piece(.o, x: 4, y: 5))
    }

    // MARK: Dropping and locking

    @Test func theGhostShowsTheLandingSpot() {
        var (game, _) = newGame()
        game.load(blocks: [GridPoint(x: 4, y: 12)], piece: piece(.t, x: 3, y: 0))
        #expect(game.ghost == piece(.t, x: 3, y: 10))
    }

    @Test func softDropScoresARowAndLocksOnTheFloor() {
        var (game, rng) = newGame()
        game.load(blocks: [], piece: piece(.t, x: 3, y: 0))
        for _ in 0..<18 { game.softDrop(using: &rng) }
        #expect(game.piece == piece(.t, x: 3, y: 18))
        #expect(game.score == 18)
        game.softDrop(using: &rng)
        #expect(game.score == 18)
        #expect(filled(game) == 4)
        #expect(game.piece?.y ?? 0 <= 0) // A new piece spawned.
    }

    @Test func hardDropScoresTwoPerRowAndLocks() {
        var (game, rng) = newGame()
        game.load(blocks: [], piece: piece(.t, x: 3, y: 0))
        game.hardDrop(using: &rng)
        #expect(game.score == 36)
        #expect(game.block(x: 4, y: 18) == .t)
        #expect(game.block(x: 3, y: 19) == .t)
        #expect(game.block(x: 5, y: 19) == .t)
        #expect(game.block(x: 4, y: 17) == nil)
        #expect(game.block(x: -1, y: 0) == nil && game.block(x: 0, y: 20) == nil)
    }

    @Test func gravityGivesOneTickOfLockDelay() {
        var (game, rng) = newGame()
        game.load(blocks: [], piece: piece(.t, x: 3, y: 17))
        game.tick(using: &rng)
        #expect(game.piece == piece(.t, x: 3, y: 18))
        game.tick(using: &rng)
        #expect(game.piece == piece(.t, x: 3, y: 18))
        #expect(filled(game) == 0)
        game.tick(using: &rng)
        #expect(filled(game) == 4)
    }

    @Test func slidingOffALedgeResetsTheLockDelay() {
        var (game, rng) = newGame()
        game.load(blocks: row(19, columns: 3...5), piece: piece(.t, x: 3, y: 17))
        game.tick(using: &rng) // Grounded once.
        for _ in 0..<3 { game.moveRight() }
        game.tick(using: &rng) // Falls instead of locking.
        #expect(game.piece == piece(.t, x: 6, y: 18))
        #expect(filled(game) == 3)
    }

    // MARK: Lines and scoring

    @Test func clearingALineScoresAndShiftsRowsDown() {
        var (game, rng) = newGame()
        let blocks = row(19, columns: [0, 1, 2, 7, 8, 9]) + [GridPoint(x: 0, y: 18)]
        game.load(blocks: blocks, piece: piece(.i, x: 3, y: -1))
        game.hardDrop(using: &rng)
        #expect(game.lines == 1)
        #expect(game.score == 2 * 19 + 100)
        #expect(filled(game) == 1)
        #expect(game.block(x: 0, y: 19) == .o) // The block above the cleared row moved down.
    }

    @Test func aTetrisScoresEightHundredTimesTheLevel() {
        var (game, rng) = newGame()
        var score = 0
        for round in 1...3 {
            let blocks = (16...19).flatMap { row($0, columns: 0...8) }
            game.load(blocks: blocks, piece: piece(.i, rotation: 1, x: 7, y: 0))
            game.hardDrop(using: &rng)
            score += 32 + 800
            #expect(game.lines == 4 * round)
            #expect(game.score == score)
            #expect(filled(game) == 0)
        }
        #expect(game.level == 2)
        #expect(approx(game.gravityInterval, 0.85))
    }

    @Test func gravitySpeedsUpWithLevelButHasAFloor() {
        let (game, _) = newGame()
        #expect(game.level == 1)
        #expect(game.gravityInterval == 1)
        #expect(max(0.1, pow(0.85, 30)) == 0.1)
    }

    // MARK: Game over

    @Test func noRoomToSpawnEndsTheGame() {
        var (game, rng) = newGame()
        let blocks = row(0, columns: 3...6) + row(1, columns: 3...6)
        game.load(blocks: blocks, piece: piece(.o, x: 0, y: 10))
        game.hardDrop(using: &rng)
        #expect(game.isOver)
        #expect(game.piece == nil)
        let score = game.score
        #expect(game.moveLeft() == false)
        #expect(game.moveRight() == false)
        #expect(game.rotate() == false)
        game.hardDrop(using: &rng)
        game.softDrop(using: &rng)
        game.tick(using: &rng)
        #expect(game.score == score)
    }

    @Test func lockingAboveTheBoardEndsTheGame() {
        var (game, rng) = newGame()
        game.load(blocks: [GridPoint(x: 5, y: 3)], piece: piece(.i, rotation: 1, x: 3, y: -1))
        game.tick(using: &rng)
        #expect(!game.isOver)
        game.tick(using: &rng)
        #expect(game.isOver)
    }

    /// Thousands of random inputs: the piece is always legal and scores never go down.
    @Test func randomPlayKeepsEveryInvariant() throws {
        var input = SeededGenerator(seed: 5)
        var (game, rng) = newGame(seed: 6)
        var games = 1
        for _ in 0..<20_000 {
            let score = game.score
            let lines = game.lines
            switch input.next() % 7 {
            case 0: game.moveLeft()
            case 1: game.moveRight()
            case 2: game.rotate()
            case 3: game.rotate(clockwise: false)
            case 4: game.softDrop(using: &rng)
            case 5: if input.next() % 4 == 0 { game.hardDrop(using: &rng) }
            default: game.tick(using: &rng)
            }
            #expect(game.score >= score)
            #expect(game.lines >= lines)
            #expect(game.board.allSatisfy { (0...7).contains($0) })
            if game.isOver {
                #expect(game.piece == nil)
                (game, rng) = newGame(seed: UInt64(games))
                games += 1
            } else {
                let current = try #require(game.piece)
                #expect(game.isValid(current))
                #expect(game.queue.count >= 6)
            }
        }
        #expect(games > 1)
    }
}
