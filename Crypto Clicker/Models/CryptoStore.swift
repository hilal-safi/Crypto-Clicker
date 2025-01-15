//
//  CryptoStore.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import Foundation
import SwiftUI

@MainActor
class CryptoStore: ObservableObject {
    
    @Published var coins: CryptoCoin?
    @Published var powerUps = PowerUps.shared
    
    // Coin-Related Properties
    @Published var coinsPerSecond: Decimal = 0
    @Published var coinsPerClick: Decimal = 1
    @Published var coinsPerStep: Decimal = 1
    
    // Step-Related Properties
    @Published var totalSteps: Int = 0
    
    // Tracking coins earned from various avenues
    @Published var totalCoinsFromSteps: Decimal = 0
    @Published var totalCoinsFromMiniGames: Decimal = 0
    @Published var totalCoinsFromClicks: Decimal = 0
    @Published var totalCoinsFromIdle: Decimal = 0
    @Published var totalCoinsEverEarned: Decimal = 0
    
    // Other Statistics
    @Published var miniGameWinMultiplier: Decimal = 0
    @Published var totalCoinsSpent: Decimal = 0

    // Hold a reference to the user's settings so we can access .difficulty.productionMultiplier and costMultiplier
    @Published var settings: SettingsModel?
    
    private var timer: Timer?
    
    // Initializer
    init() {
        Task {
            await loadCoins()
            await loadPowerUps()
            await loadStepStats()
        }
        startTimer()
    }
    
    // Call this from the App or ContentView to inject SettingsModel
    func configureSettings(_ settings: SettingsModel) {
        self.settings = settings
    }
    
