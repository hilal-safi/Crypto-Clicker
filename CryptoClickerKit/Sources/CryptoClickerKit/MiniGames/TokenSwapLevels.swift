import Foundation

/// One Token Swap level: its board, its goals, the moves it allows and what its stars take.
/// Levels are data: `TokenSwapGame(level:refillSeed:)` plays any of them, so adding one is a matter
/// of adding it to `all`.
public struct TokenSwapLevel: Sendable, Identifiable, Equatable {
    public enum Difficulty: Int, Sendable, Comparable {
        case easy = 1, medium, hard

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

        public var name: String {
            switch self {
            case .easy: "Easy"
            case .medium: "Medium"
            case .hard: "Hard"
            }
        }

        /// Star rewards are worth this much more on harder levels.
        public var rewardMultiplier: Double {
            switch self {
            case .easy: 1
            case .medium: 1.5
            case .hard: 2
            }
        }
    }

    /// The level's number, from 1.
    public let id: Int
    public let name: String
    public let difficulty: Difficulty
    /// Deals the starting board, the same at every attempt.
    public let seed: UInt64
    /// Token colors in play, from 4 to 6: fewer colors make more matches.
    public let kinds: Int
    public let moves: Int
    public let goals: [TokenSwapGame.Goal]
    /// Rows from the top, as `TokenSwapGame.board(from:)` reads them. Empty for a plain board.
    public let layout: [String]
    /// Gold bars that drop in from the top during the level, on top of any in the layout.
    public let goldToDrop: Int
    /// Scores for the second and third stars (winning earns the first).
    public let starScores: [Int]
    /// What's new in this level, shown before it starts.
    public let tip: String

    public init(id: Int, name: String, difficulty: Difficulty, seed: UInt64, kinds: Int, moves: Int,
                goals: [TokenSwapGame.Goal], layout: [String] = [], goldToDrop: Int = 0, starScores: [Int], tip: String) {
        self.id = id
        self.name = name
        self.difficulty = difficulty
        self.seed = seed
        self.kinds = kinds
        self.moves = moves
        self.goals = goals
        self.layout = layout
        self.goldToDrop = goldToDrop
        self.starScores = starScores
        self.tip = tip
    }

    /// Stars a finished game earns: none for a loss, one for a win, and two or three for a win
    /// with a high enough score (moves left over count toward it).
    public func stars(won: Bool, score: Int) -> Int {
        guard won else { return 0 }
        return 1 + starScores.prefix(2).filter { score >= $0 }.count
    }

    /// How many of each obstacle the layout starts with.
    public var obstacleCounts: (ice: Int, chains: Int, crates: Int, gold: Int) {
        var counts = (ice: 0, chains: 0, crates: 0, gold: 0)
        for mark in layout.joined() {
            switch mark {
            case "i", "I": counts.ice += 1
            case "c": counts.chains += 1
            case "x", "X", "#": counts.crates += 1
            case "g": counts.gold += 1
            default: break
            }
        }
        return counts
    }

    // MARK: The levels

