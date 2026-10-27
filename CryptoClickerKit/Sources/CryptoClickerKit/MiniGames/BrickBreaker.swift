import Foundation

/// Brick Breaker: keep the ball in play with the paddle and clear every brick to reach the next,
/// faster level. Three balls per game. The field is 1 unit wide and 1.5 units tall, y pointing down.
///
/// Level 1 is always a plain wall. From level 2 each wall takes a random shape (a checkerboard, a
/// pyramid, columns, stripes, a diamond, a frame or scattered bricks), and tough bricks that take
/// two hits make up the difference, so every wall takes about as many hits as a full one.
///
/// The ball moves in small sub-steps (never more than half its radius), so it can't pass through
/// a brick or the paddle on a slow frame.
public struct BrickBreakerGame: Sendable {
    public enum Phase: Equatable, Sendable {
        /// The ball rests on the paddle, waiting for a launch.
        case serving
        case playing
        case over
    }

    public struct Brick: Equatable, Sendable, Identifiable {
        public let id: Int
        public let row: Int
        public let frame: Box
        public let maxHits: Int
        public internal(set) var hitsLeft: Int
    }

    public static let width = 1.0
    public static let height = 1.5
    public static let ballRadius = 0.018
    public static let paddleWidth = 0.24
    public static let paddleHeight = 0.028
    public static let paddleTop = 1.40
    public static let columns = 7
    public static let startingLives = 3
    /// Hitting the paddle's edge sends the ball off at up to this angle from straight up.
    static let maxBounceAngle = Double.pi / 3
    static let brickTop = 0.14
    static let brickHeight = 0.045
    static let brickGap = 0.012
    static let sideMargin = 0.03

    public private(set) var bricks: [Brick] = []
    public private(set) var ball = Vector2.zero
    public private(set) var velocity = Vector2.zero
    public private(set) var paddleX = width / 2
    public private(set) var phase = Phase.serving
    public private(set) var lives = startingLives
    public private(set) var level = 1
    public private(set) var score = 0
    public private(set) var bricksBroken = 0
    /// Counts paddle hits, for haptics.
    public private(set) var paddleHits = 0
    private var serves = 0
    private var nextBrickID = 0
    /// Shapes the walls after level 1.
    private var rng: SeededGenerator

    public init(seed: UInt64 = .random(in: 0...UInt64.max)) {
        rng = SeededGenerator(seed: seed)
        layOutBricks()
        serve()
    }

    /// Ball speed in field units per second; each level is faster.
    public var speed: Double { min(1.5, 0.8 + Double(level - 1) * 0.1) }

    public var paddle: Box {
        Box(minX: paddleX - Self.paddleWidth / 2, minY: Self.paddleTop, width: Self.paddleWidth, height: Self.paddleHeight)
    }

    /// Rows of bricks on this level: five at first, up to eight.
    static func rows(for level: Int) -> Int { min(4 + level, 8) }

    // MARK: Controls

    /// Centers the paddle at `x`, kept inside the field. A serving ball rides along.
    public mutating func movePaddle(to x: Double) {
        guard phase != .over, x.isFinite else { return }
        paddleX = min(max(x, Self.paddleWidth / 2), Self.width - Self.paddleWidth / 2)
        if phase == .serving { ball.x = paddleX }
    }

    /// Sends a serving ball up, alternating slightly left and right.
    public mutating func launch() {
        guard phase == .serving else { return }
        serves += 1
        let angle = (serves % 2 == 1 ? 1.0 : -1.0) * 0.35
        velocity = Vector2(x: sin(angle), y: -cos(angle)) * speed
        phase = .playing
    }

    /// Advances the game by `seconds` (a long frame counts as at most 1/20 s).
    public mutating func update(by seconds: Double) {
        guard phase == .playing, seconds > 0 else { return }
        var remaining = min(seconds, 0.05)
        let maxStep = Self.ballRadius * 0.5 / speed
        while remaining > 1e-12 && phase == .playing {
            let step = min(remaining, maxStep)
            remaining -= step
            moveBall(by: step)
        }
    }

    // MARK: Physics

    private mutating func moveBall(by seconds: Double) {
        let previous = ball
        let radius = Self.ballRadius
        ball = ball + velocity * seconds

        if ball.x < radius {
            ball.x = radius
            velocity.x = abs(velocity.x)
        } else if ball.x > Self.width - radius {
            ball.x = Self.width - radius
            velocity.x = -abs(velocity.x)
        }
        if ball.y < radius {
            ball.y = radius
            velocity.y = abs(velocity.y)
        }

        let paddle = paddle
        if velocity.y > 0 && ball.y <= paddle.maxY && paddle.intersects(circle: ball, radius: radius) {
            // Where the ball meets the paddle sets its angle: the middle sends it straight up.
            let offset = min(max((ball.x - paddleX) / (Self.paddleWidth / 2), -1), 1)
            let angle = offset * Self.maxBounceAngle
            velocity = Vector2(x: sin(angle), y: -cos(angle)) * speed
            ball.y = paddle.minY - radius
            paddleHits += 1
        }

        if let index = bricks.firstIndex(where: { $0.frame.intersects(circle: ball, radius: radius) }) {
            bounce(off: bricks[index].frame, from: previous)
            hitBrick(at: index)
        }

        if ball.y - radius > Self.height {
            loseBall()
            return
        }
        keepAngleUseful()
    }

