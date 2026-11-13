import Foundation

/// Brick Breaker: keep the ball in play with the paddle and clear every brick to reach the next,
/// faster level. Three lives per game. The field is 1 unit wide and 1.5 units tall, y pointing down.
///
/// Classic walls are fixed: level 1 is a plain wall, and from level 2 each level has its own shape
/// (a full wall, a pyramid, stripes, a checkerboard, a diamond, scattered bricks, a frame or
/// columns, in turn) and its own armored, explosive and bonus bricks, the same every time it's
/// played. Random
/// walls are made up on the spot for every level (see `generatedCells`), with one to a few bonus
/// bricks and armored ones from the first level, so no two games look alike. Either way, armored bricks that take two hits (three from level 6) make up the
/// difference, so every wall takes about as many hits as a full one. The ball's speed is one of the
/// difficulty's (`ArcadeDifficulty`), which also sets the paddle's width. Some bricks are explosive (they break the bricks around them) and some carry a
/// bonus (they drop a power-up to catch with the paddle): Multi-ball, Wide Paddle, Slow Ball or
/// Laser. Every fifth level is a boss: a big block that slides from side to side, takes many hits,
/// and drops debris that shrinks the paddle for a while if it lands on it.
///
/// Every ball moves in small sub-steps (never more than half its radius), as do the falling
/// power-ups, laser bolts and debris, so nothing passes through anything on a slow frame. The
/// rules never depend on the frame rate.
public struct BrickBreakerGame: Sendable {
    public enum Phase: Equatable, Sendable {
        /// The ball rests on the paddle, waiting for a launch.
        case serving
        case playing
        case over
    }

    public enum BrickKind: Equatable, Sendable {
        case normal
        /// Takes more than one hit.
        case armored
        /// Breaks the bricks around it when it breaks.
        case explosive
        /// Drops a power-up when it breaks.
        case bonus
    }

    public struct Brick: Equatable, Sendable, Identifiable {
        public let id: Int
        public let row: Int
        public let column: Int
        public let frame: Box
        public let maxHits: Int
        public internal(set) var hitsLeft: Int
        public let kind: BrickKind
    }

    public struct Ball: Equatable, Sendable, Identifiable {
        public let id: Int
        public internal(set) var position: Vector2
        public internal(set) var velocity: Vector2
        /// Seconds since it last hit a brick or the boss: a ball the paddle keeps returning along
        /// the same empty path gets nudged off it.
        var sinceContact: TimeInterval = 0
    }

    public enum PowerUp: String, CaseIterable, Sendable {
        case multiBall, widePaddle, slowBall, laser

        /// Hash Smash's power-ups: a Fork splits the ball, Deep Liquidity widens the paddle, a Gas
        /// Limit slows the ball and Hash Rate fires bolts.
        public var name: String {
            switch self {
            case .multiBall: localized("Fork")
            case .widePaddle: localized("Deep Liquidity")
            case .slowBall: localized("Gas Limit")
            case .laser: localized("Hash Rate")
            }
        }

        /// How long it lasts; Multi-ball lasts as long as the extra balls do.
        public var duration: TimeInterval? {
            switch self {
            case .multiBall: nil
            case .widePaddle: 12
            case .slowBall: 10
            case .laser: 8
            }
        }
    }

    /// A falling power-up.
    public struct Capsule: Equatable, Sendable, Identifiable {
        public let id: Int
        public let kind: PowerUp
        public internal(set) var position: Vector2
    }

    /// A laser bolt flying up from the paddle, or debris falling from a boss.
    public struct Shot: Equatable, Sendable, Identifiable {
        public let id: Int
        public internal(set) var position: Vector2
    }

    /// Which walls a game plays.
    public enum LevelStyle: String, CaseIterable, Codable, Sendable, Identifiable {
        /// Level 1's plain wall, then one of eight shapes.
        case classic
        /// A wall made up for every level, never the same twice.
        case generated

        public var id: String { rawValue }

        public var name: String {
            switch self {
            case .classic: localized("Classic")
            case .generated: localized("Random")
            }
        }

        public var summary: String {
            switch self {
            case .classic: localized("A plain wall first, then eight familiar shapes.")
            case .generated: localized("A new wall made up for every level: blobs, waves, rings, skylines and more, never the same twice.")
            }
        }
    }

    public struct Boss: Equatable, Sendable {
        public internal(set) var frame: Box
        public let maxHits: Int
        public internal(set) var hitsLeft: Int
        /// Field units per second, sideways: negative is left.
        var speedX: Double
        var dropClock: TimeInterval
    }

