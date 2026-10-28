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

/// Snake on a 15x20 board. The snake moves one cell per tick and grows by one for every coin it
/// eats; hitting a wall, an obstacle or itself ends the game. Up to two turns are queued, so quick
/// swipes between ticks are never lost, and turning straight back into the neck is ignored.
///
/// Two modes: Classic, in a choice of arenas, goes on until the snake crashes, speeding up as it
/// eats; Coin Rush lasts a minute in the open arena with three coins out at once.
///
/// Every few coins a power-up appears for a while: Speed Boost (faster, and coins count double),
/// Slow Motion (slower), Shield (one crash forgiven: the snake waits a moment for a turn) or Coin
/// Magnet (coins near the head are pulled in). Speed Boost and Slow Motion replace each other, a
/// second Shield adds nothing, and picking up a power-up already running restarts its timer, so
/// effects never pile up.
///
/// Time only moves with `step(using:)`, one tick at a time, so the view drives it at `tickInterval`.
public struct SnakeGame: Sendable {
    public static let width = 15
    public static let height = 20
    public static let pointsPerCoin = 10
    public static let coinRushLength: TimeInterval = 60
    public static let coinRushCoins = 3
    /// A power-up appears after this many coins eaten without one out.
    public static let coinsPerPowerUp = 6
    /// How long a power-up waits on the board to be picked up.
    public static let powerUpLifetime: TimeInterval = 10
    /// Ticks a Shield holds the snake still after a crash, waiting for a turn.
    public static let shieldGraceTicks = 4
    /// Coins this close to the head (in steps) are pulled in by the Magnet.
    public static let magnetReach = 2

    public enum Mode: Hashable, Sendable {
        case classic
        case coinRush
    }

    public enum Arena: String, CaseIterable, Codable, Sendable, Identifiable {
        case open, pillars, rooms, cross

        public var id: String { rawValue }

        public var name: String {
            switch self {
            case .open: "Open"
            case .pillars: "Pillars"
            case .rooms: "Rooms"
            case .cross: "Crossroads"
            }
        }

        /// Cells walled off in this arena. None touch the starting row.
        public var walls: Set<GridPoint> {
            var cells: [GridPoint] = []
            switch self {
            case .open:
                break
            case .pillars:
                for (x, y) in [(3, 4), (10, 4), (3, 14), (10, 14)] {
                    cells += [GridPoint(x: x, y: y), GridPoint(x: x + 1, y: y), GridPoint(x: x, y: y + 1), GridPoint(x: x + 1, y: y + 1)]
                }
            case .rooms:
                for y in [5, 15] {
                    cells += (0...4).map { GridPoint(x: $0, y: y) } + (10...14).map { GridPoint(x: $0, y: y) }
                }
            case .cross:
                cells += (2...7).map { GridPoint(x: 7, y: $0) } + (13...17).map { GridPoint(x: 7, y: $0) }
                cells += (2...5).map { GridPoint(x: $0, y: 13) } + (9...12).map { GridPoint(x: $0, y: 7) }
            }
            return Set(cells)
        }
    }

    public enum PowerUp: String, CaseIterable, Codable, Sendable {
        case speedBoost, slowMotion, shield, magnet

        public var name: String {
            switch self {
            case .speedBoost: "Speed Boost"
            case .slowMotion: "Slow Motion"
            case .shield: "Shield"
            case .magnet: "Coin Magnet"
            }
        }

        /// How long it lasts once picked up; a Shield lasts until it's used.
        public var duration: TimeInterval? {
            switch self {
            case .speedBoost: 6
            case .slowMotion: 8
            case .shield: nil
            case .magnet: 8
            }
        }
    }

    /// A power-up waiting on the board.
    public struct Item: Equatable, Sendable {
        public let kind: PowerUp
        public let position: GridPoint
        /// Seconds left before it disappears.
        public internal(set) var timeLeft: TimeInterval
    }

    public let mode: Mode
    public let arena: Arena
    public let walls: Set<GridPoint>
    /// Board cells from head to tail.
    public private(set) var body: [GridPoint]
    public private(set) var heading: SnakeDirection = .right
    /// Coins to eat: one in Classic, three in Coin Rush.
    public private(set) var coins: [GridPoint] = []
    public private(set) var item: Item?
    /// Timed power-ups running, with the seconds left.
    public private(set) var effects: [PowerUp: TimeInterval] = [:]
    public private(set) var hasShield = false
    /// Ticks left waiting for a turn after a Shield forgave a crash.
    public private(set) var graceTicks = 0
    public private(set) var eaten = 0
    public private(set) var score = 0
    public private(set) var powerUpsCollected = 0
    /// Seconds played.
    public private(set) var time: TimeInterval = 0
    public private(set) var isOver = false
    /// Coins eaten since the last power-up appeared.
    private var coinsSinceItem = 0
    /// Moves left that grow the snake (for coins the Magnet pulled in).
    private var pendingGrowth = 0
    private var queuedTurns: [SnakeDirection] = []

    public init<R: RandomNumberGenerator>(mode: Mode = .classic, arena: Arena = .open, using rng: inout R) {
        self.mode = mode
        self.arena = mode == .coinRush ? .open : arena
        walls = self.arena.walls
        let row = Self.height / 2
        body = [GridPoint(x: 4, y: row), GridPoint(x: 3, y: row), GridPoint(x: 2, y: row)]
        while coins.count < coinTarget, let coin = freeCell(using: &rng) { coins.append(coin) }
    }

    public var head: GridPoint { body[0] }
    /// The first coin, for a single-coin board.
    public var food: GridPoint? { coins.first }
    private var coinTarget: Int { mode == .coinRush ? Self.coinRushCoins : 1 }

