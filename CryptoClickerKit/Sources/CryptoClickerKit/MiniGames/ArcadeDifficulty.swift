import Foundation

/// How hard an action game plays, picked on its start screen: Scam Invaders and Hash Smash. Each
/// brings its own speed, and the game adds its own twist (hits a ship takes, the paddle's width).
/// Easy pays 20% less a point, and Hard 20% more.
public enum ArcadeDifficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case easy, regular, hard

    public var id: String { rawValue }

    /// The difficulty that plays like an earlier version's Speed setting: Slow is Easy, Normal
    /// Regular and Fast Hard (ships always died in one hit, and Hard keeps that).
    public init(speed: GameSpeed) {
        switch speed {
        case .slow: self = .easy
        case .normal: self = .regular
        case .fast: self = .hard
        }
    }

    public var name: String {
        switch self {
        case .easy: localized("Easy")
        case .regular: localized("Regular")
        case .hard: localized("Hard")
        }
    }

    /// How fast everything moves.
    public var speed: GameSpeed {
        switch self {
        case .easy: .slow
        case .regular: .normal
        case .hard: .fast
        }
    }

    /// What a point pays, against Regular.
    public var payMultiplier: Double {
        switch self {
        case .easy: 0.8
        case .regular: 1
        case .hard: 1.2
        }
    }
}