    public static let width = 1.0
    public static let height = 1.5
    public static let ballRadius = 0.018
    public static let paddleWidth = 0.24
    public static let paddleHeight = 0.028
    public static let paddleTop = 1.40
    public static let columns = 7
    public static let startingLives = 3
    /// Every this many levels is a boss level.
    public static let bossEvery = 5
    public static let capsuleSize = (width: 0.09, height: 0.035)
    static let capsuleSpeed = 0.42
    static let boltSpeed = 1.8
    static let debrisSpeed = 0.5
    static let laserInterval: TimeInterval = 0.4
    static let wideFactor = 1.5
    static let shrinkFactor = 0.65
    public static let shrinkTime: TimeInterval = 5
    static let slowFactor = 0.7
    static let maxBalls = 6
    /// Hitting the paddle's edge sends the ball off at up to this angle from straight up.
    static let maxBounceAngle = Double.pi / 3
    static let brickTop = 0.14
    static let brickHeight = 0.045
    static let brickGap = 0.012
    static let sideMargin = 0.03

    public private(set) var bricks: [Brick] = []
    public private(set) var balls: [Ball] = []
    public private(set) var capsules: [Capsule] = []
    public private(set) var bolts: [Shot] = []
    public private(set) var debris: [Shot] = []
    public private(set) var boss: Boss?
    public private(set) var paddleX = width / 2
    public private(set) var phase = Phase.serving
    public private(set) var lives = startingLives
    public private(set) var level = 1
    public private(set) var score = 0
    public private(set) var bricksBroken = 0
    /// Power-ups running, with the seconds left.
    public private(set) var effects: [PowerUp: TimeInterval] = [:]
    /// Seconds left with a paddle shrunk by boss debris.
    public private(set) var shrunkFor: TimeInterval = 0
    public private(set) var powerUpsCaught = 0
    public private(set) var bossesDefeated = 0
    /// Levels cleared in a row without losing a life, and the most this game.
    public private(set) var levelStreak = 0
    public private(set) var bestLevelStreak = 0
    /// Counts paddle hits, for haptics.
    public private(set) var paddleHits = 0
    /// Counts explosions and boss hits, for effects.
    public private(set) var explosions = 0
    public private(set) var bossHits = 0
    /// Bricks that exploded in the last update, for effects.
    public private(set) var lastExplosions: [Box] = []
    /// The paddle's width, the ball's speed, and what a point pays.
    public let difficulty: ArcadeDifficulty
    /// How fast the ball moves (the difficulty's speed).
    public let gameSpeed: GameSpeed
    /// Classic walls or walls made up for every level.
    public let levelStyle: LevelStyle
    private var laserClock: TimeInterval = 0
    private var serves = 0
    private var nextID = 0
    /// Shapes the walls and picks the power-ups.
    private var rng: SeededGenerator

    /// `startLevel` starts the game further in, at a level the player has reached before. `speed`
    /// overrides the difficulty's speed.
    public init(seed: UInt64 = .random(in: 0...UInt64.max), difficulty: ArcadeDifficulty = .regular, speed: GameSpeed? = nil,
                levels: LevelStyle = .classic, startLevel: Int = 1) {
        self.difficulty = difficulty
        gameSpeed = speed ?? difficulty.speed
        levelStyle = levels
        level = max(1, startLevel)
        rng = SeededGenerator(seed: seed)
        layOutLevel()
        serve()
    }

    // MARK: Reading the game

    /// The first ball (the one on the paddle while serving).
    public var ball: Vector2 { balls.first?.position ?? Vector2(x: paddleX, y: Self.paddleTop - Self.ballRadius) }
    public var velocity: Vector2 { balls.first?.velocity ?? .zero }

    public var isBossLevel: Bool { level % Self.bossEvery == 0 }

    public func isActive(_ powerUp: PowerUp) -> Bool {
        powerUp == .multiBall ? balls.count > 1 : (effects[powerUp] ?? 0) > 0
    }

    /// Ball speed in field units per second; each level is faster, the Speed option scales it, and
    /// Slow Ball slows it.
    public var speed: Double {
        let base = min(1.5, 0.8 + Double(level - 1) * 0.1) * gameSpeed.factor
        return isActive(.slowBall) ? base * Self.slowFactor : base
    }

    /// The paddle's width before power-ups: 20% wider on Easy, 20% narrower on Hard.
    public var basePaddleWidth: Double { Self.paddleWidth * difficulty.paddleScale }

    public var currentPaddleWidth: Double {
        basePaddleWidth * (isActive(.widePaddle) ? Self.wideFactor : 1) * (shrunkFor > 0 ? Self.shrinkFactor : 1)
    }

    public var paddle: Box {
        Box(minX: paddleX - currentPaddleWidth / 2, minY: Self.paddleTop, width: currentPaddleWidth, height: Self.paddleHeight)
    }

