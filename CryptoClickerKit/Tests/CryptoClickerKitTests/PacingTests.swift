import Foundation
import Testing
@testable import CryptoClickerKit

/// Simulated players guard the balance: if a tuning change makes the game race ahead or stall,
/// these tests fail. A player taps a few times a second while playing (quick enough for combos at
/// three taps a second) and buys whatever pays back fastest, Mk upgrades included.
struct SimulatedPlayer {
    var game = GameState(now: t0)
    var now = t0
    let tapsPerSecond: Int
    /// Hours away between sessions each day, so the player can judge what Offline Mining is worth.
    let awayHours: [Double]
    private(set) var firstBought: [MinerID: TimeInterval] = [:]
    private(set) var firstPrestigeAt: TimeInterval?
    /// When prestiging first became worth it (the shop starts suggesting it).
    private(set) var prestigeSuggestedAt: TimeInterval?
    /// Taps in a row this session, for the combo.
    private var streak = 0
    /// Saves for the next mini-game once it costs at most 15 minutes of income, buying nothing else
    /// meanwhile.
    var savesForGames = false
    /// Prestiges as soon as the shop suggests it.
    var prestigesWhenSuggested = false
    private(set) var gamesUnlockedAt: [TimeInterval] = []
    private(set) var prestiges = 0
    static let gamesByPrice = MiniGame.allCases.sorted { $0.unlockCost < $1.unlockCost }

    init(tapsPerSecond: Int, awayHours: [Double] = []) {
        self.tapsPerSecond = tapsPerSecond
        self.awayHours = awayHours
    }

    var elapsed: TimeInterval { now.timeIntervalSince(t0) }

    /// Income as the player experiences it while playing.
    func income(_ state: GameState) -> Double {
        state.baseIdleIncome + Double(tapsPerSecond) * state.tapValue(at: now)
    }

    /// Taps this quick keep a combo going.
    var keepsCombos: Bool { 1 / Double(tapsPerSecond) <= Tuning.comboWindow }

    mutating func play(seconds: Int) {
        streak = 0
        for second in 0..<seconds {
            now += 1
            game.advance(to: now)
            streak = keepsCombos ? streak + tapsPerSecond : 1
            game.tap(count: tapsPerSecond, at: now, combo: streak)
            if second % 2 == 0 && !saveForGames() { buyBest() }
            notePrestige()
        }
    }

    mutating func leave(for seconds: TimeInterval) {
        now += seconds
        game.advance(to: now)
        if !saveForGames() { buyBest() }
        notePrestige()
    }

    private mutating func notePrestige() {
        if firstPrestigeAt == nil && game.claimablePrestigePoints >= 1 { firstPrestigeAt = elapsed }
        if prestigeSuggestedAt == nil && game.isPrestigeRecommended { prestigeSuggestedAt = elapsed }
        if prestigesWhenSuggested && game.isPrestigeRecommended {
            game.prestige(at: now)
            prestiges += 1
        }
    }

