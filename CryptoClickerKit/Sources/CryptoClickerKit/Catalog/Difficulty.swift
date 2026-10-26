import Foundation

/// Difficulty trades production for Hard Fork rewards, so every level has a reason to exist.
/// A run's fork reward uses the lowest multiplier picked during that run,
/// so switching to Hard just before forking earns nothing extra.
public enum Difficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case easy, normal, hard

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    public var productionMultiplier: Double {
        switch self {
        case .easy: 1.5
        case .normal: 1
        case .hard: 0.6
        }
    }

    public var forkMultiplier: Double {
        switch self {
        case .easy: 0.5
        case .normal: 1
        case .hard: 1.5
        }
    }

    public var summary: String {
        switch self {
        case .easy: "Miners produce 50% more; Hard Forks pay half."
        case .normal: "The standard balance."
        case .hard: "Miners produce 40% less; Hard Forks pay 50% more."
        }
    }
}
