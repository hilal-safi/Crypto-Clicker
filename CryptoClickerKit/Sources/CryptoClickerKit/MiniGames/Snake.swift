import Foundation

public enum SnakeDirection: Int, CaseIterable, Sendable {
    case up, right, down, left

    public var opposite: SnakeDirection {
        switch self {
        case .up: .down
        case .right: .left
        case .down: .up
        case .left: .right
        }
    }

    var step: GridPoint {
        switch self {
        case .up: GridPoint(x: 0, y: -1)
        case .right: GridPoint(x: 1, y: 0)
        case .down: GridPoint(x: 0, y: 1)
        case .left: GridPoint(x: -1, y: 0)
        }
    }
}

/// Classic Snake on a 15x20 board. The snake moves one cell per tick and grows by one for every
/// coin it eats; hitting a wall or itself ends the game. Up to two turns are queued, so quick
/// swipes between ticks are never lost, and turning straight back into the neck is ignored.
public struct SnakeGame: Sendable {
    public static let width = 15
    public static let height = 20
    public static let pointsPerCoin = 10

    /// Board cells from head to tail.
    public private(set) var body: [GridPoint]
    public private(set) var heading: SnakeDirection = .right
    /// The coin to eat next; `nil` only once the snake fills the whole board.
    public private(set) var food: GridPoint?
    public private(set) var eaten = 0
    public private(set) var isOver = false
    private var queuedTurns: [SnakeDirection] = []

    public init<R: RandomNumberGenerator>(using rng: inout R) {
        let row = Self.height / 2
        body = [GridPoint(x: 4, y: row), GridPoint(x: 3, y: row), GridPoint(x: 2, y: row)]
        placeFood(using: &rng)
    }

    public var head: GridPoint { body[0] }
    public var score: Int { eaten * Self.pointsPerCoin }

    /// Seconds per move: 0.18s at the start, speeding up to 0.08s as the snake eats.
    public var tickInterval: TimeInterval { max(0.08, 0.18 - Double(eaten) * 0.004) }

    /// Queues a turn, applied on a coming tick. Repeating the current heading or reversing into
    /// the neck is ignored.
    public mutating func turn(_ direction: SnakeDirection) {
        guard !isOver, queuedTurns.count < 2 else { return }
        let current = queuedTurns.last ?? heading
        guard direction != current, direction != current.opposite else { return }
        queuedTurns.append(direction)
    }

    /// Moves one cell, eating the coin if the head reaches it.
    public mutating func step<R: RandomNumberGenerator>(using rng: inout R) {
        guard !isOver else { return }
        if !queuedTurns.isEmpty { heading = queuedTurns.removeFirst() }
        let next = GridPoint(x: head.x + heading.step.x, y: head.y + heading.step.y)
        guard (0..<Self.width).contains(next.x), (0..<Self.height).contains(next.y) else {
            isOver = true
            return
        }
        let grows = next == food
        // The tail moves out of the way on this tick, unless the snake is growing.
        if body.dropLast(grows ? 0 : 1).contains(next) {
            isOver = true
            return
        }
        body.insert(next, at: 0)
        if grows {
            eaten += 1
            placeFood(using: &rng)
        } else {
            body.removeLast()
        }
    }

    private mutating func placeFood<R: RandomNumberGenerator>(using rng: inout R) {
        let occupied = Set(body)
        var free: [GridPoint] = []
        free.reserveCapacity(Self.width * Self.height - body.count)
        for y in 0..<Self.height {
            for x in 0..<Self.width where !occupied.contains(GridPoint(x: x, y: y)) {
                free.append(GridPoint(x: x, y: y))
            }
        }
        food = free.randomElement(using: &rng)
        if food == nil { isOver = true } // The snake fills the board: a perfect game.
    }

    #if DEBUG
    /// Test hook: places the snake and the coin.
    mutating func load(body: [GridPoint], heading: SnakeDirection, food: GridPoint?) {
        self.body = body
        self.heading = heading
        self.food = food
        queuedTurns = []
        isOver = false
    }
    #endif
}
