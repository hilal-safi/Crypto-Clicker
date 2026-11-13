import Foundation

/// Scam Invaders: rows of scam tokens march from side to side, stepping down each time they reach
/// an edge, and fire back. Shoot every one to reach the next, faster wave, which starts a little
/// lower; let one land and the game is over. Five ships per game, and each takes a hit or more
/// before it's lost, by the difficulty (`Difficulty`): three on Easy, two on Regular, one on Hard.
/// The field is 1 unit wide and 1.5 tall, y pointing down, like Brick Breaker's.
///
/// The ship follows the finger and fires while it's down (`isFiring`), with at most two volleys in
/// the air at once. Every hit adds 10% to what the next is worth, up to double, and a volley that
/// hits nothing ends the streak, so aimed fire pays. Four firewalls (server racks) shield the ship:
/// any shot chips a block away (an invader's chips two), and invaders marching through them crush
/// what they touch.
/// A whale crosses the top now and then: shoot it for bonus points and a power-up. Golden invaders
/// carry a power-up too. Every fifth wave is a boss.
///
/// Classic waves are fixed: the same formation, the same four server racks and, from the second
/// wave, one golden invader in the same place every time a wave is played. Random waves make up a
/// new formation for every wave (see `generatedFormation`) with the kinds mixed up, one to three
/// golden invaders (four from wave 6) from the very first wave, and server racks of their own sizes
/// in their own places. Boss waves are the same in both, but for the racks.
///
/// The difficulty's speed scales how fast everything moves and fires; Easy pays 20% less a point
/// and Hard 20% more. Everything moves in sub-steps of at most 1/240 s, so no shot passes through a
/// block on a slow frame, and the rules never depend on the frame rate.
public struct InvadersGame: Sendable {
    /// Which formations a game plays.
    public enum WaveStyle: String, CaseIterable, Codable, Sendable, Identifiable {
        /// The classic formation every wave.
        case classic
        /// A formation made up for every wave, never the same twice.
        case generated

        public var id: String { rawValue }
    }

    /// How hard a game plays: how many hits a ship takes before it's lost, how fast everything
    /// moves, and what a point pays.
    public typealias Difficulty = ArcadeDifficulty

    public enum Phase: Equatable, Sendable {
        /// The wave's banner is up and the invaders are about to march.
        case incoming
        case playing
        /// The ship was hit: everything holds still for a moment before the next ship.
        case shipLost
        /// The last invader is down: a moment for the bonus before the next wave.
        case waveCleared
        case over
    }

    public enum InvaderKind: String, CaseIterable, Sendable {
        /// The classic formation's bottom two rows.
        case memeCoin
        /// The classic formation's middle two rows.
        case pumpBot
        /// The classic formation's top row.
        case rugPuller

        public var name: String {
            switch self {
            case .memeCoin: localized("Meme Coin")
            case .pumpBot: localized("Pump Bot")
            case .rugPuller: localized("Rug Puller")
            }
        }

        /// Points before the streak bonus (a golden one doubles them).
        public var points: Int {
            switch self {
            case .memeCoin: 10
            case .pumpBot: 20
            case .rugPuller: 30
            }
        }

        /// The kind in a formation row: rug pullers on top, then pump bots, then meme coins.
        static func forRow(_ row: Int) -> InvaderKind {
            row == 0 ? .rugPuller : row <= 2 ? .pumpBot : .memeCoin
        }
    }

    public struct Invader: Equatable, Sendable, Identifiable {
        public let id: Int
        public let row: Int
        public let column: Int
        public let kind: InvaderKind
        /// Carries a power-up, dropped when it's shot, and is worth double.
        public let isGolden: Bool
    }

    public enum PowerUp: String, CaseIterable, Sendable {
        case rapidFire, spreadShot, laser, shield

        public var name: String {
            switch self {
            case .rapidFire: localized("Rapid Fire")
            case .spreadShot: localized("Spread Shot")
            case .laser: localized("Laser")
            case .shield: localized("Shield")
            }
        }

        /// How long it lasts; the shield is an extra hit the ship can take, and lasts until it does.
        public var duration: TimeInterval? {
            switch self {
            case .rapidFire: 9
            case .spreadShot: 8
            case .laser: 7
            case .shield: nil
            }
        }
    }

    /// A falling power-up.
    public struct Capsule: Equatable, Sendable, Identifiable {
        public let id: Int
        public let kind: PowerUp
        public internal(set) var position: Vector2
    }

    /// One of the ship's shots. Shots fired together are a volley.
    public struct Shot: Equatable, Sendable, Identifiable {
        public let id: Int
        public internal(set) var position: Vector2
        /// Field units per second: up the screen, and a little sideways for a spread.
        public let velocity: Vector2
        /// Burns through invaders instead of stopping at the first.
        public let isLaser: Bool
        let volley: Int
    }

    /// An invader's (or the boss's) shot.
    public struct EnemyShot: Equatable, Sendable, Identifiable {
        public let id: Int
        public internal(set) var position: Vector2
        public let velocity: Vector2
        /// Who fired it, for its look; `nil` for the boss.
        public let shooter: InvaderKind?
    }

    /// A wall of blocks (a server rack) between the ship and the invaders: a server to a row.
    public struct Firewall: Equatable, Sendable, Identifiable {
        /// The classic rack: five servers, eight blocks across.
        public static let classicRows = 5
        public static let classicColumns = 8

        public let id: Int
        public let frame: Box
        /// Servers stacked, and blocks across each.
        public let rows: Int
        public let columns: Int
        /// The blocks still standing, row by row from the top (`rows × columns` of them).
        public internal(set) var blocks: [Bool]

        init(id: Int, frame: Box, rows: Int = classicRows, columns: Int = classicColumns) {
            self.id = id
            self.frame = frame
            self.rows = rows
            self.columns = columns
            blocks = Array(repeating: true, count: rows * columns)
        }

        public var blockWidth: Double { frame.width / Double(columns) }
        public var blockHeight: Double { frame.height / Double(rows) }

        public func blockFrame(row: Int, column: Int) -> Box {
            Box(minX: frame.minX + Double(column) * blockWidth, minY: frame.minY + Double(row) * blockHeight,
                width: blockWidth, height: blockHeight)
        }

        public func isStanding(row: Int, column: Int) -> Bool {
            (0..<rows).contains(row) && (0..<columns).contains(column) && blocks[row * columns + column]
        }

        public var standing: Int { blocks.filter { $0 }.count }
    }

