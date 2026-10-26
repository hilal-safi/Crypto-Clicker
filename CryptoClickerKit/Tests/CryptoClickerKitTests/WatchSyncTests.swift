import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Watch sync")
struct WatchSyncTests {
    func snapshot(coins: Double = 100, income: Double = 10, boostIncome: Double = 0, boostEndsAt: Date? = nil,
                  cap: TimeInterval = 7_200, applied: [UUID] = [], date: Date = t0) -> WatchSnapshot {
        WatchSnapshot(coins: coins, income: income, boostIncome: boostIncome, boostEndsAt: boostEndsAt, tapValue: 2,
                      offlineCap: cap, stepsConnected: true, stepsToday: 1_234, stepsDay: "2026-10-24", stepValue: 1,
                      appliedBatches: applied, date: date, anchor: date)
    }

    // MARK: Phone side

    @Test func eachBatchIsAppliedOnce() {
        var game = GameState.make(upgrades: [.coinClicker])
        let batch = WatchTapBatch(taps: 10, date: t0)
        #expect(game.applyWatchTaps(batch, at: t0) == 20)
        #expect(game.applyWatchTaps(batch, at: at(5)) == nil)
        #expect(game.coins == 20)
        #expect(game.stats.taps == 10)
    }

    @Test func batchSizesAreClamped() {
        var game = GameState.make()
        #expect(game.applyWatchTaps(WatchTapBatch(taps: 1_000_000, date: t0), at: t0) == 2_000)
        #expect(game.applyWatchTaps(WatchTapBatch(taps: -5, date: t0), at: t0) == 0)
        #expect(game.stats.taps == 2_000)
    }

    @Test func onlyRecentBatchIDsAreRemembered() {
        var game = GameState.make()
        let batches = (0..<70).map { _ in WatchTapBatch(taps: 1, date: t0) }
        for batch in batches { game.applyWatchTaps(batch, at: t0) }
        #expect(game.recentWatchBatches.count == 64)
        #expect(game.recentWatchBatches == batches.suffix(64).map(\.id))
    }

    @Test func snapshotsListTheNewestAppliedBatches() {
        var game = GameState.make()
        let batches = (0..<20).map { _ in WatchTapBatch(taps: 1, date: t0) }
        for batch in batches { game.applyWatchTaps(batch, at: t0) }
        #expect(game.watchSnapshot(at: t0).appliedBatches == batches.suffix(16).map(\.id))
    }

    // MARK: Projection

    @Test func theBalanceKeepsGrowingUpToTheOfflineCap() {
        let base = snapshot()
        #expect(base.projectedCoins(at: t0) == 100)
        #expect(base.projectedCoins(at: at(30)) == 400)
        #expect(base.projectedCoins(at: at(10_000)) == 100 + 72_000)
        #expect(base.projectedCoins(at: at(-50)) == 100) // Watch clock behind the phone's.
    }

    @Test func withoutOfflineMiningTheBalanceStopsAfterAMinute() {
        let base = snapshot(cap: 0)
        #expect(base.projectedCoins(at: at(30)) == 400)
        #expect(base.projectedCoins(at: at(60)) == 700)
        #expect(base.projectedCoins(at: at(10_000)) == 700)
    }

    @Test func boostsOnlyCountUntilTheyEnd() {
        let boosted = snapshot(boostIncome: 60, boostEndsAt: at(20))
        #expect(boosted.projectedCoins(at: at(10)) == 100 + 100 + 600)
        #expect(boosted.projectedCoins(at: at(30)) == 100 + 300 + 1_200)
        #expect(boosted.income(at: at(10)) == 70)
        #expect(boosted.income(at: at(20)) == 10)
    }

    @Test func aSnapshotSentFromTheBackgroundProjectsFromTheGameClock() {
        var game = GameState.make(miners: [.desktop: 10])
        game.offlineMiningLevel = 4 // Two hours.
        game.coins = 1_000
        // The phone app went to the background at t0 and is woken by the watch 3 hours later.
        let snapshot = game.watchSnapshot(at: at(3 * 3_600))
        #expect(snapshot.date == at(3 * 3_600))
        #expect(snapshot.anchor == t0)
        // Projected from the anchor, so the 2-hour cap covers the whole absence...
        #expect(snapshot.projectedCoins(at: at(4 * 3_600)) == 1_000 + 7_200 * 20)
        // ...which is exactly what the phone credits when it opens.
        game.advance(to: at(4 * 3_600))
        #expect(game.coins == snapshot.projectedCoins(at: at(4 * 3_600)))
    }

