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
    
    // Various values for stats page (purely for display on the watch)
    @Published var coinValue: Decimal = 0
    @Published var coinsPerSecond: Decimal = 0
    @Published var coinsPerClick: Decimal = 0
    @Published var coinsPerStep: Decimal = 0
    @Published var totalPowerUpsOwned: Int = 0
    @Published var totalExchangedCoins: Int = 0
    @Published var totalSteps: Int = 0 // The phone’s known total steps (for display)
    @Published var totalCoinsFromSteps: Decimal = 0
    @Published var totalCoinsFromMiniGames: Decimal = 0
    @Published var totalCoinsFromClicks: Decimal = 0
    @Published var totalCoinsFromIdle: Decimal = 0
    @Published var totalCoinsEverEarned: Decimal = 0
    @Published var miniGameWinMultiplier: Decimal = 0
    @Published var totalCoinsSpent: Decimal = 0
    
    private var syncTimer: Timer?
    private var unsyncedUpdates: [[String: Any]] = []
    
    // For add steps method
    private var accumulatedSteps = 0
    private var lastStepSendDate = Date()
    
    // Thresholds for updates
    private let stepSendThreshold = 1 // 1 step
    private let stepSendInterval: TimeInterval = 5 // 5 seconds
    
    // Local steps tracked by the watch
    private let localStepsKey = "localSteps"
    
    @Published var localSteps: Int = 0 {
        didSet { saveLocalSteps() }
    }
    
    // MARK: - Initializer
    private override init() {
        super.init()
        loadLocalSteps() // Load watch’s last-known local steps
        loadCachedCoinValue()
    }
    
    // MARK: - Start Session
    func startSession() {
        
        guard WCSession.isSupported() else { return }
        
        session.delegate = self
        session.activate()
        
        // Periodically request coin data from phone. (30s is enough to reduce spam.)
        startSyncTimer()
    }
    
    // Periodic timer (every 60s) to sync steps & request stats
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.syncPendingSteps()       // flush step delta
            self?.requestCoinData()        // also poll phone for stats
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Step Counting
    /// Called by StepDetection whenever new steps appear.
    /// **Sends only the 'delta'** to the phone—no local awarding.
    func addSteps(_ steps: Int) {
        
        guard steps > 0 else { return }
        
        accumulatedSteps += steps
        let now = Date()
        
        if accumulatedSteps >= stepSendThreshold || now.timeIntervalSince(lastStepSendDate) > stepSendInterval {
            syncPendingSteps()
        } else {
            print("[WatchSessionManager] Buffering steps => \(accumulatedSteps)")
        }
    }
    
    /// Actually sends the buffered step delta to phone
    func syncPendingSteps() {
        
        guard accumulatedSteps > 0 else {
            print("[syncPendingSteps] No steps to sync. Exiting.")
            return
        }
        
        let toSend = accumulatedSteps
        accumulatedSteps = 0
        lastStepSendDate = Date()
        
        // Create the dictionary of steps to send
        let stepData: [String: Any] = [
            "request": "addSteps",
            "steps": toSend
        ]
        
        if session.isReachable {
            // If phone is reachable, we can just do sendMessage
            session.sendMessage(stepData, replyHandler: { response in
                
                DispatchQueue.main.async {
                    
                    if let updatedSteps = response["updatedSteps"] as? Int {
                        self.localSteps = max(self.localSteps, updatedSteps)
                        self.totalSteps = max(self.totalSteps, updatedSteps)
                    }
                    
                    if let updatedCoinValueStr = response["updatedCoinValue"] as? String,
                       let updatedCoinValue = Decimal(string: updatedCoinValueStr) {
                        self.coinValue = updatedCoinValue
                    }
                }
                
            }, errorHandler: { error in
                self.accumulatedSteps += toSend
                print("[WatchSessionManager] sendMessage error: \(error.localizedDescription)")
            })
            
        } else {
            // If phone is NOT reachable, do transferUserInfo so that it
            // will arrive in the background when iPhone wakes up
            session.transferUserInfo(stepData)
            print("[WatchSessionManager] transferUserInfo used. Steps=\(toSend)")
        }
    }
    
    // Call syncPendingSteps when walking stops
    func walkingStopped() {
        if accumulatedSteps > 0 {
            syncPendingSteps()
        }
    }
    
    func initializeSteps(_ steps: Int) {
        
        // Simplified: only phone’s total steps is the source of truth.
        guard session.isReachable else {
            
            self.localSteps = max(self.localSteps, steps)
            self.totalSteps = max(self.totalSteps, self.localSteps)
            return
        }
        
        let data: [String: Any] = ["request": "initializeSteps", "steps": steps]
        
        session.sendMessage(data, replyHandler: nil, errorHandler: { error in
            print("[WatchSessionManager] initializeSteps error: \(error.localizedDescription)")
        })
    }
    
    /// Sync local steps with phone if reachable
    func synchronizeSteps() {
        
        // Possibly: phone sets totalSteps to max(current, steps)
        guard session.isReachable else { return }
        
        let data: [String: Any] = ["request": "initializeSteps", "steps": localSteps]
        
        session.sendMessage(data, replyHandler: { resp in
            
            if let updatedSteps = resp["updatedSteps"] as? Int {
                
                DispatchQueue.main.async {
                    
                    self.localSteps = max(self.localSteps, updatedSteps)
                    self.totalSteps = max(self.totalSteps, updatedSteps)
                    print("[WatchSessionManager] Steps synchronized => local=\(self.localSteps)")
                }
            }
        }, errorHandler: { err in
            print("[WatchSessionManager] syncSteps error: \(err.localizedDescription)")
        })
    }
    
    // MARK: - Tap Coin
    /// The watch "taps coin," but the phone does the actual awarding.
    func tapCoin() {
        
        guard session.isReachable else {
            // If unreachable, do local coin increment for immediate feedback
            DispatchQueue.main.async {
                self.coinValue += self.coinsPerClick
            }
            return
        }
        
        let msg = ["request": "tapCoin"]
        
        session.sendMessage(msg, replyHandler: { reply in
            
            if let updatedValue = reply["updatedCoinValue"] as? String,
               
                let val = Decimal(string: updatedValue) {
                
                DispatchQueue.main.async {
                    self.coinValue = val
                }
            }
        }, errorHandler: { err in
            print("[WatchSessionManager] tapCoin error: \(err.localizedDescription)")
        })
    }
    
    // MARK: - Request Coin Data (polling or on demand)
    func requestCoinData() {
        
        guard session.isReachable else {
            print("[WatchSessionManager] iPhone not reachable. Skipping coin data request.")
            return
        }
        
        let msg = ["request": "requestCoinData"]
        
        session.sendMessage(msg, replyHandler: { response in
            self.updateStats(with: response)
            
        }, errorHandler: { error in
            print("[WatchSessionManager] requestCoinData error: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Update Stats from phone
    private func updateStats(with data: [String: Any]) {
        
        DispatchQueue.main.async {
            
            print("[WatchSessionManager] updateStats called with data: \(data)")
            
            if let coinValueStr = data["phoneCoinValue"] as? String,
               let value = Decimal(string: coinValueStr) {
                self.coinValue = value
                UserDefaults.standard.set("\(value)", forKey: "lastKnownCoinValue") // Cache coin value
            }

            if let phoneCoinsPerSecond = data["phoneCoinsPerSecond"] as? String,
               let value = Decimal(string: phoneCoinsPerSecond) {
                self.coinsPerSecond = value
            }
            
            if let phoneCoinsPerClick = data["phoneCoinsPerClick"] as? String,
               let value = Decimal(string: phoneCoinsPerClick) {
                self.coinsPerClick = value
            }
            
            if let phoneCoinsPerStep = data["phoneCoinsPerStep"] as? String,
               let value = Decimal(string: phoneCoinsPerStep) {
                self.coinsPerStep = value
            }
            
            if let phoneTotalPowerUpsOwned = data["phoneTotalPowerUpsOwned"] as? String,
               let value = Int(phoneTotalPowerUpsOwned) {
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
            
            if let coinsFromStepsStr = data["phoneCoinsFromSteps"] as? String,
               let value = Decimal(string: coinsFromStepsStr) {
                self.totalCoinsFromSteps = value
            }
            
            if let totalCoinsFromMiniGamesStr = data["phoneCoinsFromMiniGames"] as? String,
               let value = Decimal(string: totalCoinsFromMiniGamesStr) {
                self.totalCoinsFromMiniGames = value
            }
            
            if let totalCoinsFromClicksStr = data["phoneCoinsFromClicksStr"] as? String,
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
            
            if let miniGameMultiplierStr = data["phoneMiniGameWinMultiplier"] as? String,
               let value = Decimal(string: miniGameMultiplierStr) {
                self.miniGameWinMultiplier = value
            }
            
            if let totalCoinsSpentStr = data["phoneTotalCoinsSpent"] as? String,
               let value = Decimal(string: totalCoinsSpentStr) {
                self.totalCoinsSpent = value
            }
            
            // Cache the last updated data for quick retrieval
            UserDefaults.standard.set(data, forKey: "lastUpdatedStats")
            print("[WatchSessionManager] Stats updated and cached.")
        }
    }
    
    // MARK: - Send/Queue Data
    func syncData(_ data: [String: Any]) {
        
        guard session.isReachable else {
            
            unsyncedUpdates.append(data)
            print("[WatchSessionManager] Data queued: \(data)")
            return
        }
        session.sendMessage(data, replyHandler: nil, errorHandler: { error in
            print("[WatchSessionManager] sendMessage error: \(error.localizedDescription)")
            self.unsyncedUpdates.append(data)
        })
    }
    
    func flushUnsyncedUpdates() {
        
        guard session.isReachable else { return }
        
        unsyncedUpdates.forEach { data in
            session.sendMessage(data, replyHandler: nil, errorHandler: { error in
                print("[WatchSessionManager] Failed to resend data: \(error.localizedDescription)")
            })
        }
        
        // Sync steps explicitly to avoid missed updates
        unsyncedUpdates.removeAll()
        synchronizeSteps()
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        if let error = error {
            print("[WatchSessionManager] Activation error: \(error.localizedDescription)")
            
        } else {
            print("[WatchSessionManager] Activation state: \(activationState.rawValue)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        
        // Check if there's a request key
        guard let request = message["request"] as? String else {
            updateStats(with: message)
            return
        }
        
        switch request {
            
        case "resetLocalSteps":
            // Reset local and total steps
            DispatchQueue.main.async {
                
                self.localSteps = 0
                self.totalSteps = 0
                print("[WatchSessionManager] Reset localSteps and totalSteps to 0.")
                
                // Optionally save the reset state to persist
                self.saveLocalSteps()
            }
        default:
            // Process other updates or stats
            updateStats(with: message)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        updateStats(with: applicationContext)
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        flushUnsyncedUpdates()
        print("[WatchSessionManager] Reachability changed: \(session.isReachable)")
    }
    
    // MARK: - Local Persistence
    private func saveLocalSteps() {
        UserDefaults.standard.set(localSteps, forKey: localStepsKey)
    }
    
    private func loadLocalSteps() {
        localSteps = UserDefaults.standard.integer(forKey: localStepsKey)
    }
    
    private func loadCachedCoinValue() {
        // Retrieve the saved coin value string from UserDefaults
        let savedCoinString = UserDefaults.standard.string(forKey: "lastKnownCoinValue") ?? "0"
        
        // Attempt to parse the saved string into a Decimal value
        if let decimalValue = Decimal(string: savedCoinString) {
            // Update the `coinValue` property with the loaded value
            self.coinValue = decimalValue
            print("[WatchSessionManager] Loaded cached coinValue: \(decimalValue)")
        } else {
            // If parsing fails, log a warning and set coinValue to 0 as a fallback
            self.coinValue = 0
            print("[WatchSessionManager] Failed to parse cached coinValue, defaulting to 0.")
        }
    }
}
