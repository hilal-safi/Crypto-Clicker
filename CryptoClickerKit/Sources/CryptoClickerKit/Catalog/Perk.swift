import Foundation

/// The three branches of the perk tree.
public enum PerkBranch: String, CaseIterable, Sendable, Identifiable {
    case mining = "Mining"
    case tapping = "Tapping"
    case fortune = "Fortune"

    public var id: String { rawValue }

    /// The branch's name in the player's language.
    public var name: String {
        switch self {
        case .mining: localized("Mining")
        case .tapping: localized("Tapping")
        case .fortune: localized("Fortune")
        }
    }
}

/// Permanent perks bought with prestige points. Spending points never lowers the production
/// bonus they give: that bonus counts every point ever earned. Some perks need another first.
public enum PerkID: String, CaseIterable, Codable, Sendable, Identifiable {
    case headStart, blueprints, bulkDiscount, engineeringTeam, compoundInterest
    case strongFingers, muscleMemory, comboMaster, autoClickerPro
    case airdropRadar, bullMarket, whaleWatcher, marketInsider, arcadeChampion, marathon, luckyStreak

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .headStart: localized("Head Start")
        case .blueprints: localized("Blueprints")
        case .bulkDiscount: localized("Bulk Discount")
        case .engineeringTeam: localized("Engineering Team")
        case .compoundInterest: localized("Compound Interest")
        case .strongFingers: localized("Strong Fingers")
        case .muscleMemory: localized("Muscle Memory")
        case .comboMaster: localized("Combo Master")
        case .autoClickerPro: localized("Auto Clicker Pro")
        case .airdropRadar: localized("Airdrop Radar")
        case .bullMarket: localized("Bull Market")
        case .whaleWatcher: localized("Whale Watcher")
        case .marketInsider: localized("Market Insider")
        case .arcadeChampion: localized("Arcade Champion")
        case .marathon: localized("Marathon")
        case .luckyStreak: localized("Lucky Streak")
        }
    }

    public var summary: String {
        switch self {
        case .headStart: localized("Start every run with 10 Chromebooks, 10 Desktops and 5 GPU Rigs")
        case .blueprints: localized("Keep production upgrades when you prestige")
        case .bulkDiscount: localized("Miners cost 10% less")
        case .engineeringTeam: localized("Keep miner Mk upgrades when you prestige")
        case .compoundInterest: localized("Every achievement star adds 2% production instead of 1%")
        case .strongFingers: localized("Taps earn 50% more")
        case .muscleMemory: localized("Keep tapping upgrades when you prestige")
        case .comboMaster: localized("Combos build twice as fast and reach at least ×3")
        case .autoClickerPro: localized("Automatic taps are worth twice as much: a whole tap")
        case .airdropRadar: localized("Airdrops come every 2–4 minutes and stay for 30 seconds")
        case .bullMarket: localized("Bull Runs last 2 minutes")
        case .whaleWatcher: localized("Whale airdrops are three times as likely")
        case .marketInsider: localized("Sell tokens with no fee")
        case .arcadeChampion: localized("Mini-game and casino coin rewards ×1.5")
        case .marathon: localized("Steps earn ×2")
        case .luckyStreak: localized("Daily quest and streak rewards ×2")
        }
    }

    /// SF Symbol shown in the perk tree.
    public var symbol: String {
        switch self {
        case .headStart: "flag.checkered"
        case .blueprints: "doc.text.fill"
        case .bulkDiscount: "tag.fill"
        case .engineeringTeam: "wrench.and.screwdriver.fill"
        case .compoundInterest: "chart.line.uptrend.xyaxis"
        case .strongFingers: "hand.point.up.fill"
        case .muscleMemory: "brain.fill"
        case .comboMaster: "flame.fill"
        case .autoClickerPro: "cursorarrow.click.2"
        case .airdropRadar: "dot.radiowaves.left.and.right"
        case .bullMarket: "chart.bar.fill"
        case .whaleWatcher: "binoculars.fill"
        case .marketInsider: "building.columns.fill"
        case .arcadeChampion: "gamecontroller.fill"
        case .marathon: "figure.run"
        case .luckyStreak: "calendar.badge.checkmark"
        }
    }

    /// Price in prestige points: each perk costs about half again to twice the one before, as points
    /// grow. The first prestige affords a few cheap perks, and the last one comes after about three
    /// weeks of prestiging.
    public var cost: Int {
        switch self {
        case .headStart: 1
        case .strongFingers: 2
        case .airdropRadar: 4
        case .marketInsider: 8
        case .muscleMemory: 15
        case .blueprints: 25
        case .arcadeChampion: 40
        case .marathon: 60
        case .comboMaster: 100
        case .bullMarket: 150
        case .bulkDiscount: 250
        case .luckyStreak: 400
        case .whaleWatcher: 750
        case .autoClickerPro: 1_500
        case .engineeringTeam: 3_000
        case .compoundInterest: 6_000
        }
    }

    /// The perk that must be bought first, if any.
    public var requires: PerkID? {
        switch self {
        case .blueprints, .bulkDiscount: .headStart
        case .engineeringTeam: .blueprints
        case .compoundInterest: .bulkDiscount
        case .muscleMemory, .comboMaster: .strongFingers
        case .autoClickerPro: .muscleMemory
        case .bullMarket, .whaleWatcher: .airdropRadar
        default: nil
        }
    }

    public var branch: PerkBranch {
        switch self {
        case .headStart, .blueprints, .bulkDiscount, .engineeringTeam, .compoundInterest: .mining
        case .strongFingers, .muscleMemory, .comboMaster, .autoClickerPro: .tapping
        case .airdropRadar, .bullMarket, .whaleWatcher, .marketInsider, .arcadeChampion, .marathon, .luckyStreak: .fortune
        }
    }
}
