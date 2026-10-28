import Foundation

/// Pump and Dump: whack-a-mole with coins. Coins pop up in a 3×3 grid of holes; tap them before
/// they drop back down. Scam tokens cost points, and rug pulls (coins with a red rim) shake and
/// then turn into scams: tap one quickly and it pays like a coin. A rare golden coin is worth
/// five coins. Hits in a row build a combo that multiplies points (up to ×3); a scam, a tap on an
/// empty hole or a coin that gets away ends it.
///
/// A run is a series of 30-second rounds. Each round has a score goal: reach it to go on to the
/// next round, which is quicker and has more scams; fall short and the run ends. Each round also
/// sets a bonus objective (build a combo, catch golden coins or make no mistakes) worth extra
/// points, which count toward the goal. Targets never come faster than a finger can fairly keep up
/// with, and a coin can still be tapped for a moment as it drops back down.
///
/// Time only moves through `advance(by:)`, in fixed steps from one appearance to the next, so a
/// round plays out the same way at any frame rate (and in tests).
public struct PumpDumpGame: Sendable {
    public enum Kind: Equatable, Sendable {
        case coin, golden, scam
        /// Looks like a coin (with a red rim) until `turnsAt`, then it's a scam.
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

    public enum Phase: Equatable, Sendable {
        case playing
        /// The round ended with its goal reached; `startNextRound()` carries on.
        case roundCleared
        /// The round ended short of its goal.
        case over
    }

    /// A round's bonus objective.
    public enum Objective: Equatable, Sendable {
        /// Tap this many golden coins.
        case goldenCoins(Int)
        /// Reach a combo of this many hits in a row.
        case combo(Int)
        /// Get through the round without tapping a scam or an empty hole.
        case noMistakes

        public var description: String {
            switch self {
            case .goldenCoins(let count): "Catch \(count) golden coin\(count == 1 ? "" : "s")"
            case .combo(let hits): "Reach a combo of \(hits)"
            case .noMistakes: "No mistakes: no scams, no empty taps"
            }
        }
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
    /// The shortest a target ever stays up, and the shortest gap between appearances, however far
    /// the run goes, so a finger can always keep up.
    public static let minimumStay: TimeInterval = 0.7
    public static let minimumGap: TimeInterval = 0.3
    /// A coin sinks back down for this long after its time is up, and can still be tapped, so a
    /// finger that lands just as it goes isn't punished.
    public static let sinkTime: TimeInterval = 0.12

    // MARK: State

    public private(set) var phase = Phase.playing
    public private(set) var round = 1
    /// Time into the current round.
    public private(set) var time: TimeInterval = 0
    public private(set) var targets: [Target] = []
    /// Points over the whole run.
    public private(set) var score = 0
    /// Points this round, toward its goal.
    public private(set) var roundScore = 0
    public private(set) var objective: Objective
    /// Bonus points the objective paid at the end of the last round (0 if it was missed).
    public private(set) var lastBonus = 0
    public private(set) var objectivesMet = 0
    /// Coins, golden coins and rug pulls tapped before they turned, over the run.
    public private(set) var coinsHit = 0
    public private(set) var goldenHit = 0
    public private(set) var scamsHit = 0
    /// Taps on empty holes.
    public private(set) var misses = 0
    /// Coins that dropped back down untapped.
    public private(set) var escaped = 0
    public private(set) var combo = 0
    public private(set) var bestCombo = 0
    /// Counts every combo of three or more that ended, and holds the length of the last one, for
    /// the "combo lost" message.
    public private(set) var comboBreaks = 0
    public private(set) var lastLostCombo = 0
    /// Holes whose coins got away during the last `advance(by:)`, for the "missed" marks.
    public private(set) var escapedHoles: [Int] = []
    /// Changes on every tap, for effects.
    public private(set) var taps = 0
    private var roundGolden = 0
    private var roundMistakes = 0
    private var roundBestCombo = 0
    private var nextAppearance: TimeInterval = 0.4
    private var nextID = 0

