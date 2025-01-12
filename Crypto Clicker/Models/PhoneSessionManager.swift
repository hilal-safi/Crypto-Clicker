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
    
    /// Optional timer that periodically pushes data to the watch
    private var syncTimer: Timer?
    
    // MARK: - Start Session
    /// Call this once from App initialization (e.g., in Crypto_ClickerApp).
    func startSession(with store: CryptoStore) {
        
        self.store = store
        session.delegate = self   // Assign 'self' as WCSessionDelegate
        session.activate()        // Activate the session
        
        print("[PhoneSessionManager] WatchConnectivity session activated.")
        
        // Optionally start a repeating timer that pushes stats to watch
        startSyncTimer()
    }

    /// Creates a Timer that every 5 seconds calls pushCoinValueToWatch().
    private func startSyncTimer() {
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // Use a Task to hop into the MainActor if needed for UI or store calls
            Task {
                self?.pushCoinValueToWatch()
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
            print("[PhoneSessionManager] Session is not reachable; skipping push.")
            return
        }
        
        guard let stats = collectStats() else {
            print("[PhoneSessionManager] Failed to collect stats for push.")
            return
        }
        
        do {
            try session.updateApplicationContext(stats)
            print("[PhoneSessionManager] Application context updated with stats.")
            
        } catch {
            print("[PhoneSessionManager] Failed to update context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - WCSessionDelegate Methods
    
    // Called when the session activation finishes. WCSessionDelegate requires @objc-compatible methods, so do NOT mark them @MainActor or nonisolated.
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        
        if let error = error {
            print("[PhoneSessionManager] Activation error: \(error.localizedDescription)")
        } else {
            print("[PhoneSessionManager] Activation state: \(activationState.rawValue)")
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
        print("[PhoneSessionManager] Reachability changed: \(session.isReachable)")
    }
    
    /// Called when the watch sends a message with sendMessage(_:replyHandler:errorHandler:). We parse the 'request' key and dispatch to relevant handlers.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        
        guard let request = message["request"] as? String else {
            print("[PhoneSessionManager] No 'request' key found in message.")
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
    
    // MARK: - Message Handlers (MainActor)
    @MainActor
    private func handleTapCoin(replyHandler: @escaping ([String: Any]) -> Void) {
        
        print("[PhoneSessionManager] handleTapCoin: awarding coin for watch tap.")
        
        guard let store = store else {
            replyHandler(["error": "No store available"])
            return
        }
        
        // 1) Increment coin on phone
        store.incrementCoinValue()
        
        // 2) Gather new phone coin value
        let updatedValue = store.coins?.value ?? 0
        print("[PhoneSessionManager] Updated coin value after tap: \(updatedValue)")
        
        // 3) Return it immediately to watch
        replyHandler(["updatedCoinValue": "\(updatedValue)"])
        
        // 4) Push full stats to watch as fallback
        pushCoinValueToWatch()
    }
    
    @MainActor
    private func handleAddSteps(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let store = store else {
            replyHandler(["error": "No store available"])
            return
        }

        let steps = message["steps"] as? Int ?? 0
        let watchCurrentSteps = message["currentSteps"] as? Int ?? 0

        let newTotal = max(store.totalSteps, watchCurrentSteps + steps)
        let diff = newTotal - store.totalSteps

        if diff > 0 {
            Task {
                await store.incrementCoinsFromSteps(diff)
                let updatedCoinValue = store.coins?.value ?? 0
                replyHandler([
                    "updatedSteps": newTotal,
                    "updatedCoinValue": "\(updatedCoinValue)"
                ])
            }
        } else {
            store.totalSteps = newTotal
            replyHandler(["updatedSteps": newTotal])
        }
    }
    
    @MainActor
    private func handleInitializeSteps(message: [String: Any],
                                       replyHandler: @escaping ([String: Any]) -> Void) {
        
        print("[PhoneSessionManager] handleInitializeSteps called.")
        
        guard let store = store else {
            replyHandler(["error": "No store available"])
            return
        }
        
        let steps = message["steps"] as? Int ?? 0
        
        // Just set phone’s total steps to the max of what watch says
        let updatedSteps = max(store.totalSteps, steps)
        store.totalSteps = updatedSteps
        
        // Save step stats, but no awarding here
        Task {
            await store.saveStepStats()
        }
        
        print("[PhoneSessionManager] handleInitializeSteps: set totalSteps to \(updatedSteps)")
        replyHandler(["updatedSteps": updatedSteps])
        
        // Then push updated stats to the watch
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
            print("[PhoneSessionManager] Watch is not reachable; cannot reset local steps now.")
            return
        }
        
        let data: [String: Any] = ["request": "resetLocalSteps"]
        
        session.sendMessage(data, replyHandler: nil, errorHandler: { error in
            print("[PhoneSessionManager] Failed to request watch reset local steps: \(error.localizedDescription)")
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
