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
    
    func startSession(with store: CryptoStore) {
        self.store = store
        session.delegate = self
        session.activate()
        print("[PhoneSessionManager] WatchConnectivity session activated.")
    }
}

extension PhoneSessionManager: WCSessionDelegate {
    
    // MARK: - WCSessionDelegate Methods
    
    // MARK: Nonisolated Methods to Conform to WCSessionDelegate
    
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
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        
        guard let request = message["request"] as? String else {
            print("[PhoneSessionManager] Received message without 'request' key.")
            replyHandler(["error": "No request key found"])
            return
        }
        
        switch request {
            
        case "tapCoin":
            print("[PhoneSessionManager] Received 'tapCoin' request.")
            // Handle tapCoin request
            if let newValue = store?.incrementCoinValue() {
                print("[PhoneSessionManager] tapCoin handled. New coin value: \(newValue)")
                replyHandler(["updatedCoinValue": "\(newValue)"])
                pushCoinValueToWatch()
            } else {
                print("[PhoneSessionManager] Failed to increment coin value.")
                replyHandler(["error": "Failed to increment coin value"])
            }
            
        case "addSteps":
            // The watch detected steps
            let steps = message["steps"] as? Int ?? 0
            print("[PhoneSessionManager] Received 'addSteps' request with steps: \(steps)")
            
            // Update coin value based on steps
            store?.incrementCoinsFromSteps(steps)
            
            // Push updated value to the watch
            pushCoinValueToWatch()
            
            // Respond with the updated coin value
            let newValue = store?.coins?.value ?? 0
            print("[PhoneSessionManager] addSteps handled. New coin value: \(newValue)")
            replyHandler(["updatedCoinValue": "\(newValue)"])
            
        case "initializeSteps":
            // Initialize totalSteps without incrementing coins
            let steps = message["steps"] as? Int ?? 0
            print("[PhoneSessionManager] Received 'initializeSteps' request with steps: \(steps)")
            Task {
                await store?.initializeTotalSteps(steps)
                print("[PhoneSessionManager] Initialized totalSteps to \(steps).")
            }
            replyHandler(["status": "initialized"])
            
        case "requestCoinData":
            // The watch requests the current coin value and stats
            let coinValue = store?.coins?.value ?? 0
            let steps = store?.totalSteps ?? 0
            let coinsFromSteps = store?.totalCoinsFromSteps ?? 0
            print("[PhoneSessionManager] Received 'requestCoinData' request. Sending data.")
            replyHandler([
                "phoneCoinValue": "\(coinValue)",
                "phoneTotalSteps": "\(steps)",
                "phoneCoinsFromSteps": "\(coinsFromSteps)"
            ])
            
        case "test":
            // Handle test message
            if let testMessage = message["message"] as? String {
                print("[PhoneSessionManager] Received test message: \(testMessage)")
                replyHandler(["response": "Hello from Phone"])
            } else {
                print("[PhoneSessionManager] Received test message without 'message' key.")
                replyHandler(["error": "No message content"])
            }
            
        default:
            print("[PhoneSessionManager] Received unknown request: \(request)")
            replyHandler(["error": "Unknown request: \(request)"])
        }
    }
    
    // MARK: - Helper Methods
    
    /// Pushes the updated coin value, total steps, and coins from steps to the watch
    func pushCoinValueToWatch() {
        
        guard session.isReachable else {
            print("[PhoneSessionManager] iPhone is not reachable. Cannot push coin data.")
            return
        }
        
        guard let store = store, let coins = store.coins else {
            print("[PhoneSessionManager] Missing store or coin data.")
            return
        }
        
        let context: [String: Any] = [
            "phoneCoinValue": "\(coins.value)",
            "phoneTotalSteps": "\(store.totalSteps)",
            "phoneCoinsFromSteps": "\(store.totalCoinsFromSteps)"
        ]
        
        do {
            try session.updateApplicationContext(context)
            print("[PhoneSessionManager] Application context updated.")
        } catch {
            print("[PhoneSessionManager] Failed to update context: \(error.localizedDescription)")
        }
    }
}