    // Timer to increment coins based on coinsPerSecond
    private func startTimer() {
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.incrementCoinsPerSec()
            }
        }
    }
    
    // Increcment the coin value automatically per second
    private func incrementCoinsPerSec() {
        
        if var currentCoin = coins {
            
            let newValue = currentCoin.value + coinsPerSecond
            currentCoin.value = min(newValue, Decimal.greatestFiniteMagnitude)
                .roundedDownToWhole()
            
            coins = currentCoin
            totalCoinsFromIdle += coinsPerSecond // Track coins from idle
            totalCoinsEverEarned += coinsPerSecond // Track total coins ever earned
            
            updateAndSaveCoins()
        }
    }
    
    // Increment coin value by clicking the coin
    func incrementCoinValue() {
        
        if var currentCoin = coins {
            
            let newValue = currentCoin.value + coinsPerClick
            currentCoin.value = min(newValue, Decimal.greatestFiniteMagnitude)
                .roundedDownToWhole()
            
            DispatchQueue.main.async {
                self.coins = currentCoin
                self.totalCoinsFromClicks += self.coinsPerClick
                self.totalCoinsEverEarned += self.coinsPerClick
                self.updateAndSaveCoins()
            }

            updateAndSaveCoins()
        }
    }
    
    // Increcment the coin value after playing mini games
    func addCoinsFromMiniGame(_ baseCoins: Decimal) {
        
        guard let currentCoin = coins else { return }

        // Only use the multiplier if it's greater than 0, otherwise default to no multiplier (1x)
        let multiplier = currentCoin.miniGameWinMultiplier > 0 ? 1 + (currentCoin.miniGameWinMultiplier / 100) : 1
        let adjustedReward = (baseCoins * multiplier).roundedDownToWhole() // Apply multiplier and round down

        // Ensure at least the baseCoins are rewarded even if the multiplier is 0
        let finalReward = adjustedReward > 0 ? adjustedReward : baseCoins.roundedDownToWhole()

        var updatedCoin = currentCoin
        updatedCoin.value += finalReward
        coins = updatedCoin // Update coins in store

        totalCoinsFromMiniGames += finalReward
        totalCoinsEverEarned += finalReward // Track total coins ever earned
        
        updateAndSaveCoins()
    }
    
    // Step-based methods: Called when new steps come in from watch or phone
    func incrementCoinsFromSteps(_ steps: Int) async {
        
        guard steps > 0 else { return } // Avoid processing zero or negative steps

        totalSteps += steps

        if var currentCoin = coins {
            // Calculate added coins based on the updated coinsPerStep
            let addedCoins = coinsPerStep * Decimal(steps)

            // Update the coin value and totalCoinsFromSteps
            currentCoin.value += addedCoins

            // Ensure the values are whole and valid
            currentCoin.value = min(currentCoin.value, Decimal.greatestFiniteMagnitude).roundedDownToWhole()
            coins = currentCoin

            totalCoinsFromSteps += addedCoins
            totalCoinsEverEarned += addedCoins
            
            // Push updated stats to the watch without delay
            PhoneSessionManager.shared.pushCoinValueToWatch()
        }

        // Save step stats asynchronously
        Task {
            await saveStepStats()
            updateAndSaveCoins()
        }
    }
    
    // Modify coin spending logic to increment `totalCoinsSpent`
    func spendCoins(amount: Decimal) {
        
        let roundedAmount = amount.roundedDownToWhole() // Ensure the amount is rounded
        totalCoinsSpent += roundedAmount // Track the amount of coins spent
        coins?.value -= roundedAmount // Deduct the coin value after purchase
    }

    // Reset coin value
    func resetCoinValue() {
        
        if var currentCoin = coins {
            currentCoin.value = 0 // Reset coin value without touching power-ups
            coins = currentCoin
        }
    }
    
    // Reset step-related counters
    func resetSteps() {
        
        totalSteps = 0
        totalCoinsFromSteps = 0
        
        // Persist the reset values
        Task {
            await saveStepStats()
        }
        
        // Notify the watch to reset its local steps
        PhoneSessionManager.shared.resetWatchLocalSteps()
    }
    
    // Reset all power-ups
    func resetPowerUps() {
        
        powerUps.resetAll() // Reinitialize to default values by removing all powerups
        
        recalculateCoinsPerSecond()
        recalculateCoinsPerClick()
        recalculateCoinsPerStep()
        recalculateMiniGameWinMultiplier()
        
        Task {
            await savePowerUps()
        }
    }
    
    // Reset all statistics stats
    func resetStats() {
        
        resetStatsToDefault()
        
        Task {
            await saveStats() // Ensure the reset stats are persisted
        }
    }
    
    // Purchase a power-up
    func purchasePowerUp(powerUp: PowerUps.PowerUp, quantity: Int) -> Bool {
        
        guard let currentCoins = coins else { return false }
        
        // Original base cost (exponential sum):
        let baseCost = powerUps.totalCost(for: powerUp, quantity: quantity)
        
        // Base total cost from "PowerUps" is exponential, and incorporates the difficulty costMultiplier.
        let costMultiplier = Decimal(settings?.difficulty.costMultiplier ?? 1.0)
        let finalCost = baseCost * costMultiplier
        
        guard currentCoins.value >= finalCost else { return false }
        
        spendCoins(amount: finalCost) // Call spendCoins
        powerUps.quantities[powerUp.name, default: 0] += quantity
        
        recalculateCoinsPerSecond()
        recalculateCoinsPerClick()
        recalculateCoinsPerStep()
        recalculateMiniGameWinMultiplier()
        
        // **Push phone -> watch** so the watch sees new coin total
        PhoneSessionManager.shared.pushCoinValueToWatch()
        
        Task {
            await saveCoins()
            await savePowerUps()
        }
        
        return true
    }
    
    /// Attempts to purchase and unlock a mini-game
    /// - Parameters:
    ///   - game: The mini-game to unlock
    ///   - miniGamesModel: The MiniGamesModel managing game states
    /// - Returns: Boolean indicating success of the transaction
    func purchaseMiniGame(game: MiniGamesModel.MiniGame, miniGamesModel: MiniGamesModel) -> Bool {
        
        guard let currentCoins = coins else { return false }
        
        // Retrieve the cost of unlocking the mini-game
        let baseCost = miniGamesModel.unlockCost(for: game)
        
        // Apply any cost multipliers from settings (if applicable)
        let costMultiplier = Decimal(settings?.difficulty.costMultiplier ?? 1.0)
        let finalCost = baseCost * costMultiplier
        
        // Check if the user has enough coins
        guard currentCoins.value >= finalCost else { return false }
        
        // Deduct the cost from the user's coins
        spendCoins(amount: finalCost) // Call spendCoins

        // Mark the mini-game as unlocked
        miniGamesModel.markAsUnlocked(game)
        
        // Save the updated coin state
        Task {
            await saveCoins()
        }
        
        return true
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // Recalculate coinsPerSecond based on power-ups
    func recalculateCoinsPerSecond() {
        
        // Sum the base production from all power-ups
        let baseProduction = powerUps.quantities.reduce(Decimal(0)) { total, entry in
            
            let (powerUpName, quantity) = entry
            
            if let powerUp = PowerUps.availablePowerUps.first(where: { $0.name == powerUpName }) {
                return total + Decimal(powerUp.coinsPerSecondIncrease * quantity)
            }
            return total
        }
        
        // Multiply by difficulty's production multiplier
        let productionMultiplier = Decimal(settings?.difficulty.productionMultiplier ?? 1.0)
        var newValue = baseProduction * productionMultiplier
        
        // Round according to difficulty
        if let diff = settings?.difficulty {
            newValue = diff.roundValue(newValue)
        }
        coinsPerSecond = newValue
    }
    
    // Recalculate coinsPerClick based on power-ups
    func recalculateCoinsPerClick() {
        
        // Start with base value 1
        var newValue: Decimal = 1
        
        // Add any bonuses from power-ups
        newValue += powerUps.quantities.reduce(Decimal(0)) { total, entry in
            
            let (powerUpName, quantity) = entry
            
            if let powerUp = PowerUps.availablePowerUps.first(where: { $0.name == powerUpName }) {
                return total + Decimal(powerUp.coinsPerClickIncrease * quantity)
            }
            return total
        }
        
        // Apply the production multiplier from settings
        let productionMultiplier = Decimal(settings?.difficulty.productionMultiplier ?? 1.0)
        newValue *= productionMultiplier
        
        // Round the value as per the difficulty settings
        if let diff = settings?.difficulty {
            newValue = diff.roundValue(newValue)
        }
        
        // Update coinsPerClick
        coinsPerClick = newValue
    }
    
    // Recalculate coins.coinsPerStep based on any step-related powerUps.
    func recalculateCoinsPerStep() {
        // Start with base value 1
        var newValue: Decimal = 1
        
        // Add bonuses from power-ups
        newValue += powerUps.quantities.reduce(Decimal(0)) { total, entry in
            
            let (powerUpName, quantity) = entry
            
            if let powerUp = PowerUps.availablePowerUps.first(where: { $0.name == powerUpName }) {
                return total + Decimal(powerUp.coinsPerStepIncrease * quantity)
            }
            return total
        }
        
        // Apply the production multiplier from settings
        let productionMultiplier = Decimal(settings?.difficulty.productionMultiplier ?? 1.0)
        newValue *= productionMultiplier
        
        // Round the value as per the difficulty settings
        if let diff = settings?.difficulty {
            newValue = diff.roundValue(newValue)
        }
        
        // Update coinsPerStep
        coinsPerStep = newValue
        
        // Also update the coins struct, if initialized
        if var currentCoin = coins {
            currentCoin.coinsPerStep = newValue
            coins = currentCoin
        }
    }
    
    func recalculateMiniGameWinMultiplier() {
        
        guard var currentCoin = coins else { return }
        
        // Sum the miniGameMultiplierIncrease from all power-ups
        let newMultiplier = powerUps.quantities.reduce(Decimal(0)) { total, entry in
            let (powerUpName, quantity) = entry
            if let powerUp = PowerUps.availablePowerUps.first(where: { $0.name == powerUpName }) {
                return total + (Decimal(powerUp.miniGameMultiplierIncrease) * Decimal(quantity))
            }
            return total
        }
        
        // Update the CryptoCoin property and Multiplier stat
        currentCoin.miniGameWinMultiplier = newMultiplier
        coins = currentCoin
        miniGameWinMultiplier = newMultiplier
    }
}

