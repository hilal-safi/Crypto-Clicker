import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Time and offline earnings")
struct TimeTests {
    /// 10 desktops: 20 coins per second, no taps involved.
    func earner(offlineMiningLevel: Int = 0) -> GameState {
        var state = GameState.make(miners: [.desktop: 10])
        state.offlineMiningLevel = offlineMiningLevel
        return state
    }

    @Test func shortGapsArePaidInFullWithoutAReport() {
        var state = earner()
        #expect(state.advance(to: at(10)) == nil)
        #expect(approx(state.coins, 200))
        #expect(approx(state.stats.earnedFromIdle, 200))
        #expect(state.lastUpdate == at(10))
        #expect(state.advance(to: at(69)) == nil) // 59 seconds: still live.
        #expect(approx(state.coins, 200 + 59 * 20))
    }

    @Test func withoutOfflineMiningTimeAwayPaysOnlyTheFirstMinute() throws {
        var state = earner()
        let result = state.advance(to: at(3 * 3_600))
        let report = try #require(result)
        #expect(report.elapsed == 3 * 3_600)
        #expect(report.credited == 60)
        #expect(report.wasCapped)
        #expect(report.offlineCap == 0)
        #expect(approx(report.earned, 60 * 20))
        #expect(approx(state.stats.earnedOffline, 60 * 20))
        #expect(state.stats.earnedFromIdle == 0)
        #expect(state.lastUpdate == at(3 * 3_600))
        // The rest is gone for good: the next tick pays only new time.
        #expect(state.advance(to: at(3 * 3_600 + 1)) == nil)
        #expect(approx(state.coins, 61 * 20))
    }

    @Test func leavingForLongerNeverPaysLessThanAQuickSwitch() {
        // 59 seconds is live play, 61 is time away; both pay their full time.
        for seconds in [59.0, 60, 61, 600] {
            var state = earner()
            state.advance(to: at(seconds))
            #expect(approx(state.coins, min(seconds, 60) * 20), "\(seconds)s")
        }
    }

    @Test func offlineMiningPaysUpToItsLimit() throws {
        var state = earner(offlineMiningLevel: 4) // Two hours.
        let result = state.advance(to: at(3 * 3_600))
        let report = try #require(result)
        #expect(report.credited == 2 * 3_600)
        #expect(report.wasCapped)
        #expect(report.offlineCap == 2 * 3_600)
        #expect(approx(state.coins, 7_200 * 20))

        var long = earner(offlineMiningLevel: Tuning.offlineMiningMaxLevel)
        let longResult = long.advance(to: at(30 * 3_600))
        let longReport = try #require(longResult)
        #expect(longReport.credited == 30 * 3_600)
        #expect(!longReport.wasCapped)
    }

    @Test func theReportBreaksDownWhatEarnedTheCoins() throws {
        var state = GameState.make(miners: [.desktop: 10, .chromebook: 2, .server: 2],
                                   upgrades: [.coinClicker, .upgradedClicker, .automatedClicker, .overclocking])
        state.offlineMiningLevel = 2 // An hour.
        state.prestigePoints = 2
        state.achievementTiers = ["miner": 2]
        state.boost = Boost(multiplier: 7, endsAt: at(100))
        let result = state.advance(to: at(2 * 3_600))
        let report = try #require(result)
        #expect(report.credited == 3_600)
        #expect(report.boostedSeconds == 100)
        #expect(report.boostMultiplier == 7)
        // Largest first: servers, desktops, automatic taps, then chromebooks.
        #expect(report.sources.map(\.id) == ["server", "desktop", "autoTaps", "chromebook"])
        #expect(report.sources.first { $0.id == "desktop" }?.count == 10)
        #expect(report.sources.first { $0.id == "autoTaps" }?.count == 1)
        #expect(approx(report.sources.reduce(0) { $0 + $1.coins }, report.earned))
        #expect(approx(report.multipliers.upgrades, 2))
        #expect(approx(report.multipliers.prestige, 1.1))
        #expect(approx(report.multipliers.achievements, 1.02))
        #expect(report.multipliers.difficulty == 1)
        #expect(approx(report.multipliers.total, 2 * 1.1 * 1.02))
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
        var state = earner(offlineMiningLevel: 1)
        state.boost = Boost(multiplier: 7, endsAt: at(60))
        let result = state.advance(to: at(600))
        let report = try #require(result)
        #expect(approx(report.earned, 60 * 140 + 540 * 20))
        #expect(report.boostedSeconds == 60)
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
