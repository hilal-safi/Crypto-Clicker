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

/// Miners that earn exactly `coins` a second at today's rates, with no milestone reached (the
/// first is at 25 of a miner): Desktops for most of it and Chromebooks for the rest, with GPU Rigs
/// for what those can't make. Fixtures that only need an income use this, so a change to the
/// miners' rates doesn't change what the tests mean.
func minersEarning(_ coins: Double) -> [MinerID: Int] {
    let below = Tuning.milestones[0] - 1
    for rigs in 0...below {
        let afterRigs = coins - Double(rigs) * MinerID.gpuRig.baseRate
        guard afterRigs > -1e-9 else { break }
        let desktops = min(below, Int((afterRigs / MinerID.desktop.baseRate).rounded(.down)))
        let rest = afterRigs - Double(desktops) * MinerID.desktop.baseRate
        let chromebooks = Int((rest / MinerID.chromebook.baseRate).rounded())
        guard chromebooks <= below, abs(Double(chromebooks) * MinerID.chromebook.baseRate - rest) < 1e-9 else { continue }
        var miners: [MinerID: Int] = [:]
        if rigs > 0 { miners[.gpuRig] = rigs }
        if desktops > 0 { miners[.desktop] = desktops }
        if chromebooks > 0 { miners[.chromebook] = chromebooks }
        return miners
    }
    preconditionFailure("\(coins) coins a second can't be made from GPU Rigs, Desktops and Chromebooks without a milestone")
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

    /// Sets Offline Mining to the level that pays for `hours` away.
    mutating func setOfflineMining(hours: Double) {
        offlineMiningLevel = Self.offlineMiningLevel(reaching: hours * 3_600)
    }
}

extension GameState {
    /// This game, made a copy of `other` as it was at `revision` (for backups of one game at
    /// different points).
    func withLineage(of other: GameState, revision: Int) -> GameState {
        var game = self
        game.gameID = other.gameID
        game.revision = revision
        game.stats.lifetimeCoins = max(game.stats.lifetimeCoins, 1)
        return game
    }
}
