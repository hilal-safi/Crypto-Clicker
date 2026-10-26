import Foundation

/// The repeatable generators that produce coins every second.
/// From the Desktop on, each tier costs roughly 15x the previous one and pays back about
/// 2.8x slower, so new tiers keep arriving without making older ones worthless.
/// Every tier earns at least one whole coin per second.
public enum MinerID: String, CaseIterable, Codable, Sendable, Identifiable {
    case chromebook, desktop, gpuRig, server, dataCenter
    case mineCenter, robotAssistant, aiMiner, quantumComputer, spaceColony

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
        }
    }

    /// Price of the first unit.
    public var baseCost: Double {
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
        }
    }

    /// Coins per second from one unit before any multipliers.
    public var baseRate: Double {
        switch self {
        case .chromebook: 1
        case .desktop: 2
        case .gpuRig: 12
        case .server: 70
        case .dataCenter: 400
        case .mineCenter: 2_300
        case .robotAssistant: 13_000
        case .aiMiner: 75_000
        case .quantumComputer: 430_000
        case .spaceColony: 2_500_000
        }
    }

    /// Position in the unlock order, starting at 0.
    public var tier: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// The tier that must be owned before this one is revealed.
    public var previous: MinerID? {
        tier == 0 ? nil : Self.allCases[tier - 1]
    }
}
