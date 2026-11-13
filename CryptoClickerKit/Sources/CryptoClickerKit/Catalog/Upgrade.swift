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
}

public enum UpgradeCategory: String, CaseIterable, Sendable {
    case tapping = "Tapping"
    case production = "Production"
    case steps = "Steps"
    case miniGames = "Mini-games"
}

/// One-time purchases. They appear in the shop once this run has earned
/// a tenth of their price, so the list grows as the player does.
///
/// Tapping upgrades keep taps worth having all game long: each makes every tap also earn a share
/// of a second's production, adding up to a whole second's worth per tap at the end.
/// (Offline earnings used to be upgrades here; they are now the Offline Mining power-up.)
public enum UpgradeID: String, CaseIterable, Codable, Sendable, Identifiable {
    case coinClicker, upgradedClicker, automatedClicker, mechanicalKeyboard, roboticFinger, neuralInterface
    case hapticEngine, satoshisTouch
    case overclocking, liquidCooling, fiberUplink, asicChips, immersionCooling, solarFarm, fusionReactor, geothermalPlant, dysonSwarm
    case stepBooster, upgradedStepBooster, ultimateStepBooster, megaStepBooster
    case bonusReward1, bonusReward2, bonusReward3

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .coinClicker: localized("Coin Clicker")
        case .upgradedClicker: localized("Upgraded Clicker")
        case .automatedClicker: localized("Automated Clicker")
        case .mechanicalKeyboard: localized("Mechanical Keyboard")
        case .roboticFinger: localized("Robotic Finger")
        case .neuralInterface: localized("Neural Interface")
        case .hapticEngine: localized("Haptic Engine")
        case .satoshisTouch: localized("Satoshi's Touch")
        case .overclocking: localized("Overclocking")
        case .liquidCooling: localized("Liquid Cooling")
        case .fiberUplink: localized("Fiber Uplink")
        case .asicChips: localized("ASIC Chips")
        case .immersionCooling: localized("Immersion Cooling")
        case .solarFarm: localized("Solar Farm")
        case .fusionReactor: localized("Fusion Reactor")
        case .geothermalPlant: localized("Geothermal Plant")
        case .dysonSwarm: localized("Dyson Swarm")
        case .stepBooster: localized("Step Booster")
        case .upgradedStepBooster: localized("Upgraded Step Booster")
        case .ultimateStepBooster: localized("Ultimate Step Booster")
        case .megaStepBooster: localized("Mega Step Booster")
        case .bonusReward1: localized("Bonus Reward I")
        case .bonusReward2: localized("Bonus Reward II")
        case .bonusReward3: localized("Bonus Reward III")
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
        case .hapticEngine: "waveform.path"
        case .satoshisTouch: "hand.raised.fingers.spread.fill"
        case .overclocking: "speedometer"
        case .liquidCooling: "drop.fill"
        case .fiberUplink: "network"
        case .asicChips: "memorychip.fill"
        case .immersionCooling: "snowflake"
        case .solarFarm: "sun.max.fill"
        case .fusionReactor: "atom"
        case .geothermalPlant: "mountain.2.fill"
        case .dysonSwarm: "sun.dust.fill"
        case .stepBooster: "figure.walk"
        case .upgradedStepBooster: "figure.run"
        case .ultimateStepBooster: "figure.run.circle.fill"
        case .megaStepBooster: "figure.hiking"
        case .bonusReward1: "gift.fill"
        case .bonusReward2: "star.fill"
        case .bonusReward3: "crown.fill"
        }
    }

    /// The price: the list price, raised by the game's pace and the Shop's premium (see
    /// `Tuning.shopPrice`).
    public var cost: Double { Tuning.shopPrice(listCost) }

    /// Whether it adds coins per second or per tap (step and mini-game upgrades raise other rewards).
    public var addsCoins: Bool { category == .tapping || category == .production }

    /// The price before the pace adjustment.
    public var listCost: Double {
        switch self {
        case .coinClicker: 100
        case .upgradedClicker: 2_000
        case .automatedClicker: 20_000
        case .mechanicalKeyboard: 250_000
        case .roboticFinger: 12_000_000
        case .neuralInterface: 250_000_000
        case .hapticEngine: 25_000_000_000
        case .satoshisTouch: 2_500_000_000_000
        case .overclocking: 8_000
        case .liquidCooling: 800_000
        case .fiberUplink: 50_000_000
        case .asicChips: 500_000_000
        case .immersionCooling: 40_000_000
        case .solarFarm: 5_000_000_000
        case .fusionReactor: 500_000_000_000
        case .geothermalPlant: 5_000_000_000_000
        case .dysonSwarm: 50_000_000_000_000
        case .stepBooster: 25_000
        case .upgradedStepBooster: 2_500_000
        case .ultimateStepBooster: 2_500_000_000
        // A mid-to-late game buy, in the trillions, so walking keeps paying as income grows.
        case .megaStepBooster: 1_000_000_000_000
        case .bonusReward1: 50_000
        case .bonusReward2: 50_000_000
        case .bonusReward3: 50_000_000_000
        }
    }

    public var effect: UpgradeEffect {
        switch self {
        case .coinClicker: .tapFlat(1)
        case .upgradedClicker: .tapPercent(0.08)
        case .automatedClicker: .autoTaps(1)
        case .mechanicalKeyboard: .tapPercent(0.12)
        case .roboticFinger: .autoTaps(1)
        case .neuralInterface: .tapPercent(0.20)
        case .hapticEngine: .tapPercent(0.25)
        case .satoshisTouch: .tapPercent(0.35)
        // The first two are weaker, so the opening and the second day go slower; Immersion
        // Cooling makes up for some of that from the third day (steps carry the rest). The last two are weaker too, so later runs
        // don't race (automatic taps and Immersion Cooling made them much faster).
        case .overclocking: .production(1.25)
        case .liquidCooling: .production(1.5)
        case .immersionCooling: .production(1.4)
        case .fiberUplink, .solarFarm, .fusionReactor: .production(2)
        case .asicChips, .dysonSwarm: .production(1.5)
        case .geothermalPlant: .production(1.25)
        case .stepBooster: .steps(1.75)
        case .upgradedStepBooster: .steps(2)
        case .ultimateStepBooster: .steps(3)
        case .megaStepBooster: .steps(1.5)
        case .bonusReward1: .miniGames(1.25)
        case .bonusReward2: .miniGames(1.5)
        case .bonusReward3: .miniGames(2)
        }
    }

    public var category: UpgradeCategory {
        switch effect {
        case .tapFlat, .tapPercent, .autoTaps: .tapping
        case .production: .production
        case .steps: .steps
        case .miniGames: .miniGames
        }
    }

    public var summary: String {
        switch effect {
        case .tapFlat(let value): localized("Taps earn +\(CoinFormat.short(value)) coin")
        case .tapPercent(let share): localized("Every tap also earns \(CoinFormat.percent(share)) of a second's production")
        case .autoTaps(let rate):
            rate == 1
                ? localized("+1 automatic tap per second, worth \(CoinFormat.percent(Tuning.autoTapStrength)) of a tap")
                : localized("+\(CoinFormat.short(rate)) automatic taps per second, worth \(CoinFormat.percent(Tuning.autoTapStrength)) of a tap")
        case .production(let factor): localized("All miners produce \(CoinFormat.multiplier(factor))")
        case .steps(let factor): localized("Steps earn \(CoinFormat.multiplier(factor))")
        case .miniGames(let factor): localized("Mini-game rewards \(CoinFormat.multiplier(factor))")
        }
    }

    /// Upgrades from earlier versions that are now Offline Mining, and the hours away each grants.
    static let legacyOfflineHours: [String: Double] = ["cloudBackup": 4, "serverLease": 8, "alwaysOnRig": 24]
}