    /// Rows of bricks on this level: five at first, up to eight.
    static func rows(for level: Int) -> Int { min(4 + level, 8) }

    // MARK: Controls

    /// Centers the paddle at `x`, kept inside the field. A serving ball rides along.
    public mutating func movePaddle(to x: Double) {
        guard phase != .over, x.isFinite else { return }
        let half = currentPaddleWidth / 2
        paddleX = min(max(x, half), Self.width - half)
        if phase == .serving, !balls.isEmpty { balls[0].position.x = paddleX }
    }

    /// Sends a serving ball up, alternating slightly left and right.
    public mutating func launch() {
        guard phase == .serving, !balls.isEmpty else { return }
        serves += 1
        let angle = (serves % 2 == 1 ? 1.0 : -1.0) * 0.35
        balls[0].velocity = Vector2(x: sin(angle), y: -cos(angle)) * speed
        phase = .playing
    }

    /// Advances the game by `seconds` (a long frame counts as at most 1/20 s).
    public mutating func update(by seconds: Double) {
        lastExplosions = []
        guard phase == .playing, seconds > 0, seconds.isFinite else { return }
        var remaining = min(seconds, 0.05)
        let maxStep = Self.ballRadius * 0.5 / max(speed, 0.4)
        while remaining > 1e-12 && phase == .playing {
            let step = min(remaining, maxStep)
            remaining -= step
            advance(by: step)
        }
    }

    // MARK: Physics

    private mutating func advance(by seconds: Double) {
        let levelBefore = level
        for index in balls.indices.reversed() where index < balls.count {
            moveBall(at: index, by: seconds)
            if level != levelBefore || phase != .playing { return }
        }
        balls.removeAll { $0.position.y - Self.ballRadius > Self.height }
        if balls.isEmpty {
            loseLife()
            return
        }
        moveCapsules(by: seconds)
        fireLaser(by: seconds)
        moveBolts(by: seconds)
        if level != levelBefore { return }
        moveBoss(by: seconds)
        moveDebris(by: seconds)
        passTime(seconds)
    }

    private mutating func moveBall(at index: Int, by seconds: Double) {
        var ball = balls[index]
        let previous = ball.position
        let radius = Self.ballRadius
        ball.position = ball.position + ball.velocity * seconds
        ball.sinceContact += seconds

        if ball.position.x < radius {
            ball.position.x = radius
            ball.velocity.x = abs(ball.velocity.x)
        } else if ball.position.x > Self.width - radius {
            ball.position.x = Self.width - radius
            ball.velocity.x = -abs(ball.velocity.x)
        }
        if ball.position.y < radius {
            ball.position.y = radius
            ball.velocity.y = abs(ball.velocity.y)
        }

        let paddle = paddle
        if ball.velocity.y > 0 && ball.position.y <= paddle.maxY && paddle.intersects(circle: ball.position, radius: radius) {
            // Where the ball meets the paddle sets its angle: the middle sends it straight up.
            let offset = min(max((ball.position.x - paddleX) / (paddle.width / 2), -1), 1)
            let angle = offset * Self.maxBounceAngle
            ball.velocity = Vector2(x: sin(angle), y: -cos(angle)) * speed
            ball.position.y = paddle.minY - radius
            paddleHits += 1
        }

        var hitBrickID: Int?
        if let brickIndex = bricks.firstIndex(where: { $0.frame.intersects(circle: ball.position, radius: radius) }) {
            Self.bounce(&ball, off: bricks[brickIndex].frame, from: previous)
            ball.sinceContact = 0
            hitBrickID = bricks[brickIndex].id
        } else if let boss, boss.frame.intersects(circle: ball.position, radius: radius) {
            Self.bounce(&ball, off: boss.frame, from: previous)
            ball.sinceContact = 0
            balls[index] = ball
            hitBoss()
            if index < balls.count { keepAngleUseful(at: index) }
            return
        }
        balls[index] = ball
        if let hitBrickID { hitBrick(id: hitBrickID) }
        if phase == .playing, index < balls.count { keepAngleUseful(at: index) }
    }

    /// Reflects the ball off the side of `frame` it struck and moves it clear of the box.
    private static func bounce(_ ball: inout Ball, off frame: Box, from previous: Vector2) {
        let radius = ballRadius
        var closest = frame.closestPoint(to: ball.position)
        var dx = ball.position.x - closest.x
        var dy = ball.position.y - closest.y
        if dx == 0 && dy == 0 {
            // The center is inside the box: judge the side from where the ball came from.
            closest = frame.closestPoint(to: previous)
            dx = previous.x - closest.x
            dy = previous.y - closest.y
        }
        if abs(dx) > abs(dy) {
            ball.velocity.x = dx > 0 ? abs(ball.velocity.x) : -abs(ball.velocity.x)
            ball.position.x = dx > 0 ? frame.maxX + radius : frame.minX - radius
        } else {
            ball.velocity.y = dy > 0 ? abs(ball.velocity.y) : -abs(ball.velocity.y)
            ball.position.y = dy > 0 ? frame.maxY + radius : frame.minY - radius
        }
    }

