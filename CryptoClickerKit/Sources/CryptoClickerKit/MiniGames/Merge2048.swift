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
public struct Merge2048Game: Sendable {
    public static let size = 4
    public static let winningValue = 2048

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
    private var nextID = 0

    public init<R: RandomNumberGenerator>(using rng: inout R) {
        spawn(using: &rng)
        spawn(using: &rng)
    }

    /// A board laid out by hand, for tests: `rows` of values, 0 for an empty cell.
    init(rows: [[Int]]) {
        for (row, values) in rows.enumerated() {
            for (column, value) in values.enumerated() where value > 0 {
                tiles.append(Tile(id: nextID, value: value, row: row, column: column, isNew: false))
                nextID += 1
            }
        }
        isOver = !canSlide
    }

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
    /// doesn't count, adds no tile and leaves the game exactly as it was.
    @discardableResult
    public mutating func slide<R: RandomNumberGenerator>(_ direction: SlideDirection, using rng: inout R) -> Bool {
        guard !isOver else { return false }
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
        spawn(using: &rng)
        isOver = !canSlide
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

    private mutating func spawn<R: RandomNumberGenerator>(using rng: inout R) {
        var empty: [(row: Int, column: Int)] = []
        for row in 0..<Self.size {
            for column in 0..<Self.size where tile(row: row, column: column) == nil {
                empty.append((row, column))
            }
        }
        guard !empty.isEmpty else { return }
        let cell = empty[Int.random(in: 0..<empty.count, using: &rng)]
        let value = Double.random(in: 0..<1, using: &rng) < 0.9 ? 2 : 4
        tiles.append(Tile(id: nextID, value: value, row: cell.row, column: cell.column, isNew: true))
        nextID += 1
    }
}

extension SlideDirection {
    var isVertical: Bool { self == .up || self == .down }
}
