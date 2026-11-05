import SwiftUI
import CryptoClickerKit

// Everything beyond the app: reminders, Apple Health, Apple Watch, and the widgets and Live
// Activity.
extension GameStore {
    // MARK: Notifications

    /// Asks once for permission to send reminders. Returns whether they are allowed.
    func requestNotificationPermission() async -> Bool {
        await notifier.requestPermission()
    }

    /// Schedules the reminders turned on in Settings, as the app goes to the background.
    func scheduleNotifications() {
        guard !isSaveLocked else { return }
        let defaults = UserDefaults.standard
        let now = Date.now
        var reminders: [Notifier.Reminder] = []
        let cap = game.offlineCap
        let income = game.baseIdleIncome
        if defaults.bool(forKey: Preferences.notifyMinersKey), cap >= 30 * 60, income > 0 {
            reminders.append(Notifier.Reminder(
                id: .minersStopped, date: game.lastUpdate.addingTimeInterval(cap),
                title: "Your miners have stopped",
                body: "Offline Mining ran for \(CoinFormat.duration(cap)). Open Crypto Clicker to collect about \(CoinFormat.short(income * cap)) coins and start them again."))
        }
        if defaults.bool(forKey: Preferences.notifyDailyKey) {
            let today = StepDay.key(for: now)
            let isWaiting = game.isDailyRewardReady(today: today)
            let date = Notifier.nextReminder(after: now, rewardWaitingToday: isWaiting)
            let streak = game.streakIfClaimed(today: StepDay.key(for: date), yesterday: StepDay.previousKey(before: date))
            let sameDay = StepDay.key(for: date) == today
            reminders.append(Notifier.Reminder(
                id: .dailyReward, date: date,
                title: sameDay ? "Your daily reward is waiting" : "Your daily reward is ready",
                body: streak > 1 ? "Claim it to make your streak \(streak) days." : "Claim it in Trophies › Daily."))
        }
        notifier.replace(with: reminders)
    }

    // MARK: Apple Health

    /// Asks for Health access and starts rewarding steps. Steps unlock after 2,000 taps.
    func connectSteps() async {
        guard game.areStepsUnlocked, !game.steps.isConnected else { return }
        do {
            try await stepTracker.requestAccess()
        } catch {
            errorMessage = "Apple Health couldn't be connected. \(error.localizedDescription)"
            return
        }
        perform { game, now in game.connectSteps(today: StepDay.key(for: now)) }
        await syncSteps(force: true)
    }

    func disconnectSteps() {
        perform { game, _ in game.disconnectSteps() }
        pushToWatch(force: true)
    }

    /// Counts new steps and pays for them (as they're walked, or the next day for the game's first
    /// day). Safe to call at any time: the ledger never counts or pays a step twice.
    func syncSteps(force: Bool = false) async {
        let now = Date.now
        guard !isSaveLocked, game.steps.isConnected, !isSyncingSteps,
              force || now.timeIntervalSince(lastStepSync) >= 60 else { return }
        isSyncingSteps = true
        lastStepSync = now
        defer { isSyncingSteps = false }
        // Health data can't be read while the iPhone is locked; the next sync catches up.
        guard let days = try? await stepTracker.dailySteps(days: Tuning.stepWindowDays) else { return }
        let credit = perform { game, now in game.creditSteps(days, today: StepDay.key(for: now), at: now) }
        // Steps are paid on every sync now, so a handful walked since the last one goes by quietly.
        let onlyToday = credit.days == [StepDay.key(for: now)]
        if credit.steps > 0 && (!onlyToday || credit.steps >= Tuning.stepsToastMinimum) {
            let isYesterday = credit.days.first == StepDay.previousKey(before: now)
            show(Toast(icon: "👣", title: isYesterday ? "Yesterday's steps paid" : "Steps paid",
                       message: "\(CoinFormat.grouped(credit.steps)) steps · +\(CoinFormat.short(credit.coins)) coins"))
        }
        pushToWatch(force: true)
    }

    // MARK: Apple Watch

    /// Applies watch taps waiting in the inbox, then clears them once the game that includes
    /// them is saved. Batch ids make a repeat (after a crash in between) harmless.
    func applyWatchInbox() {
        guard !isSaveLocked else { return }
        let batches = watch.inbox.pending()
        guard !batches.isEmpty else { return }
        for batch in batches {
            perform { game, now in game.applyWatchTaps(batch, at: now) }
        }
        if save() { watch.inbox.remove(Set(batches.map(\.id))) }
        pushToWatch(force: true)
    }

    /// The watch asked for fresh numbers, or came into reach. Steps sync at most once a minute, so a
    /// watch opening and closing doesn't read Apple Health each time.
    func refreshWatch() {
        pushToWatch(force: true)
        Task { await syncSteps() }
    }

    func pushToWatch(force: Bool = false) {
        guard !isSaveLocked else { return }
        let now = Date.now
        guard force || now.timeIntervalSince(lastWatchPush) >= 60 else { return }
        lastWatchPush = now
        if isInForeground { catchUp(to: now) }
        // The balance is anchored at the game clock, which stays put in the background, so the watch
        // projects exactly what the phone will credit (up to the offline cap) when it next opens.
        // The once-a-minute refresh only corrects drift, so it waits for the watch app to read it;
        // purchases, taps and other changes go straight to an open watch app.
        watch.send(game.watchSnapshot(at: now), live: force)
    }

    // MARK: Widgets and the Live Activity

    /// Shares the balance with the widgets and the Live Activity: at once as the app opens or goes
    /// to the background, and otherwise about once a minute while it's open. Like the watch's, the
    /// balance is anchored at the game clock, so both project what the game will credit.
    func shareBalance(force: Bool = false) {
        guard !isSaveLocked else { return }
        let now = Date.now
        guard force || now.timeIntervalSince(lastBalanceShare) >= 60 else { return }
        lastBalanceShare = now
        if isInForeground { catchUp(to: now) }
        balanceSharing.share(game.balanceSnapshot(finish: coinFinish), liveActivity: Preferences.showsLiveActivity, force: force)
    }

    /// The coin's finish picked in Settings, or gold while it's locked.
    private var coinFinish: CoinFinish {
        let picked = UserDefaults.standard.string(forKey: Preferences.coinFinishKey).flatMap(CoinFinish.init(rawValue:)) ?? .gold
        return picked.isUnlocked(stars: game.earnedAchievementTiers) ? picked : .gold
    }

    /// Starts or ends the Live Activity when its setting changes.
    func liveActivitySettingChanged() {
        shareBalance(force: true)
    }
}
