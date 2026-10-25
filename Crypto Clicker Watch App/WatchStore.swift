import SwiftUI
import CryptoClickerKit

/// The watch's view of the game: the phone's latest snapshot, projected forward in time,
/// plus taps that the phone has not confirmed yet.
@Observable @MainActor
final class WatchStore {
    private(set) var snapshot: WatchSnapshot?
    private(set) var queue: WatchTapQueue
    private(set) var isPhoneReachable = false
    /// Today's steps counted by this watch, once live steps are enabled.
    private(set) var liveSteps: Int?
    private(set) var liveStepsEnabled: Bool
    /// Increments on every tap, to trigger haptics.
    private(set) var taps = 0

    private let link = PhoneLink()
    private let stepCounter = WatchStepCounter()
    @ObservationIgnored private var sendTask: Task<Void, Never>?

    private enum Key {
        static let snapshot = "snapshot"
        static let queue = "tapQueue"
        static let liveSteps = "liveStepsEnabled"
    }

    /// Taps are collected for this long after the last one, so one transfer carries a burst.
    private static let sendDelay: Duration = .seconds(1.5)

    init() {
        snapshot = Self.load(WatchSnapshot.self, key: Key.snapshot)
        queue = Self.load(WatchTapQueue.self, key: Key.queue) ?? WatchTapQueue()
        liveStepsEnabled = UserDefaults.standard.bool(forKey: Key.liveSteps)
        link.onSnapshot = { [weak self] snapshot in self?.receive(snapshot) }
        link.onReachabilityChange = { [weak self] reachable in
            self?.isPhoneReachable = reachable
            if reachable { self?.link.requestRefresh() }
        }
        link.onActivated = { [weak self] in
            self?.sendPendingTaps()
            self?.link.requestRefresh()
        }
        link.activate()
    }

    // MARK: Reading

    var hasSnapshot: Bool { snapshot != nil }

    /// The phone's balance plus this watch's unconfirmed taps.
    func balance(at date: Date) -> Double {
        let projected = snapshot?.projectedCoins(at: date) ?? 0
        return projected + Double(queue.pendingTaps) * tapValue
    }

    var tapValue: Double { snapshot?.tapValue ?? 1 }

    func income(at date: Date) -> Double { snapshot?.income(at: date) ?? 0 }

    /// Steps the phone has paid for today.
    var collectedStepsToday: Int {
        guard let snapshot, snapshot.stepsDay == StepDay.key(for: .now) else { return 0 }
        return snapshot.stepsToday
    }

    /// Steps this watch has counted today that the phone has not paid for yet.
    var uncollectedSteps: Int {
        max(0, (liveSteps ?? 0) - collectedStepsToday)
    }

    // MARK: Actions

    func tap() {
        taps += 1
        queue.record()
        persistQueue()
        sendTask?.cancel()
        sendTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.sendDelay)
            } catch {
                return
            }
            self?.sendPendingTaps()
        }
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .active:
            link.requestRefresh()
            Task { await refreshLiveSteps() }
        case .inactive, .background:
            sendPendingTaps()
        @unknown default:
            break
        }
    }

    func enableLiveSteps() async {
        try? await stepCounter.requestAccess()
        liveStepsEnabled = true
        UserDefaults.standard.set(true, forKey: Key.liveSteps)
        await refreshLiveSteps()
    }

    func refreshLiveSteps() async {
        guard liveStepsEnabled, WatchStepCounter.isAvailable else { return }
        if let steps = try? await stepCounter.todaySteps() {
            liveSteps = steps
        }
    }

    // MARK: Sync

    private func sendPendingTaps() {
        sendTask?.cancel()
        sendTask = nil
        guard link.isActivated else { return } // Sent once the session activates.
        while let batch = queue.seal(at: .now) {
            link.send(batch)
        }
        persistQueue()
    }

    private func receive(_ new: WatchSnapshot) {
        // Ignore an older snapshot arriving late, unless the stored one claims to be from the future.
        if let current = snapshot, new.date < current.date, current.date <= .now { return }
        snapshot = new
        queue.acknowledge(new)
        persistQueue()
        Self.save(new, key: Key.snapshot)
    }

    // MARK: Persistence

    private func persistQueue() {
        Self.save(queue, key: Key.queue)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? GameCoding.decoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? GameCoding.encoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
