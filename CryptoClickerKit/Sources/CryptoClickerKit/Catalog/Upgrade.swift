import Foundation

/// What a one-time upgrade does once bought.
public enum UpgradeEffect: Sendable, Equatable {
    /// Adds to the flat value of every tap.
    case tapFlat(Double)
    /// Taps also earn this share of production per second.
    case tapPercent(Double)
    /// Taps performed automatically every second.
    case autoTaps(Double)
    /// Multiplies all miner production.
    case production(Double)
    /// Multiplies step rewards.
    case steps(Double)
    /// Multiplies mini-game rewards.
    case miniGames(Double)
    /// Raises the offline earnings cap to this many seconds.
    case offlineCap(TimeInterval)
}

public enum UpgradeCategory: String, CaseIterable, Sendable {
    case tapping = "Tapping"
    case production = "Production"
    case steps = "Steps"
    case miniGames = "Mini-games"
    case offline = "Offline"
}

/// One-time purchases. They appear in the shop once this run has earned
/// a tenth of their price, so the list grows as the player does.
public enum UpgradeID: String, CaseIterable, Codable, Sendable, Identifiable {
    case coinClicker, upgradedClicker, automatedClicker, mechanicalKeyboard, roboticFinger, neuralInterface
    case overclocking, liquidCooling, fiberUplink, solarFarm, fusionReactor, dysonSwarm
    case stepBooster, upgradedStepBooster, ultimateStepBooster
    case bonusReward1, bonusReward2, bonusReward3
    case cloudBackup, serverLease, alwaysOnRig

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .coinClicker: "Coin Clicker"
        case .upgradedClicker: "Upgraded Clicker"
        case .automatedClicker: "Automated Clicker"
        case .mechanicalKeyboard: "Mechanical Keyboard"
        case .roboticFinger: "Robotic Finger"
        case .neuralInterface: "Neural Interface"
        case .overclocking: "Overclocking"
        case .liquidCooling: "Liquid Cooling"
        case .fiberUplink: "Fiber Uplink"
        case .solarFarm: "Solar Farm"
        case .fusionReactor: "Fusion Reactor"
        case .dysonSwarm: "Dyson Swarm"
        case .stepBooster: "Step Booster"
        case .upgradedStepBooster: "Upgraded Step Booster"
        case .ultimateStepBooster: "Ultimate Step Booster"
        case .bonusReward1: "Bonus Reward I"
        case .bonusReward2: "Bonus Reward II"
        case .bonusReward3: "Bonus Reward III"
        case .cloudBackup: "Cloud Backup"
        case .serverLease: "Server Lease"
        case .alwaysOnRig: "Always-On Rig"
        }
    }

    /// SF Symbol shown in the shop.
    public var symbol: String {
        switch self {
        case .coinClicker: "hand.tap.fill"
        case .upgradedClicker: "cursorarrow.click.2"
        case .automatedClicker: "gearshape.2.fill"
        case .mechanicalKeyboard: "keyboard.fill"
        case .roboticFinger: "hand.point.up.braille.fill"
        case .neuralInterface: "brain.head.profile"
        case .overclocking: "speedometer"
        case .liquidCooling: "drop.fill"
        case .fiberUplink: "network"
        case .solarFarm: "sun.max.fill"
        case .fusionReactor: "atom"
        case .dysonSwarm: "sun.dust.fill"
        case .stepBooster: "figure.walk"
        case .upgradedStepBooster: "figure.run"
        case .ultimateStepBooster: "figure.run.circle.fill"
        case .bonusReward1: "gift.fill"
        case .bonusReward2: "star.fill"
        case .bonusReward3: "crown.fill"
        case .cloudBackup: "icloud.fill"
        case .serverLease: "server.rack"
        case .alwaysOnRig: "bolt.horizontal.fill"
        }
    }

    public var cost: Double {
        switch self {
        case .coinClicker: 50
        case .upgradedClicker: 2_500
        case .automatedClicker: 10_000
        case .mechanicalKeyboard: 250_000
        case .roboticFinger: 10_000_000
        case .neuralInterface: 250_000_000
        case .overclocking: 5_000
        case .liquidCooling: 500_000
        case .fiberUplink: 50_000_000
        case .solarFarm: 5_000_000_000
        case .fusionReactor: 500_000_000_000
        case .dysonSwarm: 50_000_000_000_000
        case .stepBooster: 1_000
        case .upgradedStepBooster: 1_000_000
        case .ultimateStepBooster: 1_000_000_000
        case .bonusReward1: 5_000
        case .bonusReward2: 5_000_000
        case .bonusReward3: 5_000_000_000
        case .cloudBackup: 20_000
        case .serverLease: 20_000_000
        case .alwaysOnRig: 20_000_000_000
        }
    }

    public var effect: UpgradeEffect {
        switch self {
        case .coinClicker: .tapFlat(1)
        case .upgradedClicker: .tapPercent(0.01)
        case .automatedClicker: .autoTaps(1)
        case .mechanicalKeyboard: .tapPercent(0.02)
        case .roboticFinger: .autoTaps(2)
        case .neuralInterface: .tapPercent(0.03)
        case .overclocking, .liquidCooling, .fiberUplink, .solarFarm, .fusionReactor, .dysonSwarm: .production(2)
        case .stepBooster, .upgradedStepBooster: .steps(2)
        case .ultimateStepBooster: .steps(3)
        case .bonusReward1: .miniGames(1.25)
        case .bonusReward2: .miniGames(1.5)
        case .bonusReward3: .miniGames(2)
        case .cloudBackup: .offlineCap(4 * 3_600)
        case .serverLease: .offlineCap(8 * 3_600)
        case .alwaysOnRig: .offlineCap(24 * 3_600)
        }
    }

    public var category: UpgradeCategory {
        switch effect {
        case .tapFlat, .tapPercent, .autoTaps: .tapping
        case .production: .production
        case .steps: .steps
        case .miniGames: .miniGames
        case .offlineCap: .offline
        }
    }

    public var summary: String {
        switch effect {
        case .tapFlat(let value): "Taps earn +\(CoinFormat.short(value)) coin"
        case .tapPercent(let share): "Taps also earn \(CoinFormat.percent(share)) of production"
        case .autoTaps(let rate): "+\(CoinFormat.short(rate)) automatic tap\(rate == 1 ? "" : "s") per second"
        case .production(let factor): "All miners produce \(CoinFormat.multiplier(factor))"
        case .steps(let factor): "Steps earn \(CoinFormat.multiplier(factor))"
        case .miniGames(let factor): "Mini-game rewards \(CoinFormat.multiplier(factor))"
        case .offlineCap(let seconds): "Earn offline for up to \(CoinFormat.duration(seconds))"
        }
    }
}