// MARK: - Persistence Extensions
extension CryptoStore {
    
    // Update and Save Coins
    private func updateAndSaveCoins() {
        Task {
            await saveCoins()
            await saveStats()
        }
    }

    private static func coinsFileURL() throws -> URL {
        
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
        .appendingPathComponent("coins.data")
    }
    
    private static func powerUpsFileURL() throws -> URL {
        
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
        .appendingPathComponent("powerUps.data")
    }
    
    private static func statsFileURL() throws -> URL {
        
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
        .appendingPathComponent("stats.data")
    }
    
    func saveCoins() async {
        
        guard let coins = coins else { return }
        
        do {
            let data = try JSONEncoder().encode(coins)
            let fileURL = try Self.coinsFileURL()
            try data.write(to: fileURL)
            
        } catch {
            print("Failed to save coins: \(error)")
        }
    }
    
    func loadCoins() async {
        
        do {
            let fileURL = try Self.coinsFileURL()
            
            guard let data = try? Data(contentsOf: fileURL) else {
                coins = CryptoCoin(value: Decimal(0))
                return
            }
            
            coins = try JSONDecoder().decode(CryptoCoin.self, from: data)
            
            // Ensure loaded coin is also whole
            if var c = coins {
                c.value = c.value.roundedDownToWhole()
                coins = c
            }
            
        } catch {
            print("Failed to load coins: \(error)")
        }
    }
    
