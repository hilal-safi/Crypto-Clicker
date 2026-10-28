import Foundation

/// Token Swap, a match-three game with crypto tokens, played three ways:
/// - **Classic**: a minute on a fresh board to score as much as possible. Pays coins per point.
/// - **Levels**: a goal (collect tokens, crack ice, break chains or crates, bring gold bars down,
///   set off specials, or reach a score) in a limited number of moves, for up to three stars.
/// - **Daily puzzle**: one level a day, the same board and the same falling tokens for everyone.
///
/// Swap two neighboring tokens to line up three or more of a kind. They clear, the tokens above
/// fall into the gaps and new ones drop in, which can set off more matches, each wave scoring more
/// than the last. Bigger matches leave a special piece where the player moved:
/// - a 2×2 square makes a **Propeller**, which clears the four tokens beside it, then flies to the
///   most useful spot on the board (an obstacle or token the level needs) and clears that;
/// - four in a row makes a **Rocket**: from a row of four it clears its whole row, from a column
///   of four its whole column;
/// - an L or T of five makes a **Bomb**, which clears the 5×5 square around it;
/// - five in a row makes a **Color Clear**, which has no color of its own: swapped with a token,
///   it clears every token of that color.
///
/// When one match fits several patterns, the biggest wins: five in a row, then an L or T, then four
/// in a row, then a square. A special goes off when it's matched, when another special's blast
/// reaches it, or when it's swapped with any neighbor (which is always a move). Swapping two
/// specials together sets off a combination (see `comboBlasts`).
///
/// A wave clears everything it reaches at once: every cell is cleared, and every obstacle hit, at
/// most once per wave. Then the tiles fall and the next wave looks for matches again. The player
/// can't swap until the board has settled. A board with no move left is shuffled.
public struct TokenSwapGame: Sendable {
    public static let size = 8
    public static let classicKinds = 6
    public static let roundLength: TimeInterval = 60
    public static let pointsPerToken = 10
    /// Points for each obstacle broken: a frozen tile freed, a chain or a crate broken.
    public static let obstaclePoints = 30
    public static let goldPoints = 100
    /// Points for each move left when a level is won.
    public static let pointsPerMoveLeft = 120
    /// At most this many gold bars on the board at a time.
    static let goldOnBoardLimit = 2

    // MARK: Pieces

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

