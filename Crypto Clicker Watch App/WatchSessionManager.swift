//
//  WatchSessionManager.swift
//  Crypto Clicker Watch App
//
//  Created by Hilal Safi on 2025-01-04.
//

import WatchConnectivity
import SwiftUI

/// Manages communication between the Apple Watch and the iPhone
class WatchSessionManager: NSObject, WCSessionDelegate, ObservableObject {
    
    static let shared = WatchSessionManager() // Singleton instance
    private override init() { super.init() }

    private let session = WCSession.default // The default WatchConnectivity session
    @Published var coinValue: Decimal = 0 // Local coin value on the watch
    @Published var coinsPerSecond: Decimal = 0
    @Published var coinsPerClick: Decimal = 0
    @Published var totalPowerUpsOwned: Int = 0
    @Published var totalExchangedCoins: Int = 0
    @Published var totalSteps: Int = 0 // Total steps from phone
    @Published var totalCoinsFromSteps: Decimal = 0 // Total coins from steps from phone

    /// Starts the WatchConnectivity session
    func startSession() {
        
        guard WCSession.isSupported() else {
            print("[WatchSessionManager] WatchConnectivity not supported on this device.")
            return
        }
        
        session.delegate = self
        session.activate()
        print("[WatchSessionManager] WatchConnectivity session activated.")
    }

    /// Called when the session activation completes
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        if let error = error {
            print("[WatchSessionManager] Activation error: \(error)")
            
        } else {
            print("[WatchSessionManager] Activation state: \(activationState.rawValue)")
        }
    }

    /// Handles messages received from the iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        
        // Update the coin value if it's sent from the phone
        if let valStr = message["phoneCoinValue"] as? String,
           
           let val = Decimal(string: valStr) {
            
            DispatchQueue.main.async {
                self.coinValue = val
                print("[WatchSessionManager] Updated coin value: \(val)")
            }
        }
        
        // Update totalSteps
        if let stepsStr = message["phoneTotalSteps"] as? String,
           
           let steps = Int(stepsStr) {
            
            DispatchQueue.main.async {
                self.totalSteps = steps
                print("[WatchSessionManager] Updated total steps: \(steps)")
            }
        }
        
        // Update totalCoinsFromSteps
        if let coinsFromStepsStr = message["phoneCoinsFromSteps"] as? String,
           
           let coinsFromSteps = Decimal(string: coinsFromStepsStr) {
            
            DispatchQueue.main.async {
                self.totalCoinsFromSteps = coinsFromSteps
                print("[WatchSessionManager] Updated coins from steps: \(coinsFromSteps)")
            }
        }
    }

    /// Sends a tap action to the iPhone
    func tapCoin() {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Cannot send tapCoin.")
            return
        }
        let msg: [String: Any] = ["request": "tapCoin"] // Message to send
        
        session.sendMessage(msg, replyHandler: { reply in
            
            if let updatedStr = reply["updatedCoinValue"] as? String,
               
               let updated = Decimal(string: updatedStr) {
                
                DispatchQueue.main.async {
                    self.coinValue = updated
                }
                
            } else if let error = reply["error"] as? String {
                print("[WatchSessionManager] tapCoin error from phone: \(error)")
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] tapCoin error: \(error.localizedDescription)")
        })
    }

    /// Sends step data to the iPhone
    func addSteps(_ steps: Int) {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Cannot send steps.")
            return
        }
        let msg: [String: Any] = ["request": "addSteps", "steps": steps] // Message to send
        
        session.sendMessage(msg, replyHandler: { reply in
            
            if let updatedCoinValue = reply["updatedCoinValue"] as? String,
               
               let updatedValue = Decimal(string: updatedCoinValue) {
                
                DispatchQueue.main.async {
                    self.coinValue = updatedValue
                }
                
            } else if let error = reply["error"] as? String {
                print("[WatchSessionManager] addSteps error from phone: \(error)")
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] addSteps error: \(error.localizedDescription)")
        })
    }

    /// Requests the latest coin data from the iPhone
    func requestCoinData() {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Cannot request coin data.")
            return
        }
        let msg = ["request": "requestCoinData"] // Message to request coin data
        session.sendMessage(msg, replyHandler: { reply in
            if let valStr = reply["phoneCoinValue"] as? String,
               let val = Decimal(string: valStr) {
                DispatchQueue.main.async {
                    self.coinValue = val
                    print("[WatchSessionManager] Received phoneCoinValue: \(val)")
                }
            }
            if let stepsStr = reply["phoneTotalSteps"] as? String,
               let steps = Int(stepsStr) {
                DispatchQueue.main.async {
                    self.totalSteps = steps
                    print("[WatchSessionManager] Received phoneTotalSteps: \(steps)")
                }
            }
            if let coinsFromStepsStr = reply["phoneCoinsFromSteps"] as? String,
               let coinsFromSteps = Decimal(string: coinsFromStepsStr) {
                DispatchQueue.main.async {
                    self.totalCoinsFromSteps = coinsFromSteps
                    print("[WatchSessionManager] Received phoneCoinsFromSteps: \(coinsFromSteps)")
                }
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] requestCoinData error: \(error.localizedDescription)")
        })
    }
    
    /// Initializes the total steps on the phone without incrementing coins
    func initializeSteps(_ steps: Int) {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Cannot send initializeSteps.")
            return
        }
        let msg: [String: Any] = ["request": "initializeSteps", "steps": steps]
        session.sendMessage(msg, replyHandler: { reply in
            if let status = reply["status"] as? String {
                print("[WatchSessionManager] initializeSteps status: \(status)")
            } else if let error = reply["error"] as? String {
                print("[WatchSessionManager] initializeSteps error from phone: \(error)")
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] initializeSteps error: \(error.localizedDescription)")
        })
    }

    // MARK: - WCSessionDelegate Required Methods

    /// Called when the session's reachability changes
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[WatchSessionManager] Reachability changed: \(session.isReachable)")
    }
}
