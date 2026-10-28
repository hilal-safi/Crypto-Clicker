import Foundation

/// The repeatable generators that produce coins every second.
/// From the Desktop on, each tier costs roughly 15x the previous one and pays back about
/// 2.8x slower, so new tiers keep arriving without making older ones worthless.
/// The Chromebook earns a coin every two seconds and every later tier at least a coin a second.
/// The last three tiers open up only after the first prestige.
public enum MinerID: String, CaseIterable, Codable, Sendable, Identifiable {
    case chromebook, desktop, gpuRig, server, dataCenter
    case mineCenter, robotAssistant, aiMiner, quantumComputer, spaceColony
    case lunarBase, asteroidHarvester, galacticHashnet

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .chromebook: "Chromebook"
        case .desktop: "Desktop"
        case .gpuRig: "GPU Rig"
        case .server: "Server"
        case .dataCenter: "Data Center"
        case .mineCenter: "Mine Center"
        case .robotAssistant: "Robot Assistant"
        case .aiMiner: "AI Miner"
        case .quantumComputer: "Quantum Computer"
        case .spaceColony: "Space Mining Colony"
        case .lunarBase: "Lunar Base"
        case .asteroidHarvester: "Asteroid Harvester"
        case .galacticHashnet: "Galactic Hashnet"
        }
    }

    /// The name for several units: "Chromebooks", "Space Mining Colonies".
    public var pluralName: String {
        switch self {
        case .spaceColony: "Space Mining Colonies"
        default: name + "s"
        }
    }

    public var emoji: String {
        switch self {
        case .chromebook: "💻"
        case .desktop: "🖥️"
        case .gpuRig: "🎮"
        case .server: "📡"
        case .dataCenter: "🏢"
        case .mineCenter: "⛏️"
        case .robotAssistant: "🤖"
        case .aiMiner: "🧠"
        case .quantumComputer: "🔮"
        case .spaceColony: "🚀"
        case .lunarBase: "🌕"
        case .asteroidHarvester: "☄️"
        case .galacticHashnet: "🌌"
        }
    }

    public var blurb: String {
        switch self {
        case .chromebook: "A trusty laptop for light-duty mining."
        case .desktop: "More cores, more coins."
        case .gpuRig: "Six graphics cards and a lot of fans."
        case .server: "Rack-mounted hashing around the clock."
        case .dataCenter: "A warehouse of humming servers."
        case .mineCenter: "An industrial mining operation."
        case .robotAssistant: "Tireless robots that never stop mining."
        case .aiMiner: "Machine learning finds blocks faster."
        case .quantumComputer: "Qubits crack hashes in parallel."
        case .spaceColony: "Mining at a cosmic scale, off-world."
        case .lunarBase: "Low gravity, high hash rate."
        case .asteroidHarvester: "Crunches space rocks into blocks."
        case .galacticHashnet: "A mining network across the galaxy."
        }
    }

    /// Price of the first unit: the list price, raised by the game's pace (see `Tuning.scaledPrice`).
    public var baseCost: Double { Tuning.scaledPrice(listCost) }

    /// Price of the first unit before the pace adjustment.
    public var listCost: Double {
        switch self {
        case .chromebook: 50
        case .desktop: 200
        case .gpuRig: 3_000
        case .server: 45_000
        case .dataCenter: 700_000
        case .mineCenter: 11_000_000
        case .robotAssistant: 180_000_000
        case .aiMiner: 3_000_000_000
        case .quantumComputer: 50_000_000_000
        case .spaceColony: 900_000_000_000
        case .lunarBase: 16_000_000_000_000
        case .asteroidHarvester: 290_000_000_000_000
        case .galacticHashnet: 5_200_000_000_000_000
        }
    }

    /// Coins per second from one unit before any multipliers. (Halved in version 31 to slow the
    /// game down: every tier earned twice this before.)
    public var baseRate: Double {
        switch self {
        case .chromebook: 0.5
        case .desktop: 1
        case .gpuRig: 6
        case .server: 35
        case .dataCenter: 200
        case .mineCenter: 1_150
        case .robotAssistant: 6_500
        case .aiMiner: 37_500
        case .quantumComputer: 215_000
        case .spaceColony: 1_250_000
        case .lunarBase: 7_250_000
        case .asteroidHarvester: 42_000_000
        case .galacticHashnet: 245_000_000
        }
    }

    /// Tiers that only appear after the first prestige.
    public var needsPrestige: Bool { tier >= MinerID.lunarBase.tier }

    /// The name of the Mk upgrade at `level` (0 is Mk II): "GPU Rig Mk II".
    public func upgradeName(level: Int) -> String {
        "\(name) Mk \(Self.markName(level: level))"
    }

    /// The mark an upgrade level gives: "II" for level 0, up to "VI".
    public static func markName(level: Int) -> String {
        let marks = ["II", "III", "IV", "V", "VI"]
        return marks.indices.contains(level) ? marks[level] : "\(level + 2)"
    }

    /// Position in the unlock order, starting at 0.
    public var tier: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// The tier that must be owned before this one is revealed.
    public var previous: MinerID? {
        tier == 0 ? nil : Self.allCases[tier - 1]
    }
}
