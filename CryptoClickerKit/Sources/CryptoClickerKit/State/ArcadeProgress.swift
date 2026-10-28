import Foundation

/// Arcade Rank: experience (XP) earned by playing the mini-games, the week's variety goal, and the
/// cosmetics picked. Saved with the game and kept through prestiges. XP never pays coins; ranks
/// unlock cosmetics and titles, so they add variety without touching the economy.
public struct ArcadeProgress: Codable, Equatable, Sendable {
    public internal(set) var xp = 0
    /// The day (a `StepDay` key) `gamesToday` and `casinoXPToday` count, so variety XP is paid once
    /// per game per day and casino rounds can't be farmed for XP.
    public internal(set) var day: String?
    public internal(set) var gamesToday: Set<MiniGame> = []
    public internal(set) var casinoXPToday = 0
    /// The week (a `StepDay.weekKey`) the variety goal counts, the games played in it, and whether
    /// its reward has been paid.
    public internal(set) var week: String?
    public internal(set) var gamesThisWeek: Set<MiniGame> = []
    public internal(set) var isWeekPaid = false
    /// Weeks whose variety goal was reached.
    public internal(set) var weeklyGoals = 0
    /// The cosmetic picked for each slot; a slot left out uses its default.
    public internal(set) var equipped: [CosmeticSlot: Cosmetic] = [:]

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case xp, day, gamesToday, casinoXPToday, week, gamesThisWeek, isWeekPaid, weeklyGoals, equipped
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = max(0, c.value(.xp, default: 0))
        day = c.value(.day, default: nil)
        gamesToday = c.enumSet(.gamesToday, as: MiniGame.self)
        casinoXPToday = max(0, c.value(.casinoXPToday, default: 0))
        week = c.value(.week, default: nil)
        gamesThisWeek = c.enumSet(.gamesThisWeek, as: MiniGame.self)
        isWeekPaid = c.value(.isWeekPaid, default: false)
        weeklyGoals = max(0, c.value(.weeklyGoals, default: 0))
        // Saved by raw value; anything a later version renamed is dropped (the slot falls back to its default).
        let saved: [String: String] = c.value(.equipped, default: [:])
        var equipped: [CosmeticSlot: Cosmetic] = [:]
        for (slot, cosmetic) in saved {
            guard let slot = CosmeticSlot(rawValue: slot), let cosmetic = Cosmetic(rawValue: cosmetic), cosmetic.slot == slot else { continue }
            equipped[slot] = cosmetic
        }
        self.equipped = equipped
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(xp, forKey: .xp)
        try c.encodeIfPresent(day, forKey: .day)
        try c.encode(gamesToday.sortedRawValues, forKey: .gamesToday)
        try c.encode(casinoXPToday, forKey: .casinoXPToday)
        try c.encodeIfPresent(week, forKey: .week)
        try c.encode(gamesThisWeek.sortedRawValues, forKey: .gamesThisWeek)
        try c.encode(isWeekPaid, forKey: .isWeekPaid)
        try c.encode(weeklyGoals, forKey: .weeklyGoals)
        try c.encode(Dictionary(uniqueKeysWithValues: equipped.map { ($0.key.rawValue, $0.value.rawValue) }), forKey: .equipped)
    }
}

/// Arcade Rank: rank `n` takes `50 × n × (n - 1)` XP in all, so each rank asks 100 XP more than
/// the one before (100, 200, 300…).
public enum ArcadeRank {
    /// Stops at `Int.max` rather than overflowing (a 32-bit `Int` on Apple Watch).
    public static func xpNeeded(forRank rank: Int) -> Int {
        let needed = 50 * Double(max(1, rank)) * Double(max(1, rank) - 1)
        return needed < Double(Int.max) ? Int(needed) : Int.max
    }

    /// The rank `xp` reaches.
    public static func rank(forXP xp: Int) -> Int {
        guard xp > 0 else { return 1 }
        // Solve 50 n (n - 1) <= xp for the largest n, then settle the rounding.
        var rank = max(1, Int(((1 + (1 + Double(xp) / 12.5).squareRoot()) / 2).rounded(.down)))
        if rank > 1 && xpNeeded(forRank: rank) > xp {
            rank -= 1
        } else if xpNeeded(forRank: rank + 1) <= xp && xpNeeded(forRank: rank + 1) < Int.max {
            rank += 1
        }
        return rank
    }

