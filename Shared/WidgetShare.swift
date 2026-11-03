import Foundation
import CryptoClickerKit

// Shared by the app and its widgets.

/// Where the app leaves its balance for the widgets: the app group both belong to.
enum WidgetShare {
    /// The app group in the app's and the widgets' entitlements.
    static let appGroup = "group.Hilal-Safi.Crypto-Clicker"
    /// The balance widget's kind, for reloading its timelines.
    static let balanceKind = "Balance"
    private static let snapshotKey = "balanceSnapshot"

    /// Leaves `snapshot` for the widgets.
    static func store(_ snapshot: BalanceSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    /// The last snapshot the app left, or `nil` before it has left one (or when the app group
    /// isn't set up for this build).
    static func load() -> BalanceSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(BalanceSnapshot.self, from: data)
    }
}
