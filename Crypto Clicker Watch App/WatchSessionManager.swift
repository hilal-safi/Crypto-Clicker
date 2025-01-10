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
    private let session = WCSession.default // The default WatchConnectivity session
    
    // Various values for stats page
    @Published var coinValue: Decimal = 0 // Local coin value on the watch
    @Published var coinsPerSecond: Decimal = 0
    @Published var coinsPerClick: Decimal = 0
    @Published var coinsPerStep: Decimal = 0
    @Published var totalPowerUpsOwned: Int = 0
    @Published var totalExchangedCoins: Int = 0
    @Published var totalSteps: Int = 0 // Total steps from phone
    @Published var totalCoinsFromSteps: Decimal = 0 // Total coins from steps from phone
    @Published var totalCoinsFromMiniGames: Decimal = 0
    @Published var totalCoinsFromClicks: Decimal = 0
    @Published var totalCoinsFromIdle: Decimal = 0
    @Published var totalCoinsEverEarned: Decimal = 0
    @Published var miniGameWinMultiplier: Decimal = 0
    @Published var totalCoinsSpent: Decimal = 0
    
    private var syncTimer: Timer?
    private var unsyncedUpdates: [[String: Any]] = []
    
    // Add a local steps tracker
    @Published var localSteps: Int = 0 {
        didSet {
            saveLocalSteps() // Save local steps whenever updated
        }
    }
    
    // Add a key for persisting steps
    private let localStepsKey = "localSteps"
    
    private override init() {
        super.init()
        loadLocalSteps() // Load saved steps on initialization
    }
    
    // MARK: - Session Related Methods
    
    /// Starts the WatchConnectivity session
    func startSession() {
        
        guard WCSession.isSupported() else {
            return
        }
        
        session.delegate = self
        session.activate()
        
        startSyncTimer() // Trigger periodic syncs
    }
    
    /// Handles messages received from the iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        updateStats(with: message)
    }
    
    /// Handles application context updates from the iPhone
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        updateStats(with: applicationContext)
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        if let error = error {
            print("[WatchSessionManager] Activation error: \(error.localizedDescription)")
            
        } else {
            print("[WatchSessionManager] Activation state: \(activationState.rawValue)")
        }
    }
    
    // MARK: - Step Counting Related Methods
    
    /// Initializes step count on the iPhone
    func initializeSteps(_ steps: Int) {
        
        guard session.isReachable else {
            print("[WatchSessionManager] Phone unreachable. Local initialization.")
            totalSteps = max(totalSteps, steps) // Avoid resetting to lower value
            return
        }
        
        let message: [String: Any] = ["request": "initializeSteps", "steps": steps]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[WatchSessionManager] initializeSteps error: \(error.localizedDescription)")
        })
    }
    
    func synchronizeSteps() {
        
        guard session.isReachable else { return }
        
        let data: [String: Any] = [
            "request": "initializeSteps",
            "steps": localSteps // Send local steps only
        ]
        
        session.sendMessage(data, replyHandler: { response in
            if let updatedSteps = response["updatedSteps"] as? Int {
                DispatchQueue.main.async {
                    self.localSteps = max(self.localSteps, updatedSteps) // Use the highest value
                    self.totalSteps = max(self.totalSteps, self.localSteps)
                    print("[WatchSessionManager] Steps synchronized. Local: \(self.localSteps), Total: \(self.totalSteps).")
                }
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] Failed to synchronize steps: \(error.localizedDescription)")
        })
    }
    
    /// Sends step data to the iPhone
    func addSteps(_ steps: Int) {
        
        guard session.isReachable else {
            
            // Update locally if the phone is unreachable
            DispatchQueue.main.async {
                
                self.localSteps += steps
                self.totalSteps = max(self.totalSteps, self.localSteps) // Merge local and total steps
                self.totalCoinsFromSteps += Decimal(steps) / 100
                
                print("[WatchSessionManager] Updated local steps: \(self.localSteps), total steps: \(self.totalSteps).")
            }
            return
        }
        
        // Send cumulative steps to the phone
        let data: [String: Any] = [
            "request": "addSteps",
            "steps": steps,
            "currentSteps": localSteps
        ]
        
        session.sendMessage(data, replyHandler: { response in
            
            if let updatedSteps = response["updatedSteps"] as? Int {
                
                DispatchQueue.main.async {
                    
                    self.localSteps += steps // Increment by the new steps
                    self.totalSteps = max(self.totalSteps, self.localSteps) // Merge local and total steps
                    
                    print("[WatchSessionManager] Synchronized steps. Local: \(self.localSteps), Total: \(self.totalSteps).")
                }
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] Failed to send steps: \(error.localizedDescription)")
        })
    }
    
    // Persistence
    private func saveLocalSteps() {
        UserDefaults.standard.set(localSteps, forKey: localStepsKey)
    }
    
    private func loadLocalSteps() {
        localSteps = UserDefaults.standard.integer(forKey: localStepsKey)
    }

    // MARK: - Other Methods
    
    /// Updates stats from a dictionary of values
    private func updateStats(with data: [String: Any]) {
        
        DispatchQueue.main.async {
            print("[WatchSessionManager] updateStats called with data: \(data)")
            
            if let coinValueStr = data["phoneCoinValue"] as? String,
               let value = Decimal(string: coinValueStr) {
                self.coinValue = value
            }
            
            if let coinsPerSecondStr = data["phoneCoinsPerSecond"] as? String,
               let value = Decimal(string: coinsPerSecondStr) {
                self.coinsPerSecond = value
            }
            
            if let coinsPerClickStr = data["phoneCoinsPerClick"] as? String,
               let value = Decimal(string: coinsPerClickStr) {
                self.coinsPerClick = value
            }
            
            if let coinsPerStepStr = data["phoneCoinsPerStep"] as? String,
               let value = Decimal(string: coinsPerStepStr) {
                self.coinsPerStep = value
            }
            
            if let totalPowerUpsOwnedStr = data["phoneTotalPowerUpsOwned"] as? String,
               let value = Int(totalPowerUpsOwnedStr) {
                self.totalPowerUpsOwned = value
            }
            
            if let totalExchangedCoinsStr = data["phoneTotalExchangedCoins"] as? String,
               let value = Int(totalExchangedCoinsStr) {
                self.totalExchangedCoins = value
            }
            
            if let totalStepsStr = data["phoneTotalSteps"] as? String,
               let value = Int(totalStepsStr) {
                self.totalSteps = value
            }
            
            if let totalCoinsFromStepsStr = data["phoneCoinsFromSteps"] as? String,
               let value = Decimal(string: totalCoinsFromStepsStr) {
                self.totalCoinsFromSteps = value
            }
            
            if let totalCoinsFromMiniGamesStr = data["phoneCoinsFromMiniGames"] as? String,
               let value = Decimal(string: totalCoinsFromMiniGamesStr) {
                self.totalCoinsFromMiniGames = value
            }
            
            if let totalCoinsFromClicksStr = data["phoneCoinsFromClicks"] as? String,
               let value = Decimal(string: totalCoinsFromClicksStr) {
                self.totalCoinsFromClicks = value
            }
            
            if let totalCoinsFromIdleStr = data["phoneCoinsFromIdle"] as? String,
               let value = Decimal(string: totalCoinsFromIdleStr) {
                self.totalCoinsFromIdle = value
            }
            
            if let totalCoinsEverEarnedStr = data["phoneTotalCoinsEverEarned"] as? String,
               let value = Decimal(string: totalCoinsEverEarnedStr) {
                self.totalCoinsEverEarned = value
            }
            
            if let miniGameWinMultiplierStr = data["phoneMiniGameWinMultiplier"] as? String,
               let value = Decimal(string: miniGameWinMultiplierStr) {
                self.miniGameWinMultiplier = value
            }
            
            if let totalCoinsSpentStr = data["phoneTotalCoinsSpent"] as? String,
               let value = Decimal(string: totalCoinsSpentStr) {
                self.totalCoinsSpent = value
            }
        }
    }
    
    /// Sends a tap action to the iPhone
    func tapCoin() {
        
        guard session.isReachable else {
            
            DispatchQueue.main.async {
                self.coinValue += self.coinsPerClick
            }
            return
        }
        
        let msg: [String: Any] = ["request": "tapCoin"]
        
        session.sendMessage(msg, replyHandler: { [weak self] reply in
            
            guard let self = self else { return }
            
            if let updatedValue = reply["updatedCoinValue"] as? String, let value = Decimal(string: updatedValue) {
                DispatchQueue.main.async {
                    self.coinValue = value
                }
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] tapCoin error: \(error.localizedDescription)")
        })
    }
    
    /// Requests essential data from the iPhone
    func requestCoinData() {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Cannot request coin data.")
            return
        }
        
        let msg = ["request": "requestCoinData"]
        
        session.sendMessage(msg, replyHandler: { response in
            self.updateStats(with: response) // Update stats with the response
            
        }, errorHandler: { error in
            print("[WatchSessionManager] requestCoinData error: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Periodic Sync Timer
    
    /// Starts a periodic sync timer
    private func startSyncTimer() {
        
        // Syncs every 3 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.requestCoinData()
        }
    }
    
    /// Sends data to the phone, queuing updates if unreachable
    func syncData(_ data: [String: Any]) {
        
        guard session.isReachable else {
            
            unsyncedUpdates.append(data)
            print("[WatchSessionManager] Data queued: \(data)")
            
            return
        }
        
        session.sendMessage(data, replyHandler: nil, errorHandler: { error in
            print("[WatchSessionManager] sendMessage error: \(error.localizedDescription)")
            self.unsyncedUpdates.append(data) // Requeue on failure
        })
    }
    
    /// Resends queued updates when the phone becomes reachable
    func flushUnsyncedUpdates() {
        
        guard session.isReachable else { return }
        
        unsyncedUpdates.forEach { data in
            session.sendMessage(data, replyHandler: nil, errorHandler: { error in
                print("[WatchSessionManager] Failed to resend data: \(error.localizedDescription)")
            })
        }
        
        unsyncedUpdates.removeAll()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - WCSessionDelegate Required Methods
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        flushUnsyncedUpdates()
        print("[WatchSessionManager] Reachability changed: \(session.isReachable)")
    }
}
