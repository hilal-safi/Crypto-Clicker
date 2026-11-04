import Foundation

/// Difficulty trades production for prestige points, so every level has a reason to exist.
/// A run's prestige reward uses the lowest multiplier picked during that run,
/// so switching to Hard just before prestiging earns nothing extra.
public enum Difficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case easy, normal, hard

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .easy: localized("Easy")
        case .normal: localized("Normal")
        case .hard: localized("Hard")
        }
    }

    public var productionMultiplier: Double {
        switch self {
        case .easy: 1.5
        case .normal: 1
        case .hard: 0.6
        }
    }

    public var prestigeMultiplier: Double {
        switch self {
        case .easy: 0.5
        case .normal: 1
        case .hard: 1.5
        }
    }

    public var summary: String {
        switch self {
        case .easy: localized("Miners produce 50% more; prestiges earn half the points.")
        case .normal: localized("The standard balance.")
        case .hard: localized("Miners produce 40% less; prestiges earn 50% more points.")
        }
    }
}
