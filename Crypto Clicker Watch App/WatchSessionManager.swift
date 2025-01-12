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

    // Lower thresholds for more frequent updates:
    private let stepSendThreshold = 1
    private let stepSendInterval: TimeInterval = 5
    
    // Local steps tracked by the watch
    private let localStepsKey = "localSteps"
    
    @Published var localSteps: Int = 0 {
        didSet {
            saveLocalSteps() // Persist
        }
    }
    
    // MARK: - Initializer
    private override init() {
        super.init()
        loadLocalSteps() // Load watch’s last-known local steps
    }

    // MARK: - Start Session
    func startSession() {
        
        guard WCSession.isSupported() else { return }
        
        session.delegate = self
        session.activate()
        
        // Periodically request coin data from phone. (30s is enough to reduce spam.)
        startSyncTimer()
    }

    // MARK: - Periodic Sync Timer
    private func startSyncTimer() {
        // Sync every 5 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // Force flush any pending steps
            self?.syncPendingSteps()
            // Also request coin data from phone
            self?.requestCoinData()
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }

    // MARK: - Step Counting
    /// Called by StepDetection class whenever new steps are found.
    func addSteps(_ steps: Int) {
        
        accumulatedSteps += steps
        let now = Date()
        
        // Sync immediately if threshold or interval is met
        if accumulatedSteps >= stepSendThreshold || now.timeIntervalSince(lastStepSendDate) > stepSendInterval {
            syncPendingSteps()
        } else {
            print("[WatchSessionManager] Buffering steps => buffer=\(accumulatedSteps)")
        }
    }

    // Separate sync logic for clarity and reuse
    func syncPendingSteps() {
        
        guard accumulatedSteps > 0 else { return }

        let toSend = accumulatedSteps
        accumulatedSteps = 0
        lastStepSendDate = Date()

        if session.isReachable {
            let data: [String: Any] = [
                "request": "addSteps",
                "steps": toSend,
                "currentSteps": localSteps
            ]

            session.sendMessage(data, replyHandler: { response in
                DispatchQueue.main.async {
                    if let updatedSteps = response["updatedSteps"] as? Int {
                        self.localSteps = max(self.localSteps, updatedSteps)
                        self.totalSteps = max(self.totalSteps, self.localSteps)
                    }
                    if let updatedCoinValueStr = response["updatedCoinValue"] as? String,
                       let updatedCoinValue = Decimal(string: updatedCoinValueStr) {
                        self.coinValue = updatedCoinValue
                    }
                }
            }, errorHandler: { error in
                self.localSteps += toSend
                print("[WatchSessionManager] Failed to sync steps: \(error.localizedDescription)")
            })
        } else {
            self.localSteps += toSend
            print("[WatchSessionManager] Session not reachable; steps stored locally.")
        }
    }
    
    // Call syncPendingSteps when walking stops
    func walkingStopped() {
        if accumulatedSteps > 0 {
            syncPendingSteps()
        }
    }
    
    // If you want the watch to "initialize" steps after some reset, you can do:
    func initializeSteps(_ steps: Int) {
        
        guard session.isReachable else {
            // Just set local watch steps, no awarding
            self.localSteps = max(self.localSteps, steps)
            self.totalSteps = max(self.totalSteps, self.localSteps)
            return
        }
        
        let message: [String: Any] = ["request": "initializeSteps", "steps": steps]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[WatchSessionManager] initializeSteps error: \(error.localizedDescription)")
        })
    }
    
    /// Sync local steps with phone if reachable
    func synchronizeSteps() {
        
        guard session.isReachable else { return }
        
        let data: [String: Any] = ["request": "initializeSteps", "steps": localSteps]
        
        session.sendMessage(data, replyHandler: { response in
            
            if let updatedSteps = response["updatedSteps"] as? Int {
                
                DispatchQueue.main.async {
                    self.localSteps = max(self.localSteps, updatedSteps)
                    self.totalSteps = max(self.totalSteps, self.localSteps)
                    print("[WatchSessionManager] Steps synchronized: local=\(self.localSteps), total=\(self.totalSteps).")
                }
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] Failed to synchronize steps: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Tap Coin
    /// The watch "taps coin," but the phone does the actual awarding.
    func tapCoin() {
        
        guard session.isReachable else {
            // If unreachable, just locally update coinValue (to avoid feeling unresponsive).
            DispatchQueue.main.async {
                self.coinValue += self.coinsPerClick
            }
            return
        }
        
        let msg: [String: Any] = ["request": "tapCoin"]
        
        session.sendMessage(msg, replyHandler: { [weak self] reply in
            
            guard let self = self else { return }
            
            if let updatedValue = reply["updatedCoinValue"] as? String,
               
               let value = Decimal(string: updatedValue) {
                
                DispatchQueue.main.async {
                    self.coinValue = value
                }
            }
        }, errorHandler: { error in
            print("[WatchSessionManager] tapCoin error: \(error.localizedDescription)")
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
            }
            
            if let cpsStr = data["phoneCoinsPerSecond"] as? String,
               let value = Decimal(string: cpsStr) {
                self.coinsPerSecond = value
            }
            
            if let cpcStr = data["phoneCoinsPerClick"] as? String,
               let value = Decimal(string: cpcStr) {
                self.coinsPerClick = value
            }
            
            if let cpsStepStr = data["phoneCoinsPerStep"] as? String,
               let value = Decimal(string: cpsStepStr) {
                self.coinsPerStep = value
            }
            
            if let tpuStr = data["phoneTotalPowerUpsOwned"] as? String,
               let tpuVal = Int(tpuStr) {
                self.totalPowerUpsOwned = tpuVal
            }
            
            if let totalExchangedCoinsStr = data["phoneTotalExchangedCoins"] as? String,
               let tecVal = Int(totalExchangedCoinsStr) {
                self.totalExchangedCoins = tecVal
            }
            
            if let totalStepsStr = data["phoneTotalSteps"] as? String,
               let tsVal = Int(totalStepsStr) {
                self.totalSteps = tsVal
            }
            
            if let coinsFromStepsStr = data["phoneCoinsFromSteps"] as? String,
               let cfsVal = Decimal(string: coinsFromStepsStr) {
                self.totalCoinsFromSteps = cfsVal
            }
            
            if let totalCoinsFromMiniGamesStr = data["phoneCoinsFromMiniGames"] as? String,
               let val = Decimal(string: totalCoinsFromMiniGamesStr) {
                self.totalCoinsFromMiniGames = val
            }
            
            if let totalCoinsFromClicksStr = data["phoneCoinsFromClicksStr"] as? String,
               let val = Decimal(string: totalCoinsFromClicksStr) {
                self.totalCoinsFromClicks = val
            }
            
            if let totalCoinsFromIdleStr = data["phoneCoinsFromIdle"] as? String,
               let val = Decimal(string: totalCoinsFromIdleStr) {
                self.totalCoinsFromIdle = val
            }
            
            if let totalCoinsEverEarnedStr = data["phoneTotalCoinsEverEarned"] as? String,
               let val = Decimal(string: totalCoinsEverEarnedStr) {
                self.totalCoinsEverEarned = val
            }
            
            if let miniGameMultiplierStr = data["phoneMiniGameWinMultiplier"] as? String,
               let val = Decimal(string: miniGameMultiplierStr) {
                self.miniGameWinMultiplier = val
            }
            
            if let totalCoinsSpentStr = data["phoneTotalCoinsSpent"] as? String,
               let val = Decimal(string: totalCoinsSpentStr) {
                self.totalCoinsSpent = val
            }
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
        
        unsyncedUpdates.removeAll()
        
        // Sync steps explicitly to avoid missed updates
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
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {

        // 1) Check for updatedCoinValue first
        if let updatedValueStr = message["updatedCoinValue"] as? String,
           
           let updatedValue = Decimal(string: updatedValueStr) {
            
            DispatchQueue.main.async {
                self.coinValue = updatedValue
                print("[WatchSessionManager] updatedCoinValue => \(updatedValue)")
            }
        }
        
        // 2) Then see if there's a 'request'
        guard let request = message["request"] as? String else {
            // If no request, we might have stats or partial data
            updateStats(with: message)
            return
        }
        
        switch request {
            
        case "resetLocalSteps":
            DispatchQueue.main.async {
                self.localSteps = 0
                self.totalSteps = 0
                print("[WatchSessionManager] localSteps reset to 0.")
            }
        default:
            // Possibly stats or other updates
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
}
