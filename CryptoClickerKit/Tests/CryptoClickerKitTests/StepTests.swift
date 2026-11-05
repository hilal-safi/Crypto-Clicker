import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Steps")
struct StepTests {
    let today = "2026-10-24"

    /// A player who has tapped enough to unlock steps.
    func unlocked() -> GameState {
        var game = GameState.make()
        game.stats.taps = Tuning.stepsUnlockTaps
        return game
    }

    /// Connected on a later day of the game: steps are paid as they're walked.
    func connected() -> GameState {
        var game = unlocked()
        game.connectSteps(today: today)
        return game
    }

    /// Connected on the game's first day: that day's steps wait for the next.
    func firstDay() -> GameState {
        var game = connected()
        game.daily.firstDay = today
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

    @Test func stepsUnlockAfterEnoughTaps() {
        var game = GameState.make()
        #expect(!game.areStepsUnlocked)
        #expect(game.tapsUntilSteps == 2_000)
        #expect(game.connectSteps(today: today) == false)
        #expect(!game.steps.isConnected)
        game.tap(count: 1_500, at: t0)
        // Taps on Apple Watch count too.
        game.applyWatchTaps(WatchTapBatch(taps: 499, date: t0), at: t0)
        #expect(game.tapsUntilSteps == 1)
        #expect(!game.areStepsUnlocked)
        game.tap(at: t0)
        #expect(game.areStepsUnlocked)
        #expect(game.tapsUntilSteps == 0)
        #expect(game.connectSteps(today: today) == true)
        #expect(game.steps.isConnected)
    }

    let tomorrow = "2026-10-25"

    @Test func theFirstDaysStepsCountNowAndArePaidTomorrow() {
        var game = firstDay()
        #expect(game.stepsPaidNextDay(today: today))
        let walked = game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0)
        // Counted at once (quests, achievements and records see them)...
        #expect(walked == StepCredit(steps: 0, coins: 0, counted: 5_000))
        #expect(game.coins == 0)
        #expect(game.stats.lifetimeSteps == 5_000)
        #expect(game.stats.bestDaySteps == 5_000)
        #expect(game.stats.stepsPaid == 0)
        #expect(game.steps.todaySteps == 5_000)
        #expect(game.steps.todayKey == today)
        #expect(game.steps.lastSync == t0)
        #expect(game.pendingStepCoins(today: today) == 5_000)
        // ...and paid the next day, a coin each at least, along with the second day's steps so far:
        // from then on, steps are paid as they're walked.
        #expect(!game.stepsPaidNextDay(today: tomorrow))
        let paid = game.creditSteps([StepDay(key: today, steps: 5_000), StepDay(key: tomorrow, steps: 300)],
                                    today: tomorrow, at: at(86_400))
        #expect(paid == StepCredit(steps: 5_300, coins: 5_300, counted: 300, days: [today, tomorrow]))
        #expect(game.coins == 5_300)
        #expect(game.stats.earnedFromSteps == 5_300)
        #expect(game.stats.stepsPaid == 5_300)
        #expect(game.stats.lifetimeSteps == 5_300)
        #expect(game.steps.todaySteps == 300)
        #expect(game.pendingStepCoins(today: tomorrow) == 0)
        #expect(game.pendingStepCoins(today: today) == 0)
    }

