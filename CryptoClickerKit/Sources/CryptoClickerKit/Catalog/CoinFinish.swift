import Foundation

/// Finishes for the coin on the Mine screen, unlocked by achievement stars. Purely cosmetic:
/// the choice is a preference on the device, not part of the saved game.
public enum CoinFinish: String, CaseIterable, Codable, Sendable, Identifiable {
    case gold, silver, roseGold, emerald, sapphire, amethyst, obsidian, holographic

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .gold: "Gold"
        case .silver: "Silver"
        case .roseGold: "Rose Gold"
        case .emerald: "Emerald"
        case .sapphire: "Sapphire"
        case .amethyst: "Amethyst"
        case .obsidian: "Obsidian"
        case .holographic: "Holographic"
        }
    }

    /// Achievement stars needed to use this finish.
    public var starsNeeded: Int {
        switch self {
        case .gold: 0
        case .silver: 5
        case .roseGold: 15
        case .emerald: 30
        case .sapphire: 45
        case .amethyst: 60
        case .obsidian: 80
        case .holographic: 100
        }
    }

    public func isUnlocked(stars: Int) -> Bool { stars >= starsNeeded }
}
