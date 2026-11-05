import Foundation
import WatchConnectivity
import CryptoClickerKit

/// The iPhone end of the Apple Watch connection.
///
/// - Phone to watch: the latest `WatchSnapshot`, as the application context (the watch gets
///   it whenever it next runs) and as a live message while the watch app is open.
/// - Watch to phone: tap batches through `transferUserInfo`, which queues, survives either
///   app quitting and arrives in order. Each batch lands in `inbox` and is applied once, by id.
@MainActor
final class WatchBridge: NSObject {
    enum Status: Equatable {
        case unsupported, notPaired, appNotInstalled, connected
    }

    private(set) var status = Status.unsupported
    nonisolated let inbox = WatchTapInbox()
    var onTapBatchesReceived: (() -> Void)?
    var onRefreshRequest: (() -> Void)?
    var onStatusChange: ((Status) -> Void)?

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    /// Must run at launch so transfers that arrived while the app was closed are delivered.
    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func send(_ snapshot: WatchSnapshot) {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let payload = WatchPayload.make(snapshot, key: WatchPayload.snapshotKey) else { return }
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    private func refreshStatus() {
        let newStatus: Status
        if let session, session.activationState == .activated {
            newStatus = !session.isPaired ? .notPaired : !session.isWatchAppInstalled ? .appNotInstalled : .connected
        } else {
            newStatus = .unsupported
        }
        guard newStatus != status else { return }
        status = newStatus
        onStatusChange?(newStatus)
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        Task { @MainActor in self.refreshStatus() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Called after switching to another Apple Watch: reconnect to the new one.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshStatus() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.onRefreshRequest?() }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let batch = WatchPayload.read(WatchTapBatch.self, key: WatchPayload.tapBatchKey, from: userInfo) else { return }
        inbox.append(batch) // On disk before returning: the watch now considers it delivered.
        Task { @MainActor in self.onTapBatchesReceived?() }
    }

    /// The watch asks for fresh numbers (and a step sync) when its app opens.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message[WatchPayload.refreshKey] != nil else { return }
        Task { @MainActor in self.onRefreshRequest?() }
    }
}