    /// Keeps a ball at the current speed and never close to horizontal, so rallies keep moving;
    /// a ball that has hit nothing for 12 seconds is nudged off its loop.
    private mutating func keepAngleUseful(at index: Int) {
        guard phase == .playing else { return }
        var ball = balls[index]
        let length = ball.velocity.length
        guard length > 0 else { return }
        var direction = ball.velocity * (1 / length)
        if ball.sinceContact > 12 {
            let turn = 0.2 * (ball.id % 2 == 0 ? 1.0 : -1.0)
            direction = Vector2(x: direction.x * cos(turn) - direction.y * sin(turn), y: direction.x * sin(turn) + direction.y * cos(turn))
            ball.sinceContact = 0
        }
        let minimumVertical = 0.3
        if abs(direction.y) < minimumVertical {
            let vertical = direction.y < 0 ? -minimumVertical : minimumVertical
            let horizontal = (1 - minimumVertical * minimumVertical).squareRoot()
            direction = Vector2(x: direction.x < 0 ? -horizontal : horizontal, y: vertical)
        }
        ball.velocity = direction * speed
        balls[index] = ball
    }

    // MARK: Bricks and the boss

    /// One hit on a brick; a broken explosive brick hits every brick around it in turn.
    private mutating func hitBrick(id: Int) {
        guard let index = bricks.firstIndex(where: { $0.id == id }) else { return }
        bricks[index].hitsLeft -= 1
        guard bricks[index].hitsLeft <= 0 else { return }
        let brick = bricks.remove(at: index)
        score += 10 * brick.maxHits
        bricksBroken += 1
        switch brick.kind {
        case .bonus:
            let kind = PowerUp.allCases.randomElement(using: &rng) ?? .widePaddle
            capsules.append(Capsule(id: newID(), kind: kind, position: Vector2(x: brick.frame.midX, y: brick.frame.midY)))
        case .explosive:
            explosions += 1
            lastExplosions.append(brick.frame)
            let neighbors = bricks.filter { abs($0.row - brick.row) <= 1 && abs($0.column - brick.column) <= 1 }.map(\.id)
            for neighbor in neighbors { hitBrick(id: neighbor) }
        case .normal, .armored:
            break
        }
        checkCleared()
    }

    private mutating func hitBoss() {
        guard var current = boss else { return }
        current.hitsLeft -= 1
        bossHits += 1
        if current.hitsLeft <= 0 {
            boss = nil
            bossesDefeated += 1
            score += 500 * (level / Self.bossEvery)
            debris = []
            checkCleared()
        } else {
            boss = current
        }
    }

    private mutating func checkCleared() {
        guard bricks.isEmpty, boss == nil, phase == .playing else { return }
        score += 100 * level
        levelStreak += 1
        bestLevelStreak = max(bestLevelStreak, levelStreak)
        level += 1
        layOutLevel()
        serve()
    }

    private mutating func moveBoss(by seconds: Double) {
        guard var current = boss else { return }
        current.frame.minX += current.speedX * seconds
        if current.frame.minX < Self.sideMargin {
            current.frame.minX = Self.sideMargin
            current.speedX = abs(current.speedX)
        } else if current.frame.maxX > Self.width - Self.sideMargin {
            current.frame.minX = Self.width - Self.sideMargin - current.frame.width
            current.speedX = -abs(current.speedX)
        }
        current.dropClock -= seconds
        if current.dropClock <= 0 {
            current.dropClock = Self.bossDropInterval(level: level)
            debris.append(Shot(id: newID(), position: Vector2(x: current.frame.midX, y: current.frame.maxY)))
        }
        boss = current
    }

    /// Seconds between the boss's drops: a little quicker each boss.
    static func bossDropInterval(level: Int) -> TimeInterval {
        max(1.6, 3.0 - 0.3 * Double(level / bossEvery - 1))
    }

    // MARK: Power-ups

