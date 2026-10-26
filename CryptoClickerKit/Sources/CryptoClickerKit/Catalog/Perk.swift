import Foundation

/// The three branches of the perk tree.
public enum PerkBranch: String, CaseIterable, Sendable, Identifiable {
    case mining = "Mining"
    case tapping = "Tapping"
    case fortune = "Fortune"

    public var id: String { rawValue }
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
        case .headStart: "Head Start"
        case .blueprints: "Blueprints"
        case .bulkDiscount: "Bulk Discount"
        case .engineeringTeam: "Engineering Team"
        case .compoundInterest: "Compound Interest"
        case .strongFingers: "Strong Fingers"
        case .muscleMemory: "Muscle Memory"
        case .comboMaster: "Combo Master"
        case .autoClickerPro: "Auto Clicker Pro"
        case .airdropRadar: "Airdrop Radar"
        case .bullMarket: "Bull Market"
        case .whaleWatcher: "Whale Watcher"
        case .marketInsider: "Market Insider"
        case .arcadeChampion: "Arcade Champion"
        case .marathon: "Marathon"
        case .luckyStreak: "Lucky Streak"
        }
    }

    public var summary: String {
        switch self {
        case .headStart: "Start every run with 10 Chromebooks, 10 Desktops and 5 GPU Rigs"
        case .blueprints: "Keep production upgrades when you prestige"
        case .bulkDiscount: "Miners cost 10% less"
        case .engineeringTeam: "Keep miner Mk upgrades when you prestige"
        case .compoundInterest: "Every achievement star adds 2% production instead of 1%"
        case .strongFingers: "Taps earn 50% more"
        case .muscleMemory: "Keep tapping upgrades when you prestige"
        case .comboMaster: "Combos build twice as fast and reach ×3"
        case .autoClickerPro: "Automatic taps are worth 50% of a tap"
        case .airdropRadar: "Airdrops come every 2–4 minutes and stay for 30 seconds"
        case .bullMarket: "Bull Runs last 2 minutes"
        case .whaleWatcher: "Whale airdrops are three times as likely"
        case .marketInsider: "Sell tokens with no fee"
        case .arcadeChampion: "Mini-game and casino coin rewards ×1.5"
        case .marathon: "Steps earn ×2"
        case .luckyStreak: "Daily quest and streak rewards ×2"
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

    /// Price in prestige points. The first prestige affords a few cheap perks; the last ones take
    /// a couple of weeks of prestiging.
    public var cost: Int {
        switch self {
        case .headStart: 1
        case .strongFingers: 2
        case .airdropRadar: 5
        case .marketInsider: 10
        case .muscleMemory: 15
        case .blueprints: 25
        case .arcadeChampion, .marathon: 40
        case .comboMaster: 75
        case .bullMarket: 100
        case .bulkDiscount: 150
        case .luckyStreak: 250
        case .whaleWatcher: 400
        case .autoClickerPro: 750
        case .engineeringTeam: 1_500
        case .compoundInterest: 3_000
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
