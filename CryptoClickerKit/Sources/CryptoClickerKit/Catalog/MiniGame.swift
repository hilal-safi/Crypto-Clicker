import Foundation

/// Mini-games, unlocked with coins in the Arcade. Casino games are played with tokens from the
/// Coin Exchange; arcade games pay coins for every point scored.
///
/// Everything about a game except its rules lives in `info`, so adding a game starts there. The
/// rules live in the game's engine (in MiniGames), what it pays and records in MiniGameActions,
/// and its screen in the app.
public enum MiniGame: String, CaseIterable, Codable, Sendable, Identifiable {
    case blackjack, slots, moon
    case tetris, merge2048, snake, brickBreaker, bubbleBlaster, pumpDump

    public var id: String { rawValue }

    public var info: MiniGameInfo {
        switch self {
        case .blackjack:
            MiniGameInfo(name: "Blackjack", icon: "🃏", category: .casino, listCost: 1_000,
                         pitch: "Beat the dealer with tokens. Wins pay a coin bonus that grows with your bet.",
                         color: .init(red: 0.05, green: 0.47, blue: 0.25))
        case .slots:
            MiniGameInfo(name: "Crypto Slots", icon: "🎰", category: .casino, listCost: 5_000,
                         pitch: "Spin three reels of crypto. Three Bitcoins pay 500 times your bet.",
                         color: .init(red: 0.60, green: 0.20, blue: 0.75))
        case .moon:
            MiniGameInfo(name: "To the Moon", icon: "🚀", category: .casino, listCost: 20_000,
                         pitch: "Ride the chart as the multiplier climbs. Cash out before the market crashes.",
                         color: .init(red: 0.24, green: 0.22, blue: 0.62))
        case .tetris:
            MiniGameInfo(name: "Tetris", icon: "🧱", category: .arcade, listCost: 10_000,
                         pitch: "Clear lines for points. Every point pays coins.",
                         color: .init(red: 0.00, green: 0.46, blue: 0.62),
                         secondsPerPoint: Tuning.tetrisSecondsPerPoint)
        case .merge2048:
            MiniGameInfo(name: "2048", icon: "🔢", category: .arcade, listCost: 25_000,
                         pitch: "Slide numbered tiles and merge matching pairs. Make 2048 for a bonus.",
                         color: .init(red: 0.75, green: 0.13, blue: 0.42),
                         secondsPerPoint: Tuning.merge2048SecondsPerPoint)
        case .snake:
            MiniGameInfo(name: "Snake", icon: "🐍", category: .arcade, listCost: 2_500,
                         pitch: "Eat coins and grow longer, but don't bite your own tail.",
                         color: .init(red: 0.22, green: 0.50, blue: 0.08),
                         secondsPerPoint: Tuning.snakeSecondsPerPoint)
        case .brickBreaker:
            MiniGameInfo(name: "Brick Breaker", icon: "💥", category: .arcade, listCost: 50_000,
                         pitch: "Smash every brick with the coin ball. Each level is faster.",
                         color: .init(red: 0.75, green: 0.33, blue: 0.00),
                         secondsPerPoint: Tuning.brickBreakerSecondsPerPoint)
        case .bubbleBlaster:
            MiniGameInfo(name: "Bubble Blaster", icon: "🫧", category: .arcade, listCost: 250_000,
                         pitch: "Match three bubbles to pop them. Cut-off clusters fall for double points.",
                         color: .init(red: 0.00, green: 0.40, blue: 0.90),
                         secondsPerPoint: Tuning.bubbleSecondsPerPoint)
        case .pumpDump:
            MiniGameInfo(name: "Pump and Dump", icon: "🔨", category: .arcade, listCost: 7_500,
                         pitch: "Tap the coins before they vanish. Dodge scam tokens and rug pulls.",
                         color: .init(red: 0.72, green: 0.10, blue: 0.16),
                         secondsPerPoint: Tuning.pumpDumpSecondsPerPoint)
        }
    }

    public var name: String { info.name }

    /// The price to unlock: the list price, raised by the game's pace (see `Tuning.scaledPrice`).
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
