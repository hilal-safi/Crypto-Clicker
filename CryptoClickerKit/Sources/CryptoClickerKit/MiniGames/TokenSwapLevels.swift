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
            case .easy: localized("Easy")
            case .medium: localized("Medium")
            case .hard: localized("Hard")
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
        TokenSwapLevel(id: 1, name: localized("First Swaps"), difficulty: .easy, seed: 101, kinds: 5, moves: 15,
                       goals: [.tokens(kind: 0, count: 20)], starScores: [2_100, 2_900],
                       tip: localized("Drag a token onto its neighbor to swap them. Line up three of a kind to clear them.")),
        TokenSwapLevel(id: 2, name: localized("Falling Into Place"), difficulty: .easy, seed: 202, kinds: 5, moves: 16,
                       goals: [.tokens(kind: 1, count: 18), .tokens(kind: 2, count: 18)], starScores: [2_400, 3_600],
                       tip: localized("Tokens that fall into new matches count, and each wave scores more than the last.")),
        TokenSwapLevel(id: 3, name: localized("Rocket Science"), difficulty: .easy, seed: 303, kinds: 5, moves: 15,
                       goals: [.specials(.rocket, 3)], starScores: [2_300, 3_400],
                       tip: localized("Line up four to make a Rocket: four across clears its row, four down its column. Match it or swap it to set it off.")),
        TokenSwapLevel(id: 4, name: localized("Square Deal"), difficulty: .easy, seed: 404, kinds: 5, moves: 20,
                       goals: [.specials(.propeller, 2), .tokens(kind: 3, count: 15)], starScores: [3_800, 6_000],
                       tip: localized("A 2×2 square makes a Propeller. It clears the tokens beside it, then flies off to one you need.")),
        TokenSwapLevel(id: 5, name: localized("Thin Ice"), difficulty: .easy, seed: 505, kinds: 5, moves: 16,
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
                       tip: localized("Frozen tokens can't move or match. A match right beside one, or a blast, cracks its ice.")),
        TokenSwapLevel(id: 6, name: localized("Boom Town"), difficulty: .medium, seed: 606, kinds: 5, moves: 24,
                       goals: [.specials(.bomb, 1), .score(4_000)], starScores: [5_300, 6_700],
                       tip: localized("Match five in an L or T shape to make a Bomb. It clears the 5×5 square around it.")),
        TokenSwapLevel(id: 7, name: localized("Gold Rush"), difficulty: .medium, seed: 707, kinds: 5, moves: 22,
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
                       tip: localized("Gold bars can't be matched. Clear the tokens under one to bring it down: it's collected on the bottom row.")),
        TokenSwapLevel(id: 8, name: localized("In Chains"), difficulty: .medium, seed: 808, kinds: 5, moves: 16,
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
                       tip: localized("Chained tokens can't be swapped and don't fall, but they still match: matching one breaks its chain.")),
        TokenSwapLevel(id: 9, name: localized("Five Alive"), difficulty: .medium, seed: 909, kinds: 5, moves: 20,
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
                       tip: localized("Five in a row makes a Color Clear, and here's one to try. Swap it with any token to clear every token of that color.")),
        TokenSwapLevel(id: 10, name: localized("Crate Expectations"), difficulty: .medium, seed: 1_010, kinds: 5, moves: 22,
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
                       tip: localized("Crates take a hit from every match beside them and every blast that reaches them.")),
        TokenSwapLevel(id: 11, name: localized("Double Trouble"), difficulty: .medium, seed: 1_111, kinds: 5, moves: 21,
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
                       tip: localized("Thick ice takes two hits to break.")),
        TokenSwapLevel(id: 12, name: localized("Combo Lab"), difficulty: .medium, seed: 1_212, kinds: 5, moves: 20,
                       goals: [.specials(.any, 9)], starScores: [3_400, 6_000],
                       tip: localized("Swap two specials together for a combination: two Rockets clear a row and a column, two Bombs a 7×7 square.")),
        TokenSwapLevel(id: 13, name: localized("Deep Mine"), difficulty: .hard, seed: 1_313, kinds: 5, moves: 30,
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
                       tip: localized("More gold bars drop in from the top as you collect them. Crates under a bar hold it up.")),
        TokenSwapLevel(id: 14, name: localized("Locked Vault"), difficulty: .hard, seed: 1_414, kinds: 6, moves: 24,
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
                       tip: localized("Rockets and Bombs break every chain they reach.")),
        TokenSwapLevel(id: 15, name: localized("Strongbox"), difficulty: .hard, seed: 1_515, kinds: 6, moves: 25,
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
                       tip: localized("Six colors make matches harder to find: look for specials to do the heavy lifting.")),
        TokenSwapLevel(id: 16, name: localized("Frozen Gold"), difficulty: .hard, seed: 1_616, kinds: 5, moves: 27,
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
                       tip: localized("Propellers fly to the ice you still need to crack.")),
        TokenSwapLevel(id: 17, name: localized("Full Toolkit"), difficulty: .hard, seed: 1_717, kinds: 5, moves: 27,
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
                       tip: localized("Everything at once. Plan for combinations.")),
        TokenSwapLevel(id: 18, name: localized("Market Crash"), difficulty: .hard, seed: 1_818, kinds: 5, moves: 34,
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
                       tip: localized("The crates in the corners hold up the gold above them. Break them first.")),
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
        TokenSwapLevel(id: 0, name: localized("Collector"), difficulty: .medium, seed: 0, kinds: 5, moves: 18,
                       goals: [.tokens(kind: 0, count: 30), .specials(.any, 2)], starScores: [3_800, 6_100],
                       tip: localized("Clear the tokens the goal asks for, and set off two specials.")),
        TokenSwapLevel(id: 0, name: localized("Cold Snap"), difficulty: .medium, seed: 0, kinds: 5, moves: 20,
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
                       tip: localized("Crack all the ice: matches beside a frozen token crack it.")),
        TokenSwapLevel(id: 0, name: localized("Warehouse"), difficulty: .medium, seed: 0, kinds: 5, moves: 24,
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
                       tip: localized("Break the crates with matches beside them and with blasts.")),
        TokenSwapLevel(id: 0, name: localized("Gold Fever"), difficulty: .medium, seed: 0, kinds: 5, moves: 24,
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
                       tip: localized("Bring the gold bars down to the bottom row.")),
        TokenSwapLevel(id: 0, name: localized("Chain Gang"), difficulty: .medium, seed: 0, kinds: 5, moves: 19,
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
                       tip: localized("Match chained tokens, or blast them, to break their chains.")),
        TokenSwapLevel(id: 0, name: localized("Big Score"), difficulty: .medium, seed: 0, kinds: 5, moves: 20,
                       goals: [.score(3_800)], starScores: [4_500, 5_800],
                       tip: localized("Make specials and swap them together for the big points.")),
    ]
}

