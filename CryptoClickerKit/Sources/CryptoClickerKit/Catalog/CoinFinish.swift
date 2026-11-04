import Foundation

/// Finishes for the coin on the Mine screen, unlocked by achievement stars. Purely cosmetic:
/// the choice is a preference on the device, not part of the saved game.
public enum CoinFinish: String, CaseIterable, Codable, Sendable, Identifiable {
    case gold, silver, roseGold, emerald, sapphire, amethyst, obsidian, holographic

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .gold: localized("Gold")
        case .silver: localized("Silver")
        case .roseGold: localized("Rose Gold")
        case .emerald: localized("Emerald")
        case .sapphire: localized("Sapphire")
        case .amethyst: localized("Amethyst")
        case .obsidian: localized("Obsidian")
        case .holographic: localized("Holographic")
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

/// What rings the coin on the Mine screen: nothing, a glow, or something livelier. Unlocked by
/// achievement stars, like the finishes, and just as cosmetic: a preference on the device.
public enum CoinRim: String, CaseIterable, Codable, Sendable, Identifiable {
    case plain, glow, neon, pulse, orbit, fire, rainbow, diamond

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .plain: localized("Plain")
        case .glow: localized("Glow")
        case .neon: localized("Neon")
        case .pulse: localized("Pulse")
        case .orbit: localized("Orbit")
        case .fire: localized("Fire Ring")
        case .rainbow: localized("Rainbow")
        case .diamond: localized("Diamond")
        }
    }

    /// What it looks like, in a few words.
    public var detail: String {
        switch self {
        case .plain: localized("Just the coin's edge")
        case .glow: localized("A soft glow in the finish's color")
        case .neon: localized("A bright neon tube")
        case .pulse: localized("A glow that beats like a heart")
        case .orbit: localized("Sparks circling the edge")
        case .fire: localized("A ring of flickering flame")
        case .rainbow: localized("Every color, turning")
        case .diamond: localized("Glinting facets all around")
        }
    }

    /// Achievement stars needed to use this rim.
    public var starsNeeded: Int {
        switch self {
        case .plain: 0
        case .glow: 3
        case .neon: 10
        case .pulse: 20
        case .orbit: 35
        case .fire: 50
        case .rainbow: 70
        case .diamond: 90
        }
    }

    public func isUnlocked(stars: Int) -> Bool { stars >= starsNeeded }
}

/// What a tap on the coin sets off, on top of the coins it earned floating up. Unlocked by
/// achievement stars, like the finishes and rims.
public enum CoinTapEffect: String, CaseIterable, Codable, Sendable, Identifiable {
    case none, ripple, sparks, coinBurst, rockets, lightning, hashStorm

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .none: localized("Numbers Only")
        case .ripple: localized("Ripple")
        case .sparks: localized("Sparks")
        case .coinBurst: localized("Coin Burst")
        case .rockets: localized("To the Moon")
        case .lightning: localized("Lightning")
        case .hashStorm: localized("Hash Storm")
        }
    }

    public var detail: String {
        switch self {
        case .none: localized("The coins you earn, and nothing more")
        case .ripple: localized("A ring rolls out from the coin")
        case .sparks: localized("Golden sparks fly off")
        case .coinBurst: localized("Little coins spray out and fall")
        case .rockets: localized("Rockets lift off")
        case .lightning: localized("A bolt cracks across the coin")
        case .hashStorm: localized("Hashes swirl up around it")
        }
    }

    /// Achievement stars needed to use this effect.
    public var starsNeeded: Int {
        switch self {
        case .none: 0
        case .ripple: 8
        case .sparks: 18
        case .coinBurst: 28
        case .rockets: 40
        case .lightning: 60
        case .hashStorm: 80
        }
    }

    public func isUnlocked(stars: Int) -> Bool { stars >= starsNeeded }
}
