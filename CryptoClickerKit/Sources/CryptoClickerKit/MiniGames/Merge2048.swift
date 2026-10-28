import Foundation

/// The four ways to slide the 2048 board.
public enum SlideDirection: CaseIterable, Sendable {
    case up, down, left, right
}

/// 2048 on a 4×4 board. Every slide moves all tiles as far as they go one way; two tiles with the
/// same number that meet merge into one with their sum, which is added to the score. A tile merges
/// at most once per slide, and the tiles nearest the edge merge first (so 2 2 2 sliding left makes
/// 4 2). After a slide that changes the board, a new tile appears in a random empty cell: a 2 nine
/// times in ten, otherwise a 4. Making a 2048 tile wins, and play can carry on; the game ends when
/// no slide would change the board.
///
/// The game draws its new tiles from its own seeded generator, so the same slides always bring the
/// same tiles. That makes the daily puzzle the same for everyone (the day's start and tiles, in
/// `dailyMoves` moves), and it keeps Undo honest: taking a slide back restores the board, the score
/// and the generator, so trying the same slide again brings the same tile. Each game has
/// `undosPerGame` undos, one slide back at a time, and none once the game is over.
public struct Merge2048Game: Sendable {
    public static let size = 4
    public static let winningValue = 2048
    public static let undosPerGame = 3
    /// Moves in the daily puzzle.
    public static let dailyMoves = 150
    /// The tile goals, in order: the first one not yet made is the game's current goal.
    public static let goalTiles = [128, 256, 512, 1_024, 2_048, 4_096, 8_192, 16_384, 32_768, 65_536, 131_072]

    public enum Mode: Hashable, Sendable {
        case classic
        /// The puzzle for a day (a "yyyy-MM-dd" key).
        case daily(String)
    }

    /// A numbered tile. Its id stays the same as it slides (a merged tile keeps the id of the tile
    /// it merged into), so the board can animate it.
    public struct Tile: Equatable, Sendable, Identifiable {
        public let id: Int
        public internal(set) var value: Int
        public internal(set) var row: Int
        public internal(set) var column: Int
        /// Appeared after the last slide.
        public internal(set) var isNew: Bool
        /// Made by a merge in the last slide.
        public internal(set) var isMerged = false
    }

    public private(set) var tiles: [Tile] = []
    /// Tiles the last slide merged into others, placed in the cell where they merged, so the board
    /// can show them sliding in before they disappear.
    public private(set) var mergedAway: [Tile] = []
    public private(set) var score = 0
    /// Slides that changed the board.
    public private(set) var moves = 0
    public private(set) var merges = 0
    public private(set) var isOver = false
    public let mode: Mode
    public private(set) var undosLeft = Merge2048Game.undosPerGame
    public private(set) var undosUsed = 0
    private var nextID = 0
    /// Where new tiles come from.
    private var spawner: SeededGenerator
    /// The game before the last slide, while it can be taken back.
    private var previous: Snapshot?

    /// What Undo puts back.
    private struct Snapshot: Sendable {
        let tiles: [Tile]
        let score: Int
        let moves: Int
        let merges: Int
        let nextID: Int
        let spawner: SeededGenerator
    }

    /// A Classic game with a random start.
    public init<R: RandomNumberGenerator>(using rng: inout R) {
        self.init(seed: rng.next())
    }

    /// A game whose start and new tiles all follow from `seed`.
    public init(seed: UInt64, mode: Mode = .classic) {
        self.mode = mode
        spawner = SeededGenerator(seed: seed)
        spawn()
        spawn()
    }

    /// The day's puzzle.
    public static func daily(day: String) -> Merge2048Game {
        Merge2048Game(seed: StableHash.of("2048-daily-" + day), mode: .daily(day))
    }

    /// A board laid out by hand, for tests: `rows` of values, 0 for an empty cell.
    init(rows: [[Int]], seed: UInt64 = 0, mode: Mode = .classic) {
        self.mode = mode
        spawner = SeededGenerator(seed: seed)
        for (row, values) in rows.enumerated() {
            for (column, value) in values.enumerated() where value > 0 {
                tiles.append(Tile(id: nextID, value: value, row: row, column: column, isNew: false))
                nextID += 1
            }
        }
        isOver = !canSlide
    }

    public var isDaily: Bool {
        if case .daily = mode { true } else { false }
    }

    /// The moves a game allows: the daily puzzle's `dailyMoves`, or none for Classic.
    public var moveLimit: Int? { isDaily ? Self.dailyMoves : nil }

    public var movesLeft: Int? { moveLimit.map { max(0, $0 - moves) } }

    /// Undo can take back the last slide.
    public var canUndo: Bool { !isOver && undosLeft > 0 && previous != nil }

    /// The next tile goal: the smallest goal tile not made yet.
    public var nextGoal: Int? { Self.goalTiles.first { $0 > bestTile } }

    /// The highest tile on the board.
    public var bestTile: Int { tiles.map(\.value).max() ?? 0 }