// MARK: - Random levels

extension TokenSwapLevel {
    /// A level made up from `seed`, so there's always a new one to play: one goal (two on most
    /// medium and every hard level), a board laid out for it (mirrored left to right, like the
    /// hand-made levels), and moves and star scores worked out from what each goal takes in the
    /// hand-made levels of the same difficulty. The same seed always makes the same level.
    public static func generated(seed: UInt64, difficulty: Difficulty) -> TokenSwapLevel {
        var rng = SeededGenerator(seed: StableHash.of("token-swap-random-\(seed)-\(difficulty.rawValue)"))
        let kinds = difficulty == .hard && Double.random(in: 0..<1, using: &rng) < 0.3 ? 6 : 5
        let goalCount = switch difficulty {
        case .easy: 1
        case .medium: Double.random(in: 0..<1, using: &rng) < 0.5 ? 2 : 1
        case .hard: 2
        }
        var plan = RandomPlan(difficulty: difficulty, kinds: kinds)
        // A score goal stands alone, so it's only for single-goal levels.
        var pool = RandomPlan.Theme.allCases.filter { goalCount == 1 || $0 != .score }
        for _ in 0..<goalCount {
            // Obstacles that share the board (and gold that needs a clear path) don't mix well, so
            // a second goal is picked from what fits with the first.
            pool.removeAll { !plan.fits($0) }
            guard let theme = pool.randomElement(using: &rng) else { break }
            pool.removeAll { $0 == theme }
            plan.add(theme, using: &rng)
        }
        let moves = plan.moves
        let perMove = kinds == 6 ? 130.0 : 175.0
        let second = Int((Double(moves) * perMove / 100).rounded()) * 100
        let third = Int((Double(moves) * perMove * 1.4 / 100).rounded()) * 100
        let names = plan.themes.first?.names ?? [localized("Mystery")]
        let name = names[Int(seed % UInt64(names.count))] + " #\(seed % 10_000)"
        return TokenSwapLevel(id: 0, name: name, difficulty: difficulty, seed: seed, kinds: kinds, moves: moves,
                              goals: plan.goals, layout: plan.layout, goldToDrop: plan.goldToDrop,
                              starScores: [second, third], tip: plan.themes.first?.tip ?? "")
    }
}