    private mutating func moveCapsules(by seconds: Double) {
        let paddle = paddle
        var caught: [PowerUp] = []
        capsules = capsules.compactMap { capsule in
            var moved = capsule
            moved.position.y += Self.capsuleSpeed * seconds
            let box = Box(minX: moved.position.x - Self.capsuleSize.width / 2, minY: moved.position.y - Self.capsuleSize.height / 2,
                          width: Self.capsuleSize.width, height: Self.capsuleSize.height)
            if box.maxY >= paddle.minY && box.minY <= paddle.maxY && box.maxX >= paddle.minX && box.minX <= paddle.maxX {
                caught.append(capsule.kind)
                return nil
            }
            return moved.position.y > Self.height ? nil : moved
        }
        for kind in caught { activate(kind) }
    }

    private mutating func activate(_ kind: PowerUp) {
        powerUpsCaught += 1
        switch kind {
        case .multiBall:
            // Every ball in play splits into three, up to a limit.
            var added: [Ball] = []
            for ball in balls where balls.count + added.count < Self.maxBalls {
                for turn in [-0.45, 0.45] where balls.count + added.count < Self.maxBalls {
                    let v = ball.velocity
                    let velocity = Vector2(x: v.x * cos(turn) - v.y * sin(turn), y: v.x * sin(turn) + v.y * cos(turn))
                    added.append(Ball(id: newID(), position: ball.position, velocity: velocity))
                }
            }
            balls += added
        case .widePaddle, .slowBall, .laser:
            effects[kind] = kind.duration
            if kind == .widePaddle { movePaddle(to: paddleX) }
        }
    }

    private mutating func fireLaser(by seconds: Double) {
        guard isActive(.laser) else { return }
        laserClock -= seconds
        guard laserClock <= 0 else { return }
        laserClock = Self.laserInterval
        let offset = currentPaddleWidth * 0.4
        for x in [paddleX - offset, paddleX + offset] {
            bolts.append(Shot(id: newID(), position: Vector2(x: x, y: Self.paddleTop)))
        }
    }

    private mutating func moveBolts(by seconds: Double) {
        guard !bolts.isEmpty else { return }
        let levelBefore = level
        var flying: [Shot] = []
        for bolt in bolts {
            var moved = bolt
            moved.position.y -= Self.boltSpeed * seconds
            if let brick = bricks.first(where: { Self.contains($0.frame, moved.position) }) {
                hitBrick(id: brick.id)
                if level != levelBefore { return } // That cleared the wall: the next level is laid out.
                continue
            }
            if let frame = boss?.frame, Self.contains(frame, moved.position) {
                hitBoss()
                if level != levelBefore { return }
                continue
            }
            if moved.position.y > 0 { flying.append(moved) }
        }
        bolts = flying
    }

    private mutating func moveDebris(by seconds: Double) {
        let paddle = paddle
        var hitPaddle = false
        debris = debris.compactMap { piece in
            var moved = piece
            moved.position.y += Self.debrisSpeed * seconds
            if Self.contains(Box(minX: paddle.minX - 0.02, minY: paddle.minY, width: paddle.width + 0.04, height: paddle.height),
                             moved.position) {
                hitPaddle = true
                return nil
            }
            return moved.position.y > Self.height ? nil : moved
        }
        if hitPaddle {
            shrunkFor = Self.shrinkTime
            movePaddle(to: paddleX)
        }
    }

    private mutating func passTime(_ seconds: Double) {
        for (kind, left) in effects {
            effects[kind] = left - seconds > 0 ? left - seconds : nil
        }
        if shrunkFor > 0 { shrunkFor = max(0, shrunkFor - seconds) }
    }

    private static func contains(_ box: Box, _ point: Vector2) -> Bool {
        point.x >= box.minX && point.x <= box.maxX && point.y >= box.minY && point.y <= box.maxY
    }

    // MARK: Lives and levels

    private mutating func loseLife() {
        lives -= 1
        levelStreak = 0
        if lives <= 0 {
            lives = 0
            phase = .over
            capsules = []
            bolts = []
            debris = []
        } else {
            serve()
        }
    }

    /// Puts a ball on the paddle; power-ups and anything falling or flying are cleared.
    private mutating func serve() {
        phase = .serving
        effects = [:]
        shrunkFor = 0
        capsules = []
        bolts = []
        debris = []
        laserClock = 0
        balls = [Ball(id: newID(), position: Vector2(x: paddleX, y: Self.paddleTop - Self.ballRadius - 0.002), velocity: .zero)]
        movePaddle(to: paddleX)
    }

    private mutating func newID() -> Int {
        nextID += 1
        return nextID
    }

    /// Hits a full wall takes on `level`: every brick once, plus the top rows again from level 3
    /// (and a third time from level 6).
    static func fullWallHits(level: Int) -> Int {
        let rows = rows(for: level)
        let extra = level >= 3 ? min(rows, level - 2) * columns : 0
        return rows * columns + extra * (level >= 6 ? 2 : 1)
    }