    /// A 2048 tile (or better) has been made.
    public var hasWon: Bool { bestTile >= Self.winningValue }

    public func tile(row: Int, column: Int) -> Tile? {
        tiles.first { $0.row == row && $0.column == column }
    }

    /// Values row by row, 0 for empty cells.
    public var rows: [[Int]] {
        (0..<Self.size).map { row in (0..<Self.size).map { tile(row: row, column: $0)?.value ?? 0 } }
    }

    /// Some slide would still change the board.
    public var canSlide: Bool {
        if tiles.count < Self.size * Self.size { return true }
        let grid = rows
        for row in 0..<Self.size {
            for column in 0..<Self.size {
                let value = grid[row][column]
                if column + 1 < Self.size && grid[row][column + 1] == value { return true }
                if row + 1 < Self.size && grid[row + 1][column] == value { return true }
            }
        }
        return false
    }

    /// Slides every tile one way. Returns whether the board changed; a slide that changes nothing
    /// doesn't count, adds no tile and leaves the game exactly as it was. Nothing moves once the
    /// game is over.
    @discardableResult
    public mutating func slide(_ direction: SlideDirection) -> Bool {
        guard !isOver else { return false }
        let before = Snapshot(tiles: tiles, score: score, moves: moves, merges: merges, nextID: nextID, spawner: spawner)
        var moved = false
        var result: [Tile] = []
        var vanished: [Tile] = []
        var gained = 0
        var merged = 0
        for line in 0..<Self.size {
            // This row or column, nearest the edge the tiles slide towards first.
            let lineTiles = tiles
                .filter { direction.isVertical ? $0.column == line : $0.row == line }
                .sorted { Self.position(of: $0, sliding: direction) < Self.position(of: $1, sliding: direction) }
            var placed: [Tile] = []
            var lastCanMerge = false
            for var tile in lineTiles {
                tile.isNew = false
                tile.isMerged = false
                if lastCanMerge, let last = placed.last, last.value == tile.value {
                    placed[placed.count - 1].value *= 2
                    placed[placed.count - 1].isMerged = true
                    gained += placed[placed.count - 1].value
                    merged += 1
                    // The tile slides into the one it merged with, then goes.
                    tile.row = last.row
                    tile.column = last.column
                    vanished.append(tile)
                    lastCanMerge = false
                    moved = true
                } else {
                    let cell = Self.cell(line: line, position: placed.count, sliding: direction)
                    if tile.row != cell.row || tile.column != cell.column { moved = true }
                    tile.row = cell.row
                    tile.column = cell.column
                    placed.append(tile)
                    lastCanMerge = true
                }
            }
            result += placed
        }
        guard moved else { return false }
        tiles = result
        mergedAway = vanished
        score += gained
        merges += merged
        moves += 1
        previous = before
        spawn()
        isOver = !canSlide || movesLeft == 0
        return true
    }

    /// Takes back the last slide, its points and the tile it brought, using one of the game's
    /// undos. Only one slide back: another undo needs another slide first.
    @discardableResult
    public mutating func undo() -> Bool {
        guard canUndo, let snapshot = previous else { return false }
        tiles = snapshot.tiles.map { tile in
            var settled = tile
            settled.isNew = false
            settled.isMerged = false
            return settled
        }
        mergedAway = []
        score = snapshot.score
        moves = snapshot.moves
        merges = snapshot.merges
        nextID = snapshot.nextID
        spawner = snapshot.spawner
        previous = nil
        undosLeft -= 1
        undosUsed += 1
        return true
    }

    // MARK: Helpers

    /// How far a tile is from the edge it slides towards (0 is against it).
    static func position(of tile: Tile, sliding direction: SlideDirection) -> Int {
        switch direction {
        case .left: tile.column
        case .right: size - 1 - tile.column
        case .up: tile.row
        case .down: size - 1 - tile.row
        }
    }

    /// The cell `position` steps from the edge, in row or column `line`.
    static func cell(line: Int, position: Int, sliding direction: SlideDirection) -> (row: Int, column: Int) {
        switch direction {
        case .left: (line, position)
        case .right: (line, size - 1 - position)
        case .up: (position, line)
        case .down: (size - 1 - position, line)
        }
    }

    private mutating func spawn() {
        var empty: [(row: Int, column: Int)] = []
        for row in 0..<Self.size {
            for column in 0..<Self.size where tile(row: row, column: column) == nil {
                empty.append((row, column))
            }
        }
        guard !empty.isEmpty else { return }
        let cell = empty[Int.random(in: 0..<empty.count, using: &spawner)]
        let value = Double.random(in: 0..<1, using: &spawner) < 0.9 ? 2 : 4
        tiles.append(Tile(id: nextID, value: value, row: cell.row, column: cell.column, isNew: true))
        nextID += 1
    }
}

extension SlideDirection {
    var isVertical: Bool { self == .up || self == .down }
}