/// Builds a random level goal by goal.
private struct RandomPlan {
    enum Theme: CaseIterable {
        case tokens, ice, chains, crates, gold, specials, score

        var names: [String] {
            switch self {
            case .tokens: [localized("Token Hunt"), localized("Collector"), localized("Harvest"), localized("Shopping Spree")]
            case .ice: [localized("Cold Snap"), localized("Frozen Vault"), localized("Permafrost"), localized("Ice Floe")]
            case .chains: [localized("Locked Ledger"), localized("Chain Reaction"), localized("Shackled"), localized("Key Holder")]
            case .crates: [localized("Warehouse"), localized("Cargo Hold"), localized("Stack Attack"), localized("Loading Dock")]
            case .gold: [localized("Gold Rush"), localized("Bullion Drop"), localized("Treasure Fall"), localized("Mother Lode")]
            case .specials: [localized("Rocket Lab"), localized("Blast Zone"), localized("Fireworks"), localized("Demolition")]
            case .score: [localized("High Roller"), localized("Big Score"), localized("Jackpot Run"), localized("Bull Market")]
            }
        }

        var tip: String {
            switch self {
            case .tokens: localized("Big matches and specials clear the most tokens of the color you need.")
            case .ice: localized("A match right beside a frozen token cracks its ice, and so does a blast.")
            case .chains: localized("Match chained tokens, or blast them, to break their chains.")
            case .crates: localized("Crates take a hit from every match beside them and every blast that reaches them.")
            case .gold: localized("Clear the tokens under a gold bar to bring it down: it's collected on the bottom row.")
            case .specials: localized("Four in a row makes a Rocket, a 2×2 square a Propeller, an L or T a Bomb.")
            case .score: localized("Waves that fall into new matches score more each time, and specials score big.")
            }
        }

        /// Board obstacles the theme lays out.
        var usesBoard: Bool { [.ice, .chains, .crates].contains(self) }
    }

    let difficulty: TokenSwapLevel.Difficulty
    let kinds: Int
    private(set) var themes: [Theme] = []
    private(set) var goals: [TokenSwapGame.Goal] = []
    /// Moves each goal takes on its own, in the hand-made levels.
    private var goalMoves: [Double] = []
    private var board = Array(repeating: Array(repeating: Character("."), count: 8), count: 8)
    private(set) var goldToDrop = 0
    /// Columns gold falls down, kept clear of crates.
    private var goldColumns: Set<Int> = []

    init(difficulty: TokenSwapLevel.Difficulty, kinds: Int) {
        self.difficulty = difficulty
        self.kinds = kinds
    }

    var layout: [String] {
        board.contains { $0.contains { $0 != "." } } ? board.map { String($0) } : []
    }

    /// Moves to allow: the hardest goal, plus half of the rest (goals move along together), with
    /// room to spare on easier levels, and a little more with six colors.
    var moves: Int {
        guard let hardest = goalMoves.max() else { return 15 }
        let together = hardest + 0.5 * (goalMoves.reduce(0, +) - hardest)
        let slack = switch difficulty {
        case .easy: 1.45
        case .medium: 1.22
        case .hard: 1.1
        }
        return min(36, max(14, Int((together * slack * (kinds == 6 ? 1.15 : 1)).rounded())))
    }

    func fits(_ theme: Theme) -> Bool {
        if themes.contains(theme) { return false }
        // One kind of obstacle per board, and gold only beside obstacles that leave it a path.
        if theme.usesBoard && themes.contains(where: \.usesBoard) { return false }
        if theme == .crates && themes.contains(.gold) { return false }
        if theme == .gold && themes.contains(.crates) { return false }
        // A score goal with another goal reads oddly; it stands alone.
        if theme == .score && !themes.isEmpty { return false }
        if themes.contains(.score) { return false }
        return true
    }