    /// Fills the wall for the current level: a classic shape or a made-up wall, with enough armored
    /// bricks to take about as many hits as a full wall, and a few explosive and bonus bricks among
    /// the rest. Every fifth level brings a boss behind a low wall. A classic level is laid out the
    /// same every time (from `classicGenerator`); a random one from the game's own generator.
    private mutating func layOutLevel() {
        boss = nil
        var generator = levelStyle == .classic ? Self.classicGenerator(level: level) : rng
        if isBossLevel {
            layOutBossLevel(using: &generator)
        } else {
            layOutWall(using: &generator)
        }
        if levelStyle == .generated { rng = generator }
    }

    /// What fixes a classic level's wall, the same every time it's played.
    static func classicGenerator(level: Int) -> SeededGenerator {
        SeededGenerator(seed: 0xB71C_5A3D &+ UInt64(max(1, level)) &* 0x9E37_79B9_7F4A_7C15)
    }

    private mutating func layOutWall<R: RandomNumberGenerator>(using rng: inout R) {
        let isGenerated = levelStyle == .generated
        let rows = isGenerated ? Self.generatedRows(level: level, using: &rng) : Self.rows(for: level)
        // Made-up walls vary their specials too: one to a few bonus bricks from the very first level.
        let wobble = isGenerated ? Int.random(in: -1...1, using: &rng) : 0
        let bonusTarget = isGenerated ? Int.random(in: 1...max(3, 2 + level / 2), using: &rng)
            : level == 1 ? 0 : 2 + level / 3
        // Made-up walls are denser, so an explosion reaches more bricks: they get one explosive fewer.
        let explosiveTarget = level == 1 && !isGenerated ? 0 : max(0, (isGenerated ? 0 : 1) + level / 2 - wobble)
        let armorHits = level >= 6 ? 3 : 2
        // Made-up walls have enough bricks for armor to make up about two thirds of a full wall's
        // hits (what the classic shapes average), and at least two fifths of their grid, from the
        // first level. (The classic level 1 is a plain wall, with no armor.)
        let isPlainWall = level == 1 && !isGenerated
        let needed = isPlainWall ? Self.fullWallHits(level: 1) * 4 / 5
            : (Self.fullWallHits(level: level) * 13 / 20 + armorHits - 1) / armorHits + bonusTarget + explosiveTarget
        let cells = isGenerated ? Self.generatedCells(rows: rows, minimum: max(rows * Self.columns * 2 / 5, needed), using: &rng)
                                : Self.cells(level: level, rows: rows, using: &rng)
        let extraHits = isPlainWall ? 0 : max(0, Self.fullWallHits(level: level) - cells.count)
        // Made-up walls keep a few plain bricks for their specials.
        let armorRoom = isGenerated ? max(0, cells.count - bonusTarget - explosiveTarget) : cells.count
        // Made-up walls always have a few armored bricks.
        let armoredCount = min(armorRoom, max(isGenerated ? 2 : 0, (extraHits + armorHits - 2) / (armorHits - 1)))
        let order = cells.indices.shuffled(using: &rng)
        let armored = Set(order.prefix(armoredCount))
        let rest = order.dropFirst(armoredCount)
        let bonusCount = min(rest.count, bonusTarget)
        let explosiveCount = min(rest.count - bonusCount, explosiveTarget)
        let bonus = Set(rest.prefix(bonusCount))
        let explosive = Set(rest.dropFirst(bonusCount).prefix(explosiveCount))
        let width = Self.brickWidth
        bricks = []
        for (index, cell) in cells.enumerated() {
            let frame = Box(minX: Self.sideMargin + Double(cell.column) * (width + Self.brickGap),
                            minY: Self.brickTop + Double(cell.row) * (Self.brickHeight + Self.brickGap),
                            width: width, height: Self.brickHeight)
            let kind: BrickKind = armored.contains(index) ? .armored : bonus.contains(index) ? .bonus
                : explosive.contains(index) ? .explosive : .normal
            let hits = kind == .armored ? armorHits : 1
            bricks.append(Brick(id: newID(), row: cell.row, column: cell.column, frame: frame, maxHits: hits, hitsLeft: hits, kind: kind))
        }
    }

    static var brickWidth: Double {
        (width - 2 * sideMargin - Double(columns - 1) * brickGap) / Double(columns)
    }

