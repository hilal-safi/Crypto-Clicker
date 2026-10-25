import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Time and offline earnings")
struct TimeTests {
    /// 10 desktops: 20 coins per second, no taps involved.
    func earner() -> GameState { GameState.make(miners: [.desktop: 10]) }

    @Test func shortGapsArePaidInFullWithoutAReport() {
        var state = earner()
        #expect(state.advance(to: at(10)) == nil)
        #expect(approx(state.coins, 200))
        #expect(approx(state.stats.earnedFromIdle, 200))
        #expect(state.lastUpdate == at(10))
        #expect(state.advance(to: at(69)) == nil) // 59 seconds: still live.
        #expect(approx(state.coins, 200 + 59 * 20))
    }

    @Test func timeAwayIsReported() throws {
        var state = earner()
        let result = state.advance(to: at(60))
        let report = try #require(result)
        #expect(report.elapsed == 60)
        #expect(report.credited == 60)
        #expect(!report.wasCapped)
        #expect(approx(report.earned, 1_200))
        #expect(approx(state.stats.earnedOffline, 1_200))
        #expect(state.stats.earnedFromIdle == 0)
    }

    @Test func timeAwayIsCappedByTheOfflineCap() throws {
        var state = earner()
        let result = state.advance(to: at(3 * 3_600))
        let report = try #require(result)
        #expect(report.credited == 2 * 3_600)
        #expect(report.wasCapped)
        #expect(approx(state.coins, 7_200 * 20))
        #expect(state.lastUpdate == at(3 * 3_600))
        // The skipped hour is gone for good: the next tick pays only new time.
        #expect(state.advance(to: at(3 * 3_600 + 1)) == nil)
        #expect(approx(state.coins, 7_201 * 20))
    }

    @Test func offlineUpgradesRaiseTheCap() throws {
        var state = earner()
        state.upgrades = [.alwaysOnRig]
        let result = state.advance(to: at(30 * 3_600))
        let report = try #require(result)
        #expect(report.credited == 24 * 3_600)
    }

    @Test func aBackwardsClockReanchorsWithoutPaying() {
        var state = earner()
        state.advance(to: at(100))
        let coins = state.coins
        #expect(state.advance(to: at(40)) == nil)
        #expect(state.coins == coins)
        #expect(state.lastUpdate == at(40))
        state.advance(to: at(45))
        #expect(approx(state.coins, coins + 100))
    }

    @Test func noTimeNoMoney() {
        var state = earner()
        #expect(state.advance(to: t0) == nil)
        #expect(state.coins == 0)
    }

    @Test func boostsArePaidOnlyWhileActive() {
        var state = earner()
        state.boost = Boost(multiplier: 7, endsAt: at(30))
        state.advance(to: at(4))
        #expect(approx(state.coins, 4 * 140))
        #expect(state.boost != nil)
        // 26 boosted seconds, then 30 normal ones; the boost is cleared afterwards.
        state.advance(to: at(60))
        #expect(approx(state.coins, 30 * 140 + 30 * 20))
        #expect(state.boost == nil)
    }

    @Test func boostedIncomeIntegratesTapsAndProduction() {
        var state = GameState.make(miners: [.server: 30, .desktop: 80],
                                   upgrades: [.automatedClicker, .roboticFinger, .upgradedClicker, .coinClicker])
        state.boost = Boost(multiplier: 7, endsAt: at(20))
        let during = state.idleIncome(at: at(1))
        let after = state.idleIncome(at: at(21))
        #expect(approx(state.income(from: t0, seconds: 50), 20 * during + 30 * after))
        #expect(approx(state.income(from: t0, seconds: 10), 10 * during))
        #expect(approx(state.income(from: at(25), seconds: 10), 10 * after))
        #expect(state.income(from: t0, seconds: 0) == 0)
    }

    @Test func boostsCountTowardTimeAwayToo() throws {
        var state = earner()
        state.boost = Boost(multiplier: 7, endsAt: at(60))
        let result = state.advance(to: at(600))
        let report = try #require(result)
        #expect(approx(report.earned, 60 * 140 + 540 * 20))
    }

    @Test func peakIncomeRemembersTheBest() {
        var state = earner()
        state.boost = Boost(multiplier: 7, endsAt: at(5))
        state.advance(to: at(1))
        #expect(approx(state.stats.peakIncome, 140))
        state.advance(to: at(10))
        #expect(approx(state.stats.peakIncome, 140))
    }
}
