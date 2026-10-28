import Foundation

public enum Tetromino: Int, CaseIterable, Codable, Sendable {
    case i = 1, o, t, s, z, j, l

    public var name: String {
        switch self {
        case .i: "I"
        case .o: "O"
        case .t: "T"
        case .s: "S"
        case .z: "Z"
        case .j: "J"
        case .l: "L"
        }
    }

    /// Side of the square box the piece rotates in (SRS).
    public var boxSize: Int {
        switch self {
        case .i: 4
        case .o: 2
        default: 3
        }
    }

    /// Cells of the spawn orientation inside the rotation box, y pointing down.
    private var spawnCells: [GridPoint] {
        let points: [(Int, Int)] = switch self {
        case .i: [(0, 1), (1, 1), (2, 1), (3, 1)]
        case .o: [(0, 0), (1, 0), (0, 1), (1, 1)]
        case .t: [(1, 0), (0, 1), (1, 1), (2, 1)]
        case .s: [(1, 0), (2, 0), (0, 1), (1, 1)]
        case .z: [(0, 0), (1, 0), (1, 1), (2, 1)]
        case .j: [(0, 0), (0, 1), (1, 1), (2, 1)]
        case .l: [(2, 0), (0, 1), (1, 1), (2, 1)]
        }
        return points.map { GridPoint(x: $0.0, y: $0.1) }
    }

    /// Cells for rotation state 0 (spawn), 1 (R), 2 or 3 (L), each a clockwise turn of the box.
    public func cells(rotation: Int) -> [GridPoint] {
        var cells = spawnCells
        let turns = ((rotation % 4) + 4) % 4
        guard self != .o else { return cells }
        for _ in 0..<turns {
            cells = cells.map { GridPoint(x: boxSize - 1 - $0.y, y: $0.x) }
        }
        return cells
    }
}

public struct TetrisPiece: Equatable, Sendable {
    public let kind: Tetromino
    public internal(set) var rotation: Int
    /// Top-left corner of the rotation box on the board.
    public internal(set) var x: Int
    public internal(set) var y: Int

    public var cells: [GridPoint] {
        kind.cells(rotation: rotation).map { GridPoint(x: $0.x + x, y: $0.y + y) }
    }

    func moved(dx: Int = 0, dy: Int = 0) -> TetrisPiece {
        var copy = self
        copy.x += dx
        copy.y += dy
        return copy
    }
}

/// Guideline-style Tetris on a 10x20 board: 7-bag randomizer, SRS rotation with wall kicks,
/// a ghost piece, a hold slot, one tick of lock delay, and 100/300/500/800 x level line scores.
/// Clearing lines with piece after piece builds a combo worth 50 x combo x level more each time.
///
/// Two modes: Endless goes on, faster every 10 lines, until the stack tops out; Sprint ends the
/// moment 40 lines are cleared, as fast as the player can.
public struct TetrisGame: Sendable {
    public enum Mode: Hashable, Sendable {
        case endless
        /// Clear this many lines as quickly as possible.
        case sprint(lines: Int)
    }

    public static let width = 10
    public static let height = 20
    public static let sprintLines = 40
    static let lineScores = [0, 100, 300, 500, 800]
    /// Points for each step of a combo, times the level.
    public static let comboPoints = 50

    public let mode: Mode

    /// Row-major cells; 0 is empty, otherwise the `Tetromino` raw value that settled there.
    public private(set) var board: [Int]
    public private(set) var piece: TetrisPiece?
    public private(set) var queue: [Tetromino] = []
    public private(set) var score = 0
    /// The score without the level multiplier: line clears at their level 1 value, plus drops. Coins
    /// are paid on these, so the multiplier that keeps climbing in a long game makes points worth
    /// more on screen without making Tetris pay far more than the other games.
    public private(set) var rewardPoints = 0
    public private(set) var lines = 0
    public private(set) var isOver = false
    /// A Sprint's lines are all cleared (the game is over, and won).
    public private(set) var isComplete = false
    /// The piece set aside, to swap back in later.
    public private(set) var held: Tetromino?
    /// Hold works once per piece: the piece in play hasn't come out of the hold this turn.
    public private(set) var canHold = true
    /// Line clears in a row: 0 for a first clear, 1 for the next, and so on; -1 after a piece
    /// that cleared nothing.
    public private(set) var combo = -1
    public private(set) var bestCombo = 0
    /// Four lines at once.
    public private(set) var tetrises = 0
    /// Rows the last lock cleared (as they were numbered before the rows above fell), for effects.
    public private(set) var clearedRows: [Int] = []
    /// Counts locked pieces, for effects.
    public private(set) var pieces = 0
    private var groundedTicks = 0