    /// The boss slides along the top behind two rows of bricks with gaps, two of them bonus bricks.
    private mutating func layOutBossLevel<R: RandomNumberGenerator>(using rng: inout R) {
        let number = level / Self.bossEvery
        let frame = Box(minX: 0.32, minY: 0.12, width: 0.36, height: 0.1)
        boss = Boss(frame: frame, maxHits: 10 + 6 * number, hitsLeft: 10 + 6 * number,
                    speedX: 0.16 + 0.03 * Double(number), dropClock: Self.bossDropInterval(level: level))
        let width = Self.brickWidth
        let cells = (0..<2).flatMap { row in (0..<Self.columns).filter { ($0 + row) % 2 == 0 }.map { (row: row, column: $0) } }
        let bonus = Set(cells.indices.shuffled(using: &rng).prefix(2))
        bricks = []
        for (index, cell) in cells.enumerated() {
            let frame = Box(minX: Self.sideMargin + Double(cell.column) * (width + Self.brickGap),
                            minY: 0.36 + Double(cell.row) * (Self.brickHeight + Self.brickGap),
                            width: width, height: Self.brickHeight)
            let kind: BrickKind = bonus.contains(index) ? .bonus : .armored
            let hits = kind == .armored ? 2 : 1
            bricks.append(Brick(id: newID(), row: cell.row, column: cell.column, frame: frame, maxHits: hits, hitsLeft: hits, kind: kind))
        }
    }

    /// The order the classic shapes come in from level 2, round and round (boss levels skipped): a
    /// full wall, a pyramid, stripes, a checkerboard, a diamond, scattered bricks, a frame and
    /// columns. The fuller walls come first, while the ball is slow.
    static let classicShapes = [0, 2, 4, 1, 5, 7, 6, 3]