    /// The title a rank carries.
    public static func title(forRank rank: Int) -> String {
        switch rank {
        case ..<5: "Rookie"
        case 5..<10: "Player"
        case 10..<15: "Pro"
        case 15..<20: "Expert"
        case 20..<30: "Master"
        default: "Legend"
        }
    }
}

/// Where a cosmetic goes.
public enum CosmeticSlot: String, CaseIterable, Codable, Sendable, Identifiable {
    case cardBack, felt, reels, tetris, snake

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .cardBack: "Card Backs"
        case .felt: "Blackjack Table"
        case .reels: "Slot Reels"
        case .tetris: "Tetris Blocks"
        case .snake: "Snake Skin"
        }
    }

    /// The cosmetic a slot uses until another is picked.
    public var standard: Cosmetic {
        switch self {
        case .cardBack: .cardBackClassic
        case .felt: .feltGreen
        case .reels: .reelsClassic
        case .tetris: .tetrisClassic
        case .snake: .snakeGreen
        }
    }
}

/// How a cosmetic unlocks.
public enum CosmeticUnlock: Equatable, Sendable {
    /// From the start.
    case free
    /// On reaching an Arcade Rank.
    case rank(Int)
    /// With an achievement tier (0 bronze to 3 mythic).
    case achievement(id: String, tier: Int)
}

/// A look for a game: card backs, the Blackjack felt, slot reels, Tetris blocks and the snake.
public enum Cosmetic: String, CaseIterable, Codable, Sendable, Identifiable {
    case cardBackClassic, cardBackMidnight, cardBackEmerald, cardBackGold
    case feltGreen, feltCrimson, feltBlue
    case reelsClassic, reelsNeon, reelsGold
    case tetrisClassic, tetrisPixel, tetrisGlass
    case snakeGreen, snakeRainbow, snakeGold

    public var id: String { rawValue }

    public var slot: CosmeticSlot {
        switch self {
        case .cardBackClassic, .cardBackMidnight, .cardBackEmerald, .cardBackGold: .cardBack
        case .feltGreen, .feltCrimson, .feltBlue: .felt
        case .reelsClassic, .reelsNeon, .reelsGold: .reels
        case .tetrisClassic, .tetrisPixel, .tetrisGlass: .tetris
        case .snakeGreen, .snakeRainbow, .snakeGold: .snake
        }
    }

    public var name: String {
        switch self {
        case .cardBackClassic: "Classic Red"
        case .cardBackMidnight: "Midnight"
        case .cardBackEmerald: "Emerald"
        case .cardBackGold: "Gold Foil"
        case .feltGreen: "Casino Green"
        case .feltCrimson: "Crimson"
        case .feltBlue: "Royal Blue"
        case .reelsClassic: "Classic"
        case .reelsNeon: "Neon"
        case .reelsGold: "Gold"
        case .tetrisClassic: "Classic"
        case .tetrisPixel: "Pixel"
        case .tetrisGlass: "Glass"
        case .snakeGreen: "Green"
        case .snakeRainbow: "Rainbow"
        case .snakeGold: "Gold"
        }
    }

    public var unlock: CosmeticUnlock {
        switch self {
        case .cardBackClassic, .feltGreen, .reelsClassic, .tetrisClassic, .snakeGreen: .free
        case .cardBackMidnight: .rank(3)
        case .cardBackEmerald: .achievement(id: "poker-face", tier: 0)
        case .cardBackGold: .achievement(id: "card-shark", tier: 1)
        case .feltCrimson: .achievement(id: "card-shark", tier: 0)
        case .feltBlue: .rank(6)
        case .reelsNeon: .achievement(id: "high-roller", tier: 0)
        case .reelsGold: .rank(10)
        case .tetrisPixel: .rank(4)
        case .tetrisGlass: .achievement(id: "line-clearer", tier: 1)
        case .snakeRainbow: .rank(8)
        case .snakeGold: .achievement(id: "snake-charmer", tier: 1)
        }
    }

    /// The cosmetics for a slot, the default first.
    public static func all(in slot: CosmeticSlot) -> [Cosmetic] {
        allCases.filter { $0.slot == slot }
    }

    /// The cosmetics a rank unlocks.
    public static func unlocked(atRank rank: Int) -> [Cosmetic] {
        allCases.filter { $0.unlock == .rank(rank) }
    }
}
