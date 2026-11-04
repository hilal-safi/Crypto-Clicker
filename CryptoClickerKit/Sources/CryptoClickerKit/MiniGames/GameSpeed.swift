import Foundation

/// How fast an action game runs, picked before a game: Brick Breaker's ball, the snake, and
/// Tetris's falling pieces. Points are worth the same at every speed, so Fast scores quicker but
/// is harder to survive, and Slow is relaxed but scores more slowly.
public enum GameSpeed: String, CaseIterable, Codable, Sendable, Identifiable {
    case slow, normal, fast

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .slow: localized("Slow")
        case .normal: localized("Normal")
        case .fast: localized("Fast")
        }
    }

    /// How much faster than Normal things move.
    public var factor: Double {
        switch self {
        case .slow: 0.75
        case .normal: 1
        case .fast: 1.3
        }
    }

    /// An SF Symbol for the speed.
    public var icon: String {
        switch self {
        case .slow: "tortoise.fill"
        case .normal: "gauge.with.dots.needle.50percent"
        case .fast: "hare.fill"
        }
    }
}