    /// The bonus whale crossing the top.
    public struct Whale: Equatable, Sendable {
        public static let size = (width: 0.14, height: 0.055)
        public internal(set) var position: Vector2
        /// Field units per second at Normal speed, sideways: negative is left.
        public let speedX: Double

        public var frame: Box {
            Box(minX: position.x - Self.size.width / 2, minY: position.y - Self.size.height / 2,
                width: Self.size.width, height: Self.size.height)
        }
    }

    /// Every fifth wave: a giant bear-market bot sliding along the top.
    public struct Boss: Equatable, Sendable {
        public internal(set) var frame: Box
        public let maxHits: Int
        public internal(set) var hitsLeft: Int
        var speedX: Double
        var fireClock: TimeInterval
    }

    /// Something that happened in the last update, for effects and sounds.
    public enum Event: Equatable, Sendable {
        case invaderDestroyed(at: Vector2, kind: InvaderKind, golden: Bool, points: Int)
        case whaleHit(at: Vector2, points: Int)
        case bossHit(at: Vector2)
        case bossDefeated(at: Vector2, points: Int)
        case firewallHit(at: Vector2)
        case shieldHit(at: Vector2)
        /// The ship took a hit and flies on, with `healthLeft` hits to go.
        case shipDamaged(at: Vector2, healthLeft: Int)
        case shipHit(at: Vector2)
        case caught(PowerUp)
    }

    // MARK: Field

    public static let width = 1.0
    public static let height = 1.5
    public static let rows = 5
    public static let columns = 8
    public static let invaderSize = (width: 0.068, height: 0.05)
    static let columnSpacing = 0.094
    static let rowSpacing = 0.074
    static let sideMargin = 0.025
    /// How far the formation moves in one step, and how far it drops at an edge.
    static let stepX = 0.014
    static let dropY = 0.032
    public static let shipSize = (width: 0.1, height: 0.05)
    public static let shipTop = 1.37
    public static let startingLives = 5
    /// Every this many waves is a boss wave.
    public static let bossEvery = 5
    public static let shotSize = (width: 0.011, height: 0.036)
    public static let enemyShotSize = (width: 0.012, height: 0.03)
    public static let capsuleSize = (width: 0.085, height: 0.034)
    static let firewallTop = 1.18
    static let firewallSize = (width: 0.13, height: 0.075)
    static let whaleY = 0.085
    static let shotSpeed = 1.6
    static let capsuleSpeed = 0.34
    static let fireCooldown: TimeInterval = 0.38
    static let rapidCooldown: TimeInterval = 0.16
    static let maxVolleys = 2
    static let rapidVolleys = 4
    static let spreadAngle = 0.2
    static let streakStep = 0.1
    static let maxStreakBonus = 1.0
    static let shipLostHold: TimeInterval = 1.3
    static let invulnerableTime: TimeInterval = 1.6
    /// The blink after a hit the ship survives, so one volley can't take two hits at once.
    static let hitGrace: TimeInterval = 0.8
    static let clearedHold: TimeInterval = 1.0
    static let incomingHold: TimeInterval = 1.2
    static let maxStep: TimeInterval = 1.0 / 240

    // MARK: State

    public private(set) var invaders: [Invader] = []
    /// The top-left corner of the formation's grid: invader frames are worked out from it.
    public private(set) var formationOrigin = Vector2(x: 0, y: 0)
    public private(set) var shots: [Shot] = []
    public private(set) var enemyShots: [EnemyShot] = []
    public private(set) var firewalls: [Firewall] = []
    public private(set) var capsules: [Capsule] = []
    public private(set) var whale: Whale?
    public private(set) var boss: Boss?
    public private(set) var shipX = width / 2
    public private(set) var phase = Phase.incoming
    public private(set) var lives = startingLives
    public private(set) var wave = 1
    public private(set) var score = 0
    /// Hits in a row; a volley that hits nothing ends it.
    public private(set) var streak = 0
    public private(set) var bestStreak = 0
    /// Power-ups running, with the seconds left.
    public private(set) var effects: [PowerUp: TimeInterval] = [:]
    /// Hits the ship can still take; one more than `maxHealth` is the shield.
    public private(set) var health: Int
    /// Seconds left of the blink after a new ship arrives, when shots pass through it.
    public private(set) var invulnerableFor: TimeInterval = 0
    /// Seconds left of the current banner (incoming, ship lost or wave cleared).
    public private(set) var holdFor: TimeInterval = incomingHold
    /// Which of the invaders' two poses they're in: it flips with every step.
    public private(set) var marchPose = 0
    /// Bonus points the last cleared wave paid, for its banner.
    public private(set) var lastWaveBonus = 0
    public private(set) var invadersDestroyed = 0
    public private(set) var whalesHit = 0
    public private(set) var powerUpsCaught = 0
    public private(set) var bossesDefeated = 0
    public private(set) var volleysFired = 0
    /// Volleys that hit at least one thing.
    public private(set) var volleysHit = 0
    /// Counts the ships lost, the hits survived and the shield's saves, for haptics.
    public private(set) var shipsLost = 0
    public private(set) var hitsTaken = 0
    public private(set) var shieldSaves = 0
    /// What happened in the last update.
    public private(set) var events: [Event] = []
    /// The ship fires while this is on (the player's finger is down).
    public var isFiring = false
    /// Hits a ship takes, and the speed.
    public let difficulty: Difficulty
    /// How fast everything moves (the difficulty's speed).
    public let gameSpeed: GameSpeed
    /// Classic formations or ones made up for every wave.
    public let waveStyle: WaveStyle

    private var direction = 1.0
    private var marchClock: TimeInterval = 0
    private var fireClock: TimeInterval = 0
    private var enemyFireClock: TimeInterval = 1.5
    private var whaleClock: TimeInterval = 18
    private var lostShipThisWave = false
    private var formationSize = 0
    /// Shots still flying and things hit, by volley: a volley is a miss once its last shot is gone
    /// without a hit.
    private var volleys: [Int: (flying: Int, hits: Int)] = [:]
    private var nextID = 0
    private var rng: SeededGenerator

    /// `startWave` starts the game further in, at a wave the player has reached before. `speed`
    /// overrides the difficulty's speed.
    public init(seed: UInt64 = .random(in: 0...UInt64.max), difficulty: Difficulty = .regular, speed: GameSpeed? = nil,
                waves: WaveStyle = .classic, startWave: Int = 1) {
        self.difficulty = difficulty
        gameSpeed = speed ?? difficulty.speed
        health = difficulty.hitsPerShip
        waveStyle = waves
        wave = max(1, startWave)
        rng = SeededGenerator(seed: seed)
        whaleClock = Double.random(in: 16...24, using: &rng)
        layOutWave()
    }