        var neighbors: [Position] {
            [moved(dRow: -1, dColumn: 0), moved(dRow: 1, dColumn: 0), moved(dRow: 0, dColumn: -1), moved(dRow: 0, dColumn: 1)]
                .filter(\.isOnBoard)
        }
    }

    /// What a special piece does.
    public enum Power: String, Codable, CaseIterable, Sendable {
        /// Clears its whole row.
        case rocketAcross
        /// Clears its whole column.
        case rocketDown
        /// Clears the 5×5 square around it.
        case bomb
        /// Clears the four cells beside it, then flies to the most useful cell and clears that.
        case propeller
        /// No color of its own: swapped with a token, clears every token of that color.
        case colorClear

        public var isRocket: Bool { self == .rocketAcross || self == .rocketDown }

        public var name: String {
            switch self {
            case .rocketAcross, .rocketDown: "Rocket"
            case .bomb: "Bomb"
            case .propeller: "Propeller"
            case .colorClear: "Color Clear"
            }
        }

        /// What it's worth to make, for hints and simple players.
        var value: Int {
            switch self {
            case .colorClear: 30
            case .bomb: 20
            case .rocketAcross, .rocketDown: 12
            case .propeller: 10
            }
        }
    }

    /// A piece on the board: a token (maybe carrying a power), a Color Clear, or a gold bar.
    public struct Tile: Equatable, Sendable, Identifiable {
        /// Unique for the whole game, so the screen can animate each piece as it moves.
        public let id: Int
        /// The token's color, from 0 to `kinds - 1`. A Color Clear and a gold bar have none.
        public internal(set) var kind: Int?
        public internal(set) var power: Power?
        /// A gold bar can't be matched or broken; it's collected when it reaches the bottom row.
        public internal(set) var isGold = false

        public init(id: Int, kind: Int?, power: Power? = nil, isGold: Bool = false) {
            self.id = id
            self.kind = kind
            self.power = power
            self.isGold = isGold
        }

        public var isSpecial: Bool { power != nil }
    }

    /// One square of the board, with whatever obstacle is on it.
    public struct Cell: Equatable, Sendable {
        /// `nil` under a crate.
        public internal(set) var tile: Tile?
        /// Layers of ice around the tile. A frozen tile can't move or match; a match beside it or
        /// a blast cracks a layer.
        public internal(set) var ice = 0
        /// A chained tile can't be swapped or fall, but can still match, which breaks the chain
        /// (the tile stays). Blasts break chains too.
        public internal(set) var isChained = false
        /// Layers left of a crate filling the cell. A match beside it or a blast breaks a layer.
        public internal(set) var crate = 0

        /// Holds still while tiles fall.
        public var isFixed: Bool { crate > 0 || ice > 0 || isChained }
        public var canSwap: Bool { tile != nil && !isFixed }
        /// The color it matches as, if it can match at all.
        var matchKind: Int? { crate == 0 && ice == 0 ? tile?.kind : nil }
        var hasObstacle: Bool { crate > 0 || ice > 0 || isChained }
    }

    // MARK: Goals

    /// Which specials a goal counts.
    public enum SpecialKind: String, Codable, CaseIterable, Sendable {
        case any, rocket, bomb, propeller, colorClear

        func counts(_ power: Power) -> Bool {
            switch self {
            case .any: true
            case .rocket: power.isRocket
            case .bomb: power == .bomb
            case .propeller: power == .propeller
            case .colorClear: power == .colorClear
            }
        }
    }

    /// What a level asks for. A level is won when every goal is reached.
    public enum Goal: Hashable, Sendable {
        /// Clear this many tokens of one color.
        case tokens(kind: Int, count: Int)
        /// Free this many frozen tiles (all their ice broken).
        case ice(Int)
        case chains(Int)
        case crates(Int)
        /// Bring this many gold bars down to the bottom row.
        case gold(Int)
        /// Set off this many specials of a kind.
        case specials(SpecialKind, Int)
        case score(Int)

        public var target: Int {
            switch self {
            case .tokens(_, let count), .ice(let count), .chains(let count), .crates(let count), .gold(let count),
                 .specials(_, let count), .score(let count):
                count
            }
        }

        public var description: String {
            switch self {
            case .tokens(let kind, let count): "Clear \(count) \(TokenSwapGame.tokenName(kind))"
            case .ice(let count): "Free \(count) frozen token\(count == 1 ? "" : "s")"
            case .chains(let count): "Break \(count) chain\(count == 1 ? "" : "s")"
            case .crates(let count): "Break \(count) crate\(count == 1 ? "" : "s")"
            case .gold(let count): "Bring down \(count) gold bar\(count == 1 ? "" : "s")"
            case .specials(let kind, let count):
                switch kind {
                case .any: "Set off \(count) special\(count == 1 ? "" : "s")"
                case .rocket: "Set off \(count) Rocket\(count == 1 ? "" : "s")"
                case .bomb: "Set off \(count) Bomb\(count == 1 ? "" : "s")"
                case .propeller: "Set off \(count) Propeller\(count == 1 ? "" : "s")"
                case .colorClear: "Set off \(count) Color Clear\(count == 1 ? "" : "s")"
                }
            case .score(let points): "Score \(CoinFormat.grouped(points))"
            }
        }
    }

    /// The tokens, in kind order: Bitcoin, Ethereum, Solana, Dogecoin, XRP, Cardano.
    public static let tokens: [TokenID] = [.bitcoin, .ethereum, .solana, .dogecoin, .xrp, .cardano]

    public static func tokenName(_ kind: Int) -> String {
        tokens[((kind % tokens.count) + tokens.count) % tokens.count].ticker
    }

    // MARK: Waves

    /// A special going off, for the screen to draw.
    public struct Blast: Equatable, Sendable {
        public let power: Power
        public let origin: Position
        /// Where a propeller landed.
        public let target: Position?
        /// Every cell it reached.
        public let reach: [Position]
        /// Set off by swapping two specials together.
        public let isCombo: Bool
    }

    /// An obstacle a wave broke a layer of.
    public struct ObstacleHit: Equatable, Sendable {
        public enum Kind: Equatable, Sendable { case ice, chain, crate }
        public let position: Position
        public let kind: Kind
        /// Layers left: 0 when it's gone.
        public let layersLeft: Int
    }

    /// What one wave of clearing did, for the screen to show.
    public struct Step: Equatable, Sendable {
        /// Cells whose tiles were cleared, before the tiles above fell.
        public let cleared: [Position]
        public let points: Int
        /// 1 for the wave a swap sets off, 2 for the wave after, and so on.
        public let chain: Int
        public let blastList: [Blast]
        /// Where this wave's matches made specials, and which.
        public let made: [Position: Power]
        public let obstacles: [ObstacleHit]
        /// Gold bars that reached the bottom row, by column.
        public let goldCollected: [Int]

        /// Specials that went off.
        public var blasts: Int { blastList.count }
        public var madeSpecials: [Position] { made.keys.sorted() }
    }

    public enum Mode: Equatable, Sendable {
        case classic
        case level(Int)
        /// The daily puzzle for a day (a `StepDay` key).
        case daily(String)
    }

    public enum Phase: Equatable, Sendable {
        case playing
        /// Every goal reached (levels and the daily puzzle).
        case won
        /// Out of moves short of a goal.
        case lost
    }

    // MARK: State

    public let mode: Mode
    /// Token colors in play.
    public let kinds: Int
    public let goals: [Goal]
    /// Moves a level allows; `nil` in Classic, which has a clock instead.
    public let moveLimit: Int?
    /// Rows from the top.
    public private(set) var cells: [[Cell]] = []
    public private(set) var phase = Phase.playing
    public private(set) var score = 0
    public private(set) var time: TimeInterval = 0
    public private(set) var moves = 0
    /// Points for moves left over, added when a level is won.
    public private(set) var bonusPoints = 0
    /// Tokens cleared, all colors together.
    public private(set) var tokensCleared = 0
    /// Tokens cleared by color.
    public private(set) var clearedByKind: [Int]
    public private(set) var iceFreed = 0
    public private(set) var chainsBroken = 0
    public private(set) var cratesBroken = 0
    public private(set) var goldCollected = 0
    public private(set) var specialsMade = 0
    /// Specials that went off, of each power.
    public private(set) var setOff: [Power: Int] = [:]
    /// The most waves one swap set off.
    public private(set) var bestChain = 0
    /// Times the board ran out of moves and was shuffled.
    public private(set) var shuffles = 0
    /// The wave the next step will score as; 0 while waiting for a swap.
    public private(set) var chain = 0
    /// The swap that started the chain: specials it made appear where the player moved.
    var lastSwap: [Position] = []
    /// What the swap itself sets off, waiting for the first wave.
    var pendingBlasts: [PendingBlast] = []
    /// Gold bars still to drop in from the top.
    var goldToDrop: Int
    var rng: SeededGenerator
    var nextID = 0

    /// A blast queued for the coming wave.
    struct PendingBlast: Equatable, Sendable {
        var power: Power
        var origin: Position
        /// The color a Color Clear clears (`nil` picks the commonest).
        var kind: Int? = nil
        /// What a propeller carries to its target and sets off there.
        var carries: Power? = nil
        var isCombo = false
        /// A bigger area for combinations: the square's radius for a bomb, the band's half-width
        /// for a rocket.
        var radius = 0
    }

    /// A Classic round: a minute on a fresh board of six tokens.
    public init(seed: UInt64) {
        mode = .classic
        kinds = Self.classicKinds
        goals = []
        moveLimit = nil
        goldToDrop = 0
        clearedByKind = Array(repeating: 0, count: Self.classicKinds)
        rng = SeededGenerator(seed: seed)
        cells = Self.emptyBoard
        fill()
    }

    /// A level (or, with `mode`, the daily puzzle). The starting board comes from the level's own
    /// seed, so it's the same at every attempt; the tokens that drop in later come from `refillSeed`.
    public init(level: TokenSwapLevel, mode: Mode? = nil, refillSeed: UInt64) {
        self.mode = mode ?? .level(level.id)
        kinds = min(max(level.kinds, 3), Self.tokens.count)
        goals = level.goals
        moveLimit = max(1, level.moves)
        goldToDrop = max(0, level.goldToDrop)
        clearedByKind = Array(repeating: 0, count: Self.tokens.count)
        rng = SeededGenerator(seed: level.seed)
        cells = Self.board(from: level.layout)
        fill()
        rng = SeededGenerator(seed: refillSeed)
    }

    static var emptyBoard: [[Cell]] {
        Array(repeating: Array(repeating: Cell(), count: size), count: size)
    }

    // MARK: Reading the game

    public func cell(at position: Position) -> Cell { cells[position.row][position.column] }

    public var isClassic: Bool { mode == .classic }
    public var timeLeft: TimeInterval { isClassic ? max(0, Self.roundLength - time) : 0 }
    public var isTimeUp: Bool { isClassic && time >= Self.roundLength }
    public var movesLeft: Int? { moveLimit.map { max(0, $0 - moves) } }
    /// Tiles are clearing (and more may follow), so swaps wait.
    public var isResolving: Bool { chain > 0 }
    public var isOver: Bool { isClassic ? isTimeUp && !isResolving : phase != .playing }
    /// Specials that went off, all powers together.
    public var specialsSetOff: Int { setOff.values.reduce(0, +) }

    /// How far a goal has come (never past its target).
    public func progress(_ goal: Goal) -> Int {
        let done = switch goal {
        case .tokens(let kind, _): clearedByKind.indices.contains(kind) ? clearedByKind[kind] : 0
        case .ice: iceFreed
        case .chains: chainsBroken
        case .crates: cratesBroken
        case .gold: goldCollected
        case .specials(let kind, _): setOff.filter { kind.counts($0.key) }.values.reduce(0, +)
        case .score: score
        }
        return min(done, goal.target)
    }

    public var goalsMet: Bool { goals.allSatisfy { progress($0) >= $0.target } }

    public mutating func advance(by seconds: TimeInterval) {
        guard isClassic, seconds.isFinite, seconds > 0 else { return }
        time = min(Self.roundLength, time + seconds)
    }

    // MARK: Swapping

    /// Two neighbors that make a move: either is a special, or swapping them lines up a match.
    public func isValidSwap(_ a: Position, _ b: Position) -> Bool {
        guard a.isOnBoard, b.isOnBoard, a.isNeighbor(of: b) else { return false }
        let first = cell(at: a), second = cell(at: b)
        guard first.canSwap, second.canSwap else { return false }
        if first.tile?.isSpecial == true || second.tile?.isSpecial == true { return true }
        var copy = cells
        Self.exchange(&copy, a, b)
        return Self.hasMatch(in: copy, around: [a, b])
    }

    /// Makes a move: swaps two neighbors and starts a chain of clearing waves (see `resolveStep`).
    /// Returns false, changing nothing, for a swap that isn't a move, while tiles are clearing,
    /// once the clock or the moves have run out, or once a level is over.
    @discardableResult
    public mutating func swap(_ a: Position, _ b: Position) -> Bool {
        guard phase == .playing, !isTimeUp, movesLeft != 0, !isResolving, isValidSwap(a, b) else { return false }
        Self.exchange(&cells, a, b)
        moves += 1
        chain = 1
        lastSwap = [b, a]
        pendingBlasts = swapBlasts(moved: b, other: a)
        return true
    }

    /// What swapping sets off by itself: two specials combine at `moved` (where the dragged piece
    /// went); one special goes off where it now sits; a Color Clear takes the color it was
    /// swapped with.
    func swapBlasts(moved: Position, other: Position) -> [PendingBlast] {
        let here = cell(at: moved).tile, there = cell(at: other).tile
        switch (here?.power, there?.power) {
        case let (first?, second?):
            return comboBlasts(first, second, at: moved, from: other)
        case (.colorClear?, nil):
            return [PendingBlast(power: .colorClear, origin: moved, kind: there?.kind)]
        case (nil, .colorClear?):
            return [PendingBlast(power: .colorClear, origin: other, kind: here?.kind)]
        case let (power?, nil):
            return [PendingBlast(power: power, origin: moved)]
        case let (nil, power?):
            return [PendingBlast(power: power, origin: other)]
        case (nil, nil):
            return []
        }
    }

    /// Two specials swapped together, centered on `center`:
    /// - Rocket and Rocket: the whole row and column.
    /// - Rocket and Bomb: three rows and three columns.
    /// - Bomb and Bomb: the 7×7 square.
    /// - Propeller and Propeller: three propellers take off.
    /// - Propeller and Rocket or Bomb: the propeller carries the other to its target and sets it off there.
    /// - Color Clear and a special: every token of that special's color becomes one and goes off.
    /// - Color Clear and Color Clear: the whole board.
    func comboBlasts(_ first: Power, _ second: Power, at center: Position, from other: Position) -> [PendingBlast] {
        let pair = Set([first, second])
        let partnerKind = cell(at: first == .colorClear ? other : center).tile?.kind
        let colorPartner: Power? = first == .colorClear ? second : second == .colorClear ? first : nil
        if first == .colorClear && second == .colorClear {
            return [PendingBlast(power: .colorClear, origin: center, isCombo: true, radius: Self.size)]
        }
        if let partner = colorPartner {
            return [PendingBlast(power: .colorClear, origin: center, kind: partnerKind, carries: partner, isCombo: true)]
        }
        if pair.isSubset(of: [.rocketAcross, .rocketDown]) {
            return [PendingBlast(power: .rocketAcross, origin: center, isCombo: true),
                    PendingBlast(power: .rocketDown, origin: center, isCombo: true)]
        }
        if pair.contains(.bomb) && (pair.contains(.rocketAcross) || pair.contains(.rocketDown)) {
            return [PendingBlast(power: .rocketAcross, origin: center, isCombo: true, radius: 1),
                    PendingBlast(power: .rocketDown, origin: center, isCombo: true, radius: 1)]
        }
        if pair == [.bomb] {
            return [PendingBlast(power: .bomb, origin: center, isCombo: true, radius: 3)]
        }
        if pair == [.propeller] {
            return (0..<3).map { _ in PendingBlast(power: .propeller, origin: center, isCombo: true) }
        }
        // A propeller with a rocket or a bomb.
        let carried = first == .propeller ? second : first
        return [PendingBlast(power: .propeller, origin: center, carries: carried, isCombo: true)]
    }

    // MARK: Resolving

    /// Clears one wave: the specials a swap set off and every match on the board, with all the
    /// blasts they set off in turn; then the tiles fall, new ones drop in, and gold bars on the
    /// bottom row are collected. Returns `nil` once nothing is left to clear, which ends the chain
    /// (shuffling a board with no move left, and deciding a level).
    public mutating func resolveStep() -> Step? {
        guard chain > 0 else { return nil }
        let groups = Self.matchGroups(in: cells, swapped: lastSwap)
        guard !groups.isEmpty || !pendingBlasts.isEmpty else {
            finishChain()
            return nil
        }
        var wave = Wave()
        // Specials made this wave sit out its blasts.
        for group in groups {
            if let power = group.power, let spot = group.spot { wave.made[spot] = power }
        }
        wave.protected = Set(wave.made.keys)
        if !pendingBlasts.isEmpty {
            wave.queue = pendingBlasts
            pendingBlasts = []
            // The swapped specials go off through those blasts, not again when something reaches them.
            for position in lastSwap where cell(at: position).tile?.isSpecial == true && !wave.protected.contains(position) {
                wave.fired.insert(position)
                wave.cleared.insert(position)
            }
        }
        for group in groups {
            for position in group.cells.sorted() {
                let wasChained = cell(at: position).isChained
                if !wave.protected.contains(position) { strike(position, in: &wave) }
                // A match also knocks the obstacles beside it (once each per wave).
                if !wasChained {
                    for neighbor in position.neighbors { knock(neighbor, in: &wave) }
                }
            }
        }
        while !wave.queue.isEmpty {
            let blast = wave.queue.removeFirst()
            fire(blast, in: &wave)
        }
        // Score and count what this wave cleared.
        var tokens = 0
        for position in wave.cleared {
            guard let tile = cell(at: position).tile else { continue }
            if let kind = tile.kind {
                tokens += 1
                if clearedByKind.indices.contains(kind) { clearedByKind[kind] += 1 }
            } else if tile.power == .colorClear {
                tokens += 1
            }
        }
        var points = tokens * Self.pointsPerToken * chain + wave.broken * Self.obstaclePoints
        tokensCleared += tokens
        for position in wave.cleared { cells[position.row][position.column].tile = nil }
        for (spot, power) in wave.made {
            cells[spot.row][spot.column].tile?.power = power
            if power == .colorClear { cells[spot.row][spot.column].tile?.kind = nil }
        }
        specialsMade += wave.made.count
        for blast in wave.blasts { setOff[blast.power, default: 0] += 1 }
        let gold = settleAndCollect()
        points += gold.count * Self.goldPoints
        score += points
        bestChain = max(bestChain, chain)
        let step = Step(cleared: wave.cleared.sorted(), points: points, chain: chain, blastList: wave.blasts,
                        made: wave.made, obstacles: wave.hits, goldCollected: gold)
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

    /// Everything one wave reaches.
    struct Wave {
        var cleared: Set<Position> = []
        /// Obstacles already hit this wave.
        var hitCells: Set<Position> = []
        var hits: [ObstacleHit] = []
        /// Obstacles broken for good this wave.
        var broken = 0
        var queue: [PendingBlast] = []
        /// Specials already gone off this wave.
        var fired: Set<Position> = []
        var blasts: [Blast] = []
        var made: [Position: Power] = [:]
        var protected: Set<Position> = []
        /// Cells propellers are already heading for.
        var targeted: Set<Position> = []
    }

    /// A match or a blast reaches `position`: an obstacle there loses a layer; otherwise its
    /// tile clears, and a special there goes off. Gold bars can't be cleared.
    private mutating func strike(_ position: Position, in wave: inout Wave) {
        guard position.isOnBoard, !wave.protected.contains(position), !wave.cleared.contains(position) else { return }
        let here = cell(at: position)
        if here.hasObstacle {
            hitObstacle(position, in: &wave)
            return
        }
        guard let tile = here.tile, !tile.isGold else { return }
        wave.cleared.insert(position)
        if let power = tile.power, wave.fired.insert(position).inserted {
            wave.queue.append(PendingBlast(power: power, origin: position))
        }
    }

    /// A match beside `position` cracks ice and crates there (chains need a match or a blast).
    private mutating func knock(_ position: Position, in wave: inout Wave) {
        let here = cell(at: position)
        guard here.crate > 0 || here.ice > 0 else { return }
        hitObstacle(position, in: &wave)
    }

    private mutating func hitObstacle(_ position: Position, in wave: inout Wave) {
        guard wave.hitCells.insert(position).inserted else { return }
        let row = position.row, column = position.column
        if cells[row][column].crate > 0 {
            cells[row][column].crate -= 1
            let left = cells[row][column].crate
            wave.hits.append(ObstacleHit(position: position, kind: .crate, layersLeft: left))
            if left == 0 {
                cratesBroken += 1
                wave.broken += 1
            }
        } else if cells[row][column].ice > 0 {
            cells[row][column].ice -= 1
            let left = cells[row][column].ice
            wave.hits.append(ObstacleHit(position: position, kind: .ice, layersLeft: left))
            if left == 0 {
                iceFreed += 1
                wave.broken += 1
            }
        } else if cells[row][column].isChained {
            cells[row][column].isChained = false
            wave.hits.append(ObstacleHit(position: position, kind: .chain, layersLeft: 0))
            chainsBroken += 1
            wave.broken += 1
        }
    }

    /// Sets off one special: clears what it reaches, recording the blast.
    private mutating func fire(_ blast: PendingBlast, in wave: inout Wave) {
        let origin = blast.origin
        // The special's own cell clears (when swapped, it hasn't been struck yet).
        if !wave.cleared.contains(origin), !wave.protected.contains(origin), cell(at: origin).tile?.isSpecial == true {
            wave.cleared.insert(origin)
            wave.fired.insert(origin)
        }
        var reach: [Position] = []
        var target: Position?
        switch blast.power {
        case .rocketAcross:
            for row in (origin.row - blast.radius)...(origin.row + blast.radius) where (0..<Self.size).contains(row) {
                reach += (0..<Self.size).map { Position(row: row, column: $0) }
            }
        case .rocketDown:
            for column in (origin.column - blast.radius)...(origin.column + blast.radius) where (0..<Self.size).contains(column) {
                reach += (0..<Self.size).map { Position(row: $0, column: column) }
            }
        case .bomb:
            let radius = max(2, blast.radius)
            reach = Self.square(around: origin, radius: radius)
        case .propeller:
            reach = origin.neighbors
            for position in reach { strike(position, in: &wave) }
            target = propellerTarget(from: origin, wave: wave)
            if let target {
                wave.targeted.insert(target)
                if let carried = blast.carries {
                    wave.blasts.append(Blast(power: .propeller, origin: origin, target: target, reach: reach, isCombo: true))
                    fire(PendingBlast(power: carried, origin: target, isCombo: true), in: &wave)
                    return
                }
                reach.append(target)
            }
        case .colorClear:
            if blast.radius >= Self.size {
                reach = Self.allPositions
            } else {
                let kind = blast.kind ?? commonestKind(excluding: wave.cleared)
                if let kind {
                    reach = Self.allPositions.filter { cell(at: $0).tile?.kind == kind && $0 != origin }
                    if let carried = blast.carries {
                        // Every token of that color turns into the other special and goes off.
                        wave.blasts.append(Blast(power: .colorClear, origin: origin, target: nil, reach: reach, isCombo: true))
                        for (index, position) in reach.enumerated() where !wave.protected.contains(position) {
                            let power: Power = carried.isRocket ? (index % 2 == 0 ? .rocketAcross : .rocketDown) : carried
                            if cell(at: position).hasObstacle {
                                strike(position, in: &wave)
                                continue
                            }
                            guard cell(at: position).tile != nil, wave.fired.insert(position).inserted else { continue }
                            wave.cleared.insert(position)
                            wave.queue.append(PendingBlast(power: power, origin: position, isCombo: true))
                        }
                        return
                    }
                }
            }
        }
        wave.blasts.append(Blast(power: blast.power, origin: origin, target: target, reach: reach, isCombo: blast.isCombo))
        // The origin too: a blast carried somewhere (or a Color Clear's partner) clears where it lands.
        for position in reach { strike(position, in: &wave) }
        strike(origin, in: &wave)
    }

    /// Where a propeller flies: an obstacle a goal needs, then a token a goal needs (or the cell
    /// under a gold bar), then any obstacle or special, then any token. Ties go to a random pick.
    func propellerTarget(from origin: Position, wave: Wave) -> Position? {
        var best: [Position] = []
        var bestValue = -1
        let wantsIce = wants(.ice), wantsChains = wants(.chain), wantsCrates = wants(.crate)
        let wantedKinds = Set(goals.compactMap { goal -> Int? in
            if case .tokens(let kind, let count) = goal, progress(goal) < count { return kind }
            return nil
        })
        let underGold = Set(Self.allPositions.filter { cell(at: $0).tile?.isGold == true }.map { $0.moved(dRow: 1, dColumn: 0) })
        for position in Self.allPositions {
            guard position != origin, !wave.cleared.contains(position), !wave.protected.contains(position),
                  !wave.targeted.contains(position), !wave.hitCells.contains(position) else { continue }
            let here = cell(at: position)
            var value: Int
            if (here.crate > 0 && wantsCrates) || (here.ice > 0 && wantsIce) || (here.isChained && wantsChains) {
                value = 4
            } else if let kind = here.matchKind, wantedKinds.contains(kind) || underGold.contains(position) {
                value = 3
            } else if here.hasObstacle || here.tile?.isSpecial == true {
                value = 2
            } else if here.tile != nil && here.tile?.isGold != true {
                value = 1
            } else {
                continue
            }
            if underGold.contains(position) && here.tile != nil { value = max(value, 3) }
            if value > bestValue {
                bestValue = value
                best = [position]
            } else if value == bestValue {
                best.append(position)
            }
        }
        guard !best.isEmpty else { return nil }
        var generator = rng
        let pick = best[Int.random(in: 0..<best.count, using: &generator)]
        return pick
    }

    /// A goal still needs this kind of obstacle broken.
    private func wants(_ kind: ObstacleHit.Kind) -> Bool {
        goals.contains { goal in
            switch (goal, kind) {
            case (.ice, .ice), (.chains, .chain), (.crates, .crate): progress(goal) < goal.target
            default: false
            }
        }
    }

    /// The color with the most tokens that can match, for a Color Clear set off by a blast.
    func commonestKind(excluding cleared: Set<Position>) -> Int? {
        var counts: [Int: Int] = [:]
        for position in Self.allPositions where !cleared.contains(position) {
            if let kind = cell(at: position).matchKind, cell(at: position).tile?.power == nil { counts[kind, default: 0] += 1 }
        }
        return counts.max { ($0.value, -$0.key) < ($1.value, -$1.key) }?.key
    }

    /// Ends a chain: shuffles a stuck board and decides a finished level.
    private mutating func finishChain() {
        chain = 0
        lastSwap = []
        if !isClassic {
            if goalsMet {
                phase = .won
                bonusPoints = (movesLeft ?? 0) * Self.pointsPerMoveLeft
                score += bonusPoints
                return
            }
            if movesLeft == 0 {
                phase = .lost
                return
            }
        }
        if !hasMove { shuffle() }
    }

    // MARK: Matching

    /// A connected set of matched tokens of one color, and the special it makes.
    struct MatchGroup: Equatable {
        var cells: Set<Position>
        var kind: Int
        var power: Power?
        var spot: Position?
    }

    struct Run: Equatable {
        let cells: [Position]
        let isAcross: Bool
    }

    /// Runs of three or more of a color, across then down.
    static func runs(in cells: [[Cell]]) -> [Run] {
        var runs: [Run] = []
        for row in 0..<size {
            var start = 0
            for column in 1...size {
                let kind = cells[row][start].matchKind
                if column == size || cells[row][column].matchKind != kind || kind == nil {
                    if kind != nil && column - start >= 3 {
                        runs.append(Run(cells: (start..<column).map { Position(row: row, column: $0) }, isAcross: true))
                    }
                    start = column
                }
            }
        }
        for column in 0..<size {
            var start = 0
            for row in 1...size {
                let kind = cells[start][column].matchKind
                if row == size || cells[row][column].matchKind != kind || kind == nil {
                    if kind != nil && row - start >= 3 {
                        runs.append(Run(cells: (start..<row).map { Position(row: $0, column: column) }, isAcross: false))
                    }
                    start = row
                }
            }
        }
        return runs
    }

    /// 2×2 squares of one color, by top-left corner.
    static func squares(in cells: [[Cell]]) -> [[Position]] {
        var squares: [[Position]] = []
        for row in 0..<(size - 1) {
            for column in 0..<(size - 1) {
                guard let kind = cells[row][column].matchKind,
                      cells[row][column + 1].matchKind == kind,
                      cells[row + 1][column].matchKind == kind,
                      cells[row + 1][column + 1].matchKind == kind else { continue }
                squares.append([Position(row: row, column: column), Position(row: row, column: column + 1),
                                Position(row: row + 1, column: column), Position(row: row + 1, column: column + 1)])
            }
        }
        return squares
    }

    /// Whether a run or square shows anywhere touching `cells` (or anywhere, when empty).
    static func hasMatch(in board: [[Cell]], around positions: [Position] = []) -> Bool {
        let found = runs(in: board).map(\.cells) + squares(in: board)
        guard !positions.isEmpty else { return !found.isEmpty }
        return found.contains { shape in shape.contains(where: positions.contains) }
    }

    /// Every match on the board, joined into groups (a run and a square or two runs that share a
    /// token are one group), each with the special it makes and where. Five in a row beats an L or
    /// T, which beats four in a row, which beats a square. The special appears where the player
    /// moved when the group includes that cell; otherwise at the crossing of an L or T, the middle
    /// of a run, or a square's lower-left token.
    static func matchGroups(in board: [[Cell]], swapped: [Position]) -> [MatchGroup] {
        let runs = runs(in: board)
        let squares = squares(in: board)
        guard !runs.isEmpty || !squares.isEmpty else { return [] }
        // Join shapes that share a cell.
        var parent: [Position: Position] = [:]
        func find(_ position: Position) -> Position {
            var root = position
            while let next = parent[root], next != root { root = next }
            var walk = position
            while let next = parent[walk], next != root {
                parent[walk] = root
                walk = next
            }
            return root
        }
        func union(_ a: Position, _ b: Position) {
            let rootA = find(a), rootB = find(b)
            if rootA != rootB { parent[max(rootA, rootB)] = min(rootA, rootB) }
        }
        let shapes = runs.map(\.cells) + squares
        for shape in shapes {
            for position in shape where parent[position] == nil { parent[position] = position }
            for position in shape.dropFirst() { union(shape[0], position) }
        }
        var members: [Position: Set<Position>] = [:]
        for position in parent.keys { members[find(position), default: []].insert(position) }
        var groups: [MatchGroup] = []
        for (root, groupCells) in members.sorted(by: { $0.key < $1.key }) {
            guard let kind = board[root.row][root.column].matchKind else { continue }
            let groupRuns = runs.filter { groupCells.contains($0.cells[0]) }
            let groupSquares = squares.filter { groupCells.contains($0[0]) }
            var power: Power?
            var natural: Position?
            let longest = groupRuns.max { $0.cells.count < $1.cells.count }
            var crossing: Position?
            search: for across in groupRuns where across.isAcross {
                for down in groupRuns where !down.isAcross {
                    if let shared = Set(across.cells).intersection(down.cells).min() {
                        crossing = shared
                        break search
                    }
                }
            }
            if let longest, longest.cells.count >= 5 {
                power = .colorClear
                natural = longest.cells[longest.cells.count / 2]
            } else if let crossing {
                power = .bomb
                natural = crossing
            } else if let longest, longest.cells.count == 4 {
                power = longest.isAcross ? .rocketAcross : .rocketDown
                natural = longest.cells[2]
            } else if let square = groupSquares.first {
                power = .propeller
                natural = square[2]
            }
            var spot: Position?
            if power != nil {
                // Where the player moved, if the group includes it; a token that can take a power.
                let eligible = groupCells.filter { position in
                    let here = board[position.row][position.column]
                    return !here.isChained && here.tile?.power == nil
                }
                spot = swapped.first(where: eligible.contains)
                    ?? natural.flatMap { eligible.contains($0) ? $0 : nil }
                    ?? eligible.min()
                if spot == nil { power = nil }
            }
            groups.append(MatchGroup(cells: groupCells, kind: kind, power: power, spot: spot))
        }
        return groups
    }

    // MARK: Falling

    /// Tiles fall into the gaps (each column splits where crates and frozen or chained tiles hold
    /// still), new tiles drop into the top of each stretch, and gold bars on the bottom row are
    /// collected, until none is left there. Returns the columns gold was collected from.
    mutating func settleAndCollect() -> [Int] {
        var collected: [Int] = []
        while true {
            settle()
            let bottom = Self.size - 1
            let goldColumns = (0..<Self.size).filter { cells[bottom][$0].tile?.isGold == true && !cells[bottom][$0].isFixed }
            guard !goldColumns.isEmpty else { return collected }
            for column in goldColumns {
                cells[bottom][column].tile = nil
                goldCollected += 1
                collected.append(column)
            }
        }
    }

    mutating func settle() {
        var goldOnBoard = cells.joined().filter { $0.tile?.isGold == true }.count
        for column in 0..<Self.size {
            var row = Self.size - 1
            while row >= 0 {
                if cells[row][column].isFixed {
                    row -= 1
                    continue
                }
                var top = row
                while top > 0 && !cells[top - 1][column].isFixed { top -= 1 }
                var tiles: [Tile] = [] // Bottom up.
                for index in stride(from: row, through: top, by: -1) {
                    if let tile = cells[index][column].tile { tiles.append(tile) }
                }
                while tiles.count < row - top + 1 {
                    if top == 0 && goldToDrop > 0 && goldOnBoard < Self.goldOnBoardLimit {
                        goldToDrop -= 1
                        goldOnBoard += 1
                        tiles.append(newGold())
                    } else {
                        tiles.append(newTile(kind: Int.random(in: 0..<kinds, using: &rng)))
                    }
                }
                for (offset, index) in stride(from: row, through: top, by: -1).enumerated() {
                    cells[index][column].tile = tiles[offset]
                }
                row = top - 1
            }
        }
    }

    // MARK: Moves

    /// Some swap is a move.
    public var hasMove: Bool { !validSwaps.isEmpty }

    /// Every swap that is a move, each listed once.
    public var validSwaps: [(Position, Position)] {
        var swaps: [(Position, Position)] = []
        for position in Self.allPositions {
            for next in [position.moved(dRow: 0, dColumn: 1), position.moved(dRow: 1, dColumn: 0)] where isValidSwap(position, next) {
                swaps.append((position, next))
            }
        }
        return swaps
    }

    /// A good move to point out: combining specials first, then setting one off, then the swap
    /// whose matches make the best special and clear the most (and help the goals most).
    public var hint: (Position, Position)? {
        var best: (swap: (Position, Position), value: Int)?
        for (a, b) in validSwaps {
            let value = moveValue(a, b)
            if value > best?.value ?? .min { best = ((a, b), value) }
        }
        return best?.swap
    }

    /// How good a move looks, judged from the board alone.
    func moveValue(_ a: Position, _ b: Position) -> Int {
        let first = cell(at: a).tile, second = cell(at: b).tile
        if let one = first?.power, let two = second?.power { return 200 + one.value + two.value }
        if let power = first?.power ?? second?.power { return 100 + power.value }
        var copy = cells
        Self.exchange(&copy, a, b)
        let wanted = Set(goals.compactMap { goal -> Int? in
            if case .tokens(let kind, let count) = goal, progress(goal) < count { return kind }
            return nil
        })
        // The lowest gold bar in each column: clearing under it brings it down.
        var goldRow: [Int: Int] = [:]
        for position in Self.allPositions where copy[position.row][position.column].tile?.isGold == true {
            goldRow[position.column] = max(goldRow[position.column] ?? -1, position.row)
        }
        var value = 0
        for group in Self.matchGroups(in: copy, swapped: [a, b]) where group.cells.contains(a) || group.cells.contains(b) {
            value += group.cells.count + (group.power?.value ?? 0)
            if wanted.contains(group.kind) { value += group.cells.count * 2 }
            for position in group.cells {
                if let row = goldRow[position.column], row < position.row { value += 4 }
                for neighbor in position.neighbors where copy[neighbor.row][neighbor.column].crate > 0 || copy[neighbor.row][neighbor.column].ice > 0 {
                    value += 3
                }
                if copy[position.row][position.column].isChained { value += 3 }
            }
        }
        return value
    }

    // MARK: Board

    /// Every cell, row by row.
    public static let allPositions: [Position] = (0..<size).flatMap { row in (0..<size).map { Position(row: row, column: $0) } }

    static func square(around center: Position, radius: Int) -> [Position] {
        var cells: [Position] = []
        for row in (center.row - radius)...(center.row + radius) {
            for column in (center.column - radius)...(center.column + radius) {
                let position = Position(row: row, column: column)
                if position.isOnBoard { cells.append(position) }
            }
        }
        return cells
    }

    static func exchange(_ board: inout [[Cell]], _ a: Position, _ b: Position) {
        let tile = board[a.row][a.column].tile
        board[a.row][a.column].tile = board[b.row][b.column].tile
        board[b.row][b.column].tile = tile
    }

    mutating func newTile(kind: Int?, power: Power? = nil) -> Tile {
        nextID += 1
        return Tile(id: nextID, kind: kind, power: power)
    }

    mutating func newGold() -> Tile {
        nextID += 1
        return Tile(id: nextID, kind: nil, power: nil, isGold: true)
    }

    /// The obstacles and gold bars a level's layout lays out, rows from the top:
    /// `.` a token, `i` a frozen token (`I` with two layers of ice), `c` a chained token,
    /// `x` a crate (`X` two layers, `#` three), `g` a gold bar, and `<` `^` `*` `%` `@` a token
    /// already holding a Rocket across, a Rocket down, a Bomb, a Propeller or a Color Clear.
    static func board(from layout: [String]) -> [[Cell]] {
        var board = emptyBoard
        for (row, line) in layout.prefix(size).enumerated() {
            for (column, mark) in line.prefix(size).enumerated() {
                var cell = Cell()
                switch mark {
                case "i": cell.ice = 1
                case "I": cell.ice = 2
                case "c": cell.isChained = true
                case "x": cell.crate = 1
                case "X": cell.crate = 2
                case "#": cell.crate = 3
                case "g": cell.tile = Tile(id: -1, kind: nil, isGold: true)
                case "<": cell.tile = Tile(id: -1, kind: nil, power: .rocketAcross)
                case "^": cell.tile = Tile(id: -1, kind: nil, power: .rocketDown)
                case "*": cell.tile = Tile(id: -1, kind: nil, power: .bomb)
                case "%": cell.tile = Tile(id: -1, kind: nil, power: .propeller)
                case "@": cell.tile = Tile(id: -1, kind: nil, power: .colorClear)
                default: break
                }
                board[row][column] = cell
            }
        }
        return board
    }

    /// Deals tokens into every cell that needs one, with no match showing and a move to make.
    /// Obstacles, gold bars and specials from the layout stay where they are.
    mutating func fill() {
        let template = cells
        var attempts = 0
        repeat {
            attempts += 1
            cells = template
            for position in Self.allPositions {
                let here = template[position.row][position.column]
                guard here.crate == 0 else { continue }
                if let tile = here.tile {
                    nextID += 1
                    var placed = Tile(id: nextID, kind: tile.kind, power: tile.power, isGold: tile.isGold)
                    if !tile.isGold && tile.power != .colorClear && tile.kind == nil {
                        placed.kind = freshKind(at: position)
                    }
                    cells[position.row][position.column].tile = placed
                } else {
                    cells[position.row][position.column].tile = newTile(kind: freshKind(at: position))
                }
            }
        } while (Self.hasMatch(in: cells) || !hasMove) && attempts < 500
    }

    /// A random color that doesn't complete a run or a square with the tokens already dealt
    /// above and to the left.
    private mutating func freshKind(at position: Position) -> Int {
        var kind = 0
        for _ in 0..<60 {
            kind = Int.random(in: 0..<kinds, using: &rng)
            if !completesMatch(kind, at: position) { break }
        }
        return kind
    }

    /// `kind` here would finish three in a row with the two tokens to its left or above, or a
    /// square with the three up and to the left.
    func completesMatch(_ kind: Int, at position: Position) -> Bool {
        let row = position.row, column = position.column
        func kindAt(_ r: Int, _ c: Int) -> Int? {
            guard r >= 0, c >= 0 else { return nil }
            return cells[r][c].tile?.kind
        }
        if kindAt(row, column - 1) == kind && kindAt(row, column - 2) == kind { return true }
        if kindAt(row - 1, column) == kind && kindAt(row - 2, column) == kind { return true }
        if kindAt(row - 1, column) == kind && kindAt(row, column - 1) == kind && kindAt(row - 1, column - 1) == kind { return true }
        return false
    }

    /// Mixes up the tiles that can move until no match shows and a move is possible.
    mutating func shuffle() {
        shuffles += 1
        let movable = Self.allPositions.filter { cell(at: $0).canSwap }
        var tiles = movable.compactMap { cell(at: $0).tile }
        for _ in 0..<200 {
            tiles.shuffle(using: &rng)
            for (position, tile) in zip(movable, tiles) { cells[position.row][position.column].tile = tile }
            if !Self.hasMatch(in: cells) && hasMove { return }
        }
        // Practically never: new colors for the plain tokens that can move.
        for _ in 0..<200 {
            for position in movable where cell(at: position).tile?.power == nil && cell(at: position).tile?.isGold != true {
                cells[position.row][position.column].tile = newTile(kind: Int.random(in: 0..<kinds, using: &rng))
            }
            if !Self.hasMatch(in: cells) && hasMove { return }
        }
    }

    // MARK: Testing

    #if DEBUG
    /// Sets every tile from kinds, row by row, clearing obstacles (tests only). -1 places a gold bar.
    mutating func place(_ kinds: [[Int]], powers: [Position: Power] = [:]) {
        cells = Self.emptyBoard
        for (row, line) in kinds.enumerated() {
            for (column, kind) in line.enumerated() {
                let position = Position(row: row, column: column)
                if kind < 0 {
                    cells[row][column].tile = newGold()
                } else {
                    let power = powers[position]
                    cells[row][column].tile = newTile(kind: power == .colorClear ? nil : kind, power: power)
                }
            }
        }
    }

    /// Puts an obstacle on a cell (tests only).
    mutating func setObstacle(at position: Position, ice: Int = 0, chained: Bool = false, crate: Int = 0) {
        cells[position.row][position.column].ice = ice
        cells[position.row][position.column].isChained = chained
        cells[position.row][position.column].crate = crate
        if crate > 0 { cells[position.row][position.column].tile = nil }
    }

    /// Sets the moves already made (tests only).
    mutating func setMoves(_ moves: Int) {
        self.moves = moves
    }
    #endif
}