    /// The levels, in order: each brings in one new idea, then they mix.
    public static let all: [TokenSwapLevel] = [
        TokenSwapLevel(id: 1, name: "First Swaps", difficulty: .easy, seed: 101, kinds: 5, moves: 15,
                       goals: [.tokens(kind: 0, count: 20)], starScores: [2_100, 2_900],
                       tip: "Drag a token onto its neighbor to swap them. Line up three of a kind to clear them."),
        TokenSwapLevel(id: 2, name: "Falling Into Place", difficulty: .easy, seed: 202, kinds: 5, moves: 16,
                       goals: [.tokens(kind: 1, count: 18), .tokens(kind: 2, count: 18)], starScores: [2_400, 3_600],
                       tip: "Tokens that fall into new matches count, and each wave scores more than the last."),
        TokenSwapLevel(id: 3, name: "Rocket Science", difficulty: .easy, seed: 303, kinds: 5, moves: 15,
                       goals: [.specials(.rocket, 3)], starScores: [2_300, 3_400],
                       tip: "Line up four to make a Rocket: four across clears its row, four down its column. Match it or swap it to set it off."),
        TokenSwapLevel(id: 4, name: "Square Deal", difficulty: .easy, seed: 404, kinds: 5, moves: 20,
                       goals: [.specials(.propeller, 2), .tokens(kind: 3, count: 15)], starScores: [3_800, 6_000],
                       tip: "A 2×2 square makes a Propeller. It clears the tokens beside it, then flies off to one you need."),
        TokenSwapLevel(id: 5, name: "Thin Ice", difficulty: .easy, seed: 505, kinds: 5, moves: 16,
                       goals: [.ice(8)],
                       layout: ["........",
                                "........",
                                "........",
                                "..iiii..",
                                "..iiii..",
                                "........",
                                "........",
                                "........"],
                       starScores: [2_300, 3_300],
                       tip: "Frozen tokens can't move or match. A match right beside one, or a blast, cracks its ice."),
        TokenSwapLevel(id: 6, name: "Boom Town", difficulty: .medium, seed: 606, kinds: 5, moves: 24,
                       goals: [.specials(.bomb, 1), .score(4_000)], starScores: [5_300, 6_700],
                       tip: "Match five in an L or T shape to make a Bomb. It clears the 5×5 square around it."),
        TokenSwapLevel(id: 7, name: "Gold Rush", difficulty: .medium, seed: 707, kinds: 5, moves: 22,
                       goals: [.gold(2)],
                       layout: ["..g..g..",
                                "........",
                                "........",
                                "........",
                                "........",
                                "........",
                                "........",
                                "........"],
                       starScores: [4_500, 5_700],
                       tip: "Gold bars can't be matched. Clear the tokens under one to bring it down: it's collected on the bottom row."),
        TokenSwapLevel(id: 8, name: "In Chains", difficulty: .medium, seed: 808, kinds: 5, moves: 16,
                       goals: [.chains(8)],
                       layout: ["........",
                                "........",
                                ".c....c.",
                                "..c..c..",
                                "..c..c..",
                                ".c....c.",
                                "........",
                                "........"],
                       starScores: [3_300, 4_700],
                       tip: "Chained tokens can't be swapped and don't fall, but they still match: matching one breaks its chain."),
        TokenSwapLevel(id: 9, name: "Five Alive", difficulty: .medium, seed: 909, kinds: 5, moves: 20,
                       goals: [.specials(.colorClear, 1), .tokens(kind: 2, count: 40)],
                       layout: ["........",
                                "........",
                                "........",
                                "...@....",
                                "........",
                                "........",
                                "........",
                                "........"],
                       starScores: [4_000, 5_400],
                       tip: "Five in a row makes a Color Clear, and here's one to try. Swap it with any token to clear every token of that color."),
        TokenSwapLevel(id: 10, name: "Crate Expectations", difficulty: .medium, seed: 1_010, kinds: 5, moves: 22,
                       goals: [.crates(10)],
                       layout: ["........",
                                "........",
                                "........",
                                "........",
                                "........",
                                "x......x",
                                "xx....xx",
                                "xx....xx"],
                       starScores: [4_500, 6_300],
                       tip: "Crates take a hit from every match beside them and every blast that reaches them."),
        TokenSwapLevel(id: 11, name: "Double Trouble", difficulty: .medium, seed: 1_111, kinds: 5, moves: 21,
                       goals: [.ice(10)],
                       layout: ["........",
                                "I......I",
                                ".I....I.",
                                "..I..I..",
                                "...II...",
                                "...II...",
                                "........",
                                "........"],
                       starScores: [3_400, 4_800],
                       tip: "Thick ice takes two hits to break."),
        TokenSwapLevel(id: 12, name: "Combo Lab", difficulty: .medium, seed: 1_212, kinds: 5, moves: 20,
                       goals: [.specials(.any, 9)], starScores: [3_400, 6_000],
                       tip: "Swap two specials together for a combination: two Rockets clear a row and a column, two Bombs a 7×7 square."),
        TokenSwapLevel(id: 13, name: "Deep Mine", difficulty: .hard, seed: 1_313, kinds: 5, moves: 30,
                       goals: [.gold(3), .crates(6)],
                       layout: ["...g....",
                                "........",
                                "........",
                                "........",
                                "........",
                                "........",
                                "xx....xx",
                                "x......x"],
                       goldToDrop: 2, starScores: [5_600, 7_700],
                       tip: "More gold bars drop in from the top as you collect them. Crates under a bar hold it up."),
        TokenSwapLevel(id: 14, name: "Locked Vault", difficulty: .hard, seed: 1_414, kinds: 6, moves: 24,
                       goals: [.chains(10), .tokens(kind: 0, count: 25)],
                       layout: ["........",
                                "........",
                                "cc....cc",
                                "........",
                                "...cc...",
                                "........",
                                "cc....cc",
                                "........"],
                       starScores: [3_300, 4_100],
                       tip: "Rockets and Bombs break every chain they reach."),
        TokenSwapLevel(id: 15, name: "Strongbox", difficulty: .hard, seed: 1_515, kinds: 6, moves: 25,
                       goals: [.crates(14)],
                       layout: ["........",
                                "........",
                                "........",
                                "..XXXX..",
                                "..XXXX..",
                                "........",
                                "xx....xx",
                                "xx....xx"],
                       starScores: [3_100, 3_700],
                       tip: "Six colors make matches harder to find: look for specials to do the heavy lifting."),
        TokenSwapLevel(id: 16, name: "Frozen Gold", difficulty: .hard, seed: 1_616, kinds: 5, moves: 27,
                       goals: [.gold(3), .ice(8)],
                       layout: ["..g..g..",
                                "........",
                                "........",
                                ".i.ii.i.",
                                ".i.ii.i.",
                                "........",
                                "........",
                                "........"],
                       goldToDrop: 1, starScores: [5_500, 6_800],
                       tip: "Propellers fly to the ice you still need to crack."),
        TokenSwapLevel(id: 17, name: "Full Toolkit", difficulty: .hard, seed: 1_717, kinds: 5, moves: 27,
                       goals: [.crates(8), .ice(8), .chains(6)],
                       layout: ["........",
                                "c......c",
                                ".c....c.",
                                "..iiii..",
                                "..iiii..",
                                ".c....c.",
                                "xxx..xxx",
                                "x......x"],
                       starScores: [5_300, 7_500],
                       tip: "Everything at once. Plan for combinations."),
        TokenSwapLevel(id: 18, name: "Market Crash", difficulty: .hard, seed: 1_818, kinds: 5, moves: 34,
                       goals: [.gold(3), .crates(8)],
                       layout: [".g....g.",
                                "........",
                                "........",
                                "........",
                                "...##...",
                                "........",
                                "X......X",
                                "xx....xx"],
                       goldToDrop: 1, starScores: [7_000, 9_700],
                       tip: "The crates in the corners hold up the gold above them. Break them first."),
    ]

