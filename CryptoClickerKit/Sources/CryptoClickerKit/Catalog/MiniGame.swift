import Foundation

/// Mini-games, unlocked with coins in the Arcade. Casino games are played with tokens from the
/// Coin Exchange; arcade games pay coins for every point scored.
public enum MiniGame: String, CaseIterable, Codable, Sendable, Identifiable {
    case blackjack, slots, tetris, merge2048, snake, brickBreaker, bubbleBlaster

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .blackjack: "Blackjack"
        case .slots: "Crypto Slots"
        case .tetris: "Tetris"
        case .merge2048: "2048"
        case .snake: "Snake"
        case .brickBreaker: "Brick Breaker"
        case .bubbleBlaster: "Bubble Blaster"
        }
    }

    /// The price to unlock: the list price, raised by the game's pace (see `Tuning.scaledPrice`).
    public var unlockCost: Double { Tuning.scaledPrice(listCost) }

    /// The unlock price before the pace adjustment.
    public var listCost: Double {
        switch self {
        case .blackjack: 1_000
        case .snake: 2_500
        case .slots: 5_000
        case .tetris: 10_000
        case .merge2048: 25_000
        case .brickBreaker: 50_000
        case .bubbleBlaster: 250_000
        }
    }

    /// Casino games are bet with tokens; the others are scored arcade games.
    public var isCasino: Bool { self == .blackjack || self == .slots }
}
