import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Steps")
struct StepTests {
    let today = "2026-10-24"

    func connected() -> GameState {
        var game = GameState.make()
        game.connectSteps(today: today)
        return game
    }

    func week(_ steps: [Int]) -> [StepDay] {
        // Seven days ending today, oldest first, as StepTracker reports them.
        let keys = ["2026-10-18", "2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24"]
        return zip(keys, steps).map { StepDay(key: $0, steps: $1) }
    }

    @Test func nothingIsPaidUntilConnected() {
        var game = GameState.make()
        let credit = game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0)
        #expect(credit == StepCredit(steps: 0, coins: 0))
        #expect(game.coins == 0)
        #expect(game.steps.lastSync == nil)
    }

    @Test func connectingStartsTheLedgerToday() {
        let game = connected()
        #expect(game.steps.isConnected)
        #expect(game.steps.startDay == today)
    }

    @Test func everyStepIsWorthAtLeastOneCoin() {
        var game = connected()
        let credit = game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0)
        #expect(credit == StepCredit(steps: 5_000, coins: 5_000))
        #expect(game.coins == 5_000)
        #expect(game.stats.lifetimeSteps == 5_000)
        #expect(game.stats.bestDaySteps == 5_000)
        #expect(game.stats.earnedFromSteps == 5_000)
        #expect(game.steps.todaySteps == 5_000)
        #expect(game.steps.todayKey == today)
        #expect(game.steps.lastSync == t0)
    }

    @Test func syncingTwicePaysOnce() {
        var game = connected()
        game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0)
        let again = game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: at(60))
        #expect(again.steps == 0)
        #expect(game.coins == 5_000)
        #expect(game.steps.lastSync == at(60))
    }

    @Test func onlyNewStepsArePaid() {
        var game = connected()
        game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0)
        let more = game.creditSteps([StepDay(key: today, steps: 7_250)], today: today, at: at(60))
        #expect(more == StepCredit(steps: 2_250, coins: 2_250))
        #expect(game.stats.lifetimeSteps == 7_250)
        #expect(game.stats.bestDaySteps == 7_250)
    }

    @Test func aLowerCountNeverTakesCoinsBack() {
        var game = connected()
        game.creditSteps([StepDay(key: today, steps: 7_000)], today: today, at: t0)
        let lower = game.creditSteps([StepDay(key: today, steps: 6_000)], today: today, at: at(60))
        #expect(lower.steps == 0)
        #expect(game.coins == 7_000)
        #expect(game.steps.todaySteps == 6_000)
        let back = game.creditSteps([StepDay(key: today, steps: 7_100)], today: today, at: at(120))
        #expect(back.steps == 100)
    }

    @Test func daysBeforeConnectingAreNeverPaid() {
        var game = connected()
        let credit = game.creditSteps(week([9_000, 9_000, 9_000, 9_000, 9_000, 9_000, 1_000]), today: today, at: t0)
        #expect(credit.steps == 1_000)
        #expect(game.stats.bestDaySteps == 1_000)
    }

    @Test func lateArrivingStepsForEarlierDaysArePaid() {
        var game = GameState.make()
        game.connectSteps(today: "2026-10-20")
        game.creditSteps(week([0, 0, 4_000, 3_000, 0, 0, 0]), today: today, at: t0)
        #expect(game.coins == 7_000)
        // The watch synced more steps for the 21st later on.
        let late = game.creditSteps(week([0, 0, 4_000, 8_000, 2_000, 0, 500]), today: today, at: at(60))
        #expect(late.steps == 5_000 + 2_000 + 500)
        #expect(game.stats.bestDaySteps == 8_000)
        #expect(game.steps.todaySteps == 500)
    }

    @Test func daysThatLeftTheWindowAreForgotten() {
        var game = GameState.make()
        game.connectSteps(today: "2026-10-01")
        game.creditSteps([StepDay(key: "2026-10-10", steps: 3_000)], today: "2026-10-10", at: t0)
        #expect(game.steps.credited["2026-10-10"] == 3_000)
        game.creditSteps(week([1, 1, 1, 1, 1, 1, 1]), today: today, at: at(60))
        #expect(game.steps.credited["2026-10-10"] == nil)
        #expect(game.steps.credited.count == 7)
    }

    @Test func disconnectingPausesPayments() {
        var game = connected()
        game.disconnectSteps()
        #expect(game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0).steps == 0)
        game.connectSteps(today: "2026-10-25")
        #expect(game.steps.startDay == today) // Reconnecting keeps the original start day.
        #expect(game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0).steps == 5_000)
    }

    @Test func stepValueScalesWithIncomeAndUpgrades() {
        var game = connected()
        #expect(game.stepValue == 1)
        game.upgrades = [.stepBooster]
        #expect(game.stepValue == 2) // Boosters multiply the one-coin floor too.
        game.miners = [.desktop: 50] // 400 coins per second.
        #expect(approx(game.stepValue, 0.06 * 400 * 2))
        let credit = game.creditSteps([StepDay(key: today, steps: 1_000)], today: today, at: t0)
        #expect(approx(credit.coins, 1_000 * 0.06 * 400 * 2))
    }

    @Test func dayKeysUseTheLocalGregorianDay() throws {
        let toronto = try #require(TimeZone(identifier: "America/Toronto"))
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        // 2026-10-25 02:30 UTC is still the 24th in Toronto but already the 25th in Tokyo.
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-25T02:30:00Z"))
        #expect(StepDay.key(for: date, in: toronto) == "2026-10-24")
        #expect(StepDay.key(for: date, in: tokyo) == "2026-10-25")
        #expect(StepDay.key(for: date, in: toronto) < StepDay.key(for: date, in: tokyo))
    }

    @Test func negativeStepCountsAreClampedToZero() {
        #expect(StepDay(key: "2026-10-24", steps: -40).steps == 0)
    }
}