    /// The level with a number, if there is one.
    public static func number(_ id: Int) -> TokenSwapLevel? {
        all.indices.contains(id - 1) ? all[id - 1] : nil
    }

    // MARK: The daily puzzle

    /// A day's puzzle, the same for everyone: the day picks one of several goals and deals its own
    /// board, and the tokens that drop in later come from the day too.
    public static func daily(day: String) -> TokenSwapLevel {
        let seed = StableHash.of("token-swap-daily-" + day)
        let template = dailyTemplates[Int(seed % UInt64(dailyTemplates.count))]
        let kind = Int((seed >> 8) % 5)
        let goals = template.goals.map { goal -> TokenSwapGame.Goal in
            if case .tokens(_, let count) = goal { return .tokens(kind: kind, count: count) }
            return goal
        }
        return TokenSwapLevel(id: 0, name: template.name, difficulty: .medium, seed: seed, kinds: template.kinds,
                              moves: template.moves, goals: goals, layout: template.layout,
                              goldToDrop: template.goldToDrop, starScores: template.starScores, tip: template.tip)
    }

    /// The seed for the tokens that drop in during a day's puzzle.
    public static func dailyRefillSeed(day: String) -> UInt64 {
        StableHash.of("token-swap-daily-refill-" + day)
    }

    static let dailyTemplates: [TokenSwapLevel] = [
        TokenSwapLevel(id: 0, name: "Collector", difficulty: .medium, seed: 0, kinds: 5, moves: 18,
                       goals: [.tokens(kind: 0, count: 30), .specials(.any, 2)], starScores: [3_800, 6_100],
                       tip: "Clear the tokens the goal asks for, and set off two specials."),
        TokenSwapLevel(id: 0, name: "Cold Snap", difficulty: .medium, seed: 0, kinds: 5, moves: 20,
                       goals: [.ice(12)],
                       layout: ["........",
                                "........",
                                ".iiiiii.",
                                "........",
                                "........",
                                ".iiiiii.",
                                "........",
                                "........"],
                       starScores: [3_100, 4_000],
                       tip: "Crack all the ice: matches beside a frozen token crack it."),
        TokenSwapLevel(id: 0, name: "Warehouse", difficulty: .medium, seed: 0, kinds: 5, moves: 24,
                       goals: [.crates(12)],
                       layout: ["........",
                                "........",
                                "........",
                                "........",
                                "x..xx..x",
                                "x..xx..x",
                                "xx....xx",
                                "........"],
                       starScores: [4_200, 6_200],
                       tip: "Break the crates with matches beside them and with blasts."),
        TokenSwapLevel(id: 0, name: "Gold Fever", difficulty: .medium, seed: 0, kinds: 5, moves: 24,
                       goals: [.gold(3)],
                       layout: ["...gg...",
                                "........",
                                "........",
                                "........",
                                "........",
                                "........",
                                "........",
                                "........"],
                       goldToDrop: 1, starScores: [3_800, 5_300],
                       tip: "Bring the gold bars down to the bottom row."),
        TokenSwapLevel(id: 0, name: "Chain Gang", difficulty: .medium, seed: 0, kinds: 5, moves: 19,
                       goals: [.chains(10)],
                       layout: ["........",
                                "c......c",
                                "..c..c..",
                                "........",
                                "..c..c..",
                                "c......c",
                                "...cc...",
                                "........"],
                       starScores: [4_300, 5_200],
                       tip: "Match chained tokens, or blast them, to break their chains."),
        TokenSwapLevel(id: 0, name: "Big Score", difficulty: .medium, seed: 0, kinds: 5, moves: 20,
                       goals: [.score(3_800)], starScores: [4_500, 5_800],
                       tip: "Make specials and swap them together for the big points."),
    ]
}

