import ActivityKit
import UIKit
import WidgetKit
import CryptoClickerKit

/// Shares the balance beyond the app: the widgets read it from the app group, and the Live
/// Activity on the Lock Screen and in the Dynamic Island gets it with each update.
@MainActor
final class BalanceSharing {
    private var lastWidgetReload = Date.distantPast
    private var lastActivityUpdate = Date.distantPast

    /// Shares `snapshot`. `force` (the app opening or going to the background) updates everything
    /// at once; otherwise the widgets reload at most every five minutes and the Live Activity
    /// updates at most every minute. The Live Activity only runs while it's on (`liveActivity`)
    /// and miners are earning: a new game has nothing to show yet.
    func share(_ snapshot: BalanceSnapshot, liveActivity: Bool, force: Bool) {
        let now = Date.now
        WidgetShare.store(snapshot)
        // The widgets project the balance forward themselves, so they only need the new snapshot
        // when something changed: right away as the app closes, and now and then while it's open.
        if force || now.timeIntervalSince(lastWidgetReload) >= 300 {
            lastWidgetReload = now
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShare.balanceKind)
        }
        guard liveActivity && snapshot.income > 0 else {
            if !Activity<MiningActivityAttributes>.activities.isEmpty {
                Task { await Self.endActivities() }
            }
            return
        }
        guard force || now.timeIntervalSince(lastActivityUpdate) >= 60 else { return }
        lastActivityUpdate = now
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Stale once the miners stop: the Live Activity then shows the balance waiting to be collected.
        let content = ActivityContent(state: snapshot, staleDate: snapshot.miningEndsAt)
        if Activity<MiningActivityAttributes>.activities.contains(where: { $0.activityState == .active }) {
            // The update can finish after the app has gone to the background, so it asks for time.
            let task = UIApplication.shared.beginBackgroundTask(withName: "Update the Live Activity")
            Task {
                await Self.update(with: content)
                UIApplication.shared.endBackgroundTask(task)
            }
        } else if UIApplication.shared.applicationState == .active {
            // A new one can only start while the app is in front. If it can't (Live Activities
            // turned off for the app, say), the widgets still have the balance.
            _ = try? Activity.request(attributes: MiningActivityAttributes(), content: content)
        }
    }

    /// Updates the running Live Activity, and ends any others (one from an earlier launch, say).
    private nonisolated static func update(with content: ActivityContent<BalanceSnapshot>) async {
        let running = Activity<MiningActivityAttributes>.activities.filter { $0.activityState == .active }
        guard let current = running.first else { return }
        await current.update(content)
        for extra in running.dropFirst() {
            await extra.end(nil, dismissalPolicy: .immediate)
        }
    }

    private nonisolated static func endActivities() async {
        for activity in Activity<MiningActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
