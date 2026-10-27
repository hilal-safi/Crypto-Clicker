import Foundation

/// Pump and Dump: whack-a-mole with coins. Coins pop up in a 3×3 grid of holes; tap them before
/// they drop back down. Scam tokens cost points, and rug pulls show up looking like coins, then
/// shake and turn into scams. A rare golden coin is worth five coins. Hits in a row build a combo
/// that multiplies points (up to ×3); a scam, a missed tap or a coin that gets away ends it.
/// A round lasts 30 seconds and speeds up as it goes.
///
/// Time only moves through `advance(by:)`, in fixed steps from one appearance to the next, so a
/// round plays out the same way at any frame rate (and in tests).
public struct PumpDumpGame: Sendable {
    public enum Kind: Equatable, Sendable {
        case coin, golden, scam
        /// Looks like a coin until `turnsAt`, then it's a scam.
        case rug
    }

    public struct Target: Equatable, Sendable, Identifiable {
        public let id: Int
        public let hole: Int
        public let kind: Kind
        public let appearedAt: TimeInterval
        public let leavesAt: TimeInterval
        /// When a rug pull turns into a scam; `nil` for every other kind.
        public let turnsAt: TimeInterval?

        public func isScam(at time: TimeInterval) -> Bool {
            kind == .scam || (turnsAt.map { time >= $0 } ?? false)
        }

        /// A rug pull about to turn: the screen shakes it as a warning.
        public func isWarning(at time: TimeInterval) -> Bool {
            guard let turnsAt else { return false }
            return time >= turnsAt - PumpDumpGame.warningTime && time < turnsAt
        }
    }

    /// What a tap did.
    public enum Hit: Equatable, Sendable {
        case coin(points: Int)
        case golden(points: Int)
        case scam(penalty: Int)
        /// Nothing there: the combo ends.
        case miss
    }

    public static let holes = 9
    public static let roundLength: TimeInterval = 30
    public static let coinPoints = 10
    public static let goldenPoints = 50
    public static let scamPenalty = 30
    /// How long a rug pull shakes before it turns.
    public static let warningTime: TimeInterval = 0.35
    /// Each hit in a row adds this to the points multiplier...
    public static let comboStep = 0.1
    /// ...up to this.
    public static let maxComboMultiplier = 3.0

    public private(set) var time: TimeInterval = 0
    public private(set) var targets: [Target] = []
    public private(set) var score = 0
    /// Coins, golden coins and rug pulls tapped before they turned.
    public private(set) var coinsHit = 0
    public private(set) var goldenHit = 0
    public private(set) var scamsHit = 0
    /// Coins that dropped back down untapped.
    public private(set) var escaped = 0
    public private(set) var combo = 0
    public private(set) var bestCombo = 0
    public private(set) var isOver = false
    /// Changes on every tap, for effects.
    public private(set) var taps = 0
    private var nextAppearance: TimeInterval = 0.4
    private var nextID = 0

    public init() {}

    public var timeLeft: TimeInterval { max(0, Self.roundLength - time) }

    /// The points multiplier for the next hit.
    public var comboMultiplier: Double { Self.comboMultiplier(hitsInARow: combo) }

    public static func comboMultiplier(hitsInARow combo: Int) -> Double {
        min(1 + Double(max(0, combo)) * comboStep, maxComboMultiplier)
    }

    public func target(inHole hole: Int) -> Target? {
        targets.first { $0.hole == hole }
    }

    /// How far through the round, from 0 to 1. Everything speeds up as it goes.
    var progress: Double { min(1, time / Self.roundLength) }
    var appearanceInterval: TimeInterval { 0.72 - 0.32 * progress }
    var stayTime: TimeInterval { 1.5 - 0.6 * progress }
    var maxTargets: Int { progress < 0.5 ? 3 : 4 }

    // MARK: Play

    /// Moves the round on by `seconds`: targets leave when their time is up and new ones appear.
    public mutating func advance<R: RandomNumberGenerator>(by seconds: TimeInterval, using rng: inout R) {
        guard !isOver, seconds.isFinite, seconds > 0 else { return }
        let end = min(time + seconds, Self.roundLength)
        while nextAppearance <= end {
            time = nextAppearance
            removeDeparted()
            appear(using: &rng)
            nextAppearance = time + appearanceInterval
        }
        time = end
        removeDeparted()
        if time >= Self.roundLength {
            isOver = true
            targets = []
        }
    }

    /// Taps a hole: a coin scores, a scam costs points, and an empty hole ends the combo.
    @discardableResult
    public mutating func tap(hole: Int) -> Hit {
        guard !isOver else { return .miss }
        taps += 1
        guard let index = targets.firstIndex(where: { $0.hole == hole }) else {
            combo = 0
            return .miss
        }
        let target = targets.remove(at: index)
        if target.isScam(at: time) {
            score = max(0, score - Self.scamPenalty)
            scamsHit += 1
            combo = 0
            return .scam(penalty: Self.scamPenalty)
        }
        let base = target.kind == .golden ? Self.goldenPoints : Self.coinPoints
        let points = Int((Double(base) * comboMultiplier).rounded())
        combo += 1
        bestCombo = max(bestCombo, combo)
        score += points
        coinsHit += 1
        if target.kind == .golden {
            goldenHit += 1
            return .golden(points: points)
        }
        return .coin(points: points)
    }

    // MARK: Helpers

    private mutating func removeDeparted() {
        var kept: [Target] = []
        for target in targets {
            guard target.leavesAt <= time else {
                kept.append(target)
                continue
            }
            // A coin that gets away ends the combo; a scam (or a turned rug pull) leaving is good news.
            if !target.isScam(at: target.leavesAt) {
                escaped += 1
                combo = 0
            }
        }
        targets = kept
    }

    private mutating func appear<R: RandomNumberGenerator>(using rng: inout R) {
        guard targets.count < maxTargets else { return }
        let taken = Set(targets.map(\.hole))
        let free = (0..<Self.holes).filter { !taken.contains($0) }
        guard let hole = free.randomElement(using: &rng) else { return }
        let roll = Double.random(in: 0..<1, using: &rng)
        // Rug pulls start a few seconds in, once the player has the hang of it.
        let kind: Kind = switch roll {
        case ..<0.06: .golden
        case ..<0.28: .scam
        case ..<0.40 where time >= 4: .rug
        default: .coin
        }
        let stay = stayTime * (kind == .golden ? 0.7 : kind == .rug ? 1.3 : 1)
        let turnsAt: TimeInterval? = kind == .rug ? time + stay * 0.45 : nil
        targets.append(Target(id: nextID, hole: hole, kind: kind, appearedAt: time, leavesAt: time + stay, turnsAt: turnsAt))
        nextID += 1
    }

    #if DEBUG
    /// Puts a target in a hole, for tests.
    mutating func place(_ kind: Kind, inHole hole: Int, stay: TimeInterval = 1, turnsAfter: TimeInterval? = nil) {
        targets.removeAll { $0.hole == hole }
        targets.append(Target(id: nextID, hole: hole, kind: kind, appearedAt: time, leavesAt: time + stay,
                              turnsAt: turnsAfter.map { time + $0 }))
        nextID += 1
    }
    #endif
}