    @Test func theProjectionMatchesWhatThePhoneWillCredit() {
        var game = GameState.make(miners: [.server: 30, .desktop: 80],
                                  upgrades: [.automatedClicker, .upgradedClicker, .coinClicker])
        game.coins = 5_000
        game.boost = Boost(multiplier: 7, endsAt: at(25))
        let snapshot = game.watchSnapshot(at: t0)

        var live = game
        live.advance(to: at(40)) // Crosses the end of the boost.
        #expect(approx(snapshot.projectedCoins(at: at(40)), live.coins))

        var away = game
        away.advance(to: at(5 * 3_600)) // Longer than the offline cap.
        #expect(approx(snapshot.projectedCoins(at: at(5 * 3_600)), away.coins))

        for level in [3, 50] {
            var mining = game
            mining.offlineMiningLevel = level
            let snapshot = mining.watchSnapshot(at: t0)
            mining.advance(to: at(30 * 3_600))
            #expect(approx(snapshot.projectedCoins(at: at(30 * 3_600)), mining.coins), "level \(level)")
        }
    }

    @Test func snapshotsCarryRatesAndSteps() {
        var game = GameState.make(miners: [.desktop: 10], upgrades: [.coinClicker])
        game.stats.taps = Tuning.stepsUnlockTaps
        game.connectSteps(today: "2026-10-24")
        game.creditSteps([StepDay(key: "2026-10-24", steps: 321)], today: "2026-10-24", at: t0)
        let snapshot = game.watchSnapshot(at: at(1))
        #expect(snapshot.income == 20)
        #expect(snapshot.boostIncome == 0)
        #expect(snapshot.boostEndsAt == nil)
        #expect(snapshot.tapValue == 2)
        #expect(snapshot.offlineCap == 0)
        #expect(snapshot.stepsConnected)
        #expect(snapshot.stepsToday == 321)
        #expect(snapshot.stepsDay == "2026-10-24")
        #expect(snapshot.stepValue == 1) // 0.06 × 20 = 1.2, paid as a whole coin.
        #expect(snapshot.date == at(1))
        #expect(snapshot.anchor == t0)
    }

    // MARK: Watch side

    @Test func tapsAreCollectedThenSealedIntoBatches() throws {
        var queue = WatchTapQueue()
        #expect(queue.seal(at: t0) == nil)
        queue.record()
        queue.record(taps: 2)
        queue.record(taps: -4)
        #expect(queue.pendingTaps == 3)
        let result = queue.seal(at: t0)
        let first = try #require(result)
        #expect(first.taps == 3)
        #expect(queue.unsent == 0)
        queue.record(taps: 2)
        #expect(queue.pendingTaps == 5)
        #expect(queue.sent == [first])
    }

    @Test func hugeBurstsAreSplitAcrossBatches() throws {
        var queue = WatchTapQueue()
        queue.record(taps: 2_500)
        let full = queue.seal(at: t0)
        #expect(try #require(full).taps == 2_000)
        let rest = queue.seal(at: t0)
        #expect(try #require(rest).taps == 500)
        #expect(queue.seal(at: t0) == nil)
        #expect(queue.pendingTaps == 2_500)
    }

    @Test func confirmingABatchAlsoConfirmsEarlierOnes() throws {
        var queue = WatchTapQueue()
        var batches: [WatchTapBatch] = []
        for taps in 1...4 {
            queue.record(taps: taps)
            let sealed = queue.seal(at: t0)
            batches.append(try #require(sealed))
        }
        queue.acknowledge(snapshot(applied: [UUID(), batches[2].id]))
        #expect(queue.sent == [batches[3]])
        #expect(queue.pendingTaps == 4)
        queue.acknowledge(snapshot(applied: [UUID()]))
        #expect(queue.sent == [batches[3]])
    }

    @Test func unconfirmedBatchesExpireAfterADay() throws {
        var queue = WatchTapQueue()
        queue.record(taps: 3)
        _ = queue.seal(at: t0)
        queue.acknowledge(snapshot(date: at(3_600)))
        #expect(queue.pendingTaps == 3)
        queue.acknowledge(snapshot(date: at(25 * 3_600)))
        #expect(queue.pendingTaps == 0)
    }

    @Test func payloadsRoundTrip() throws {
        let original = snapshot(boostIncome: 5, boostEndsAt: at(9), applied: [UUID()])
        let payload = try #require(WatchPayload.make(original, key: WatchPayload.snapshotKey))
        #expect(WatchPayload.read(WatchSnapshot.self, key: WatchPayload.snapshotKey, from: payload) == original)
        #expect(WatchPayload.read(WatchSnapshot.self, key: WatchPayload.tapBatchKey, from: payload) == nil)
        #expect(WatchPayload.read(WatchTapBatch.self, key: WatchPayload.snapshotKey, from: payload) == nil)
        #expect(WatchPayload.read(WatchSnapshot.self, key: "x", from: ["x": "not data"]) == nil)

        let batch = WatchTapBatch(taps: 12, date: t0)
        let batchPayload = try #require(WatchPayload.make(batch, key: WatchPayload.tapBatchKey))
        #expect(WatchPayload.read(WatchTapBatch.self, key: WatchPayload.tapBatchKey, from: batchPayload) == batch)
    }
}