    // MARK: Reading the game

    public var isBossWave: Bool { wave % Self.bossEvery == 0 }

    /// Hits a fresh ship takes.
    public var maxHealth: Int { difficulty.hitsPerShip }

    /// The ship has the shield's extra hit.
    public var hasShield: Bool { health > maxHealth }

    public func isActive(_ powerUp: PowerUp) -> Bool {
        powerUp == .shield ? hasShield : (effects[powerUp] ?? 0) > 0
    }

    /// What the next hit's points are multiplied by: 10% more a hit in a row, up to double.
    public var streakMultiplier: Double {
        1 + min(Double(streak) * Self.streakStep, Self.maxStreakBonus)
    }

    /// Share of volleys that hit something.
    public var accuracy: Double {
        volleysFired > 0 ? Double(volleysHit) / Double(volleysFired) : 0
    }

    public var ship: Box {
        Box(minX: shipX - Self.shipSize.width / 2, minY: Self.shipTop, width: Self.shipSize.width, height: Self.shipSize.height)
    }

    /// What enemy shots must touch to hit the ship: a little inside its outline.
    var shipHitbox: Box { ship.insetBy(dx: 0.012, dy: 0.008) }

    public func frame(of invader: Invader) -> Box {
        Box(minX: formationOrigin.x + Double(invader.column) * Self.columnSpacing,
            minY: formationOrigin.y + Double(invader.row) * Self.rowSpacing,
            width: Self.invaderSize.width, height: Self.invaderSize.height)
    }

    /// Seconds between the formation's steps: quicker each wave, much quicker as it thins out
    /// (the last invader all but runs), and scaled by the Speed option.
    var marchInterval: TimeInterval {
        let base = 0.5 * pow(0.93, Double(min(wave, 12) - 1))
        let share = formationSize > 0 ? Double(invaders.count) / Double(formationSize) : 1
        return max(0.03, base * (0.12 + 0.88 * share)) / gameSpeed.factor
    }

    /// Seconds between invader shots on average: quicker each wave.
    var enemyFireInterval: TimeInterval {
        max(0.4, 1.15 * pow(0.92, Double(min(wave, 12) - 1))) / Self.fireRate / gameSpeed.factor
    }

    /// How much more often everyone fires than the waves were first tuned for: a little, to make up
    /// for ships taking more than one hit.
    static let fireRate = 1.05

    var maxEnemyShots: Int { min(2 + wave / 2, 6) }

    var enemyShotSpeed: Double { (0.5 + 0.025 * Double(min(wave, 16))) * gameSpeed.factor }

    /// Where the formation's top row starts: a little lower each wave, up to six waves' worth.
    static func formationTop(wave: Int) -> Double {
        0.17 + 0.03 * Double(min(max(wave, 1) - 1, 6))
    }

    // MARK: Controls

    /// Centers the ship at `x`, kept inside the field.
    public mutating func moveShip(to x: Double) {
        guard phase != .over, x.isFinite else { return }
        let half = Self.shipSize.width / 2
        shipX = min(max(x, half + 0.01), Self.width - half - 0.01)
    }

    /// Advances the game by `seconds` (a long frame counts as at most 1/20 s).
    public mutating func update(by seconds: Double) {
        events = []
        guard phase != .over, seconds > 0, seconds.isFinite else { return }
        var remaining = min(seconds, 0.05)
        while remaining > 1e-12 && phase != .over {
            let step = min(remaining, Self.maxStep)
            remaining -= step
            advance(by: step)
        }
    }

    // MARK: The clock

    private mutating func advance(by seconds: Double) {
        switch phase {
        case .incoming, .shipLost, .waveCleared:
            holdFor -= seconds
            guard holdFor <= 0 else { return }
            if phase == .waveCleared {
                wave += 1
                layOutWave()
            } else {
                if phase == .shipLost { invulnerableFor = Self.invulnerableTime }
                phase = .playing
            }
        case .playing:
            let factor = gameSpeed.factor
            fire(by: seconds)
            moveShots(by: seconds)
            if phase != .playing { return }
            march(by: seconds)
            if phase != .playing { return }
            moveBoss(by: seconds * factor)
            enemyFire(by: seconds)
            moveEnemyShots(by: seconds)
            if phase != .playing { return }
            moveWhale(by: seconds * factor)
            moveCapsules(by: seconds)
            passTime(seconds)
        case .over:
            break
        }
    }

    private mutating func passTime(_ seconds: Double) {
        for (kind, left) in effects {
            effects[kind] = left - seconds > 0 ? left - seconds : nil
        }
        if invulnerableFor > 0 { invulnerableFor = max(0, invulnerableFor - seconds) }
    }

    // MARK: The ship's fire

    private mutating func fire(by seconds: Double) {
        fireClock -= seconds * gameSpeed.factor
        guard isFiring, fireClock <= 0 else { return }
        let rapid = isActive(.rapidFire)
        guard volleys.count < (rapid ? Self.rapidVolleys : Self.maxVolleys) else { return }
        fireClock = rapid ? Self.rapidCooldown : Self.fireCooldown
        let volley = newID()
        let speed = Self.shotSpeed * gameSpeed.factor
        let angles = isActive(.spreadShot) ? [-Self.spreadAngle, 0, Self.spreadAngle] : [0]
        let start = Vector2(x: shipX, y: Self.shipTop - Self.shotSize.height / 2)
        for angle in angles {
            shots.append(Shot(id: newID(), position: start, velocity: Vector2(x: sin(angle) * speed, y: -cos(angle) * speed),
                              isLaser: isActive(.laser), volley: volley))
        }
        volleys[volley] = (angles.count, 0)
        volleysFired += 1
    }