    public init() {
        objective = Self.objective(for: 1)
    }

    public var isOver: Bool { phase == .over }
    public var timeLeft: TimeInterval { max(0, Self.roundLength - time) }
    /// Points needed this round.
    public var goal: Int { Self.goal(round: round) }

    /// The score goal for a round: 300 in the first, rising faster than a player's score does, so
    /// every run ends somewhere (most players get three to six rounds in).
    public static func goal(round: Int) -> Int {
        let after = max(1, round) - 1
        return 300 + 150 * after + 25 * after * after
    }

    /// Bonus points for meeting a round's objective.
    public static func objectiveBonus(round: Int) -> Int { 50 * max(1, round) }

    /// The objectives take turns: a combo, golden coins, then no mistakes, each a little harder
    /// every time it comes round.
    public static func objective(for round: Int) -> Objective {
        let lap = (max(1, round) - 1) / 3
        switch (max(1, round) - 1) % 3 {
        case 0: return .combo(10 + 5 * lap)
        case 1: return .goldenCoins(2 + lap)
        default: return .noMistakes
        }
    }

    /// How far the current objective has come, and its target (no mistakes counts down from one).
    public var objectiveProgress: (current: Int, target: Int) {
        switch objective {
        case .goldenCoins(let count): (min(roundGolden, count), count)
        case .combo(let hits): (min(roundBestCombo, hits), hits)
        case .noMistakes: (roundMistakes == 0 ? 1 : 0, 1)
        }
    }

    public var isObjectiveMet: Bool {
        switch objective {
        case .goldenCoins(let count): roundGolden >= count
        case .combo(let hits): roundBestCombo >= hits
        case .noMistakes: roundMistakes == 0
        }
    }

    /// The objective can no longer be met this round (a mistake was made on a no-mistakes round).
    public var isObjectiveFailed: Bool {
        if case .noMistakes = objective { return roundMistakes > 0 }
        return false
    }

    /// Taps that hit something worth points, out of all taps.
    public var accuracy: Double {
        let total = coinsHit + scamsHit + misses
        return total > 0 ? Double(coinsHit) / Double(total) : 0
    }

    /// The points multiplier for the next hit.
    public var comboMultiplier: Double { Self.comboMultiplier(hitsInARow: combo) }

    public static func comboMultiplier(hitsInARow combo: Int) -> Double {
        min(1 + Double(max(0, combo)) * comboStep, maxComboMultiplier)
    }

    public func target(inHole hole: Int) -> Target? {
        targets.first { $0.hole == hole }
    }

    /// A target whose time is up, sinking back down (still tappable for `sinkTime`).
    public func isSinking(_ target: Target) -> Bool {
        time >= target.leavesAt
    }

    // MARK: Difficulty

    /// How far through the round, from 0 to 1. Everything speeds up as it goes.
    var progress: Double { min(1, time / Self.roundLength) }
    /// Later rounds run faster, up to 70% faster than the first.
    var pace: Double { min(1.7, 1 + 0.1 * Double(round - 1)) }
    var appearanceInterval: TimeInterval { max(Self.minimumGap, (0.72 - 0.32 * progress) / pace) }
    var stayTime: TimeInterval { max(Self.minimumStay, (1.5 - 0.6 * progress) / pow(pace, 0.6)) }
    var maxTargets: Int { (progress < 0.5 ? 3 : 4) + (round >= 4 ? 1 : 0) }
    var scamShare: Double { min(0.34, 0.22 + 0.02 * Double(round - 1)) }
    var rugShare: Double { min(0.18, 0.12 + 0.01 * Double(round - 1)) }

    // MARK: Play