    /// The cells with a brick on classic `level`, row by row: level 1 is a full wall, and each
    /// level after takes the next shape in `classicShapes`, turned over every other time round.
    /// Every shape keeps at least two rows' worth.
    static func cells<R: RandomNumberGenerator>(level: Int, rows: Int, using rng: inout R) -> [(row: Int, column: Int)] {
        let all = (0..<rows).flatMap { row in (0..<columns).map { (row: row, column: $0) } }
        guard level > 1 else { return all }
        let middle = columns / 2
        // Counting only the walls (boss levels have none).
        let wall = max(0, level - 2 - level / bossEvery)
        let lap = wall / classicShapes.count
        let flip = lap % 2 == 1
        let shape = classicShapes[wall % classicShapes.count]
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

    // MARK: Made-up walls

    /// Rows for a made-up wall: about as many as the classic wall on that level, give or take one.
    static func generatedRows<R: RandomNumberGenerator>(level: Int, using rng: inout R) -> Int {
        min(8, max(4, rows(for: level) + Int.random(in: -1...1, using: &rng)))
    }

    /// A wall made up on the spot, mirrored left to right like the classic ones: scattered bricks,
    /// smoothed blobs, stacked blocks, a wave, rings, chevrons or a skyline, each with its own
    /// random sizes, gaps and density. Always at least two rows' worth of bricks, and `minimum`.
    static func generatedCells<R: RandomNumberGenerator>(rows: Int, minimum: Int = 0, using rng: inout R) -> [(row: Int, column: Int)] {
        let rows = max(2, rows)
        let middle = columns / 2
        var grid = Array(repeating: Array(repeating: false, count: columns), count: rows)
        func inside(_ row: Int, _ column: Int) -> Bool { (0..<rows).contains(row) && (0..<columns).contains(column) }
        func mirror() {
            for row in 0..<rows {
                for column in (middle + 1)..<columns { grid[row][column] = grid[row][columns - 1 - column] }
            }
        }
        switch Int.random(in: 0..<7, using: &rng) {
        case 0: // Scattered bricks.
            let density = Double.random(in: 0.5...0.8, using: &rng)
            for row in 0..<rows { for column in 0...middle { grid[row][column] = Double.random(in: 0..<1, using: &rng) < density } }
        case 1: // Blobs: scattered bricks, smoothed twice so they clump together.
            let density = Double.random(in: 0.45...0.62, using: &rng)
            for row in 0..<rows { for column in 0..<columns { grid[row][column] = Double.random(in: 0..<1, using: &rng) < density } }
            for _ in 0..<2 {
                var next = grid
                for row in 0..<rows {
                    for column in 0..<columns {
                        var count = 0
                        for dRow in -1...1 { for dColumn in -1...1 where inside(row + dRow, column + dColumn) && grid[row + dRow][column + dColumn] { count += 1 } }
                        next[row][column] = count >= 5
                    }
                }
                grid = next
            }
        case 2: // Stacked blocks.
            for _ in 0..<Int.random(in: 3...5, using: &rng) {
                let width = Int.random(in: 1...3, using: &rng), height = Int.random(in: 1...min(3, rows), using: &rng)
                let left = Int.random(in: 0...max(0, middle + 1 - width), using: &rng)
                let top = Int.random(in: 0...(rows - height), using: &rng)
                for row in top..<(top + height) { for column in left..<min(columns, left + width) { grid[row][column] = true } }
            }
        case 3: // A wave across the wall.
            let amplitude = Double.random(in: 1...max(1, Double(rows) / 2), using: &rng)
            let frequency = Double.random(in: 0.6...1.4, using: &rng)
            let phase = Double.random(in: 0..<(2 * Double.pi), using: &rng)
            let thickness = Double.random(in: 0.8...1.8, using: &rng)
            let center = Double(rows - 1) / 2
            for row in 0..<rows {
                for column in 0...middle {
                    grid[row][column] = abs(Double(row) - (center + amplitude * sin(Double(column) * frequency + phase))) <= thickness
                }
            }
        case 4: // Rings, with a few bricks knocked out.
            let ring = Int.random(in: 0...1, using: &rng)
            let holes = Double.random(in: 0.05...0.2, using: &rng)
            for row in 0..<rows {
                for column in 0...middle {
                    let depth = min(row, rows - 1 - row, column, columns - 1 - column)
                    grid[row][column] = depth % 2 == ring && Double.random(in: 0..<1, using: &rng) >= holes
                }
            }
        case 5: // Chevrons pointing up or down.
            let slope = Int.random(in: 1...2, using: &rng), period = Int.random(in: 3...4, using: &rng)
            let thickness = Int.random(in: 1...2, using: &rng), upward = Bool.random(using: &rng)
            for row in 0..<rows {
                for column in 0...middle {
                    let depth = upward ? row : rows - 1 - row
                    grid[row][column] = (depth + (middle - column) * slope) % period < thickness
                }
            }
        default: // A skyline: columns of random heights, standing up or hanging down.
            let hanging = Bool.random(using: &rng)
            for column in 0...middle {
                let height = Int.random(in: 1...rows, using: &rng)
                for row in 0..<rows { grid[row][column] = hanging ? row < height : row >= rows - height }
            }
        }
        mirror()
        // Too sparse to be a wall: add mirrored pairs until there are enough.
        var count = grid.joined().filter { $0 }.count
        let target = min(rows * columns, max(2 * columns, minimum))
        var attempts = 0
        while count < target && attempts < 2_000 {
            attempts += 1
            let row = Int.random(in: 0..<rows, using: &rng), column = Int.random(in: 0...middle, using: &rng)
            guard !grid[row][column] else { continue }
            grid[row][column] = true
            grid[row][columns - 1 - column] = true
            count += column == middle ? 1 : 2
        }
        return (0..<rows).flatMap { row in (0..<columns).filter { grid[row][$0] }.map { (row: row, column: $0) } }
    }

    #if DEBUG
    /// Test hook: puts one ball in play at `ball` with `velocity`, against plain `bricks` (frames).
    mutating func load(ball: Vector2, velocity: Vector2, bricks frames: [Box], paddleX: Double = width / 2) {
        self.paddleX = paddleX
        balls = [Ball(id: newID(), position: ball, velocity: velocity)]
        bricks = frames.enumerated().map { Brick(id: newID(), row: 0, column: $0.offset, frame: $0.element, maxHits: 1, hitsLeft: 1, kind: .normal) }
        boss = nil
        capsules = []
        bolts = []
        debris = []
        phase = .playing
    }

    /// Test hook: replaces the bricks with these, by kind and grid cell.
    mutating func load(bricks layout: [(row: Int, column: Int, kind: BrickKind, hits: Int)]) {
        let width = Self.brickWidth
        bricks = layout.map { cell in
            let frame = Box(minX: Self.sideMargin + Double(cell.column) * (width + Self.brickGap),
                            minY: Self.brickTop + Double(cell.row) * (Self.brickHeight + Self.brickGap),
                            width: width, height: Self.brickHeight)
            return Brick(id: newID(), row: cell.row, column: cell.column, frame: frame, maxHits: cell.hits, hitsLeft: cell.hits, kind: cell.kind)
        }
    }

    /// Test hook: drops a power-up just above the paddle, or catches it at once.
    mutating func give(_ kind: PowerUp) {
        activate(kind)
    }

    mutating func dropCapsule(_ kind: PowerUp, at position: Vector2) {
        capsules.append(Capsule(id: newID(), kind: kind, position: position))
    }

    mutating func dropDebris(at position: Vector2) {
        debris.append(Shot(id: newID(), position: position))
    }

    /// Test hook: removes every brick (the boss stays).
    mutating func clearBricks() {
        bricks = []
    }

    /// Test hook: jumps to a level and lays it out.
    mutating func jump(toLevel level: Int) {
        self.level = level
        layOutLevel()
        serve()
    }
    #endif
}
