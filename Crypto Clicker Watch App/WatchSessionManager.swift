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
    
    // Various values for stats page
    @Published var coinValue: Decimal = 0 // Local coin value on the watch
    @Published var coinsPerSecond: Decimal = 0
    @Published var coinsPerClick: Decimal = 0
    @Published var totalPowerUpsOwned: Int = 0
    @Published var totalExchangedCoins: Int = 0
    @Published var totalSteps: Int = 0 // Total steps from phone
    @Published var totalCoinsFromSteps: Decimal = 0 // Total coins from steps from phone
    
    private var syncTimer: Timer?

    /// Starts the WatchConnectivity session
    func startSession() {
        
        guard WCSession.isSupported() else {
            print("[WatchSessionManager] WatchConnectivity not supported on this device.")
            return
        }
        
        session.delegate = self
        session.activate()
        print("[WatchSessionManager] WatchConnectivity session activated.")
        
        startSyncTimer() // Trigger periodic syncs
    }

    /// Initializes step count on the iPhone
    func initializeSteps(_ steps: Int) {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Storing steps locally.")
            totalSteps += steps // Locally update steps if the phone isn't reachable
            return
        }
        
        let message: [String: Any] = ["request": "initializeSteps", "steps": steps]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[WatchSessionManager] Error initializing steps: \(error.localizedDescription)")
        })
    }

    /// Handles messages received from the iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        updateStats(with: message)
    }

    /// Handles application context updates from the iPhone
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        updateStats(with: applicationContext)
    }

    /// Updates stats from a dictionary of values
    private func updateStats(with data: [String: Any]) {
        
        DispatchQueue.main.async {
            
            if let coinValueStr = data["phoneCoinValue"] as? String, let value = Decimal(string: coinValueStr) {
                self.coinValue = value
            }
            if let coinsPerSecondStr = data["phoneCoinsPerSecond"] as? String, let value = Decimal(string: coinsPerSecondStr) {
                self.coinsPerSecond = value
            }
            if let coinsPerClickStr = data["phoneCoinsPerClick"] as? String, let value = Decimal(string: coinsPerClickStr) {
                self.coinsPerClick = value
            }
            if let totalPowerUpsOwnedStr = data["phoneTotalPowerUpsOwned"] as? String, let value = Int(totalPowerUpsOwnedStr) {
                self.totalPowerUpsOwned = value
            }
            if let totalExchangedCoinsStr = data["phoneTotalExchangedCoins"] as? String, let value = Int(totalExchangedCoinsStr) {
                self.totalExchangedCoins = value
            }
            if let totalStepsStr = data["phoneTotalSteps"] as? String, let value = Int(totalStepsStr) {
                self.totalSteps = value
            }
            if let totalCoinsFromStepsStr = data["phoneCoinsFromSteps"] as? String, let value = Decimal(string: totalCoinsFromStepsStr) {
                self.totalCoinsFromSteps = value
            }
        }
    }

    /// Sends a tap action to the iPhone
    func tapCoin() {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Incrementing coin locally.")
            coinValue += coinsPerClick // Locally increment coin value if the phone isn't reachable
            return
        }
        
        let msg: [String: Any] = ["request": "tapCoin"]
        
        session.sendMessage(msg, replyHandler: { [weak self] reply in
            
            if let updatedValue = reply["updatedCoinValue"] as? String, let value = Decimal(string: updatedValue) {
                
                DispatchQueue.main.async {
                    self?.coinValue = value
                }
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] tapCoin error: \(error.localizedDescription)")
        })
    }

    /// Sends step data to the iPhone
    func addSteps(_ steps: Int) {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Incrementing steps locally.")
            totalSteps += steps // Locally update steps if the phone isn't reachable
            totalCoinsFromSteps += Decimal(steps) / 100 // Increment coins from steps locally
            return
        }
        
        let msg: [String: Any] = ["request": "addSteps", "steps": steps]
        
        session.sendMessage(msg, replyHandler: { reply in
            
            if let updatedValue = reply["updatedCoinValue"] as? String, let value = Decimal(string: updatedValue) {
                
                DispatchQueue.main.async {
                    self.coinValue = value
                }
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] addSteps error: \(error.localizedDescription)")
        })
    }

    /// Requests all data from the iPhone
    func requestCoinData() {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Cannot request coin data.")
            return
        }
        
        let msg = ["request": "requestCoinData"]
        
        session.sendMessage(msg, replyHandler: nil, errorHandler: { error in
            print("[WatchSessionManager] requestCoinData error: \(error.localizedDescription)")
        })
    }

    // MARK: - Periodic Sync Timer

    /// Starts a periodic sync timer
    private func startSyncTimer() {
        
        // Syncs every 3 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.requestCoinData()
        }
    }

    deinit {
        syncTimer?.invalidate()
    }

    // MARK: - WCSessionDelegate Required Methods

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[WatchSessionManager] Reachability changed: \(session.isReachable)")
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("[WatchSessionManager] Activation error: \(error.localizedDescription)")
        } else {
            print("[WatchSessionManager] Activation state: \(activationState.rawValue)")
        }
    }
}
