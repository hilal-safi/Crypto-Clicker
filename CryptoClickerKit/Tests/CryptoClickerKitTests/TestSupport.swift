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
