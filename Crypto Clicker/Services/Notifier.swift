import Foundation
import UserNotifications

/// Local reminders the player can turn on in Settings: when Offline Mining runs out, and when the
/// daily reward is ready. They are scheduled as the app goes to the background and cleared when
/// it comes back, so they only ever arrive while the game is closed.
@MainActor
final class Notifier {
    enum ID: String, CaseIterable {
        case minersStopped = "miners-stopped"
        case dailyReward = "daily-reward"
    }

    struct Reminder {
        let id: ID
        let date: Date
        let title: String
        let body: String
    }

    private var center: UNUserNotificationCenter { .current() }

    /// Asks for permission the first time; after that, reports the answer the player gave.
    func requestPermission() async -> Bool {
        switch await Self.authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await Self.requestAuthorization()
        @unknown default:
            return false
        }
    }

    // Off the main actor, so the settings object never has to cross over to it.
    nonisolated private static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    nonisolated private static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces any pending reminders with these.
    func replace(with reminders: [Reminder]) {
        center.removePendingNotificationRequests(withIdentifiers: ID.allCases.map(\.rawValue))
        for reminder in reminders {
            let delay = reminder.date.timeIntervalSinceNow
            guard delay >= 60 else { continue }
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            center.add(UNNotificationRequest(identifier: reminder.id.rawValue, content: content, trigger: trigger),
                       withCompletionHandler: nil)
        }
    }

    /// Clears pending and delivered reminders: the player is back.
    func clear() {
        let ids = ID.allCases.map(\.rawValue)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// When to remind about the daily reward: 7 pm today while today's is still waiting (so the
    /// streak isn't lost), otherwise 10 am on the next day.
    static func nextReminder(after now: Date, rewardWaitingToday: Bool, calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        if rewardWaitingToday,
           let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: startOfToday),
           evening.timeIntervalSince(now) >= 60 {
            return evening
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow.addingTimeInterval(36_000)
    }
}