    /// Unlocks the next mini-game if it can; true while still saving for it.
    private mutating func saveForGames() -> Bool {
        guard savesForGames else { return false }
        while let next = Self.gamesByPrice.first(where: { !game.isUnlocked($0) }) {
            guard game.unlock(next) else { return next.unlockCost <= income(game) * 900 }
            gamesUnlockedAt.append(elapsed)
        }
        return false
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
                if let upgrade = game.availableMinerUpgrade(miner) {
                    var upgraded = game
                    upgraded.minerUpgrades[miner] = upgrade.level + 1
                    consider(cost: upgrade.price, gain: income(upgraded) - current) { $0.buyMinerUpgrade(miner) }
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
    func casualPlayer(days: Int, buyingGames: Bool = false) -> SimulatedPlayer {
        let gaps: [Double] = [3, 4, 5, 10]
        var player = SimulatedPlayer(tapsPerSecond: 3, awayHours: gaps)
        player.savesForGames = buyingGames
        player.prestigesWhenSuggested = buyingGames
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
        print("Active 3h:", tiers.joined(separator: ", "), "| first prestige", hours(player.firstPrestigeAt),
              "| suggested", hours(player.prestigeSuggestedAt), "| income", CoinFormat.short(player.game.baseIdleIncome))
        // A first session should feel rewarding but leave the game ahead. Steady tapping with combos
        // pays: a player who taps all session long sees the first prestige points, but prestiging
        // isn't worth it yet and the last miner is still to come.
        let unlocked = player.firstBought.count
        #expect((6...9).contains(unlocked))
        #expect(player.firstBought[.desktop].map { $0 < 10 * 60 } == true)
        #expect(player.firstPrestigeAt.map { $0 >= 3_600 } ?? true)
        #expect(player.prestigeSuggestedAt == nil)
        // Nobody who stays in the app needs Offline Mining.
        #expect(player.game.offlineMiningLevel == 0)
    }

    @Test func aRelaxedTapperIsNotReadyToPrestigeAfterTheFirstSession() {
        var player = SimulatedPlayer(tapsPerSecond: 1) // Too slow for combos.
        player.play(seconds: 3 * 3_600)
        print("Relaxed 3h: tiers", player.firstBought.count, "| first prestige", hours(player.firstPrestigeAt),
              "| income", CoinFormat.short(player.game.baseIdleIncome))
        #expect((5...8).contains(player.firstBought.count))
        #expect(player.firstPrestigeAt.map { $0 >= 2 * 3_600 } ?? true)
        #expect(player.prestigeSuggestedAt == nil)
    }

    @Test func aCasualPlayerReachesEveryTierAndAPrestigeWithinDays() {
        let player = casualPlayer(days: 5)
        let tiers = MinerID.allCases.map { "\($0.name) \(hours(player.firstBought[$0]))" }
        print("Casual 5 days:", tiers.joined(separator: ", "), "| first prestige", hours(player.firstPrestigeAt),
              "| suggested", hours(player.prestigeSuggestedAt), "| potential", player.game.prestigePotential,
              "| income", CoinFormat.short(player.game.baseIdleIncome), "| offline", CoinFormat.duration(player.game.offlineCap))
        let lastTier = player.firstBought[.spaceColony]
        #expect(lastTier.map { (24 * 3_600...72 * 3_600).contains($0) } == true)
        #expect(player.firstPrestigeAt.map { (12 * 3_600...72 * 3_600).contains($0) } == true)
        // The shop suggests the first prestige within the first few days.
        #expect(player.prestigeSuggestedAt.map { (24 * 3_600...96 * 3_600).contains($0) } == true)
        // Offline Mining covers the longest absence (ten hours) by the end of the first day.
        #expect(player.game.offlineCap >= 10 * 3_600)
    }

    @Test func miniGamesUnlockAboutAnHourApart() {
        // A player who keeps playing (and prestiges when the shop suggests it) gets a new game about
        // every hour through the first run; the last few take later runs.
        var active = SimulatedPlayer(tapsPerSecond: 3)
        active.savesForGames = true
        active.prestigesWhenSuggested = true
        active.play(seconds: 6 * 3_600)
        let times = active.gamesUnlockedAt
        print("Games, active 6h:", times.map(hours).joined(separator: " "), "| prestiges", active.prestiges)
        #expect((5...7).contains(times.count))
        #expect(times.first.map { (30 * 60...75 * 60).contains($0) } == true)
        for (earlier, later) in zip(times, times.dropFirst()).prefix(4) {
            #expect((40 * 60...100 * 60).contains(later - earlier))
        }
        // Someone who checks in four times a day gets the first on day one and every game within a week.
        let casual = casualPlayer(days: 7, buyingGames: true)
        print("Games, casual:", casual.gamesUnlockedAt.map { String(format: "day %.1f", $0 / 86_400) }.joined(separator: ", "))
        #expect(casual.gamesUnlockedAt.count == MiniGame.allCases.count)
        #expect(casual.gamesUnlockedAt.first.map { $0 < 86_400 } == true)
        #expect(casual.gamesUnlockedAt.last.map { $0 > 3 * 86_400 } == true)
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
