import Foundation

/// Power-ups bought in levels with coins and kept through prestiges, like Offline Mining (which
/// keeps its own rules: see `GameState.offlineMiningLevel`). These four build up the coin's combo:
/// Combo Booster and then Combo Overdrive raise the biggest combo from ×2 to ×10, Quick Combos
/// makes each step of a combo come sooner, up to four times as fast, and Combo Keeper gives more
/// time between taps before a combo ends, up to twice as long.
public enum PowerUpID: String, CaseIterable, Codable, Sendable, Identifiable {
    case comboBooster, comboOverdrive, quickCombos, comboKeeper

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .comboBooster: localized("Combo Booster")
        case .comboOverdrive: localized("Combo Overdrive")
        case .quickCombos: localized("Quick Combos")
        case .comboKeeper: localized("Combo Keeper")
        }
    }

    /// SF Symbol for the Shop.
    public var symbol: String {
        switch self {
        case .comboBooster: "flame.fill"
        case .comboOverdrive: "bolt.fill"
        case .quickCombos: "hare.fill"
        case .comboKeeper: "timer"
        }
    }

    public var summary: String {
        switch self {
        case .comboBooster:
            localized("Raises the biggest combo by ×\(CoinFormat.compact(Tuning.comboBoosterStep)) a level, from ×\(CoinFormat.compact(Tuning.comboMaxMultiplier)) up to ×\(CoinFormat.compact(Self.boosterTop)).")
        case .comboOverdrive:
            localized("Raises the biggest combo by ×\(CoinFormat.compact(Tuning.comboOverdriveStep)) a level, from ×\(CoinFormat.compact(Self.boosterTop)) up to ×\(CoinFormat.compact(Tuning.comboTopMultiplier)).")
        case .quickCombos:
            localized("Each +0.1 of a combo comes sooner: \(CoinFormat.percent(Tuning.quickComboStep)) faster a level, up to \(CoinFormat.compact(Self.quickTop))× as fast.")
        case .comboKeeper:
            localized("A combo waits \(Self.seconds(Tuning.comboKeeperStep)) longer for your next tap a level: from \(Self.seconds(Tuning.comboWindow)) up to \(Self.seconds(Self.keeperTop)).")
        }
    }

    public var maxLevel: Int {
        switch self {
        case .comboBooster: 6
        case .comboOverdrive: 5
        case .quickCombos: 6
        case .comboKeeper: 8
        }
    }

    /// The power-up that must reach its last level before this one appears.
    public var requires: PowerUpID? {
        self == .comboOverdrive ? .comboBooster : nil
    }

    /// The list price of the level after `level` (so `0` is the first level's), before the pace
    /// and the Shop's premium (see `Tuning.shopPrice`).
    public func listPrice(afterLevel level: Int) -> Double {
        let level = Double(max(0, level))
        return switch self {
        case .comboBooster: Tuning.comboBoosterBaseCost * pow(Tuning.comboBoosterCostGrowth, level)
        case .comboOverdrive: Tuning.comboOverdriveBaseCost * pow(Tuning.comboOverdriveCostGrowth, level)
        case .quickCombos: Tuning.quickCombosBaseCost * pow(Tuning.quickCombosCostGrowth, level)
        case .comboKeeper: Tuning.comboKeeperBaseCost * pow(Tuning.comboKeeperCostGrowth, level)
        }
    }

    /// What this power-up gives at `level` on its own, for the Shop: "Biggest combo ×3.5",
    /// "Combos build 2.5× as fast".
    public func effect(atLevel level: Int) -> String {
        let level = Double(min(max(0, level), maxLevel))
        return switch self {
        case .comboBooster:
            localized("Biggest combo ×\(CoinFormat.compact(Tuning.comboMaxMultiplier + level * Tuning.comboBoosterStep))")
        case .comboOverdrive:
            localized("Biggest combo ×\(CoinFormat.compact(Self.boosterTop + level * Tuning.comboOverdriveStep))")
        case .quickCombos:
            localized("Combos build \(CoinFormat.compact(1 + level * Tuning.quickComboStep))× as fast")
        case .comboKeeper:
            localized("Combos wait \(Self.seconds(Self.keeperWindow(level: level))) between taps")
        }
    }

    /// What this power-up gives at `level`, as the value alone for the Shop's Now and Next: "×4.5",
    /// "3× as fast", "0.84s".
    public func value(atLevel level: Int) -> String {
        let level = Double(min(max(0, level), maxLevel))
        return switch self {
        case .comboBooster: "×\(CoinFormat.compact(Tuning.comboMaxMultiplier + level * Tuning.comboBoosterStep))"
        case .comboOverdrive: "×\(CoinFormat.compact(Self.boosterTop + level * Tuning.comboOverdriveStep))"
        case .quickCombos: localized("\(CoinFormat.compact(1 + level * Tuning.quickComboStep))× as fast")
        case .comboKeeper: Self.seconds(Self.keeperWindow(level: level))
        }
    }

    /// What `value(atLevel:)` measures, for the Shop: "Biggest combo".
    public var valueName: String {
        switch self {
        case .comboBooster, .comboOverdrive: localized("Biggest combo")
        case .quickCombos: localized("Combo speed")
        case .comboKeeper: localized("Time between taps")
        }
    }

    /// A short time in seconds: "0.6s", "1.2s", "0.84s".
    static func seconds(_ value: TimeInterval) -> String {
        "\(CoinFormat.compact((value * 100).rounded() / 100))s"
    }

    /// The time between taps with Combo Keeper at its last level.
    static var keeperTop: TimeInterval {
        keeperWindow(level: Double(PowerUpID.comboKeeper.maxLevel))
    }

    /// Time between taps before a combo ends with Combo Keeper at `level`.
    static func keeperWindow(level: Double) -> TimeInterval {
        Tuning.comboWindow + level * Tuning.comboKeeperStep
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