    /// How big a goal is: small on easy levels, larger on hard ones.
    private func size(_ easy: ClosedRange<Int>, _ medium: ClosedRange<Int>, _ hard: ClosedRange<Int>,
                      using rng: inout SeededGenerator) -> Int {
        Int.random(in: difficulty == .easy ? easy : difficulty == .medium ? medium : hard, using: &rng)
    }

    mutating func add(_ theme: Theme, using rng: inout SeededGenerator) {
        themes.append(theme)
        switch theme {
        case .tokens:
            let count = size(16...22, 22...30, 26...34, using: &rng)
            goals.append(.tokens(kind: Int.random(in: 0..<kinds, using: &rng), count: count))
            goalMoves.append(Double(count) / 1.45)
        case .ice:
            let thick = difficulty == .hard || (difficulty == .medium && Bool.random(using: &rng))
            let placed = place(size(6...8, 8...10, 8...12, using: &rng), mark: thick ? "I" : "i", rows: 2...6, using: &rng)
            goals.append(.ice(placed))
            goalMoves.append(Double(placed) * (thick ? 1.75 : 1.4))
        case .chains:
            let placed = place(size(6...8, 8...10, 8...12, using: &rng), mark: "c", rows: 1...6, using: &rng)
            goals.append(.chains(placed))
            goalMoves.append(Double(placed) * 1.6)
        case .crates:
            let thick = difficulty == .hard
            let placed = place(size(6...8, 8...12, 10...14, using: &rng), mark: thick ? "X" : "x", rows: 4...7, using: &rng)
            goals.append(.crates(placed))
            goalMoves.append(Double(placed) * (thick ? 1.9 : 1.6))
        case .gold:
            // A mirrored pair on the top row, and on bigger goals one more dropping in later.
            let count = size(2...2, 2...3, 3...3, using: &rng)
            let column = Int.random(in: 1...3, using: &rng)
            board[0][column] = "g"
            board[0][7 - column] = "g"
            goldColumns.formUnion([column, 7 - column])
            goldToDrop = count - 2
            goals.append(.gold(count))
            goalMoves.append(7 + Double(count) * 5)
        case .specials:
            if difficulty == .easy || Bool.random(using: &rng) {
                let count = size(3...4, 4...6, 6...8, using: &rng)
                goals.append(.specials(.any, count))
                goalMoves.append(Double(count) * 2.6)
            } else {
                let rockets = Bool.random(using: &rng)
                let count = rockets ? size(2...3, 3...3, 3...4, using: &rng) : 1
                goals.append(.specials(rockets ? .rocket : .bomb, count))
                goalMoves.append(rockets ? Double(count) * 5 : 13)
            }
        case .score:
            let points = size(30...36, 38...46, 46...54, using: &rng) * 100
            goals.append(.score(points))
            goalMoves.append(Double(points) / 190)
        }
    }

    /// Lays out about `target` obstacles in `rows`, mirrored left to right, and returns how many
    /// were placed (the goal asks for all of them).
    private mutating func place(_ target: Int, mark: Character, rows: ClosedRange<Int>, using rng: inout SeededGenerator) -> Int {
        var placed = 0
        var attempts = 0
        // A tidy shape most of the time (rows, a block or a ring), scattered pairs otherwise.
        let shape = Int.random(in: 0..<4, using: &rng)
        var candidates: [(Int, Int)] = []
        for row in rows {
            for column in 0..<4 {
                switch shape {
                case 0: if row % 2 == rows.lowerBound % 2 { candidates.append((row, column)) } // Bands.
                case 1: if column >= 2 { candidates.append((row, column)) } // A block in the middle.
                case 2: if column <= 1 { candidates.append((row, column)) } // Pillars at the sides.
                default: candidates.append((row, column)) // Anywhere.
                }
            }
        }
        candidates.shuffle(using: &rng)
        for (row, column) in candidates where placed < target {
            attempts += 1
            let mirrored = 7 - column
            guard board[row][column] == ".", board[row][mirrored] == "." else { continue }
            if mark == "x" || mark == "X", goldColumns.contains(column) || goldColumns.contains(mirrored) { continue }
            board[row][column] = mark
            board[row][mirrored] = mark
            placed += 2
        }
        return placed
    }
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
