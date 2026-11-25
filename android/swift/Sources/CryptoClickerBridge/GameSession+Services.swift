import Foundation
import CryptoClickerKit

/// A reminder to schedule as the app goes to the background (iOS: Notifier.Reminder).
struct Reminder: Equatable {
    enum ID: String, CaseIterable {
        case minersStopped = "miners-stopped"
        case dailyReward = "daily-reward"
    }

    let id: ID
    let date: Date
    let title: String
    let body: String
}

// Everything beyond the app: reminders, Health Connect steps and the widget (iOS: GameStore+Services,
// with Apple Health, the watch and the Live Activity). The Android app does the platform's part (it
// reads Health Connect, posts notifications, draws the widget) and the game's part happens here.
extension GameSession {
    // MARK: Notifications

    /// The reminders turned on in Settings, worked out as the app goes to the background. The app
    /// schedules them, and clears them when it comes back.
    func reminders(notifyMiners: Bool, notifyDaily: Bool) -> [Reminder] {
        guard !isSaveLocked else { return [] }
        let now = self.now
        var reminders: [Reminder] = []
        let cap = game.offlineCap
        let income = game.baseIdleIncome
        if notifyMiners, cap >= 30 * 60, income > 0 {
            reminders.append(Reminder(
                id: .minersStopped, date: game.lastUpdate.addingTimeInterval(cap),
                title: "Your miners have stopped",
                body: "Offline Mining ran for \(CoinFormat.duration(cap)). Open Crypto Clicker to collect about \(CoinFormat.short(income * game.paidAwaySeconds(cap))) coins and start them again."))
        }
        if notifyDaily {
            let today = StepDay.key(for: now)
            let isWaiting = game.isDailyRewardReady(today: today)
            let date = Self.nextReminder(after: now, rewardWaitingToday: isWaiting)
            let streak = game.streakIfClaimed(today: StepDay.key(for: date), yesterday: StepDay.previousKey(before: date))
            let sameDay = StepDay.key(for: date) == today
            reminders.append(Reminder(
                id: .dailyReward, date: date,
                title: sameDay ? "Your daily reward is waiting" : "Your daily reward is ready",
                body: streak > 1 ? "Claim it to make your streak \(streak) days." : "Claim it in Trophies › Daily."))
        }
        // As on iOS, a reminder less than a minute away isn't worth sending.
        return reminders.filter { $0.date.timeIntervalSince(now) >= 60 }
    }

    /// When to remind about the daily reward: 7 pm today while today's is still waiting (so the
    /// streak isn't lost), otherwise 10 am on the next day.
    static func nextReminder(after now: Date, rewardWaitingToday: Bool, calendar: Calendar = StepDay.calendar()) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        if rewardWaitingToday,
           let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: startOfToday),
           evening.timeIntervalSince(now) >= 60 {
            return evening
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow.addingTimeInterval(36_000)
    }

    // MARK: Health Connect (iOS: Apple Health)

    /// Starts rewarding steps, once the app has Health Connect's permission. Steps unlock after
    /// 2,000 taps.
    @discardableResult
    func connectSteps() -> Bool {
        guard game.areStepsUnlocked, !game.steps.isConnected else { return false }
        perform { game, now in game.connectSteps(today: StepDay.key(for: now)) }
        return game.steps.isConnected
    }

    func disconnectSteps() {
        perform { game, _ in game.disconnectSteps() }
    }

    /// Counts new steps and pays for them (as they're walked, or the next day for the game's first
    /// day). `days` are Health Connect's daily totals for the sync window: each day's start and its
    /// steps. Safe to call at any time: the ledger never counts or pays a step twice.
    func creditSteps(_ days: [(start: Date, steps: Int)]) {
        let now = self.now
        guard !isSaveLocked, game.steps.isConnected else { return }
        let stepDays = days.map { StepDay(key: StepDay.key(for: $0.start), steps: max(0, $0.steps)) }
        let credit = perform { game, now in game.creditSteps(stepDays, today: StepDay.key(for: now), at: now) }
        // While the welcome-back screen is up, it lists the steps walked and what they paid
        // (steps still waiting for tomorrow's payment included) instead of a separate toast.
        let taken = max(credit.steps, credit.counted)
        // Steps are paid on every sync now, so a handful walked since the last one goes by quietly.
        let onlyToday = credit.days == [StepDay.key(for: now)]
        if taken > 0, welcomeBack != nil {
            welcomeBack?.steps += taken
            welcomeBack?.stepCoins += credit.coins
            publish()
        } else if credit.steps > 0 && (!onlyToday || credit.steps >= Tuning.stepsToastMinimum) {
            let isYesterday = credit.days.first == StepDay.previousKey(before: now)
            show("👣", isYesterday ? "Yesterday's steps paid" : "Steps paid",
                 "\(CoinFormat.grouped(credit.steps)) steps · +\(CoinFormat.short(credit.coins)) coins")
        }
    }

    // MARK: The widget

    /// The balance and what it's earning, for the home screen widget, anchored at the game clock
    /// (which stays put in the background), so it projects what the game will credit.
    func balanceSnapshot(finish: CoinFinish) -> BalanceSnapshot {
        if isInForeground { catchUp(to: now) }
        return game.balanceSnapshot(finish: finish.isUnlocked(stars: game.earnedAchievementTiers) ? finish : .gold)
    }
}
