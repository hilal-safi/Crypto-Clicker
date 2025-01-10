//
//  PhoneSessionManager.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-04.
//

import WatchConnectivity
import Foundation

@MainActor
class PhoneSessionManager: NSObject, ObservableObject {
    
    static let shared = PhoneSessionManager()
    private override init() {
        super.init()
    }
    
    private var store: CryptoStore?
    private let session = WCSession.default
    private var syncTimer: Timer?
    
    /// Starts the WatchConnectivity session
    func startSession(with store: CryptoStore) {
        self.store = store
        session.delegate = self
        session.activate()
        print("[PhoneSessionManager] WatchConnectivity session activated.")
        startSyncTimer()
    }
    
    /// Periodic sync timer for faster updates
    private func startSyncTimer() {
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            
            Task { @MainActor in
                self?.pushCoinValueToWatch()
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}

// MARK: - WCSessionDelegate Methods
extension PhoneSessionManager: WCSessionDelegate {
    
    // Nonisolated Methods to Conform to WCSessionDelegate
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        if let error = error {
            print("[PhoneSessionManager] Activation error: \(error)")
        } else {
            print("[PhoneSessionManager] Activation state: \(activationState.rawValue)")
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        print("[PhoneSessionManager] Reachability changed: \(session.isReachable)")
    }
    
    // Handle incoming messages
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        
        // Process the message content
        guard let request = message["request"] as? String else {
            print("[PhoneSessionManager] Received message without 'request' key.")
            replyHandler(["error": "No request key found"])
            return
        }

        // Handle the request
        switch request {
            
        case "tapCoin":
            Task { @MainActor in
                handleTapCoin(replyHandler: replyHandler)
            }

        case "addSteps":
            Task { @MainActor in
                handleAddSteps(message: message, replyHandler: replyHandler)
            }

        case "initializeSteps":
            Task { @MainActor in
                handleInitializeSteps(message: message, replyHandler: replyHandler)
            }

        case "requestCoinData":
            Task { @MainActor in
                sendAllStats(replyHandler: replyHandler)
            }

        case "test":
            Task { @MainActor in
                handleTestMessage(message: message, replyHandler: replyHandler)
            }

        default:
            print("[PhoneSessionManager] Received unknown request: \(request)")
            replyHandler(["error": "Unknown request: \(request)"])
        }
    }

    // MARK: - Message Handlers
    
    private func handleTapCoin(replyHandler: @escaping ([String: Any]) -> Void) {
        
        print("[PhoneSessionManager] handleTapCoin: Incrementing coin value.")
        
        if let newValue = store?.incrementCoinValue() {
            
            DispatchQueue.main.async {
                
                print("[PhoneSessionManager] handleTapCoin: Sending updated coin value: \(newValue)")
                
                replyHandler(["updatedCoinValue": "\(newValue)"])
                self.pushCoinValueToWatch()
            }
        } else {
            replyHandler(["error": "Failed to increment coin value"])
        }
    }
    
    private func handleAddSteps(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        
        let steps = message["steps"] as? Int ?? 0
        let currentSteps = message["currentSteps"] as? Int ?? 0

        // Merge watch and phone steps
        let updatedSteps = max(store?.totalSteps ?? 0, currentSteps + steps)

        print("[PhoneSessionManager] Received addSteps. Steps: \(steps), CurrentSteps: \(currentSteps), UpdatedSteps: \(updatedSteps)")

        Task {
            await store?.incrementCoinsFromSteps(updatedSteps - (store?.totalSteps ?? 0)) // Increment only the difference
            store?.totalSteps = updatedSteps // Update the total steps
            DispatchQueue.main.async {
                replyHandler(["updatedSteps": updatedSteps]) // Respond with updated steps
            }
        }
    }
    
    private func handleInitializeSteps(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        
        let steps = message["steps"] as? Int ?? 0

        // Merge Watch steps with Phone steps
        let updatedSteps = max(store?.totalSteps ?? 0, steps)

        Task {
            store?.totalSteps = updatedSteps
            await store?.saveStepStats()
            DispatchQueue.main.async {
                replyHandler(["updatedSteps": updatedSteps])
            }
        }
    }
    
    private func sendAllStats(replyHandler: @escaping ([String: Any]) -> Void) {
        
        guard let stats = collectStats() else {
            replyHandler(["error": "Failed to collect stats."])
            return
        }
        DispatchQueue.main.async {
            replyHandler(stats)
        }
    }
    
    private func handleTestMessage(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        
        if let testMessage = message["message"] as? String {
            
            print("[PhoneSessionManager] Received test message: \(testMessage)")
            replyHandler(["response": "Hello from Phone"])
            
        } else {
            replyHandler(["error": "No message content"])
        }
    }
    
    // MARK: - Helper Methods
    
    func pushCoinValueToWatch() {
        
        guard session.isReachable else {
            return
        }
        guard let stats = collectStats() else {
            print("[PhoneSessionManager] Failed to collect stats for push.")
            return
        }
        do {
            try session.updateApplicationContext(stats)
            print("[PhoneSessionManager] Application context updated.")
        } catch {
            print("[PhoneSessionManager] Failed to update context: \(error.localizedDescription)")
        }
    }
    
    private func collectStats() -> [String: Any]? {
        
        guard let store = store else { return nil }

        let stats: [String: Any] = [
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
        return stats
    }}
