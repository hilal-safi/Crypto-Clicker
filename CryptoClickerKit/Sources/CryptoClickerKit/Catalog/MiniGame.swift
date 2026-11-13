import Foundation

/// Mini-games, unlocked with coins in the Arcade. Casino games are played with tokens from the
/// Shop's Tokens page; arcade games pay coins for every point scored.
///
/// Everything about a game except its rules lives in `info`, so adding a game starts there. The
/// rules live in the game's engine (in MiniGames), what it pays and records in MiniGameActions,
/// and its screen in the app.
public enum MiniGame: String, CaseIterable, Codable, Sendable, Identifiable {
    case blackjack, slots, moon, videoPoker
    case tetris, merge2048, snake, brickBreaker, bubbleBlaster, pumpDump, tokenSwap, invaders

    public var id: String { rawValue }

    /// The game's name, picture, pitch, price, color and pay.
    public var info: MiniGameInfo {
        switch self {
        case .blackjack:
            MiniGameInfo(name: localized("21 Million"), icon: "🃏", category: .casino, listCost: 1_000,
                         pitch: localized("Get closer to 21 than the dealer, betting tokens. Wins pay a coin bonus that grows with your bet."),
                         color: .init(red: 0.05, green: 0.47, blue: 0.25))
        case .slots:
            MiniGameInfo(name: localized("Crypto Slots"), icon: "🎰", category: .casino, listCost: 45e6,
                         pitch: localized("Spin three reels of crypto. Three Bitcoins pay 500 times your bet."),
                         color: .init(red: 0.60, green: 0.20, blue: 0.75))
        case .moon:
            MiniGameInfo(name: localized("To the Moon"), icon: "🚀", category: .casino, listCost: 250e9,
                         pitch: localized("Ride the chart as the multiplier climbs. Cash out before the market crashes."),
                         color: .init(red: 0.24, green: 0.22, blue: 0.62))
        case .tetris:
            MiniGameInfo(name: localized("Block Chain"), icon: "⛓️", category: .arcade, listCost: 4_000,
                         pitch: localized("Stack coin blocks into full rows to mine them, before the gas spikes push the stack up."),
                         color: .init(red: 0.00, green: 0.46, blue: 0.62),
                         secondsPerPoint: Tuning.tetrisSecondsPerPoint)
        case .merge2048:
            MiniGameInfo(name: localized("Merge Mining"), icon: "⛏️", category: .arcade, listCost: 150e6,
                         pitch: localized("Slide miners together to upgrade them, from a Chromebook up. Build a Lunar Base for a bonus."),
                         color: .init(red: 0.75, green: 0.13, blue: 0.42),
                         secondsPerPoint: Tuning.merge2048SecondsPerPoint)
        case .snake:
            MiniGameInfo(name: localized("Hash Chain"), icon: "🔗", category: .arcade, listCost: 35_000,
                         pitch: localized("Mine coins to add blocks to your chain, but never cross your own blocks."),
                         color: .init(red: 0.22, green: 0.50, blue: 0.08),
                         secondsPerPoint: Tuning.snakeSecondsPerPoint)
        case .brickBreaker:
            MiniGameInfo(name: localized("Hash Smash"), icon: "💥", category: .arcade, listCost: 80e9,
                         pitch: localized("Smash every hash block with the coin ball. Each level is faster, and the whale comes every fifth."),
                         color: .init(red: 0.75, green: 0.33, blue: 0.00),
                         secondsPerPoint: Tuning.brickBreakerSecondsPerPoint)
        case .bubbleBlaster:
            MiniGameInfo(name: localized("Bubble Market"), icon: "🫧", category: .arcade, listCost: 10e9,
                         pitch: localized("Pop three token bubbles of a kind before the market sinks to the crash line."),
                         color: .init(red: 0.00, green: 0.40, blue: 0.90),
                         secondsPerPoint: Tuning.bubbleSecondsPerPoint)
        case .videoPoker:
            MiniGameInfo(name: localized("Diamond Hands"), icon: "💎", category: .casino, listCost: 300_000,
                         pitch: localized("HODL the cards you believe in and draw once. A royal flush pays 800 to 1."),
                         color: .init(red: 0.55, green: 0.38, blue: 0.04))
        case .tokenSwap:
            MiniGameInfo(name: localized("Token Swap"), icon: "🪙", category: .arcade, listCost: 6e6,
                         pitch: localized("Swap neighboring tokens to line up three or more. Big matches leave Blasts behind."),
                         color: .init(red: 0.00, green: 0.46, blue: 0.38),
                         secondsPerPoint: Tuning.tokenSwapSecondsPerPoint)
        case .invaders:
            MiniGameInfo(name: localized("Scam Invaders"), icon: "👾", category: .arcade, listCost: 1e12,
                         pitch: localized("Shoot down the scam tokens before they land. Hide behind the server racks."),
                         color: .init(red: 0.32, green: 0.16, blue: 0.92),
                         secondsPerPoint: Tuning.invadersSecondsPerPoint)
        case .pumpDump:
            MiniGameInfo(name: localized("Pump and Dump"), icon: "📈", category: .arcade, listCost: 1.2e9,
                         pitch: localized("Tap the coins as they list before they're delisted. Dodge scam tokens and rug pulls."),
                         color: .init(red: 0.72, green: 0.10, blue: 0.16),
                         secondsPerPoint: Tuning.pumpDumpSecondsPerPoint)
        }
    }

    public var name: String { info.name }

    /// The price to unlock: the list price, raised by the game's pace (see `Tuning.scaledPrice`).
    /// Blackjack and Tetris cost a few thousand coins; each game after costs several times the one
    /// before, up to Scam Invaders at about one and a half trillion, spread over the first run so a
    /// new game comes every half day or so until the first prestige (see `PacingTests`).
    public var unlockCost: Double { Tuning.scaledPrice(listCost) }

    /// The unlock price before the pace adjustment.
    public var listCost: Double { info.listCost }

    /// Casino games are bet with tokens; the others are scored arcade games.
    public var isCasino: Bool { info.category == .casino }

    /// Seconds of idle income an arcade game pays per point (0 for casino games).
    public var secondsPerPoint: Double { info.secondsPerPoint }

    /// Casino games, then arcade games, each cheapest first: the order the Arcade lists them.
    public static var byPrice: [MiniGame] {
        allCases.sorted { ($0.isCasino ? 0 : 1, $0.listCost) < ($1.isCasino ? 0 : 1, $1.listCost) }
    }
}

/// What the Arcade shows for a game, what it costs and how it pays.
public struct MiniGameInfo: Sendable {
    public enum Category: Sendable {
        case casino, arcade
    }

    /// Red, green and blue from 0 to 1.
    public struct RGB: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
    }

    public let name: String
    /// An emoji.
    public let icon: String
    public let category: Category
    /// The unlock price before the pace adjustment.
    public let listCost: Double
    /// One line on how to play.
    public let pitch: String
    /// The game's color: deep enough for white text on it to read clearly (at least 4.5:1).
    public let color: RGB
    /// Seconds of idle income paid per point; 0 for casino games, which pay bonuses instead.
    public var secondsPerPoint: Double = 0
}