/// Token Swap levels won and the daily puzzle, saved with the game.
public struct TokenSwapProgress: Codable, Equatable, Sendable {
    /// Best stars for each level, by level number (index 0 is level 1); 0 until it's won.
    public internal(set) var stars: [Int] = []
    public internal(set) var bestScores: [Int] = []
    /// The last day whose daily puzzle was won (and paid).
    public internal(set) var dailyWonDay: String?
    public internal(set) var dailyWins = 0

    public init() {}

    public func stars(for level: Int) -> Int {
        stars.indices.contains(level - 1) ? stars[level - 1] : 0
    }

    public func bestScore(for level: Int) -> Int {
        bestScores.indices.contains(level - 1) ? bestScores[level - 1] : 0
    }

    /// Level 1 is always open; each level after opens once the one before is won.
    public func isUnlocked(_ level: Int) -> Bool {
        level <= 1 || stars(for: level - 1) > 0
    }

    public var totalStars: Int { stars.reduce(0, +) }
    public var levelsWon: Int { stars.filter { $0 > 0 }.count }

    /// The first level not yet won, or the last level once every one is.
    public var nextLevel: Int {
        let count = TokenSwapLevel.all.count
        return (1...count).first { stars(for: $0) == 0 } ?? count
    }

    public func hasWonDaily(day: String) -> Bool { dailyWonDay == day }

    mutating func record(level: Int, stars earned: Int, score: Int) {
        guard level >= 1 else { return }
        if stars.count < level { stars += Array(repeating: 0, count: level - stars.count) }
        if bestScores.count < level { bestScores += Array(repeating: 0, count: level - bestScores.count) }
        stars[level - 1] = max(stars[level - 1], min(3, max(0, earned)))
        bestScores[level - 1] = max(bestScores[level - 1], score)
    }

    private enum CodingKeys: String, CodingKey { case stars, bestScores, dailyWonDay, dailyWins }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stars = c.value(.stars, default: []).map { min(3, max(0, $0)) }
        bestScores = c.value(.bestScores, default: []).map { max(0, $0) }
        dailyWonDay = c.value(.dailyWonDay, default: nil)
        dailyWins = max(0, c.value(.dailyWins, default: 0))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(stars, forKey: .stars)
        try c.encode(bestScores, forKey: .bestScores)
        try c.encodeIfPresent(dailyWonDay, forKey: .dailyWonDay)
        try c.encode(dailyWins, forKey: .dailyWins)
    }
}
