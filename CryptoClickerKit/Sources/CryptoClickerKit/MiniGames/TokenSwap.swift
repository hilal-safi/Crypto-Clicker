import Foundation

/// Token Swap, a match-three game. Swap two neighboring tokens to line up three or more of a kind:
/// they clear, the tokens above fall into the gaps and new ones drop in, which can set off more
/// matches, each wave scoring more than the last. Lining up four or more, or matching across and
/// down at once, leaves a Blast token behind, which clears its whole row and column when it's
/// matched. A round lasts a minute; waves already falling when time runs out still count.
public struct TokenSwapGame: Sendable {
    public static let size = 8
    public static let kinds = 6
    public static let roundLength: TimeInterval = 60
    public static let pointsPerToken = 10

    public struct Position: Hashable, Comparable, Sendable {
        public let row: Int
        public let column: Int

        public init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }

        public static func < (lhs: Self, rhs: Self) -> Bool { (lhs.row, lhs.column) < (rhs.row, rhs.column) }

        public var isOnBoard: Bool {
            (0..<TokenSwapGame.size).contains(row) && (0..<TokenSwapGame.size).contains(column)
        }

        public func isNeighbor(of other: Position) -> Bool {
            abs(row - other.row) + abs(column - other.column) == 1
        }

        /// The cell next to this one in a direction: `dRow` and `dColumn` are -1, 0 or 1.
        public func moved(dRow: Int, dColumn: Int) -> Position {
            Position(row: row + dRow, column: column + dColumn)
        }
    }

    public struct Tile: Equatable, Sendable, Identifiable {
        /// Unique for the whole round, so the screen can animate each token as it moves.
        public let id: Int
        /// Which token it is, from 0 to `kinds - 1`.
        public let kind: Int
        public internal(set) var isBlast = false
    }

    /// What one wave of clearing did, for the screen to show.
    public struct Step: Equatable, Sendable {
        /// Cells cleared, before the tokens above fell.
        public let cleared: [Position]
        public let points: Int
        /// 1 for the matches a swap makes, 2 for the wave after, and so on.
        public let chain: Int
        /// Blast tokens that went off.
        public let blasts: Int
        /// Where this wave's long or crossing matches left new Blast tokens.
        public let madeBlasts: [Position]
    }

    /// Rows from the top; every cell holds a token.
    public private(set) var board: [[Tile]] = []
    public private(set) var score = 0
    public private(set) var time: TimeInterval = 0
    public private(set) var tokensCleared = 0
    public private(set) var moves = 0
    public private(set) var blastsSetOff = 0
    /// The most waves one swap set off.
    public private(set) var bestChain = 0
    /// Times the board ran out of moves and was shuffled.
    public private(set) var shuffles = 0
    /// The wave the next step will score as; 0 while waiting for a swap.
    public private(set) var chain = 0
    /// The swap that started the chain, so a long match leaves its Blast where the player moved.
    var lastSwap: [Position] = []
    var rng: SeededGenerator
    var nextID = 0

    public init(seed: UInt64) {
        rng = SeededGenerator(seed: seed)
        fill()
    }

    public var timeLeft: TimeInterval { max(0, Self.roundLength - time) }
    public var isTimeUp: Bool { time >= Self.roundLength }
    /// Matches are clearing (and more may follow), so swaps wait.
    public var isResolving: Bool { chain > 0 }
    public var isOver: Bool { isTimeUp && !isResolving }

    public func tile(at position: Position) -> Tile { board[position.row][position.column] }

    public mutating func advance(by seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
        time = min(Self.roundLength, time + seconds)
    }

    // MARK: Swapping

    /// Two neighbors that would line up a match if swapped.
    public func isValidSwap(_ a: Position, _ b: Position) -> Bool {
        guard a.isOnBoard, b.isOnBoard, a.isNeighbor(of: b) else { return false }
        var copy = board
        Self.exchange(&copy, a, b)
        return !Self.runs(in: copy).isEmpty
    }

    /// Swaps two neighbors if that makes a match, starting a chain of clearing steps
    /// (see `resolveStep`). Returns false, changing nothing, for any other swap or once time is up.
    @discardableResult
    public mutating func swap(_ a: Position, _ b: Position) -> Bool {
        guard !isTimeUp, !isResolving, isValidSwap(a, b) else { return false }
        Self.exchange(&board, a, b)
        moves += 1
        chain = 1
        lastSwap = [a, b]
        return true
    }

    /// Clears the matches on the board, drops the tokens above into the gaps and fills the top
    /// with new tokens. Returns `nil` once nothing matches, which ends the chain (shuffling the
    /// board if no swap is left).
    public mutating func resolveStep() -> Step? {
        guard chain > 0 else { return nil }
        let found = Self.runs(in: board)
        guard !found.isEmpty else {
            chain = 0
            lastSwap = []
            if !hasMove { shuffle() }
            return nil
        }
        var cleared = Set(found.flatMap { $0 })
        // A run of four or more, or a token matched across and down, leaves a Blast behind.
        var made: [Position] = []
        var timesMatched: [Position: Int] = [:]
        for run in found {
            for position in run { timesMatched[position, default: 0] += 1 }
        }
        for run in found where run.count >= 4 {
            let spot = run.first(where: lastSwap.contains) ?? run[run.count / 2]
            if !made.contains(spot) { made.append(spot) }
        }
        for (position, count) in timesMatched.sorted(by: { $0.key < $1.key }) where count >= 2 && !made.contains(position) {
            made.append(position)
        }
        // Blasts in the match go off, clearing their row and column, and set off any Blast they reach.
        var waiting = cleared.filter { tile(at: $0).isBlast }.sorted()
        var fired: Set<Position> = []
        while let blast = waiting.popLast() {
            guard fired.insert(blast).inserted else { continue }
            for index in 0..<Self.size {
                for position in [Position(row: blast.row, column: index), Position(row: index, column: blast.column)]
                where cleared.insert(position).inserted && tile(at: position).isBlast {
                    waiting.append(position)
                }
            }
        }
        for spot in made { cleared.remove(spot) }
        let points = cleared.count * Self.pointsPerToken * chain
        score += points
        tokensCleared += cleared.count
        blastsSetOff += fired.count
        bestChain = max(bestChain, chain)
        for spot in made { board[spot.row][spot.column].isBlast = true }
        // Tokens fall into the gaps, and new ones drop in from the top.
        for column in 0..<Self.size {
            var kept: [Tile] = [] // Bottom up.
            for row in stride(from: Self.size - 1, through: 0, by: -1)
            where !cleared.contains(Position(row: row, column: column)) {
                kept.append(board[row][column])
            }
            while kept.count < Self.size { kept.append(newTile(Int.random(in: 0..<Self.kinds, using: &rng))) }
            for (index, tile) in kept.enumerated() { board[Self.size - 1 - index][column] = tile }
        }
        let step = Step(cleared: cleared.sorted(), points: points, chain: chain, blasts: fired.count, madeBlasts: made)
        chain += 1
        lastSwap = []
        return step
    }

    /// Clears every wave a swap set off at once (for tests and simulations).
    @discardableResult
    public mutating func resolveAll() -> [Step] {
        var steps: [Step] = []
        while let step = resolveStep() { steps.append(step) }
        return steps
    }

    // MARK: Moves

    /// Some swap would make a match.
    public var hasMove: Bool { hint != nil }

    /// A swap that makes a match, if there is one: the first found, top left first.
    public var hint: (Position, Position)? {
        for row in 0..<Self.size {
            for column in 0..<Self.size {
                let here = Position(row: row, column: column)
                for next in [here.moved(dRow: 0, dColumn: 1), here.moved(dRow: 1, dColumn: 0)] where isValidSwap(here, next) {
                    return (here, next)
                }
            }
        }
        return nil
    }

    /// Every swap that makes a match, each listed once.
    public var validSwaps: [(Position, Position)] {
        var swaps: [(Position, Position)] = []
        for row in 0..<Self.size {
            for column in 0..<Self.size {
                let here = Position(row: row, column: column)
                for next in [here.moved(dRow: 0, dColumn: 1), here.moved(dRow: 1, dColumn: 0)] where isValidSwap(here, next) {
                    swaps.append((here, next))
                }
            }
        }
        return swaps
    }

    // MARK: Board

    /// Runs of three or more of a kind, across then down.
    static func runs(in board: [[Tile]]) -> [[Position]] {
        var runs: [[Position]] = []
        for row in 0..<size {
            var start = 0
            for column in 1...size where column == size || board[row][column].kind != board[row][start].kind {
                if column - start >= 3 { runs.append((start..<column).map { Position(row: row, column: $0) }) }
                start = column
            }
        }
        for column in 0..<size {
            var start = 0
            for row in 1...size where row == size || board[row][column].kind != board[start][column].kind {
                if row - start >= 3 { runs.append((start..<row).map { Position(row: $0, column: column) }) }
                start = row
            }
        }
        return runs
    }

    static func exchange(_ board: inout [[Tile]], _ a: Position, _ b: Position) {
        let tile = board[a.row][a.column]
        board[a.row][a.column] = board[b.row][b.column]
        board[b.row][b.column] = tile
    }

    mutating func newTile(_ kind: Int) -> Tile {
        nextID += 1
        return Tile(id: nextID, kind: kind)
    }

    /// A new board with no matches on it and at least one swap to make.
    mutating func fill() {
        repeat {
            board = []
            for row in 0..<Self.size {
                board.append([])
                for column in 0..<Self.size {
                    var kind: Int
                    repeat { kind = Int.random(in: 0..<Self.kinds, using: &rng) } while completesRun(kind, row: row, column: column)
                    board[row].append(newTile(kind))
                }
            }
        } while !hasMove
    }

    /// `kind` here would finish three in a row with the two tokens to its left or above.
    func completesRun(_ kind: Int, row: Int, column: Int) -> Bool {
        (column >= 2 && board[row][column - 1].kind == kind && board[row][column - 2].kind == kind)
            || (row >= 2 && board[row - 1][column].kind == kind && board[row - 2][column].kind == kind)
    }

    /// Mixes up the tokens already on the board until no match shows and a swap is possible.
    mutating func shuffle() {
        shuffles += 1
        var tiles = board.flatMap { $0 }
        for _ in 0..<200 {
            tiles.shuffle(using: &rng)
            board = (0..<Self.size).map { row in Array(tiles[row * Self.size..<(row + 1) * Self.size]) }
            if Self.runs(in: board).isEmpty && hasMove { return }
        }
        fill() // Practically never: a whole new board.
    }

    // MARK: Testing

    #if DEBUG
    /// Sets the board from kinds, row by row (tests only).
    mutating func place(_ kinds: [[Int]], blasts: Set<Position> = []) {
        var rows: [[Tile]] = []
        for (row, line) in kinds.enumerated() {
            var tiles: [Tile] = []
            for (column, kind) in line.enumerated() {
                var tile = newTile(kind)
                tile.isBlast = blasts.contains(Position(row: row, column: column))
                tiles.append(tile)
            }
            rows.append(tiles)
        }
        board = rows
    }
    #endif
}
