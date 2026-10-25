import Foundation
import Testing
@testable import CryptoClickerKit

/// Simulated players guard the balance: if a tuning change makes the game race ahead or stall,
/// these tests fail. A player taps a few times a second while playing and buys whatever pays back fastest.
struct SimulatedPlayer {
    var game = GameState(now: t0)
    var now = t0
    let tapsPerSecond: Int
    private(set) var firstBought: [MinerID: TimeInterval] = [:]
    private(set) var firstForkAt: TimeInterval?

    init(tapsPerSecond: Int) { self.tapsPerSecond = tapsPerSecond }

    var elapsed: TimeInterval { now.timeIntervalSince(t0) }

    /// Income as the player experiences it while playing.
    func income(_ state: GameState) -> Double {
        state.baseIdleIncome + Double(tapsPerSecond) * state.tapValue(at: now)
    }

    mutating func play(seconds: Int) {
        for second in 0..<seconds {
            now += 1
            game.advance(to: now)
            game.tap(count: tapsPerSecond, at: now)
            if second % 2 == 0 { buyBest() }
            noteFork()
        }
    }

    mutating func leave(for seconds: TimeInterval) {
        now += seconds
        game.advance(to: now)
        buyBest()
        noteFork()
    }

    private mutating func noteFork() {
        if firstForkAt == nil && game.forkPoints >= 1 { firstForkAt = elapsed }
    }

    private mutating func buyBest() {
        while true {
            let current = max(income(game), 1e-9)
            var best: (score: Double, apply: (inout GameState) -> Bool, miner: MinerID?)?
            for miner in MinerID.allCases where game.isRevealed(miner) {
                var copy = game
                copy.miners[miner, default: 0] += 1
                let gain = income(copy) - current
                let cost = game.price(of: miner, quantity: 1)
                let score = max(0, (cost - game.coins) / current) + cost / gain
                if gain > 0 && score < best?.score ?? .infinity {
                    best = (score, { $0.buy(miner, quantity: 1) }, miner)
                }
            }
            for upgrade in UpgradeID.allCases where !game.upgrades.contains(upgrade) && game.isRevealed(upgrade) {
                var gain: Double
                switch upgrade.category {
                case .offline: gain = current * 0.02
                case .steps, .miniGames: continue
                case .tapping, .production:
                    var copy = game
                    copy.upgrades.insert(upgrade)
                    gain = income(copy) - current
                }
                let score = max(0, (upgrade.cost - game.coins) / current) + upgrade.cost / gain
                if gain > 0 && score < best?.score ?? .infinity {
                    best = (score, { $0.buy(upgrade) }, nil)
                }
            }
            guard let best, best.apply(&game) else { return }
            if let miner = best.miner, firstBought[miner] == nil { firstBought[miner] = elapsed }
        }
    }
}

@Suite("Pacing")
struct PacingTests {
    func hours(_ seconds: TimeInterval?) -> String {
        seconds.map { String(format: "%.1fh", $0 / 3_600) } ?? "-"
    }

    @Test func anActivePlayerUnlocksSeveralTiersInTheFirstSession() {
        var player = SimulatedPlayer(tapsPerSecond: 3)
        player.play(seconds: 3 * 3_600)
        let tiers = MinerID.allCases.map { "\($0.name) \(hours(player.firstBought[$0]))" }
        print("Active 3h:", tiers.joined(separator: ", "), "| income", CoinFormat.short(player.game.baseIdleIncome))
        // A first session should feel rewarding but leave most of the game ahead.
        let unlocked = player.firstBought.count
        #expect((5...8).contains(unlocked))
        #expect(player.firstBought[.desktop].map { $0 < 10 * 60 } == true)
        #expect(player.firstForkAt == nil)
    }

    @Test func aCasualPlayerReachesEveryTierAndAForkWithinDays() {
        var player = SimulatedPlayer(tapsPerSecond: 3)
        for _ in 0..<5 {
            // Four ten-minute check-ins a day.
            for gap in [3.0, 4, 5, 10] {
                player.play(seconds: 600)
                player.leave(for: gap * 3_600)
            }
        }
        let tiers = MinerID.allCases.map { "\($0.name) \(hours(player.firstBought[$0]))" }
        print("Casual 5 days:", tiers.joined(separator: ", "), "| first fork", hours(player.firstForkAt),
              "| forks", player.game.forkPoints, "| income", CoinFormat.short(player.game.baseIdleIncome))
        let lastTier = player.firstBought[.spaceColony]
        #expect(lastTier.map { (24 * 3_600...96 * 3_600).contains($0) } == true)
        #expect(player.firstForkAt.map { (12 * 3_600...72 * 3_600).contains($0) } == true)
    }
}
