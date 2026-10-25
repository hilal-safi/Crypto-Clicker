import Foundation
import WatchConnectivity
import CryptoClickerKit

/// The Apple Watch end of the iPhone connection.
///
/// The phone owns the game. It sends `WatchSnapshot`s here; taps made on the watch go back
/// as `WatchTapBatch`es through `transferUserInfo`, which queues them, delivers them in order
/// and keeps them safe if either app quits. The phone applies each batch once, by id.
@MainActor
final class PhoneLink: NSObject {
    var onSnapshot: ((WatchSnapshot) -> Void)?
    var onActivated: (() -> Void)?
    var onReachabilityChange: ((Bool) -> Void)?

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    var isActivated: Bool { session?.activationState == .activated }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Queues taps for the phone. Only call once the session is activated.
    func send(_ batch: WatchTapBatch) {
        guard let session, session.activationState == .activated,
              let payload = WatchPayload.make(batch, key: WatchPayload.tapBatchKey) else { return }
        session.transferUserInfo(payload)
    }

    /// Asks the phone for fresh numbers and a step sync. Wakes the iPhone app if needed.
    func requestRefresh() {
        guard let session, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([WatchPayload.refreshKey: true], replyHandler: nil, errorHandler: nil)
    }
}

extension PhoneLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        // The application context holds the newest snapshot sent while this app wasn't running.
        let snapshot = WatchPayload.read(WatchSnapshot.self, key: WatchPayload.snapshotKey,
                                         from: session.receivedApplicationContext)
        let reachable = session.isReachable
        Task { @MainActor in
            if let snapshot { self.onSnapshot?(snapshot) }
            self.onReachabilityChange?(reachable)
            self.onActivated?()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let snapshot = WatchPayload.read(WatchSnapshot.self, key: WatchPayload.snapshotKey,
                                               from: applicationContext) else { return }
        Task { @MainActor in self.onSnapshot?(snapshot) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let snapshot = WatchPayload.read(WatchSnapshot.self, key: WatchPayload.snapshotKey,
                                               from: message) else { return }
        Task { @MainActor in self.onSnapshot?(snapshot) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.onReachabilityChange?(reachable) }
    }
}
