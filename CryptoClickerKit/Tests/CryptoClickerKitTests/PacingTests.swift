import Foundation
import Testing
@testable import CryptoClickerKit

/// Simulated players guard the balance: if a tuning change makes the game race ahead or stall,
/// these tests fail. A player taps a few times a second while playing and buys whatever pays back fastest.
struct SimulatedPlayer {
    var game = GameState(now: t0)
    var now = t0
    let tapsPerSecond: Int
    /// Hours away between sessions each day, so the player can judge what Offline Mining is worth.
    let awayHours: [Double]
    private(set) var firstBought: [MinerID: TimeInterval] = [:]
    private(set) var firstForkAt: TimeInterval?

    init(tapsPerSecond: Int, awayHours: [Double] = []) {
        self.tapsPerSecond = tapsPerSecond
        self.awayHours = awayHours
    }

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

    /// What one more Offline Mining level adds, as income per second of play: the extra time it
    /// pays each day, spread over the ten minutes played per session.
    private func offlineMiningGain() -> Double {
        guard !awayHours.isEmpty else { return 0 }
        let current = GameState.offlineCap(level: game.offlineMiningLevel)
        let next = GameState.offlineCap(level: game.offlineMiningLevel + 1)
        let extra = awayHours.reduce(0.0) { $0 + min($1 * 3_600, next) - min($1 * 3_600, current) }
        return game.baseIdleIncome * extra / (600 * Double(awayHours.count))
    }

    private mutating func buyBest() {
        while true {
            let current = max(income(game), 1e-9)
            let coins = game.coins
            var best: (score: Double, apply: (inout GameState) -> Bool, miner: MinerID?)?
            func consider(cost: Double, gain: Double, miner: MinerID? = nil,
                          _ apply: @escaping (inout GameState) -> Bool) {
                guard gain > 0 else { return }
                let score = max(0, (cost - coins) / current) + cost / gain
                if score < best?.score ?? .infinity { best = (score, apply, miner) }
            }
            for miner in MinerID.allCases where game.isRevealed(miner) {
                var copy = game
                copy.miners[miner, default: 0] += 1
                consider(cost: game.price(of: miner, quantity: 1), gain: income(copy) - current, miner: miner) {
                    $0.buy(miner, quantity: 1)
                }
            }
            for upgrade in UpgradeID.allCases where !game.upgrades.contains(upgrade) && game.isRevealed(upgrade) {
                switch upgrade.category {
                case .steps, .miniGames: continue
                case .tapping, .production:
                    var copy = game
                    copy.upgrades.insert(upgrade)
                    consider(cost: upgrade.cost, gain: income(copy) - current) { $0.buy(upgrade) }
                }
            }
            if let price = game.offlineMiningPrice {
                consider(cost: price, gain: offlineMiningGain()) { $0.buyOfflineMining() }
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

    /// Four ten-minute check-ins a day, `days` days in a row.
    func casualPlayer(days: Int) -> SimulatedPlayer {
        let gaps: [Double] = [3, 4, 5, 10]
        var player = SimulatedPlayer(tapsPerSecond: 3, awayHours: gaps)
        for _ in 0..<days {
            for gap in gaps {
                player.play(seconds: 600)
                player.leave(for: gap * 3_600)
            }
        }
        return player
    }

    @Test func anActivePlayerUnlocksSeveralTiersInTheFirstSession() {
        var player = SimulatedPlayer(tapsPerSecond: 3)
        player.play(seconds: 3 * 3_600)
        let tiers = MinerID.allCases.map { "\($0.name) \(hours(player.firstBought[$0]))" }
        print("Active 3h:", tiers.joined(separator: ", "), "| first fork", hours(player.firstForkAt),
              "| income", CoinFormat.short(player.game.baseIdleIncome))
        // A first session should feel rewarding but leave most of the game ahead. Steady tapping
        // pays: a player who taps all session long may reach a first (small) Hard Fork near its end.
        let unlocked = player.firstBought.count
        #expect((5...8).contains(unlocked))
        #expect(player.firstBought[.desktop].map { $0 < 10 * 60 } == true)
        #expect(player.firstForkAt.map { $0 >= 2 * 3_600 } ?? true)
        // Nobody who stays in the app needs Offline Mining.
        #expect(player.game.offlineMiningLevel == 0)
    }

    @Test func aRelaxedTapperGetsNoForkInTheFirstSession() {
        var player = SimulatedPlayer(tapsPerSecond: 1)
        player.play(seconds: 3 * 3_600)
        #expect((5...8).contains(player.firstBought.count))
        #expect(player.firstForkAt == nil)
    }

    @Test func aCasualPlayerReachesEveryTierAndAForkWithinDays() {
        let player = casualPlayer(days: 5)
        let tiers = MinerID.allCases.map { "\($0.name) \(hours(player.firstBought[$0]))" }
        print("Casual 5 days:", tiers.joined(separator: ", "), "| first fork", hours(player.firstForkAt),
              "| forks", player.game.forkPoints, "| income", CoinFormat.short(player.game.baseIdleIncome),
              "| offline", CoinFormat.duration(player.game.offlineCap))
        let lastTier = player.firstBought[.spaceColony]
        #expect(lastTier.map { (24 * 3_600...96 * 3_600).contains($0) } == true)
        #expect(player.firstForkAt.map { (12 * 3_600...72 * 3_600).contains($0) } == true)
        // Offline Mining covers the longest absence (ten hours) by the end of the first day.
        #expect(player.game.offlineCap >= 10 * 3_600)
    }

    @Test func offlineMiningIsEarnedInTheFirstSessionNotGivenAtTheStart() {
        var player = SimulatedPlayer(tapsPerSecond: 3, awayHours: [3, 4, 5, 10])
        player.play(seconds: 60)
        #expect(player.game.offlineMiningLevel == 0) // Not affordable in the first minute.
        player.play(seconds: 540)
        #expect(player.game.offlineMiningLevel >= 1) // Bought before the first break.
    }

    @Test func tapsStayWorthHavingAllGameLong() {
        // Half an hour in, three taps a second add more than half again to idle income...
        var early = SimulatedPlayer(tapsPerSecond: 3)
        early.play(seconds: 30 * 60)
        let earlyGame = early.game
        #expect(3 * earlyGame.tapValue(at: early.now) >= 0.5 * earlyGame.baseIdleIncome)
        // ...and days in, a single tap is worth most of a second of production.
        let late = casualPlayer(days: 3).game
        #expect(late.tapValue(at: t0) >= 0.75 * late.baseProduction)
        #expect(3 * late.tapValue(at: t0) >= late.baseIdleIncome)
    }
}
