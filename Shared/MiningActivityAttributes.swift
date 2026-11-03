import ActivityKit
import CryptoClickerKit

// Shared by the app and its widgets.

/// The Live Activity on the Lock Screen and in the Dynamic Island: the coin, the balance, and what
/// the miners earn while the game is closed. Its state is the snapshot the widgets read.
struct MiningActivityAttributes: ActivityAttributes {
    typealias ContentState = BalanceSnapshot
}
