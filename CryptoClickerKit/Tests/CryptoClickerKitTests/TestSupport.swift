import Foundation
@testable import CryptoClickerKit

/// A fixed reference time, so tests never depend on the clock.
let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

/// Relative comparison for Doubles that went through different (but equivalent) arithmetic.
func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    if a == b { return true }
    return abs(a - b) <= tolerance * max(abs(a), abs(b), 1)
}

/// Miners that earn exactly `coins` a second at today's rates, with no milestone reached: Desktops
/// for most of it and Chromebooks for the rest. Fixtures that only need an income use this, so a
/// change to the miners' rates doesn't change what the tests mean.
func minersEarning(_ coins: Double) -> [MinerID: Int] {
    let desktops = min(24, Int((coins / MinerID.desktop.baseRate).rounded(.down)))
    let rest = coins - Double(desktops) * MinerID.desktop.baseRate
    let chromebooks = Int((rest / MinerID.chromebook.baseRate).rounded())
    precondition(chromebooks < 25 && abs(Double(chromebooks) * MinerID.chromebook.baseRate - rest) < 1e-9,
                 "\(coins) coins a second can't be made from Desktops and Chromebooks without a milestone")
    var miners: [MinerID: Int] = [:]
    if desktops > 0 { miners[.desktop] = desktops }
    if chromebooks > 0 { miners[.chromebook] = chromebooks }
    return miners
}

extension GameState {
    /// A new game at `t0` with an optional balance and miners.
    static func make(coins: Double = 0, miners: [MinerID: Int] = [:], upgrades: Set<UpgradeID> = []) -> GameState {
        var state = GameState(now: t0)
        state.coins = coins
        state.miners = miners
        state.upgrades = upgrades
        return state
    }
}
