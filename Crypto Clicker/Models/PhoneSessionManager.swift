//
//  PhoneSessionManager.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-04.
//

import WatchConnectivity
import Foundation

/// PhoneSessionManager manages the WatchConnectivity session on the phone side.  It conforms to WCSessionDelegate, which is an @objc protocol.
class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    
    /// Shared singleton instance
    static let shared = PhoneSessionManager()
    
    /// Private initializer to enforce singleton usage
    private override init() {
        super.init()
    }
    
    /// A reference to our data store (CryptoStore), used for awarding coins, etc.
    private var store: CryptoStore?
    
    /// The active WatchConnectivity session on iPhone
    private let session = WCSession.default
    
    // Track the watch coinValue from the last sync so we can see how many new coins were added.
    @Published var lastSyncedWatchCoinValue: Decimal = 0
    @Published var lastSyncedWatchCoinsFromSteps: Decimal = 0
    
    /// Optional timer that periodically pushes data to the watch
    private var syncTimer: Timer?
    
    // MARK: - Start Session
    /// Call this once from App initialization (e.g., in Crypto_ClickerApp).
    func startSession(with store: CryptoStore) {
        
        self.store = store
        session.delegate = self   // Assign 'self' as WCSessionDelegate
        session.activate()        // Activate the session
        
        //print("[PhoneSessionManager] WatchConnectivity session activated.")
        
        // Optionally start a repeating timer that pushes stats to watch
        startSyncTimer()
    }

    /// Creates a Timer that every 5 seconds calls pushCoinValueToWatch().
    private func startSyncTimer() {
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // Use a Task to hop into the MainActor if needed for UI or store calls
            Task {
                await self?.pushCoinValueToWatch()
            }
        }
    }
    
    /// Invalidate the timer when this object goes away
    deinit {
        syncTimer?.invalidate()
    }
    
    // Collects stats and sends them to the watch via updateApplicationContext().
    @MainActor
    func pushCoinValueToWatch() {
        
        guard session.isReachable else {
            //print("[PhoneSessionManager] Session is not reachable; skipping push.")
            return
        }
        
        guard let stats = collectStats() else {
            print("[PhoneSessionManager] Failed to collect stats for push.")
            return
        }
        
        do {
            try session.updateApplicationContext(stats)
            //print("[PhoneSessionManager] Application context updated with stats.")
            
        } catch {
            //print("[PhoneSessionManager] Failed to update context: \(error.localizedDescription)")
        }
    }
    
    func requestWatchFetchStepsNow() {
        guard session.isReachable else {
            //print("[PhoneSessionManager] Watch not reachable; cannot fetch steps now.")
            return
        }
        let msg: [String: Any] = ["request": "fetchStepsNow"]
        session.sendMessage(msg, replyHandler: nil, errorHandler: { err in
            //print("[PhoneSessionManager] requestWatchFetchStepsNow error: \(err.localizedDescription)")
        })
    }
    
    // MARK: - WCSessionDelegate Methods
    
    // Called when the session activation finishes. WCSessionDelegate requires @objc-compatible methods, so do NOT mark them @MainActor or nonisolated.
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        
        if error != nil {
            //print("[PhoneSessionManager] Activation error: \(error.localizedDescription)")
        } else {
            //print("[PhoneSessionManager] Activation state: \(activationState.rawValue)")
        }
    }
    
    /// Called when the session moves from active to inactive.
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Not used in most simple apps, but must be present to satisfy the protocol.
    }
    
    /// Called when the session is deactivated (e.g., new iPhone or Apple Watch). You usually re-activate the session if needed.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    /// Called whenever reachability changes (e.g., watch is reachable/unreachable).
    func sessionReachabilityDidChange(_ session: WCSession) {
        //print("[PhoneSessionManager] Reachability changed: \(session.isReachable)")
    }
    
    /// Called when the watch sends a message with sendMessage(_:replyHandler:errorHandler:). We parse the 'request' key and dispatch to relevant handlers.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        
        guard let request = message["request"] as? String else {
            //print("[PhoneSessionManager] No 'request' key found in message.")
            replyHandler(["error": "No request key found"])
            return
        }
        
        switch request {
            
        case "tapCoin":
            // Hop into concurrency with Task+@MainActor to safely update the store
            Task { @MainActor in
                handleTapCoin(replyHandler: replyHandler)
            }
            
        case "addSteps":
            // Merge steps from watch into phone
            Task { @MainActor in
                handleAddSteps(message: message, replyHandler: replyHandler)
            }
            
        case "initializeSteps":
            // Set phone's totalSteps from watch, no awarding
            Task { @MainActor in
                handleInitializeSteps(message: message, replyHandler: replyHandler)
            }
            
        case "requestCoinData":
            // Watch wants stats to display
            Task { @MainActor in
                sendAllStats(replyHandler: replyHandler)
            }
            
        default:
            print("[PhoneSessionManager] Unknown request: \(request)")
            replyHandler(["error": "Unknown request: \(request)"])
        }
    }
    
    // handle user-info deliveries in the background
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let request = userInfo["request"] as? String else {
            //print("[PhoneSessionManager] (didReceiveUserInfo) => no request key.")
            return
        }
        switch request {
        case "addSteps":
            // There's no replyHandler for userInfo, so we just do background awarding
            Task { @MainActor in
                await handleAddStepsInBackground(userInfo)
            }
            
        default:
            print("[PhoneSessionManager] (didReceiveUserInfo) => unknown request \(request)")
        }
    }

    // MARK: - Message Handlers (MainActor)
    @MainActor
    private func handleAddSteps(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // We get `steps` as a delta, so no need to do total-lifetime subtractions
        guard let store = store else {
            replyHandler(["error": "No store available"])
            return
        }
        
        let steps = message["steps"] as? Int ?? 0
        //print("[PhoneSessionManager] handleAddSteps => steps=\(steps)")
        
        Task {
            await store.incrementCoinsFromSteps(steps)
        }
        
        let updatedValue = store.coins?.value ?? 0
        let updatedSteps = store.totalSteps
        
        replyHandler([
            "updatedSteps": updatedSteps,
            "updatedCoinValue": "\(updatedValue)"
        ])
        
        // Then push fresh stats
        Task {
            await store.saveStepStats()
        }
        pushCoinValueToWatch()
    }
    
    @MainActor
    private func handleAddStepsInBackground(_ userInfo: [String: Any]) async {
        
        guard let store = store else { return }
        let steps = userInfo["steps"] as? Int ?? 0
        
        if steps > 0 {
            // Award steps in the same way as handleAddSteps
            //print("[PhoneSessionManager] handleAddStepsInBackground => steps=\(steps)")

            // We do the usual awarding
            await store.incrementCoinsFromSteps(steps)

            // Optionally: no direct reply to userInfo. We can push updated stats to watch
            pushCoinValueToWatch()
        }
    }

    @MainActor
    private func handleInitializeSteps( message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        
        //print("[PhoneSessionManager] handleInitializeSteps called.")
        
        guard let store = store else {
            replyHandler(["error": "No store available"])
            return
        }
        
        let watchSteps = message["steps"] as? Int ?? 0
        let phoneSteps = store.totalSteps
        
        // If the watch is ahead of the phone’s total,
        // we award the difference so the phone’s stats match the watch.
        if watchSteps > phoneSteps {
            
            let difference = watchSteps - phoneSteps
            
            //print("[PhoneSessionManager] (initializeSteps) => phone steps behind watch: awarding difference=\(difference).")
            
            // Let the phone store do its normal coin awarding logic,
            // which respects power-ups & coinsPerStep.
            Task {
                await store.incrementCoinsFromSteps(difference)
            }
        } else {
            // If watch is <= phone’s total, do nothing (avoid double-counting).
            //print("[PhoneSessionManager] (initializeSteps) => watch steps (\(watchSteps)) <= phone (\(phoneSteps)). Doing nothing.")
        }
        
        // Now respond with the phone’s updated stats.
        let updatedValue = store.coins?.value ?? 0
        let updatedSteps = store.totalSteps
        
        replyHandler([
            "updatedSteps": updatedSteps,
            "updatedCoinValue": "\(updatedValue)"
        ])
        
        // Optionally save steps/coins
        Task {
            await store.saveStepStats()
        }
        
        // Push updated stats to the watch
        pushCoinValueToWatch()
    }
    
    @MainActor
    private func handleTapCoin(replyHandler: @escaping ([String: Any]) -> Void) {
        
        //print("[PhoneSessionManager] handleTapCoin: awarding coin for watch tap.")
        
        guard let store = store else {
            replyHandler(["error": "No store available"])
            return
        }
        
        // 1) Increment coin on phone
        store.incrementCoinValue()
        
        // 2) Gather new phone coin value
        let updatedValue = store.coins?.value ?? 0
        //print("[PhoneSessionManager] Updated coin value after tap: \(updatedValue)")
        
        // 3) Return it immediately to watch
        replyHandler(["updatedCoinValue": "\(updatedValue)"])
        
        // 4) Push full stats to watch as fallback
        pushCoinValueToWatch()
    }

    @MainActor
    private func sendAllStats(replyHandler: @escaping ([String: Any]) -> Void) {
        
        guard let stats = collectStats() else {
            replyHandler(["error": "Failed to collect stats"])
            return
        }
        replyHandler(stats)
    }
    
    @MainActor
    func resetWatchLocalSteps() {
        
        guard session.isReachable else {
            //print("[PhoneSessionManager] Watch is not reachable; cannot reset local steps now.")
            return
        }
        
        let data: [String: Any] = ["request": "resetLocalSteps"]
        
        session.sendMessage(data, replyHandler: nil, errorHandler: { error in
            //print("[PhoneSessionManager] Failed to request watch reset local steps: \(error.localizedDescription)")
        })
    }
    
    // Gathers current phone stats for the watch
    @MainActor
    private func collectStats() -> [String: Any]? {
        
        guard let store = store else { return nil }
        
        return [
            "phoneCoinValue": "\(store.coins?.value ?? 0)",
            "phoneCoinsPerSecond": "\(store.coinsPerSecond)",
            "phoneCoinsPerClick": "\(store.coinsPerClick)",
            "phoneCoinsPerStep": "\(store.coinsPerStep)",
            "phoneTotalSteps": "\(store.totalSteps)",
            "phoneCoinsFromSteps": "\(store.totalCoinsFromSteps)",
            "phoneTotalPowerUpsOwned": "\(store.powerUps.calculateTotalOwned())",
            "phoneTotalExchangedCoins": "\(CoinExchangeModel.shared.totalExchangedCoins())",
            "phoneTotalCoinsEverEarned": "\(store.totalCoinsEverEarned)",
            "phoneTotalCoinsSpent": "\(store.totalCoinsSpent)"
        ]
    }
}
