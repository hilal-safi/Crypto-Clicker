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
        case ..<5: localized("Rookie")
        case 5..<10: localized("Player")
        case 10..<15: localized("Pro")
        case 15..<20: localized("Expert")
        case 20..<30: localized("Master")
        default: localized("Legend")
        }
    }
}

/// Where a cosmetic goes: at least one look for every game, in the order the Arcade lists them.
public enum CosmeticSlot: String, CaseIterable, Codable, Sendable, Identifiable {
    case cardBack, felt, pokerTable, reels, moonRide
    case tetris, mergeTiles, snake, paddle, bubbles, pumpBoard, swapTiles, ship

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .cardBack: localized("Card Backs")
        case .felt: localized("\(MiniGame.blackjack.name) Table")
        case .pokerTable: localized("\(MiniGame.videoPoker.name) Table")
        case .reels: localized("Slot Reels")
        case .moonRide: localized("\(MiniGame.moon.name) Ride")
        case .tetris: localized("Block Chain Coins")
        case .mergeTiles: localized("Merge Mining Tiles")
        case .snake: localized("Hash Chain Blocks")
        case .paddle: localized("Hash Smash Paddle")
        case .bubbles: localized("Bubble Market Bubbles")
        case .pumpBoard: localized("Pump and Dump Board")
        case .swapTiles: localized("Token Swap Tiles")
        case .ship: localized("Invaders Ship")
        }
    }

    /// The games that show it.
    public var games: [MiniGame] {
        switch self {
        case .cardBack: [.blackjack, .videoPoker]
        case .felt: [.blackjack]
        case .pokerTable: [.videoPoker]
        case .reels: [.slots]
        case .moonRide: [.moon]
        case .tetris: [.tetris]
        case .mergeTiles: [.merge2048]
        case .snake: [.snake]
        case .paddle: [.brickBreaker]
        case .bubbles: [.bubbleBlaster]
        case .pumpBoard: [.pumpDump]
        case .swapTiles: [.tokenSwap]
        case .ship: [.invaders]
        }
    }

    /// The cosmetic a slot uses until another is picked.
    public var standard: Cosmetic {
        switch self {
        case .cardBack: .cardBackClassic
        case .felt: .feltGreen
        case .pokerTable: .pokerSapphire
        case .reels: .reelsClassic
        case .moonRide: .moonRocket
        case .tetris: .tetrisClassic
        case .mergeTiles: .mergeClassic
        case .snake: .snakeGreen
        case .paddle: .paddleGold
        case .bubbles: .bubblesGlossy
        case .pumpBoard: .pumpExchange
        case .swapTiles: .swapRounded
        case .ship: .shipClassic
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

/// A look for a game: card backs, the tables, slot reels, the moon ride, Block Chain's coins, Merge
/// Mining's tiles, the chain, Hash Smash's paddle, Bubble Market's bubbles, Pump and Dump's board,
/// Token Swap's tiles and the Scam Invaders ship.
public enum Cosmetic: String, CaseIterable, Codable, Sendable, Identifiable {
    case cardBackClassic, cardBackMidnight, cardBackEmerald, cardBackGold
    case feltGreen, feltCrimson, feltBlue
    case pokerSapphire, pokerObsidian, pokerRoseGold
    case reelsClassic, reelsNeon, reelsGold
    case moonRocket, moonLambo, moonSaucer
    case tetrisClassic, tetrisPixel, tetrisGlass
    case mergeClassic, mergeMidnight, mergeGold
    case snakeGreen, snakeRainbow, snakeGold
    case paddleGold, paddleNeon, paddleDiamond
    case bubblesGlossy, bubblesNeon, bubblesPearl
    case pumpExchange, pumpNeon, pumpGold
    case swapRounded, swapBubbles, swapGems
    case shipClassic, shipNeon, shipGold

    public var id: String { rawValue }

    public var slot: CosmeticSlot {
        switch self {
        case .cardBackClassic, .cardBackMidnight, .cardBackEmerald, .cardBackGold: .cardBack
        case .feltGreen, .feltCrimson, .feltBlue: .felt
        case .pokerSapphire, .pokerObsidian, .pokerRoseGold: .pokerTable
        case .reelsClassic, .reelsNeon, .reelsGold: .reels
        case .moonRocket, .moonLambo, .moonSaucer: .moonRide
        case .tetrisClassic, .tetrisPixel, .tetrisGlass: .tetris
        case .mergeClassic, .mergeMidnight, .mergeGold: .mergeTiles
        case .snakeGreen, .snakeRainbow, .snakeGold: .snake
        case .paddleGold, .paddleNeon, .paddleDiamond: .paddle
        case .bubblesGlossy, .bubblesNeon, .bubblesPearl: .bubbles
        case .pumpExchange, .pumpNeon, .pumpGold: .pumpBoard
        case .swapRounded, .swapBubbles, .swapGems: .swapTiles
        case .shipClassic, .shipNeon, .shipGold: .ship
        }
    }

    public var name: String {
        switch self {
        case .cardBackClassic: localized("Classic Red")
        case .cardBackMidnight: localized("Midnight")
        case .cardBackEmerald: localized("Emerald")
        case .cardBackGold: localized("Gold Foil")
        case .feltGreen: localized("Casino Green")
        case .feltCrimson: localized("Crimson")
        case .feltBlue: localized("Royal Blue")
        case .pokerSapphire: localized("Sapphire")
        case .pokerObsidian: localized("Obsidian")
        case .pokerRoseGold: localized("Rose Gold")
        case .reelsClassic: localized("Classic")
        case .reelsNeon: localized("Neon")
        case .reelsGold: localized("Gold")
        case .moonRocket: localized("Rocket")
        case .moonLambo: localized("Lambo")
        case .moonSaucer: localized("Flying Saucer")
        case .tetrisClassic: localized("Coin Chips")
        case .tetrisPixel: localized("Pixel")
        case .tetrisGlass: localized("Glass")
        case .mergeClassic: localized("Classic")
        case .mergeMidnight: localized("Midnight")
        case .mergeGold: localized("Gold Rush")
        case .snakeGreen: localized("Green")
        case .snakeRainbow: localized("Rainbow")
        case .snakeGold: localized("Gold")
        case .paddleGold: localized("Gold")
        case .paddleNeon: localized("Neon")
        case .paddleDiamond: localized("Diamond")
        case .bubblesGlossy: localized("Glossy")
        case .bubblesNeon: localized("Neon")
        case .bubblesPearl: localized("Pearl")
        case .pumpExchange: localized("Exchange")
        case .pumpNeon: localized("Neon")
        case .pumpGold: localized("Gold")
        case .swapRounded: localized("Rounded")
        case .swapBubbles: localized("Bubbles")
        case .swapGems: localized("Gems")
        case .shipClassic: localized("Classic")
        case .shipNeon: localized("Neon")
        case .shipGold: localized("Gold")
        }
    }

    public var unlock: CosmeticUnlock {
        switch self {
        case .cardBackClassic, .feltGreen, .pokerSapphire, .reelsClassic, .moonRocket, .tetrisClassic, .mergeClassic,
             .snakeGreen, .paddleGold, .bubblesGlossy, .pumpExchange, .swapRounded, .shipClassic: .free
        case .swapBubbles: .rank(2)
        case .cardBackMidnight: .rank(3)
        case .cardBackEmerald: .achievement(id: "poker-face", tier: 0)
        case .cardBackGold: .achievement(id: "card-shark", tier: 1)
        case .feltCrimson: .achievement(id: "card-shark", tier: 0)
        case .feltBlue: .rank(6)
        case .pokerObsidian: .rank(9)
        case .pokerRoseGold: .achievement(id: "poker-face", tier: 1)
        case .reelsNeon: .achievement(id: "high-roller", tier: 0)
        case .reelsGold: .rank(10)
        case .moonLambo: .rank(5)
        case .moonSaucer: .achievement(id: "moonshot", tier: 1)
        case .tetrisPixel: .rank(4)
        case .tetrisGlass: .achievement(id: "line-clearer", tier: 1)
        case .mergeMidnight: .rank(11)
        case .mergeGold: .achievement(id: "merge-master", tier: 1)
        case .snakeRainbow: .rank(8)
        case .snakeGold: .achievement(id: "snake-charmer", tier: 1)
        case .paddleNeon: .rank(12)
        case .paddleDiamond: .achievement(id: "boss-slayer", tier: 0)
        case .bubblesNeon: .rank(13)
        case .bubblesPearl: .achievement(id: "bubble-popper", tier: 1)
        case .pumpNeon: .rank(14)
        case .pumpGold: .achievement(id: "whack-a-coin", tier: 1)
        case .swapGems: .achievement(id: "token-swapper", tier: 1)
        case .shipNeon: .rank(7)
        case .shipGold: .achievement(id: "invader-hunter", tier: 1)
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