    /// Moves the round on by `seconds`: targets leave when their time is up and new ones appear.
    /// At 30 seconds the round ends: cleared if its goal was reached, otherwise the run is over.
    public mutating func advance<R: RandomNumberGenerator>(by seconds: TimeInterval, using rng: inout R) {
        escapedHoles = []
        guard phase == .playing, seconds.isFinite, seconds > 0 else { return }
        let end = min(time + seconds, Self.roundLength)
        while nextAppearance <= end {
            time = nextAppearance
            removeDeparted()
            appear(using: &rng)
            nextAppearance = time + appearanceInterval
        }
        time = end
        removeDeparted()
        if time >= Self.roundLength { endRound() }
    }

    /// Starts the next round after one was cleared.
    public mutating func startNextRound() {
        guard phase == .roundCleared else { return }
        round += 1
        phase = .playing
        time = 0
        roundScore = 0
        roundGolden = 0
        roundMistakes = 0
        roundBestCombo = 0
        combo = 0
        lastBonus = 0
        targets = []
        escapedHoles = []
        nextAppearance = 0.4
        objective = Self.objective(for: round)
    }

    /// Taps a hole: a coin scores, a scam costs points, and an empty hole ends the combo.
    @discardableResult
    public mutating func tap(hole: Int) -> Hit {
        guard phase == .playing else { return .miss }
        taps += 1
        guard let index = targets.firstIndex(where: { $0.hole == hole }) else {
            misses += 1
            roundMistakes += 1
            breakCombo()
            return .miss
        }
        let target = targets.remove(at: index)
        // A rug pull is judged by what it was when its time ran out, while it sinks.
        if target.isScam(at: min(time, target.leavesAt)) {
            score = max(0, score - Self.scamPenalty)
            roundScore = max(0, roundScore - Self.scamPenalty)
            scamsHit += 1
            roundMistakes += 1
            breakCombo()
            return .scam(penalty: Self.scamPenalty)
        }
        let base = target.kind == .golden ? Self.goldenPoints : Self.coinPoints
        let points = Int((Double(base) * comboMultiplier).rounded())
        combo += 1
        bestCombo = max(bestCombo, combo)
        roundBestCombo = max(roundBestCombo, combo)
        score += points
        roundScore += points
        coinsHit += 1
        if target.kind == .golden {
            goldenHit += 1
            roundGolden += 1
            return .golden(points: points)
        }
        return .coin(points: points)
    }

    // MARK: Helpers

    private mutating func breakCombo() {
        if combo >= 3 {
            comboBreaks += 1
            lastLostCombo = combo
        }
        combo = 0
    }

    private mutating func endRound() {
        targets = []
        if isObjectiveMet {
            lastBonus = Self.objectiveBonus(round: round)
            score += lastBonus
            roundScore += lastBonus
            objectivesMet += 1
        }
        phase = roundScore >= goal ? .roundCleared : .over
    }

    private mutating func removeDeparted() {
        var kept: [Target] = []
        for target in targets {
            guard target.leavesAt + Self.sinkTime <= time else {
                kept.append(target)
                continue
            }
            // A coin that gets away ends the combo; a scam (or a turned rug pull) leaving is good news.
            if !target.isScam(at: target.leavesAt) {
                escaped += 1
                escapedHoles.append(target.hole)
                breakCombo()
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
        // Rug pulls start a few seconds into the first round, once the player has the hang of it.
        let rugsAllowed = round > 1 || time >= 4
        let kind: Kind
        if roll < 0.06 {
            kind = .golden
        } else if roll < 0.06 + scamShare {
            kind = .scam
        } else if rugsAllowed && roll < 0.06 + scamShare + rugShare {
            kind = .rug
        } else {
            kind = .coin
        }
        let stay = max(Self.minimumStay, stayTime * (kind == .golden ? 0.75 : kind == .rug ? 1.3 : 1))
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

    /// Jumps to a later round, for tests.
    mutating func jump(toRound round: Int) {
        self.round = round
        objective = Self.objective(for: round)
    }
    #endif
}