    public init<R: RandomNumberGenerator>(mode: Mode = .endless, using rng: inout R) {
        self.mode = mode
        board = Array(repeating: 0, count: Self.width * Self.height)
        refillQueue(using: &rng)
        spawn(using: &rng)
    }

    /// Lines still to clear in a Sprint (0 in Endless).
    public var linesLeft: Int {
        guard case .sprint(let target) = mode else { return 0 }
        return max(0, target - lines)
    }

    public var level: Int { lines / 10 + 1 }

    public var nextPiece: Tetromino? { queue.first }

    /// Seconds between gravity steps: 1s at level 1, about 0.23s at level 10, never below 0.1s.
    public var gravityInterval: TimeInterval { max(0.1, pow(0.85, Double(level - 1))) }

    /// The piece type settled at a cell, if any.
    public func block(x: Int, y: Int) -> Tetromino? {
        guard (0..<Self.width).contains(x), (0..<Self.height).contains(y) else { return nil }
        return Tetromino(rawValue: board[y * Self.width + x])
    }

    /// Where the current piece would land with a hard drop.
    public var ghost: TetrisPiece? {
        guard var landing = piece else { return nil }
        while isValid(landing.moved(dy: 1)) { landing = landing.moved(dy: 1) }
        return landing
    }

    // MARK: Controls

    @discardableResult
    public mutating func moveLeft() -> Bool { shift(dx: -1) }

    @discardableResult
    public mutating func moveRight() -> Bool { shift(dx: 1) }

    /// Rotates with SRS wall kicks. Returns `false` if no kick position fits.
    @discardableResult
    public mutating func rotate(clockwise: Bool = true) -> Bool {
        guard !isOver, let current = piece, current.kind != .o else { return false }
        let from = current.rotation
        let to = (from + (clockwise ? 1 : 3)) % 4
        for kick in Self.kicks(for: current.kind, from: from, to: to) {
            var candidate = current
            candidate.rotation = to
            candidate.x += kick.x
            candidate.y -= kick.y // Kick tables use y-up; the board uses y-down.
            if isValid(candidate) {
                piece = candidate
                return true
            }
        }
        return false
    }

    /// Moves down one row for a point; locks at once if the piece is already resting.
    public mutating func softDrop<R: RandomNumberGenerator>(using rng: inout R) {
        guard !isOver, let current = piece else { return }
        if isValid(current.moved(dy: 1)) {
            piece = current.moved(dy: 1)
            score += 1
            rewardPoints += 1
            groundedTicks = 0
        } else {
            lock(using: &rng)
        }
    }

    /// Drops to the ghost position for two points a row and locks.
    public mutating func hardDrop<R: RandomNumberGenerator>(using rng: inout R) {
        guard !isOver, let current = piece, let landing = ghost else { return }
        score += 2 * (landing.y - current.y)
        rewardPoints += 2 * (landing.y - current.y)
        piece = landing
        lock(using: &rng)
    }

    /// Sets the piece in play aside (or swaps it with the one held), once per piece. The piece from
    /// the hold starts again at the top.
    @discardableResult
    public mutating func hold<R: RandomNumberGenerator>(using rng: inout R) -> Bool {
        guard !isOver, canHold, let current = piece else { return false }
        canHold = false
        groundedTicks = 0
        let swappedIn = held
        held = current.kind
        if let swappedIn {
            let candidate = Self.spawnPosition(for: swappedIn)
            if isValid(candidate) {
                piece = candidate
            } else {
                piece = nil
                isOver = true
            }
        } else {
            spawn(using: &rng)
        }
        return true
    }

    /// One gravity step. A resting piece locks on its second grounded tick.
    public mutating func tick<R: RandomNumberGenerator>(using rng: inout R) {
        guard !isOver, let current = piece else { return }
        if isValid(current.moved(dy: 1)) {
            piece = current.moved(dy: 1)
            groundedTicks = 0
        } else {
            groundedTicks += 1
            if groundedTicks >= 2 { lock(using: &rng) }
        }
    }

    // MARK: Rules

    func isValid(_ candidate: TetrisPiece) -> Bool {
        candidate.cells.allSatisfy { cell in
            guard (0..<Self.width).contains(cell.x), cell.y < Self.height else { return false }
            return cell.y < 0 || board[cell.y * Self.width + cell.x] == 0
        }
    }

    private mutating func shift(dx: Int) -> Bool {
        guard !isOver, let current = piece, isValid(current.moved(dx: dx)) else { return false }
        piece = current.moved(dx: dx)
        return true
    }

