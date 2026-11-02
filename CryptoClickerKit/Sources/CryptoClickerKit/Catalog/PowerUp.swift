import Foundation

/// Power-ups bought in levels with coins and kept through prestiges, like Offline Mining (which
/// keeps its own rules: see `GameState.offlineMiningLevel`). These three build up the coin's combo:
/// Combo Booster and then Combo Overdrive raise the biggest combo from ×2 to ×10, and Quick Combos
/// makes each step of a combo come sooner, up to four times as fast.
public enum PowerUpID: String, CaseIterable, Codable, Sendable, Identifiable {
    case comboBooster, comboOverdrive, quickCombos

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .comboBooster: "Combo Booster"
        case .comboOverdrive: "Combo Overdrive"
        case .quickCombos: "Quick Combos"
        }
    }

    /// SF Symbol for the Shop.
    public var symbol: String {
        switch self {
        case .comboBooster: "flame.fill"
        case .comboOverdrive: "bolt.fill"
        case .quickCombos: "hare.fill"
        }
    }

    public var summary: String {
        switch self {
        case .comboBooster:
            "Raises the biggest combo by ×\(CoinFormat.compact(Tuning.comboBoosterStep)) a level, from ×\(CoinFormat.compact(Tuning.comboMaxMultiplier)) up to ×\(CoinFormat.compact(Self.boosterTop))."
        case .comboOverdrive:
            "Raises the biggest combo by ×\(CoinFormat.compact(Tuning.comboOverdriveStep)) a level, from ×\(CoinFormat.compact(Self.boosterTop)) up to ×\(CoinFormat.compact(Tuning.comboTopMultiplier))."
        case .quickCombos:
            "Each +0.1 of a combo comes sooner: \(CoinFormat.percent(Tuning.quickComboStep)) faster a level, up to \(CoinFormat.compact(Self.quickTop))× as fast."
        }
    }

    public var maxLevel: Int {
        switch self {
        case .comboBooster: 6
        case .comboOverdrive: 5
        case .quickCombos: 6
        }
    }

    /// The power-up that must reach its last level before this one appears.
    public var requires: PowerUpID? {
        self == .comboOverdrive ? .comboBooster : nil
    }

    /// The list price of the level after `level` (so `0` is the first level's), before the pace
    /// adjustment (see `Tuning.scaledPrice`).
    public func listPrice(afterLevel level: Int) -> Double {
        let level = Double(max(0, level))
        return switch self {
        case .comboBooster: Tuning.comboBoosterBaseCost * pow(Tuning.comboBoosterCostGrowth, level)
        case .comboOverdrive: Tuning.comboOverdriveBaseCost * pow(Tuning.comboOverdriveCostGrowth, level)
        case .quickCombos: Tuning.quickCombosBaseCost * pow(Tuning.quickCombosCostGrowth, level)
        }
    }

    /// What this power-up gives at `level` on its own, for the Shop: "Biggest combo ×3.5",
    /// "Combos build 2.5× as fast".
    public func effect(atLevel level: Int) -> String {
        let level = Double(min(max(0, level), maxLevel))
        return switch self {
        case .comboBooster:
            "Biggest combo ×\(CoinFormat.compact(Tuning.comboMaxMultiplier + level * Tuning.comboBoosterStep))"
        case .comboOverdrive:
            "Biggest combo ×\(CoinFormat.compact(Self.boosterTop + level * Tuning.comboOverdriveStep))"
        case .quickCombos:
            "Combos build \(CoinFormat.compact(1 + level * Tuning.quickComboStep))× as fast"
        }
    }

    /// The biggest combo with Combo Booster at its last level.
    static var boosterTop: Double {
        Tuning.comboMaxMultiplier + Double(PowerUpID.comboBooster.maxLevel) * Tuning.comboBoosterStep
    }

    /// How fast combos build with Quick Combos at its last level.
    static var quickTop: Double {
        1 + Double(PowerUpID.quickCombos.maxLevel) * Tuning.quickComboStep
    }
}