    /// Reflects the ball off the side of `frame` it struck and moves it clear of the brick.
    private mutating func bounce(off frame: Box, from previous: Vector2) {
        let radius = Self.ballRadius
        var closest = frame.closestPoint(to: ball)
        var dx = ball.x - closest.x
        var dy = ball.y - closest.y
        if dx == 0 && dy == 0 {
            // The center is inside the brick: judge the side from where the ball came from.
            closest = frame.closestPoint(to: previous)
            dx = previous.x - closest.x
            dy = previous.y - closest.y
        }
        if abs(dx) > abs(dy) {
            velocity.x = dx > 0 ? abs(velocity.x) : -abs(velocity.x)
            ball.x = dx > 0 ? frame.maxX + radius : frame.minX - radius
        } else {
            velocity.y = dy > 0 ? abs(velocity.y) : -abs(velocity.y)
            ball.y = dy > 0 ? frame.maxY + radius : frame.minY - radius
        }
    }

    private mutating func hitBrick(at index: Int) {
        bricks[index].hitsLeft -= 1
        guard bricks[index].hitsLeft <= 0 else { return }
        score += 10 * bricks[index].maxHits
        bricksBroken += 1
        bricks.remove(at: index)
        if bricks.isEmpty {
            score += 100 * level
            level += 1
            layOutBricks()
            serve()
        }
    }

    /// Keeps the ball at the level's speed and never close to horizontal, so rallies keep moving.
    private mutating func keepAngleUseful() {
        guard phase == .playing else { return }
        let length = velocity.length
        guard length > 0 else { return }
        var direction = velocity * (1 / length)
        let minimumVertical = 0.3
        if abs(direction.y) < minimumVertical {
            let vertical = direction.y < 0 ? -minimumVertical : minimumVertical
            let horizontal = (1 - minimumVertical * minimumVertical).squareRoot()
            direction = Vector2(x: direction.x < 0 ? -horizontal : horizontal, y: vertical)
        }
        velocity = direction * speed
    }

    private mutating func loseBall() {
        lives -= 1
        if lives <= 0 {
            lives = 0
            phase = .over
            velocity = .zero
        } else {
            serve()
        }
    }

    private mutating func serve() {
        phase = .serving
        velocity = .zero
        ball = Vector2(x: paddleX, y: Self.paddleTop - Self.ballRadius - 0.002)
    }

    /// Hits a full wall takes on `level`: every brick once, plus the top rows twice from level 3.
    static func fullWallHits(level: Int) -> Int {
        let rows = rows(for: level)
        return rows * columns + (level >= 3 ? min(rows, level - 2) * columns : 0)
    }

    /// Fills the wall for the current level: level 1's plain wall, then random shapes with enough
    /// tough bricks to take about as many hits as a full wall.
    private mutating func layOutBricks() {
        let rows = Self.rows(for: level)
        let cells = Self.cells(level: level, rows: rows, using: &rng)
        let toughCount = level == 1 ? 0 : min(cells.count, max(0, Self.fullWallHits(level: level) - cells.count))
        let tough = Set(cells.indices.shuffled(using: &rng).prefix(toughCount))
        let width = (Self.width - 2 * Self.sideMargin - Double(Self.columns - 1) * Self.brickGap) / Double(Self.columns)
        bricks = []
        for (index, cell) in cells.enumerated() {
            let frame = Box(minX: Self.sideMargin + Double(cell.column) * (width + Self.brickGap),
                            minY: Self.brickTop + Double(cell.row) * (Self.brickHeight + Self.brickGap),
                            width: width, height: Self.brickHeight)
            let hits = tough.contains(index) ? 2 : 1
            bricks.append(Brick(id: nextBrickID, row: cell.row, frame: frame, maxHits: hits, hitsLeft: hits))
            nextBrickID += 1
        }
    }

    /// The cells with a brick on `level`, row by row. Every shape keeps at least two rows' worth.
    static func cells<R: RandomNumberGenerator>(level: Int, rows: Int, using rng: inout R) -> [(row: Int, column: Int)] {
        let all = (0..<rows).flatMap { row in (0..<columns).map { (row: row, column: $0) } }
        guard level > 1 else { return all }
        let middle = columns / 2
        let flip = Bool.random(using: &rng)
        let shape = Int.random(in: 0..<8, using: &rng)
        let scattered = Set(all.indices.filter { _ in Double.random(in: 0..<1, using: &rng) < 0.65 })
        let picked = all.enumerated().filter { index, cell in
            let (row, column) = cell
            switch shape {
            case 0: return true // A full wall.
            case 1: return (row + column + (flip ? 1 : 0)) % 2 == 0 // A checkerboard.
            case 2: return abs(column - middle) <= (flip ? rows - 1 - row : row) // A pyramid, up or down.
            case 3: return column % 2 == (flip ? 1 : 0) // Columns.
            case 4: return row % 2 == (flip ? 1 : 0) // Stripes.
            case 5: // A diamond.
                let across = Double(abs(column - middle)) / (Double(middle) + 0.5)
                let down = abs(Double(row) - Double(rows - 1) / 2) / (Double(rows) / 2)
                return across + down <= 1
            case 6: return row == 0 || row == rows - 1 || column == 0 || column == columns - 1 // A frame.
            default: return scattered.contains(index)
            }
        }.map(\.element)
        return picked.count >= 2 * columns ? picked : all
    }

    #if DEBUG
    /// Test hook: puts the ball in play at `ball` with `velocity`, against `bricks` (frames).
    mutating func load(ball: Vector2, velocity: Vector2, bricks frames: [Box], paddleX: Double = width / 2) {
        self.paddleX = paddleX
        self.ball = ball
        self.velocity = velocity
        bricks = frames.enumerated().map { Brick(id: $0.offset, row: 0, frame: $0.element, maxHits: 1, hitsLeft: 1) }
        phase = .playing
    }
    #endif
}