    public var timeLeft: TimeInterval { mode == .coinRush ? max(0, Self.coinRushLength - time) : 0 }

    public func isActive(_ powerUp: PowerUp) -> Bool {
        powerUp == .shield ? hasShield : (effects[powerUp] ?? 0) > 0
    }

    /// Points a coin is worth now: double during a Speed Boost.
    public var coinValue: Int { Self.pointsPerCoin * (isActive(.speedBoost) ? 2 : 1) }

    /// Seconds per move: 0.18s at the start, speeding up to 0.08s as the snake eats; a Speed
    /// Boost moves faster and Slow Motion slower, but never faster than a finger can steer.
    public var tickInterval: TimeInterval {
        let base = max(0.08, 0.18 - Double(eaten) * 0.004)
        if isActive(.speedBoost) { return max(0.065, base * 0.65) }
        if isActive(.slowMotion) { return base * 1.7 }
        return base
    }

    /// Queues a turn, applied on a coming tick. Repeating the current heading or reversing into
    /// the neck is ignored.
    public mutating func turn(_ direction: SnakeDirection) {
        guard !isOver, queuedTurns.count < 2 else { return }
        let current = queuedTurns.last ?? heading
        guard direction != current, direction != current.opposite else { return }
        queuedTurns.append(direction)
    }

    /// Moves one cell, eating a coin or picking up a power-up if the head reaches one.
    public mutating func step<R: RandomNumberGenerator>(using rng: inout R) {
        guard !isOver else { return }
        let interval = tickInterval
        defer { passTime(interval) }
        if mode == .coinRush && time >= Self.coinRushLength {
            isOver = true
            return
        }
        if !queuedTurns.isEmpty { heading = queuedTurns.removeFirst() }
        let next = GridPoint(x: head.x + heading.step.x, y: head.y + heading.step.y)
        let grows = coins.contains(next) || pendingGrowth > 0
        // The tail moves out of the way on this tick, unless the snake is growing.
        let crashes = !(0..<Self.width).contains(next.x) || !(0..<Self.height).contains(next.y)
            || walls.contains(next) || body.dropLast(grows ? 0 : 1).contains(next)
        if crashes {
            if graceTicks > 0 {
                graceTicks -= 1 // Still waiting for a turn.
                return
            }
            if hasShield {
                hasShield = false
                graceTicks = Self.shieldGraceTicks
                return
            }
            isOver = true
            return
        }
        graceTicks = 0
        body.insert(next, at: 0)
        if let index = coins.firstIndex(of: next) {
            coins.remove(at: index)
            eat()
        } else if pendingGrowth > 0 {
            pendingGrowth -= 1
        } else {
            body.removeLast()
        }
        if let item, item.position == next { collect(item.kind) }
        if isActive(.magnet) {
            for coin in coins where abs(coin.x - next.x) + abs(coin.y - next.y) <= Self.magnetReach {
                coins.removeAll { $0 == coin }
                pendingGrowth += 1
                eat()
            }
        }
        while coins.count < coinTarget {
            guard let coin = freeCell(using: &rng) else {
                if coins.isEmpty { isOver = true } // The snake fills the board: a perfect game.
                break
            }
            coins.append(coin)
        }
        if item == nil && coinsSinceItem >= Self.coinsPerPowerUp, let spot = freeCell(using: &rng) {
            let kind = PowerUp.allCases.randomElement(using: &rng) ?? .shield
            item = Item(kind: kind, position: spot, timeLeft: Self.powerUpLifetime)
            coinsSinceItem = 0
        }
    }

    private mutating func eat() {
        eaten += 1
        score += coinValue
        coinsSinceItem += 1
    }

    private mutating func collect(_ kind: PowerUp) {
        item = nil
        powerUpsCollected += 1
        switch kind {
        case .shield:
            hasShield = true
        case .speedBoost, .slowMotion:
            // One speed at a time.
            effects[kind == .speedBoost ? .slowMotion : .speedBoost] = nil
            effects[kind] = kind.duration
        case .magnet:
            effects[kind] = kind.duration
        }
    }

    private mutating func passTime(_ seconds: TimeInterval) {
        time += seconds
        for (kind, left) in effects {
            effects[kind] = left - seconds > 0 ? left - seconds : nil
        }
        if var waiting = item {
            waiting.timeLeft -= seconds
            item = waiting.timeLeft > 0 ? waiting : nil
        }
    }

    /// A random cell clear of the snake, walls, coins and the power-up.
    private func freeCell<R: RandomNumberGenerator>(using rng: inout R) -> GridPoint? {
        let occupied = Set(body).union(walls).union(coins).union(item.map { [$0.position] } ?? [])
        var free: [GridPoint] = []
        free.reserveCapacity(Self.width * Self.height - occupied.count)
        for y in 0..<Self.height {
            for x in 0..<Self.width where !occupied.contains(GridPoint(x: x, y: y)) {
                free.append(GridPoint(x: x, y: y))
            }
        }
        return free.randomElement(using: &rng)
    }

    #if DEBUG
    /// Test hook: places the snake and the coin.
    mutating func load(body: [GridPoint], heading: SnakeDirection, food: GridPoint?) {
        self.body = body
        self.heading = heading
        coins = food.map { [$0] } ?? []
        queuedTurns = []
        isOver = false
    }

    /// Test hook: puts a power-up on the board.
    mutating func place(_ kind: PowerUp, at position: GridPoint) {
        item = Item(kind: kind, position: position, timeLeft: Self.powerUpLifetime)
    }

    /// Test hook: sets the coins.
    mutating func placeCoins(_ positions: [GridPoint]) {
        coins = positions
    }
    #endif
}