    @Test func afterTheFirstDayStepsArePaidAsTheyreWalked() {
        var game = connected()
        #expect(!game.stepsPaidNextDay(today: today))
        let walked = game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0)
        #expect(walked == StepCredit(steps: 5_000, coins: 5_000, counted: 5_000, days: [today]))
        #expect(game.coins == 5_000)
        #expect(game.stats.stepsPaid == 5_000 && game.stats.lifetimeSteps == 5_000)
        #expect(game.pendingStepCoins(today: today) == 0)
        let more = game.creditSteps([StepDay(key: today, steps: 7_250)], today: today, at: at(60))
        #expect(more == StepCredit(steps: 2_250, coins: 2_250, counted: 2_250, days: [today]))
        // Nothing is left for tomorrow.
        let next = game.creditSteps([StepDay(key: today, steps: 7_250)], today: tomorrow, at: at(86_400))
        #expect(next.steps == 0)
        #expect(game.coins == 7_250)
        // A game from before the first day was recorded pays as it goes too.
        var old = connected()
        old.daily.firstDay = nil
        #expect(!old.stepsPaidNextDay(today: today))
    }

    @Test func syncingTwiceCountsAndPaysOnce() {
        for start in [firstDay(), connected()] {
            var game = start
            game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0)
            let again = game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: at(60))
            #expect(again == StepCredit(steps: 0, coins: 0, counted: 0))
            #expect(game.stats.lifetimeSteps == 5_000)
            #expect(game.steps.lastSync == at(60))
            game.creditSteps([StepDay(key: today, steps: 5_000)], today: tomorrow, at: at(86_400))
            let twice = game.creditSteps([StepDay(key: today, steps: 5_000)], today: tomorrow, at: at(86_460))
            #expect(twice.steps == 0)
            #expect(game.coins == 5_000)
            #expect(game.stats.stepsPaid == 5_000)
        }
    }

    @Test func moreStepsLaterInTheFirstDayAreAllPaidTomorrow() {
        var game = firstDay()
        game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0)
        let more = game.creditSteps([StepDay(key: today, steps: 7_250)], today: today, at: at(60))
        #expect(more.counted == 2_250 && more.steps == 0)
        #expect(game.stats.lifetimeSteps == 7_250)
        #expect(game.stats.bestDaySteps == 7_250)
        let paid = game.creditSteps([StepDay(key: today, steps: 7_250)], today: tomorrow, at: at(86_400))
        #expect(paid.steps == 7_250 && paid.coins == 7_250)
    }

    @Test func aLowerCountNeverTakesStepsBack() {
        var game = firstDay()
        game.creditSteps([StepDay(key: today, steps: 7_000)], today: today, at: t0)
        let lower = game.creditSteps([StepDay(key: today, steps: 6_000)], today: today, at: at(60))
        #expect(lower.counted == 0)
        #expect(game.stats.lifetimeSteps == 7_000)
        #expect(game.steps.todaySteps == 6_000)
        let back = game.creditSteps([StepDay(key: today, steps: 7_100)], today: today, at: at(120))
        #expect(back.counted == 100)
        let paid = game.creditSteps([StepDay(key: today, steps: 7_100)], today: tomorrow, at: at(86_400))
        #expect(paid.steps == 7_100)
    }

    @Test func daysBeforeConnectingAreNeverCounted() {
        var game = connected()
        let credit = game.creditSteps(week([9_000, 9_000, 9_000, 9_000, 9_000, 9_000, 1_000]), today: today, at: t0)
        #expect(credit.counted == 1_000 && credit.steps == 1_000)
        #expect(game.stats.bestDaySteps == 1_000)
    }

    @Test func lateArrivingStepsForEarlierDaysArePaid() {
        var game = unlocked()
        game.connectSteps(today: "2026-10-20")
        let first = game.creditSteps(week([0, 0, 4_000, 3_000, 0, 0, 0]), today: today, at: t0)
        #expect(game.coins == 7_000)
        #expect(first.days == ["2026-10-20", "2026-10-21"])
        // The watch synced more steps for the 21st later on, and for the 22nd and today.
        let late = game.creditSteps(week([0, 0, 4_000, 8_000, 2_000, 0, 500]), today: today, at: at(60))
        #expect(late.steps == 5_000 + 2_000 + 500) // Today's are paid too: it isn't the first day.
        #expect(late.counted == 5_000 + 2_000 + 500)
        #expect(game.stats.bestDaySteps == 8_000)
        #expect(game.steps.todaySteps == 500)
    }

    @Test func aWeekAwayIsPaidOnReturn() {
        var game = unlocked()
        game.connectSteps(today: "2026-10-18")
        game.daily.firstDay = "2026-10-18"
        game.creditSteps([StepDay(key: "2026-10-18", steps: 2_000)], today: "2026-10-18", at: t0)
        // Back a week later: the first day's steps, every day since and today's are all paid.
        let back = game.creditSteps(week([2_500, 1_000, 1_000, 1_000, 1_000, 1_000, 4_000]), today: today, at: at(6 * 86_400))
        #expect(back.steps == 2_500 + 5_000 + 4_000)
        #expect(back.days.count == 7)
        #expect(game.stats.lifetimeSteps == 2_500 + 5_000 + 4_000)
    }

    @Test func daysThatLeftTheWindowArePaidThenForgotten() {
        var game = unlocked()
        game.connectSteps(today: "2026-10-01")
        game.daily.firstDay = "2026-10-10"
        game.creditSteps([StepDay(key: "2026-10-10", steps: 3_000)], today: "2026-10-10", at: t0)
        #expect(game.steps.counted["2026-10-10"] == 3_000)
        #expect(game.steps.credited["2026-10-10"] == nil)
        // Two weeks later the 10th has left the window: it's paid before it's dropped.
        let later = game.creditSteps(week([1, 1, 1, 1, 1, 1, 1]), today: today, at: at(60))
        #expect(later.steps == 3_000 + 7)
        #expect(game.steps.counted["2026-10-10"] == nil && game.steps.credited["2026-10-10"] == nil)
        #expect(game.steps.counted.count == 7 && game.steps.credited.count == 7)
    }

    @Test func disconnectingPausesCounting() {
        var game = connected()
        game.disconnectSteps()
        #expect(game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0).counted == 0)
        game.connectSteps(today: "2026-10-25")
        #expect(game.steps.startDay == today) // Reconnecting keeps the original start day.
        #expect(game.creditSteps([StepDay(key: today, steps: 5_000)], today: today, at: t0).counted == 5_000)
    }

    @Test func savesFromBeforeNextDayPayingNeverPayTwice() throws {
        // An older save paid steps as they came: 4,000 of today's were already paid.
        let old = Data(#"{"isConnected":true,"startDay":"2026-10-20","credited":{"2026-10-24":4000},"todayKey":"2026-10-24","todaySteps":4000}"#.utf8)
        var game = connected()
        game.steps = try GameCoding.decoder().decode(StepLedger.self, from: old)
        #expect(game.steps.counted == ["2026-10-24": 4_000])
        let now = game.creditSteps([StepDay(key: today, steps: 6_000)], today: today, at: t0)
        #expect(now.steps == 2_000) // Only the steps walked after the update.
        let later = game.creditSteps([StepDay(key: today, steps: 6_000)], today: tomorrow, at: at(86_400))
        #expect(later.steps == 0)
        let stats = try GameCoding.decoder().decode(Stats.self, from: Data(#"{"lifetimeSteps":9000}"#.utf8))
        #expect(stats.stepsPaid == 9_000)
    }

    @Test func stepValueScalesWithIncomeAndUpgrades() {
        var game = connected()
        #expect(game.stepValue == 1)
        game.upgrades = [.stepBooster]
        #expect(game.stepValue == 2) // Boosters multiply the one-coin floor too.
        game.miners = [.desktop: 50] // 400 coins per second.
        #expect(game.stepValue == 48) // 0.06 × 400 × 2
        let credit = game.creditSteps([StepDay(key: today, steps: 1_000)], today: today, at: t0)
        #expect(credit.coins == 48_000)
    }

    @Test func stepsAreWorthWholeCoins() {
        var game = connected()
        game.miners = minersEarning(20) // 20 coins per second: 1.2 coins a step, paid as 1.
        #expect(game.stepValue == 1)
        game.miners = [.gpuRig: 5] // 30 coins per second: 1.8 coins a step, paid as 2.
        #expect(game.stepValue == 2)
    }

    @Test func playersWhoConnectedBeforeStayUnlocked() {
        // A save from before the tap requirement: steps were connected with few taps, then paused.
        var game = GameState.make()
        game.stats.taps = 40
        game.steps.isConnected = true
        game.steps.startDay = "2026-10-01"
        game.disconnectSteps()
        #expect(game.areStepsUnlocked)
        let reconnected = game.connectSteps(today: today)
        #expect(reconnected)
    }

    @Test func stepUpgradesWaitUntilStepsUnlock() {
        var game = GameState.make()
        game.stats.runCoins = 1e12
        #expect(!game.isRevealed(.stepBooster))
        #expect(!game.isRevealed(.ultimateStepBooster))
        #expect(game.isRevealed(.overclocking))
        game.stats.taps = Tuning.stepsUnlockTaps
        #expect(game.isRevealed(.stepBooster))
    }

    @Test func theFirstStepBoosterCostsMore() {
        // It used to cost 1,000, which let walking outpace tapping right away.
        #expect(UpgradeID.stepBooster.listCost == 25_000)
        #expect(UpgradeID.stepBooster.cost == Tuning.scaledPrice(25_000))
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
