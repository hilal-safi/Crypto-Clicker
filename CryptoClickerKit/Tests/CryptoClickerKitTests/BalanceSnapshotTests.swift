import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Widgets and the Live Activity")
struct BalanceSnapshotTests {
    @Test func theBalanceGrowsUntilTheMinersStop() {
        let snapshot = BalanceSnapshot(coins: 100, income: 10, offlineCap: 7_200, anchor: t0)
        #expect(snapshot.coins(at: t0) == 100)
        #expect(snapshot.coins(at: at(30)) == 400)
        #expect(snapshot.coins(at: at(-50)) == 100) // A widget's clock a little behind the game's.
        #expect(snapshot.miningEndsAt == at(7_200))
        #expect(snapshot.coins(at: at(10_000)) == 100 + 72_000)
        #expect(snapshot.coinsWhenMiningEnds == 100 + 72_000)
        #expect(snapshot.isMining(at: at(7_199)) && !snapshot.isMining(at: at(7_200)))
        #expect(snapshot.income(at: at(100)) == 10 && snapshot.income(at: at(7_200)) == 0)
        #expect(snapshot.miningProgress(at: at(3_600)) == 0.5)
        #expect(snapshot.miningProgress(at: at(-5)) == 0 && snapshot.miningProgress(at: at(9_999)) == 1)
        // Without Offline Mining the miners stop after a minute.
        let short = BalanceSnapshot(coins: 100, income: 10, offlineCap: 0, anchor: t0)
        #expect(short.miningEndsAt == at(60) && short.coinsWhenMiningEnds == 700)
    }

    @Test func aBullRunCountsUntilItEnds() {
        let boosted = BalanceSnapshot(coins: 100, income: 10, boostIncome: 60, boostEndsAt: at(20), offlineCap: 0, anchor: t0)
        #expect(boosted.coins(at: at(30)) == 100 + 300 + 1_200)
        #expect(boosted.income(at: at(10)) == 70 && boosted.income(at: at(25)) == 10)
    }

    @Test func theProjectionMatchesWhatTheGameWillCredit() {
        var game = GameState.make(miners: [.server: 30, .desktop: 80],
                                  upgrades: [.automatedClicker, .upgradedClicker, .coinClicker])
        game.coins = 5_000
        game.boost = Boost(multiplier: 7, endsAt: at(25))
        let snapshot = game.balanceSnapshot(finish: .emerald)
        #expect(snapshot.anchor == game.lastUpdate && snapshot.finish == .emerald)
        // The same rule as the watch's.
        #expect(snapshot.coins(at: at(40)) == game.watchSnapshot(at: t0).projectedCoins(at: at(40)))
        for seconds: TimeInterval in [40, 5 * 3_600] {
            var played = game
            played.advance(to: at(seconds))
            #expect(approx(snapshot.coins(at: at(seconds)), played.coins), "\(seconds) s")
        }
        for level in [3, 62] {
            var mining = game
            mining.offlineMiningLevel = level
            let snapshot = mining.balanceSnapshot()
            #expect(snapshot.offlineCap == mining.offlineCap)
            mining.advance(to: at(30 * 3_600))
            #expect(approx(snapshot.coinsWhenMiningEnds, mining.coins), "level \(level)")
        }
    }

    @Test func aWidgetTimelineRunsUntilTheMinersStop() {
        let snapshot = BalanceSnapshot(coins: 100, income: 10, offlineCap: 7_200, anchor: t0)
        // Every five minutes for two hours, ending as the miners stop.
        let dates = snapshot.timelineDates(from: t0)
        #expect(dates.first == t0 && dates.last == at(7_200))
        #expect(dates.count == 25)
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $1.timeIntervalSince($0) >= 300 - 1e-6 })
        // A long Offline Mining limit spreads the same number out.
        let long = BalanceSnapshot(coins: 100, income: 10, offlineCap: 48 * 3_600, anchor: t0)
        let spread = long.timelineDates(from: at(600))
        #expect(spread.count <= 60 && spread.first == at(600) && spread.last == long.miningEndsAt)
        // Halfway through, the timeline starts where the widget is.
        #expect(snapshot.timelineDates(from: at(3_600)).first == at(3_600))
        // Once the miners have stopped, there's one moment to show.
        #expect(snapshot.timelineDates(from: at(9_000)) == [at(9_000)])
    }

    @Test func aSnapshotSurvivesTheTripAndReadsLeniently() throws {
        let snapshot = BalanceSnapshot(coins: 1.5e15, income: 2.5e9, boostIncome: 1e9, boostEndsAt: at(90),
                                       offlineCap: 14_400, finish: .holographic, anchor: t0)
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(BalanceSnapshot.self, from: data) == snapshot)
        // Only the clock is needed: a snapshot from another version fills in the rest.
        let sparse = try JSONDecoder().decode(BalanceSnapshot.self, from: Data(#"{"anchor": 800000000, "coins": 42}"#.utf8))
        #expect(sparse.coins == 42 && sparse.income == 0 && sparse.finish == .gold && sparse.anchor == t0)
        // An unknown finish falls back to gold.
        let odd = try JSONDecoder().decode(BalanceSnapshot.self, from: Data(#"{"anchor": 800000000, "finish": "plaid"}"#.utf8))
        #expect(odd.finish == .gold)
    }
}