    private mutating func moveShots(by seconds: Double) {
        guard !shots.isEmpty else { return }
        var flying: [Shot] = []
        for var shot in shots {
            shot.position = shot.position + shot.velocity * seconds
            let box = Self.box(around: shot.position, size: Self.shotSize)
            if chipFirewall(touching: box, fromBelow: true) {
                land(shot, hit: false)
                continue
            }
            // The hit is counted for its volley first: clearing the wave forgets the volleys.
            if let index = invaders.firstIndex(where: { frame(of: $0).overlaps(box) }) {
                land(shot, hit: true, removing: !shot.isLaser)
                destroyInvader(at: index)
                if phase != .playing { return }
                if !shot.isLaser { continue }
            }
            if let whale, whale.frame.overlaps(box) {
                land(shot, hit: true)
                hitWhale(whale)
                continue
            }
            if boss?.frame.overlaps(box) == true {
                land(shot, hit: true)
                hitBoss(at: shot.position)
                if phase != .playing { return }
                continue
            }
            if shot.position.y < -Self.shotSize.height || shot.position.x < 0 || shot.position.x > Self.width {
                land(shot, hit: false)
                continue
            }
            flying.append(shot)
        }
        shots = flying
    }

    /// Counts what a shot did for its volley. A volley whose last shot is gone without a hit is a
    /// miss, and ends the streak. `removing` is false for a laser that hit and flies on.
    private mutating func land(_ shot: Shot, hit: Bool, removing: Bool = true) {
        guard var volley = volleys[shot.volley] else { return }
        if hit {
            if volley.hits == 0 { volleysHit += 1 }
            volley.hits += 1
        }
        if removing {
            volley.flying -= 1
            shots.removeAll { $0.id == shot.id }
        }
        if volley.flying <= 0 {
            volleys[shot.volley] = nil
            if volley.hits == 0 { streak = 0 }
        } else {
            volleys[shot.volley] = volley
        }
    }

    /// Counts a hit toward the streak and returns `points` with the streak's bonus.
    private mutating func scoreHit(_ points: Int) -> Int {
        let earned = Int((Double(points) * streakMultiplier).rounded())
        streak += 1
        bestStreak = max(bestStreak, streak)
        score = score.addingCount(earned)
        return earned
    }

    // MARK: Invaders

    private mutating func destroyInvader(at index: Int) {
        let invader = invaders.remove(at: index)
        let body = frame(of: invader)
        let center = Vector2(x: body.midX, y: body.midY)
        let points = scoreHit(invader.kind.points * (invader.isGolden ? 2 : 1))
        invadersDestroyed += 1
        events.append(.invaderDestroyed(at: center, kind: invader.kind, golden: invader.isGolden, points: points))
        if invader.isGolden { dropCapsule(at: center) }
        checkCleared()
    }

    /// One step of the march: sideways, or down and back at an edge. Invaders crush firewall blocks
    /// they reach, and reaching the ship's line ends the game.
    private mutating func march(by seconds: Double) {
        guard !invaders.isEmpty else { return }
        marchClock -= seconds
        while marchClock <= 0 && phase == .playing {
            marchClock += marchInterval
            step()
        }
    }

    private mutating func step() {
        marchPose = 1 - marchPose
        let frames = invaders.map { frame(of: $0) }
        let left = frames.map(\.minX).min() ?? 0
        let right = frames.map(\.maxX).max() ?? 0
        let dx = direction * Self.stepX
        if left + dx < Self.sideMargin || right + dx > Self.width - Self.sideMargin {
            formationOrigin.y += Self.dropY
            direction = -direction
        } else {
            formationOrigin.x += dx
        }
        for invader in invaders { crushFirewalls(under: frame(of: invader)) }
        if invaders.contains(where: { frame(of: $0).maxY >= Self.shipTop }) {
            lives = 0
            endGame()
        }
    }

    private mutating func enemyFire(by seconds: Double) {
        enemyFireClock -= seconds
        guard enemyFireClock <= 0 else { return }
        enemyFireClock = enemyFireInterval * Double.random(in: 0.7...1.3, using: &rng)
        guard enemyShots.count < maxEnemyShots else { return }
        // The lowest invader in each column can fire; often the one nearest the ship takes aim.
        let shooters = Dictionary(grouping: invaders, by: \.column).compactMap { $0.value.max { $0.row < $1.row } }
            .sorted { $0.column < $1.column }
        guard !shooters.isEmpty else { return }
        let aimed = Double.random(in: 0..<1, using: &rng) < 0.4
        let shooter = aimed ? shooters.min { abs(frame(of: $0).midX - shipX) < abs(frame(of: $1).midX - shipX) }
                            : shooters.randomElement(using: &rng)
        guard let shooter else { return }
        let muzzle = frame(of: shooter)
        enemyShots.append(EnemyShot(id: newID(), position: Vector2(x: muzzle.midX, y: muzzle.maxY + Self.enemyShotSize.height / 2),
                                    velocity: Vector2(x: 0, y: enemyShotSpeed), shooter: shooter.kind))
    }

    private mutating func moveEnemyShots(by seconds: Double) {
        guard !enemyShots.isEmpty else { return }
        var falling: [EnemyShot] = []
        for var shot in enemyShots {
            shot.position = shot.position + shot.velocity * seconds
            let box = Self.box(around: shot.position, size: Self.enemyShotSize)
            if chipFirewall(touching: box, fromBelow: false) { continue }
            if box.overlaps(shipHitbox) && invulnerableFor <= 0 {
                guard health > 1 else {
                    loseShip()
                    return
                }
                takeHit(at: shot.position)
                continue
            }
            if shot.position.y - Self.enemyShotSize.height > Self.height || shot.position.x < -0.05 || shot.position.x > Self.width + 0.05 {
                continue
            }
            falling.append(shot)
        }
        enemyShots = falling
    }

    /// A hit the ship survives: the shield goes first, then the ship's own health, and it blinks for
    /// a moment so the rest of a volley passes through.
    private mutating func takeHit(at point: Vector2) {
        if hasShield {
            shieldSaves += 1
            events.append(.shieldHit(at: point))
        } else {
            events.append(.shipDamaged(at: point, healthLeft: health - 1))
        }
        health -= 1
        hitsTaken += 1
        invulnerableFor = max(invulnerableFor, Self.hitGrace)
    }

    // MARK: Firewalls