    private mutating func lock<R: RandomNumberGenerator>(using rng: inout R) {
        guard let current = piece else { return }
        piece = nil
        groundedTicks = 0
        canHold = true
        pieces += 1
        for cell in current.cells {
            guard cell.y >= 0 else {
                isOver = true // Locked above the visible board.
                return
            }
            board[cell.y * Self.width + cell.x] = current.kind.rawValue
        }
        clearLines()
        if case .sprint(let target) = mode, lines >= target {
            isComplete = true
            isOver = true
            return
        }
        spawn(using: &rng)
    }

    private mutating func clearLines() {
        var kept: [[Int]] = []
        clearedRows = []
        for row in 0..<Self.height {
            let cells = Array(board[(row * Self.width)..<((row + 1) * Self.width)])
            if cells.contains(0) {
                kept.append(cells)
            } else {
                clearedRows.append(row)
            }
        }
        let cleared = Self.height - kept.count
        guard cleared > 0 else {
            combo = -1
            return
        }
        // The level the clear happens at, before these lines can raise it.
        let clearLevel = level
        let empty = Array(repeating: Array(repeating: 0, count: Self.width), count: cleared)
        board = (empty + kept).flatMap { $0 }
        combo += 1
        bestCombo = max(bestCombo, combo)
        if cleared >= 4 { tetrises += 1 }
        let comboBonus = Self.comboPoints * combo
        score += (Self.lineScores[min(cleared, 4)] + comboBonus) * clearLevel
        rewardPoints += Self.lineScores[min(cleared, 4)] + comboBonus
        lines += cleared
    }

    static func spawnPosition(for kind: Tetromino) -> TetrisPiece {
        TetrisPiece(kind: kind, rotation: 0, x: kind == .o ? 4 : 3, y: kind == .i ? -1 : 0)
    }

    private mutating func spawn<R: RandomNumberGenerator>(using rng: inout R) {
        if queue.count < 7 { refillQueue(using: &rng) }
        let candidate = Self.spawnPosition(for: queue.removeFirst())
        if isValid(candidate) {
            piece = candidate
        } else {
            isOver = true // Block out: no room to spawn.
        }
    }

    /// 7-bag randomizer: every run of seven pieces contains each tetromino once.
    private mutating func refillQueue<R: RandomNumberGenerator>(using rng: inout R) {
        queue.append(contentsOf: Tetromino.allCases.shuffled(using: &rng))
    }

    /// SRS wall-kick offsets (x right, y up) tried in order when rotating `from` -> `to`.
    static func kicks(for kind: Tetromino, from: Int, to: Int) -> [GridPoint] {
        let table: [(Int, Int)]
        if kind == .i {
            table = switch (from, to) {
            case (0, 1): [(0, 0), (-2, 0), (1, 0), (-2, -1), (1, 2)]
            case (1, 0): [(0, 0), (2, 0), (-1, 0), (2, 1), (-1, -2)]
            case (1, 2): [(0, 0), (-1, 0), (2, 0), (-1, 2), (2, -1)]
            case (2, 1): [(0, 0), (1, 0), (-2, 0), (1, -2), (-2, 1)]
            case (2, 3): [(0, 0), (2, 0), (-1, 0), (2, 1), (-1, -2)]
            case (3, 2): [(0, 0), (-2, 0), (1, 0), (-2, -1), (1, 2)]
            case (3, 0): [(0, 0), (1, 0), (-2, 0), (1, -2), (-2, 1)]
            case (0, 3): [(0, 0), (-1, 0), (2, 0), (-1, 2), (2, -1)]
            default: [(0, 0)]
            }
        } else {
            table = switch (from, to) {
            case (0, 1), (2, 1): [(0, 0), (-1, 0), (-1, 1), (0, -2), (-1, -2)]
            case (1, 0), (1, 2): [(0, 0), (1, 0), (1, -1), (0, 2), (1, 2)]
            case (2, 3), (0, 3): [(0, 0), (1, 0), (1, 1), (0, -2), (1, -2)]
            case (3, 2), (3, 0): [(0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2)]
            default: [(0, 0)]
            }
        }
        return table.map { GridPoint(x: $0.0, y: $0.1) }
    }

    #if DEBUG
    /// Test hook: places settled blocks and a specific piece. The combo starts over unless kept.
    mutating func load(blocks: [GridPoint], piece: TetrisPiece?, keepCombo: Bool = false) {
        board = Array(repeating: 0, count: Self.width * Self.height)
        for block in blocks { board[block.y * Self.width + block.x] = Tetromino.o.rawValue }
        self.piece = piece
        isOver = false
        groundedTicks = 0
        if !keepCombo { combo = -1 }
    }
    #endif
}
