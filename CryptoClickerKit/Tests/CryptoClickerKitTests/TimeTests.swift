import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Time and offline earnings")
struct TimeTests {
    /// 10 Chromebooks and 10 Desktops: 20 coins per second, no taps involved.
    /// Offline Efficiency is at its last level unless a test says otherwise, so time away pays all
    /// of its income (10% is the level 0 default: see the efficiency tests below).
    func earner(offlineHours: Double = 0, efficiency: Int = PowerUpID.offlineEfficiency.maxLevel) -> GameState {
        var state = GameState.make(miners: minersEarning(20))
        state.setOfflineMining(hours: offlineHours)
        state.powerUps[.offlineEfficiency] = efficiency
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

    @Test func withoutOfflineMiningTimeAwayPaysTheFirstSixMinutes() throws {
        var state = earner()
        let result = state.advance(to: at(3 * 3_600))
        let report = try #require(result)
        #expect(report.elapsed == 3 * 3_600)
        #expect(report.credited == 6 * 60)
        #expect(report.wasCapped)
        #expect(report.offlineCap == 0)
        #expect(approx(report.earned, 360 * 20))
        #expect(approx(state.stats.earnedOffline, 360 * 20))
        #expect(state.stats.earnedFromIdle == 0)
        #expect(state.lastUpdate == at(3 * 3_600))
        // The rest is gone for good: the next tick pays only new time.
        #expect(state.advance(to: at(3 * 3_600 + 1)) == nil)
        #expect(approx(state.coins, 361 * 20))
    }

    @Test func atFullEfficiencyTimeAwayPaysItsFullTimeUpToTheSixMinutes() {
        // 59 seconds is live play, 61 is time away; at full efficiency both pay their full time.
        for seconds in [59.0, 60, 61, 359, 360, 700] {
            var state = earner()
            state.advance(to: at(seconds))
            #expect(approx(state.coins, min(seconds, 360) * 20), "\(seconds)s")
        }
    }

    @Test func offlineMiningPaysUpToItsLimit() throws {
        var state = earner(offlineHours: 2)
        let result = state.advance(to: at(3 * 3_600))
        let report = try #require(result)
        #expect(report.credited == 2 * 3_600)
        #expect(report.wasCapped)
        #expect(report.offlineCap == 2 * 3_600)
        #expect(approx(state.coins, 7_200 * 20))

        var long = earner(offlineHours: 72)
        let longResult = long.advance(to: at(30 * 3_600))
        let longReport = try #require(longResult)
        #expect(longReport.credited == 30 * 3_600)
        #expect(!longReport.wasCapped)
    }

    @Test func timeAwayPaysOnlyTheEfficiencyShare() throws {
        for level in 0...PowerUpID.offlineEfficiency.maxLevel {
            var state = earner(offlineHours: 1, efficiency: level)
            let result = state.advance(to: at(3_600))
            let report = try #require(result)
            let share = Double(10 + 5 * level) / 100
            #expect(approx(report.efficiency, share), "level \(level)")
            // 20 coins a second for an hour, at the share.
            #expect(approx(report.earned, 20 * 3_600 * share), "level \(level)")
            #expect(approx(state.coins, report.earned), "level \(level)")
            #expect(approx(report.sources.reduce(0) { $0 + $1.coins }, report.earned), "level \(level)")
        }
        // Without any Offline Efficiency that is a tenth of the income.
        var plain = GameState.make(miners: minersEarning(20))
        plain.setOfflineMining(hours: 1)
        let plainResult = plain.advance(to: at(3_600))
        let plainReport = try #require(plainResult)
        #expect(approx(plainReport.earned, 20 * 3_600 * 0.1))
        // Without Offline Mining, the first six minutes away pay a tenth of it.
        var none = GameState.make(miners: minersEarning(20))
        none.advance(to: at(600))
        #expect(approx(none.coins, 20 * 360 * 0.1))
    }

    @Test func aGapUnderAMinuteIsLivePlayAndPaidInFullButTimeAwayPaysTheShare() {
        // 20 coins a second at a ten percent share, with Offline Mining for six minutes.
        for seconds in [30.0, 59] {
            var state = earner(offlineHours: 0.1, efficiency: 0)
            state.advance(to: at(seconds))
            #expect(approx(state.coins, 20 * seconds), "\(seconds)s") // Live play: all of it.
        }
        for seconds in [60.0, 61, 200, 360, 400] {
            var state = earner(offlineHours: 0.1, efficiency: 0)
            state.advance(to: at(seconds))
            #expect(approx(state.coins, 20 * min(seconds, 6 * 60) * 0.1), "\(seconds)s") // Time away: a tenth.
        }
    }

    @Test func efficiencyAppliesToABullRunToo() throws {
        // A Bull Run that ends after a minute pays its extra at 30% too, like the rest.
        var inside = earner(offlineHours: 0.5, efficiency: 4) // 30%
        inside.boost = Boost(multiplier: 7, endsAt: at(60))
        let insideResult = inside.advance(to: at(600))
        let insideReport = try #require(insideResult)
        let insideEarned: Double = (60 * 140 + 540 * 20) * 0.3
        #expect(approx(insideReport.earned, insideEarned))
        #expect(approx(insideReport.sources.reduce(0) { $0 + $1.coins }, insideReport.earned))
        // One that runs on for five minutes.
        var long = earner(offlineHours: 0.5, efficiency: 4)
        long.boost = Boost(multiplier: 7, endsAt: at(300))
        let longResult = long.advance(to: at(600))
        let longReport = try #require(longResult)
        #expect(longReport.boostedSeconds == 300)
        #expect(approx(longReport.earned, (300 * 140.0 + 300 * 20) * 0.3))
        #expect(approx(longReport.sources.reduce(0) { $0 + $1.coins }, longReport.earned))
    }

    @Test func theReportBreaksDownWhatEarnedTheCoins() throws {
        var state = GameState.make(miners: [.desktop: 10, .chromebook: 2, .server: 2],
                                   upgrades: [.coinClicker, .upgradedClicker, .automatedClicker, .overclocking])
        state.setOfflineMining(hours: 1)
        state.powerUps[.offlineEfficiency] = PowerUpID.offlineEfficiency.maxLevel
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
        #expect(approx(report.multipliers.upgrades, 1.25))
        #expect(approx(report.multipliers.prestige, 1.1))
        #expect(approx(report.multipliers.achievements, 1.02))
        #expect(report.multipliers.difficulty == 1)
        #expect(approx(report.multipliers.total, 1.25 * 1.1 * 1.02))
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
        var state = earner(offlineHours: 0.5)
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