    /// Knocks out the block a shot meets first, if it touches a standing one: the lowest for the
    /// ship's shots (fired up from below), the highest for the invaders'. An invader's shot also
    /// takes a block next to it.
    private mutating func chipFirewall(touching box: Box, fromBelow: Bool) -> Bool {
        guard let wall = firewalls.firstIndex(where: { $0.frame.overlaps(box) }) else { return false }
        let firewall = firewalls[wall]
        var hit: (row: Int, column: Int)?
        let rows = fromBelow ? Array((0..<firewall.rows).reversed()) : Array(0..<firewall.rows)
        search: for row in rows {
            for column in 0..<firewall.columns where firewall.isStanding(row: row, column: column)
                && firewall.blockFrame(row: row, column: column).overlaps(box) {
                hit = (row, column)
                break search
            }
        }
        guard let hit else { return false }
        firewalls[wall].blocks[hit.row * firewall.columns + hit.column] = false
        if !fromBelow {
            let neighbors = [(hit.row + 1, hit.column), (hit.row, hit.column - 1), (hit.row, hit.column + 1)]
                .filter { firewalls[wall].isStanding(row: $0.0, column: $0.1) }
            if let extra = neighbors.randomElement(using: &rng) {
                firewalls[wall].blocks[extra.0 * firewall.columns + extra.1] = false
            }
        }
        let block = firewall.blockFrame(row: hit.row, column: hit.column)
        events.append(.firewallHit(at: Vector2(x: block.midX, y: block.midY)))
        return true
    }

    private mutating func crushFirewalls(under frame: Box) {
        for wall in firewalls.indices where firewalls[wall].frame.overlaps(frame) {
            let size = (rows: firewalls[wall].rows, columns: firewalls[wall].columns)
            for row in 0..<size.rows {
                for column in 0..<size.columns where firewalls[wall].blockFrame(row: row, column: column).overlaps(frame) {
                    firewalls[wall].blocks[row * size.columns + column] = false
                }
            }
        }
    }

    /// Four server racks, each a solid block of 5 by 8: one server to a row.
    static func freshFirewalls(startingID: Int) -> [Firewall] {
        let gap = (width - 4 * firewallSize.width) / 5
        return (0..<4).map { index in
            let frame = Box(minX: gap + Double(index) * (firewallSize.width + gap), minY: firewallTop,
                            width: firewallSize.width, height: firewallSize.height)
            return Firewall(id: startingID + index, frame: frame)
        }
    }

    /// Racks for a random wave: two to five of them, each three to six servers tall and five to
    /// eleven blocks across (blocks the classic size), spread across the field with gaps of their
    /// own, at heights of their own.
    static func madeUpFirewalls<R: RandomNumberGenerator>(startingID: Int, using rng: inout R) -> [Firewall] {
        let block = (width: firewallSize.width / Double(Firewall.classicColumns),
                     height: firewallSize.height / Double(Firewall.classicRows))
        let count = Int.random(in: 2...5, using: &rng)
        var sizes = (0..<count).map { _ in (rows: Int.random(in: 3...6, using: &rng), columns: Int.random(in: 5...11, using: &rng)) }
        let minimumGap = 0.03
        func total() -> Double { Double(sizes.reduce(0) { $0 + $1.columns }) * block.width + Double(count + 1) * minimumGap }
        // Too wide for the field: trim the widest until they fit.
        while total() > width, let widest = sizes.indices.max(by: { sizes[$0].columns < sizes[$1].columns }),
              sizes[widest].columns > 3 {
            sizes[widest].columns -= 1
        }
        let spare = max(0, width - total())
        let shares = (0...count).map { _ in Double.random(in: 0.3...1, using: &rng) }
        let sum = shares.reduce(0, +)
        var x = minimumGap + spare * shares[0] / sum
        var racks: [Firewall] = []
        for (index, size) in sizes.enumerated() {
            let frame = Box(minX: x, minY: Double.random(in: 1.12...1.2, using: &rng),
                            width: Double(size.columns) * block.width, height: Double(size.rows) * block.height)
            racks.append(Firewall(id: startingID + index, frame: frame, rows: size.rows, columns: size.columns))
            x += frame.width + minimumGap + spare * shares[index + 1] / sum
        }
        return racks
    }

    // MARK: The whale

    private mutating func moveWhale(by seconds: Double) {
        if var current = whale {
            current.position.x += current.speedX * seconds
            whale = current.frame.maxX < -0.02 || current.frame.minX > Self.width + 0.02 ? nil : current
            return
        }
        whaleClock -= seconds
        guard whaleClock <= 0 else { return }
        whaleClock = Double.random(in: 16...26, using: &rng)
        // Not over a boss, and not for the last few invaders.
        guard boss == nil, invaders.count >= 8 else { return }
        let fromLeft = Bool.random(using: &rng)
        let x = fromLeft ? -Whale.size.width / 2 : Self.width + Whale.size.width / 2
        whale = Whale(position: Vector2(x: x, y: Self.whaleY), speedX: fromLeft ? 0.2 : -0.2)
    }

    private mutating func hitWhale(_ current: Whale) {
        whale = nil
        whalesHit += 1
        streak += 1
        bestStreak = max(bestStreak, streak)
        let points = [50, 100, 100, 150, 150, 300].randomElement(using: &rng) ?? 100
        score = score.addingCount(points)
        events.append(.whaleHit(at: current.position, points: points))
        dropCapsule(at: current.position)
    }