    func savePowerUps() async {
        
        do {
            let data = try JSONEncoder().encode(powerUps)
            let fileURL = try Self.powerUpsFileURL()
            try data.write(to: fileURL)
            
        } catch {
            print("Failed to save power-ups: \(error)")
        }
    }
    
    func loadPowerUps() async {
        
        do {
            let fileURL = try Self.powerUpsFileURL()
            
            guard let data = try? Data(contentsOf: fileURL) else {
                PowerUps.shared.resetAll()
                recalculateCoinsPerSecond()
                recalculateCoinsPerClick()
                return
            }
            
            let loadedPowerUps = try JSONDecoder().decode(PowerUps.self, from: data)
            PowerUps.shared.quantities = loadedPowerUps.quantities
            
            recalculateCoinsPerSecond()
            recalculateCoinsPerClick()
            
        } catch {
            print("Failed to load power-ups: \(error)")
        }
    }
    
    // Persistence methods for saving and loading stats
    func saveStats() async {
        
        let stats = Stats(
            totalCoinsFromSteps: totalCoinsFromSteps,
            totalCoinsFromMiniGames: totalCoinsFromMiniGames,
            totalCoinsFromClicks: totalCoinsFromClicks,
            totalCoinsFromIdle: totalCoinsFromIdle,
            miniGameWinMultiplier: miniGameWinMultiplier,
            totalCoinsEverEarned: totalCoinsEverEarned,
            totalCoinsSpent: totalCoinsSpent,
            totalSteps: totalSteps
        )
        do {
            let data = try JSONEncoder().encode(stats)
            let fileURL = try Self.statsFileURL()
            try data.write(to: fileURL)
            
        } catch {
            print("[ERROR] Failed to save stats: \(error)")
        }
    }
    
    func loadStats() async {
        
        do {
            
            let fileURL = try Self.statsFileURL()
            
            guard let data = try? Data(contentsOf: fileURL) else {
                resetStatsToDefault() // Optional fallback
                return
            }
            
            let loadedStats = try JSONDecoder().decode(Stats.self, from: data)

            totalCoinsFromSteps = loadedStats.totalCoinsFromSteps
            totalCoinsFromMiniGames = loadedStats.totalCoinsFromMiniGames
            totalCoinsFromClicks = loadedStats.totalCoinsFromClicks
            totalCoinsFromIdle = loadedStats.totalCoinsFromIdle
            miniGameWinMultiplier = loadedStats.miniGameWinMultiplier
            totalCoinsEverEarned = loadedStats.totalCoinsEverEarned
            totalCoinsSpent = loadedStats.totalCoinsSpent
            totalSteps = loadedStats.totalSteps
            
        } catch {
            print("[ERROR] Failed to load stats: \(error)")
            resetStatsToDefault() // Optional fallback
        }
    }

    // Fallback to reset stats
    private func resetStatsToDefault() {
        totalCoinsFromSteps = 0
        totalCoinsFromMiniGames = 0
        totalCoinsFromClicks = 0
        totalCoinsFromIdle = 0
        miniGameWinMultiplier = 0
        totalCoinsEverEarned = 0
        totalCoinsSpent = 0
        totalSteps = 0
    }
    
    // Saves totalSteps and totalCoinsFromSteps so they’re preserved between launches
    func saveStepStats() async {
        // A simple approach: store them in UserDefaults as basic keys
        UserDefaults.standard.set(totalSteps, forKey: "totalSteps")
        // Convert Decimal -> String for safe storage
        UserDefaults.standard.set("\(totalCoinsFromSteps)", forKey: "totalCoinsFromSteps")
    }
    
    // Loads totalSteps and totalCoinsFromSteps from persistent storage
    func loadStepStats() async {
        
        let savedSteps = UserDefaults.standard.integer(forKey: "totalSteps")
        let savedCoinsStr = UserDefaults.standard.string(forKey: "totalCoinsFromSteps") ?? "0"
        
        totalSteps = savedSteps
        totalCoinsFromSteps = Decimal(string: savedCoinsStr) ?? 0
    }

    // Initialize Total Steps Without Incrementing Coins
    func initializeTotalSteps(_ steps: Int) async {
        
        totalSteps = max(totalSteps, steps) // Avoid resetting to a lower value
        await saveStepStats()
    }
}

// Stats model for persistence
struct Stats: Codable {
    let totalCoinsFromSteps: Decimal
    let totalCoinsFromMiniGames: Decimal
    let totalCoinsFromClicks: Decimal
    let totalCoinsFromIdle: Decimal
    let miniGameWinMultiplier: Decimal
    let totalCoinsEverEarned: Decimal
    let totalCoinsSpent: Decimal
    let totalSteps: Int
}