    // MARK: The boss

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
        current.fireClock -= seconds
        if current.fireClock <= 0 {
            current.fireClock = Self.bossFireInterval(wave: wave)
            // Three shots fanning out, aimed at where the ship is.
            let start = Vector2(x: current.frame.midX, y: current.frame.maxY)
            let toward = min(max((shipX - start.x) * 0.25, -0.12), 0.12)
            let speed = enemyShotSpeed
            for spread in [-0.16, 0, 0.16] {
                enemyShots.append(EnemyShot(id: newID(), position: start,
                                            velocity: Vector2(x: (spread + toward) * speed, y: speed), shooter: nil))
            }
        }
        boss = current
    }

    /// Seconds (at Normal speed) between the boss's volleys: a little quicker each boss.
    static func bossFireInterval(wave: Int) -> TimeInterval {
        max(0.9, 1.8 - 0.2 * Double(wave / bossEvery - 1)) / fireRate
    }

    /// Hits each boss takes: more for every one after the first.
    static func bossHits(wave: Int) -> Int { 25 + 15 * max(0, wave / bossEvery - 1) }

    private mutating func hitBoss(at point: Vector2) {
        guard var current = boss else { return }
        current.hitsLeft -= 1
        _ = scoreHit(5)
        if current.hitsLeft > 0 {
            boss = current
            events.append(.bossHit(at: point))
            return
        }
        boss = nil
        bossesDefeated += 1
        let points = 500 * (wave / Self.bossEvery)
        score = score.addingCount(points)
        // Beating a boss gives back a lost ship.
        lives = min(Self.startingLives, lives + 1)
        events.append(.bossDefeated(at: Vector2(x: current.frame.midX, y: current.frame.midY), points: points))
        dropCapsule(at: Vector2(x: current.frame.midX, y: current.frame.maxY))
        checkCleared()
    }

    // MARK: Power-ups

    private mutating func dropCapsule(at point: Vector2) {
        let kind = PowerUp.allCases.randomElement(using: &rng) ?? .rapidFire
        capsules.append(Capsule(id: newID(), kind: kind, position: point))
    }

    private mutating func moveCapsules(by seconds: Double) {
        guard !capsules.isEmpty else { return }
        let ship = ship
        var caught: [PowerUp] = []
        capsules = capsules.compactMap { capsule in
            var moved = capsule
            moved.position.y += Self.capsuleSpeed * seconds
            if Self.box(around: moved.position, size: Self.capsuleSize).overlaps(ship) {
                caught.append(capsule.kind)
                return nil
            }
            return moved.position.y > Self.height ? nil : moved
        }
        for kind in caught { activate(kind) }
    }

    private mutating func activate(_ kind: PowerUp) {
        powerUpsCaught += 1
        events.append(.caught(kind))
        if kind == .shield {
            // One hit more, mending a damaged ship first; never more than one over full.
            health = min(health + 1, maxHealth + 1)
        } else {
            effects[kind] = kind.duration
        }
    }

    // MARK: Ships and waves

    private mutating func loseShip() {
        lives -= 1
        shipsLost += 1
        lostShipThisWave = true
        streak = 0
        events.append(.shipHit(at: Vector2(x: shipX, y: Self.shipTop + Self.shipSize.height / 2)))
        enemyShots = []
        dropVolleys()
        capsules = []
        effects = [:]
        // The next ship comes in whole.
        health = maxHealth
        if lives <= 0 {
            health = 0
            endGame()
        } else {
            phase = .shipLost
            holdFor = Self.shipLostHold
        }
    }

    private mutating func endGame() {
        lives = max(0, lives)
        phase = .over
        isFiring = false
        dropVolleys()
        enemyShots = []
        capsules = []
        whale = nil
    }

    /// Ends the wave once every invader (and the boss) is down: 100 points a wave, and 50 more a
    /// wave if no ship was lost on it.
    private mutating func checkCleared() {
        guard invaders.isEmpty, boss == nil, phase == .playing else { return }
        lastWaveBonus = 100 * wave + (lostShipThisWave ? 0 : 50 * wave)
        score = score.addingCount(lastWaveBonus)
        phase = .waveCleared
        holdFor = Self.clearedHold
        dropVolleys()
        enemyShots = []
        whale = nil
    }

    /// Sets up the current wave: the formation (classic or made up, or a boss with two rows of
    /// escorts), fresh firewalls, and the incoming banner.
    private mutating func layOutWave() {
        phase = .incoming
        holdFor = Self.incomingHold
        shots = []
        enemyShots = []
        capsules = []
        volleys = [:]
        whale = nil
        lostShipThisWave = false
        direction = 1
        enemyFireClock = 1.5
        let formationWidth = Double(Self.columns - 1) * Self.columnSpacing + Self.invaderSize.width
        formationOrigin = Vector2(x: (Self.width - formationWidth) / 2, y: Self.formationTop(wave: wave))
        func classic(rows: Range<Int>) -> [Cell] {
            rows.flatMap { row in (0..<Self.columns).map { Cell(row: row, column: $0, kind: InvaderKind.forRow(row)) } }
        }
        let cells: [Cell]
        if isBossWave {
            // The escorts march lower down, under the boss's lane.
            formationOrigin.y = Self.formationTop(wave: wave) - 0.02
            let frame = Box(minX: 0.34, minY: 0.13, width: 0.32, height: 0.11)
            boss = Boss(frame: frame, maxHits: Self.bossHits(wave: wave), hitsLeft: Self.bossHits(wave: wave),
                        speedX: 0.15 + 0.03 * Double(wave / Self.bossEvery), fireClock: Self.bossFireInterval(wave: wave))
            cells = classic(rows: 3..<Self.rows)
        } else if waveStyle == .generated {
            boss = nil
            cells = Self.generatedFormation(using: &rng)
            // Made-up formations set off either way.
            if Bool.random(using: &rng) { direction = -1 }
        } else {
            boss = nil
            cells = classic(rows: 0..<Self.rows)
        }
        // Random waves have one to three golden invaders (four from wave 6) from the very first wave.
        // Classic waves have one from the second, always in the same place on a wave.
        let golden: Set<Int>
        if waveStyle == .generated {
            let count = Int.random(in: 1...(wave >= 6 ? 4 : 3), using: &rng)
            golden = Set(cells.indices.shuffled(using: &rng).prefix(count))
        } else if wave >= 2 {
            var fixed = Self.classicGenerator(wave: wave)
            golden = Set(cells.indices.randomElement(using: &fixed).map { [$0] } ?? [])
        } else {
            golden = []
        }
        invaders = []
        for (index, cell) in cells.enumerated() {
            invaders.append(Invader(id: newID(), row: cell.row, column: cell.column, kind: cell.kind, isGolden: golden.contains(index)))
        }
        formationSize = invaders.count
        // The first step comes one beat after the march begins.
        marchClock = marchInterval
        let firstRack = newID()
        firewalls = waveStyle == .generated ? Self.madeUpFirewalls(startingID: firstRack, using: &rng)
                                            : Self.freshFirewalls(startingID: firstRack)
        nextID += firewalls.count
    }

    /// What fixes a classic wave's choices (its golden invader), the same every time it's played.
    static func classicGenerator(wave: Int) -> SeededGenerator {
        SeededGenerator(seed: 0x5CA3_1A7E &+ UInt64(max(1, wave)) &* 0x9E37_79B9_7F4A_7C15)
    }

    /// Clears the ship's shots when a wave or a ship ends. Volleys cut short before they hit
    /// anything never had their chance, so they don't count toward accuracy.
    private mutating func dropVolleys() {
        volleysFired -= volleys.values.filter { $0.hits == 0 }.count
        volleys = [:]
        shots = []
    }

    // MARK: Made-up formations

    /// A place in the formation's grid, and the kind of invader there.
    struct Cell: Equatable {
        let row: Int
        let column: Int
        let kind: InvaderKind
    }

    /// The fewest invaders a made-up formation holds: seven tenths of the classic one.
    static let generatedMinimum = 28

    /// A formation made up on the spot for random waves, mirrored left to right like the classic
    /// one: scattered, blobs, a diamond, an hourglass or a bow tie, a pyramid, chevrons, stripes,
    /// columns, a frame, a skyline or one giant invader, each with its own sizes and gaps. A shape too
    /// sparse grows outward from what it has until it holds `generatedMinimum`. It sits on the
    /// classic formation's bottom row, so it comes down no later.
    ///
    /// The kinds follow a pattern of their own (in rows either way up, from the middle out or the
    /// outside in, a checkerboard, or scattered) in about the classic's shares, a fifth rug pullers
    /// and two fifths each pump bots and meme coins, so a wave is worth about as much.
    static func generatedFormation<R: RandomNumberGenerator>(using rng: inout R) -> [Cell] {
        let grid = grownToMinimum(madeUpShape(using: &rng), using: &rng)
        // Down onto the bottom row.
        let lowest = (0..<rows).last { grid[$0].contains(true) } ?? rows - 1
        let shift = rows - 1 - lowest
        var cells: [(row: Int, column: Int)] = []
        for row in 0..<rows {
            for column in 0..<(columns / 2) where grid[row][column] { cells.append((row: row + shift, column: column)) }
        }
        let kinds = mixedKinds(for: cells, using: &rng)
        var formation: [Cell] = []
        for (index, cell) in cells.enumerated() {
            formation.append(Cell(row: cell.row, column: cell.column, kind: kinds[index]))
            formation.append(Cell(row: cell.row, column: columns - 1 - cell.column, kind: kinds[index]))
        }
        return formation.sorted { $0.row != $1.row ? $0.row < $1.row : $0.column < $1.column }
    }

    /// The left half of a made-up shape, row by row: the right half mirrors it.
    private static func madeUpShape<R: RandomNumberGenerator>(using rng: inout R) -> [[Bool]] {
        let half = columns / 2
        var grid = Array(repeating: Array(repeating: false, count: half), count: rows)
        /// Columns out from the middle: 0 beside it, 3 at the edge.
        func reach(_ column: Int) -> Int { half - 1 - column }
        let middle = rows / 2
        switch Int.random(in: 0..<11, using: &rng) {
        case 0: // Scattered.
            let density = Double.random(in: 0.6...0.85, using: &rng)
            for row in 0..<rows { for column in 0..<half { grid[row][column] = Double.random(in: 0..<1, using: &rng) < density } }
        case 1: // Blobs: scattered across the whole width, smoothed twice so they clump together.
            let full = blobs(density: Double.random(in: 0.5...0.66, using: &rng), using: &rng)
            for row in 0..<rows { for column in 0..<half { grid[row][column] = full[row][column] } }
        case 2: // A diamond: a slim one, or a fat one that's sometimes hollow.
            let fat = Bool.random(using: &rng)
            let hollow = fat && Bool.random(using: &rng)
            for row in 0..<rows {
                let width = Double(half) - Double(abs(row - middle)) * (fat ? 0.75 : 1)
                for column in 0..<half {
                    let isHole = hollow && row == middle && reach(column) == 0
                    grid[row][column] = Double(reach(column)) < width && !isHole
                }
            }
        case 3: // An hourglass, or a bow tie on its side.
            let bowTie = Bool.random(using: &rng)
            for row in 0..<rows {
                let fromMiddle = abs(row - middle)
                for column in 0..<half { grid[row][column] = bowTie ? fromMiddle <= reach(column) : reach(column) < 2 + fromMiddle }
            }
        case 4: // A pyramid, pointing up or down, with a narrow or a broad tip.
            let pointsUp = Bool.random(using: &rng)
            let tip = Int.random(in: 1...2, using: &rng)
            for row in 0..<rows {
                let depth = pointsUp ? row : rows - 1 - row
                for column in 0..<half { grid[row][column] = reach(column) < tip + depth }
            }
        case 5: // Chevrons, pointing up or down.
            let period = Int.random(in: 3...4, using: &rng)
            let upward = Bool.random(using: &rng)
            for row in 0..<rows {
                let depth = upward ? row : rows - 1 - row
                for column in 0..<half { grid[row][column] = (depth + reach(column)) % period < period - 1 }
            }
        case 6: // Stripes: every row but one.
            let gap = Int.random(in: 0..<(rows - 1), using: &rng)
            for row in 0..<rows where row != gap { for column in 0..<half { grid[row][column] = true } }
        case 7: // Columns, with a gap between them: in the middle, at the edges, or in between.
            let gap = Int.random(in: 0..<half, using: &rng)
            for row in 0..<rows { for column in 0..<half { grid[row][column] = reach(column) != gap } }
        case 8: // A frame: a thick one with a slot in the middle and a few gaps, or a thin one with a bar across.
            let bar = Bool.random(using: &rng)
            let holes = Double.random(in: 0...0.12, using: &rng)
            for row in 0..<rows {
                for column in 0..<half {
                    let ring = min(row, rows - 1 - row, column)
                    if bar {
                        grid[row][column] = ring == 0 || row == middle
                    } else {
                        grid[row][column] = ring <= 1 && Double.random(in: 0..<1, using: &rng) >= holes
                    }
                }
            }
        case 9: // A skyline: columns of different heights, standing on the bottom row.
            for column in 0..<half {
                let height = Int.random(in: 2...rows, using: &rng)
                for row in (rows - height)..<rows { grid[row][column] = true }
            }
        default: // One giant invader, eyes and legs and all.
            let art = ["..XX", ".XXX", "XX.X", "XXXX", ".X.X"]
            for (row, line) in art.enumerated() {
                for (column, mark) in line.enumerated() { grid[row][column] = mark == "X" }
            }
        }
        return grid
    }

    /// Scattered cells across the whole formation, smoothed twice: a cell stays when at least five
    /// of the nine around it (itself included) are taken.
    private static func blobs<R: RandomNumberGenerator>(density: Double, using rng: inout R) -> [[Bool]] {
        var full = Array(repeating: Array(repeating: false, count: columns), count: rows)
        for row in 0..<rows { for column in 0..<columns { full[row][column] = Double.random(in: 0..<1, using: &rng) < density } }
        for _ in 0..<2 {
            var next = full
            for row in 0..<rows {
                for column in 0..<columns {
                    var count = 0
                    for r in (row - 1)...(row + 1) where (0..<rows).contains(r) {
                        for c in (column - 1)...(column + 1) where (0..<columns).contains(c) && full[r][c] { count += 1 }
                    }
                    next[row][column] = count >= 5
                }
            }
            full = next
        }
        return full
    }

    /// Grows a shape too sparse outward from what it has (or from anywhere, when it has nothing)
    /// until the formation holds `generatedMinimum`.
    private static func grownToMinimum<R: RandomNumberGenerator>(_ shape: [[Bool]], using rng: inout R) -> [[Bool]] {
        let half = columns / 2
        var grid = shape
        func isTaken(_ row: Int, _ column: Int) -> Bool {
            (0..<rows).contains(row) && (0..<half).contains(column) && grid[row][column]
        }
        var count = 2 * grid.joined().filter { $0 }.count
        while count < generatedMinimum {
            var empty: [(row: Int, column: Int)] = []
            var touching: [(row: Int, column: Int)] = []
            for row in 0..<rows {
                for column in 0..<half where !grid[row][column] {
                    empty.append((row: row, column: column))
                    if isTaken(row - 1, column) || isTaken(row + 1, column) || isTaken(row, column - 1) || isTaken(row, column + 1) {
                        touching.append((row: row, column: column))
                    }
                }
            }
            guard let pick = (touching.isEmpty ? empty : touching).randomElement(using: &rng) else { break }
            grid[pick.row][pick.column] = true
            count += 2
        }
        return grid
    }

    /// The kinds for a formation's left half: the cells ranked by a pattern, then each group of
    /// equal rank takes the kind its place in the ranking falls in. The first fifth are rug
    /// pullers, the next two fifths pump bots, and the rest meme coins.
    private static func mixedKinds<R: RandomNumberGenerator>(for cells: [(row: Int, column: Int)], using rng: inout R) -> [InvaderKind] {
        let pattern = Int.random(in: 0..<6, using: &rng)
        var ranks: [Double] = []
        for cell in cells {
            let reach = columns / 2 - 1 - cell.column
            switch pattern {
            case 0: ranks.append(Double(cell.row)) // In rows, rug pullers on top like the classic.
            case 1: ranks.append(Double(-cell.row)) // Upside down: rug pullers at the bottom.
            case 2: ranks.append(Double(reach)) // From the middle out.
            case 3: ranks.append(Double(-reach)) // From the outside in.
            case 4: ranks.append(Double((cell.row + cell.column) % 2 * rows + cell.row)) // A checkerboard.
            default: ranks.append(Double.random(in: 0..<1, using: &rng)) // Scattered.
            }
        }
        let order = cells.indices.sorted { a, b in
            if ranks[a] != ranks[b] { return ranks[a] < ranks[b] }
            return cells[a].row != cells[b].row ? cells[a].row < cells[b].row : cells[a].column < cells[b].column
        }
        var kinds = Array(repeating: InvaderKind.memeCoin, count: cells.count)
        var start = 0
        while start < order.count {
            var end = start + 1
            while end < order.count && ranks[order[end]] == ranks[order[start]] { end += 1 }
            let place = Double(start + end) / 2 / Double(order.count)
            let kind: InvaderKind = place < 0.2 ? .rugPuller : place < 0.6 ? .pumpBot : .memeCoin
            for index in order[start..<end] { kinds[index] = kind }
            start = end
        }
        return kinds
    }

    private static func box(around center: Vector2, size: (width: Double, height: Double)) -> Box {
        Box(minX: center.x - size.width / 2, minY: center.y - size.height / 2, width: size.width, height: size.height)
    }

    private mutating func newID() -> Int {
        nextID += 1
        return nextID
    }

    #if DEBUG
    /// Test hook: starts the wave now, without the banner.
    mutating func skipBanner() {
        guard phase == .incoming else { return }
        phase = .playing
        holdFor = 0
    }

    /// Test hook: keeps only the invaders at these grid cells.
    mutating func keepInvaders(at cells: [(row: Int, column: Int)]) {
        invaders = invaders.filter { invader in cells.contains { $0.row == invader.row && $0.column == invader.column } }
        formationSize = max(formationSize, invaders.count)
    }

    /// Test hook: moves the formation so its top-left grid corner is at `origin`.
    mutating func placeFormation(at origin: Vector2) {
        formationOrigin = origin
    }

    /// Test hook: fires an invader shot from `position`, straight down.
    mutating func dropEnemyShot(at position: Vector2) {
        enemyShots.append(EnemyShot(id: newID(), position: position, velocity: Vector2(x: 0, y: enemyShotSpeed), shooter: .memeCoin))
    }

    /// Test hook: holds the invaders' fire (and the whale) for a long while.
    mutating func holdFire() {
        enemyFireClock = 1e9
        whaleClock = 1e9
    }

    /// Test hook: holds the formation still.
    mutating func holdMarch() {
        marchClock = 1e9
    }

    /// Test hook: catches a power-up at once.
    mutating func give(_ kind: PowerUp) {
        activate(kind)
    }

    /// Test hook: drops a power-up at `position`.
    mutating func dropCapsule(_ kind: PowerUp, at position: Vector2) {
        capsules.append(Capsule(id: newID(), kind: kind, position: position))
    }

    /// Test hook: sends the whale across now.
    mutating func sendWhale(at x: Double, speedX: Double = 0.2) {
        whale = Whale(position: Vector2(x: x, y: Self.whaleY), speedX: speedX)
    }

    /// Test hook: jumps to a wave and lays it out.
    mutating func jump(toWave wave: Int) {
        self.wave = wave
        layOutWave()
    }

    /// Test hook: sets the boss's hits left.
    mutating func setBossHits(_ hits: Int) {
        boss?.hitsLeft = hits
    }
    #endif
}

extension ArcadeDifficulty {
    /// Hits a Scam Invaders ship takes before it's lost.
    public var hitsPerShip: Int {
        switch self {
        case .easy: 3
        case .regular: 2
        case .hard: 1
        }
    }

    /// Scam Invaders' difficulty in a line.
    public var invadersSummary: String {
        switch self {
        case .easy: localized("Ships take three hits, the invaders march slowly, and points pay 20% less.")
        case .regular: localized("Ships take two hits, at the usual pace.")
        case .hard: localized("One hit and the ship is lost, the invaders march fast, and points pay 20% more.")
        }
    }

    /// How much wider Hash Smash's paddle is than Regular's.
    public var paddleScale: Double {
        switch self {
        case .easy: 1.2
        case .regular: 1
        case .hard: 0.8
        }
    }

    /// Hash Smash's difficulty in a line.
    public var brickBreakerSummary: String {
        switch self {
        case .easy: localized("A wider paddle and a slower ball, and points pay 20% less.")
        case .regular: localized("The usual paddle and ball.")
        case .hard: localized("A narrower paddle and a faster ball, and points pay 20% more.")
        }
    }
}
