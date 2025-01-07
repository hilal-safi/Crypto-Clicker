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
    @Published var totalCoinsFromSteps: Decimal = 0
    
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
        }
    }

    // Increment coin value by clicking the coin
    func incrementCoinValue() {
        
        if var currentCoin = coins {
            
            let newValue = currentCoin.value + coinsPerClick
            
            currentCoin.value = min(newValue, Decimal.greatestFiniteMagnitude)
                .roundedDownToWhole()
            coins = currentCoin
        }
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
    }

    // Reset all power-ups
    func resetPowerUps() {
        
        powerUps.resetAll() // Reinitialize to default values by removing all powerups
        recalculateCoinsPerSecond()
        recalculateCoinsPerClick()
        recalculateCoinsPerStep()

        Task {
            await savePowerUps()
        }
    }

    // Purchase a power-up
    func purchasePowerUp(powerUp: PowerUps.PowerUp, quantity: Int) -> Bool {
        
        guard let currentCoins = coins else { return false }

        // Base total cost from "PowerUps" is exponential, but we can also incorporate the difficulty costMultiplier here if desired.
        // For now, let's keep the "PowerUps" formula and add difficulty cost multiplier:
        
        // Original base cost (exponential sum):
        let baseCost = powerUps.totalCost(for: powerUp, quantity: quantity)
        
        let costMultiplier = Decimal(settings?.difficulty.costMultiplier ?? 1.0)
        let finalCost = baseCost * costMultiplier

        guard currentCoins.value >= finalCost else {
            return false
        }

        // Subtract cost, rounding down to ensure whole
        coins?.value = (currentCoins.value - finalCost)
            .roundedDownToWhole()

        powerUps.quantities[powerUp.name, default: 0] += quantity

        recalculateCoinsPerSecond()
        recalculateCoinsPerClick()
        recalculateCoinsPerStep()

        // **Push phone -> watch** so the watch sees new coin total
        PhoneSessionManager.shared.pushCoinValueToWatch()

        Task {
            await saveCoins()
            await savePowerUps()
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
        
        // Start at 1 by default
        let baseClick = powerUps.quantities.reduce(Decimal(1)) { total, entry in
            
            let (powerUpName, quantity) = entry
            
            if let powerUp = PowerUps.availablePowerUps.first(where: { $0.name == powerUpName }) {
                return total + Decimal(powerUp.coinsPerClickIncrease * quantity)
            }
            return total
        }

        // Multiply by difficulty's production multiplier
        let productionMultiplier = Decimal(settings?.difficulty.productionMultiplier ?? 1.0)
        var newValue = baseClick * productionMultiplier
        
        // Round according to difficulty
        if let diff = settings?.difficulty {
            newValue = diff.roundValue(newValue)
        }
        coinsPerClick = newValue
    }
    
    // Recalculate coins.coinsPerStep based on any step-related powerUps.
    func recalculateCoinsPerStep() {
        
        let baseStep = powerUps.quantities.reduce(Decimal(1)) { total, entry in
            
            let (powerUpName, quantity) = entry
            
            if let powerUp = PowerUps.availablePowerUps.first(where: { $0.name == powerUpName }) {
                // Add up the total step-boost from that powerUp * quantity
                let totalBoost = powerUp.coinsPerStepIncrease * quantity
                return total + Decimal(totalBoost)
            }
            return total
        }

        let prodMult = Decimal(settings?.difficulty.productionMultiplier ?? 1.0)
        var newValue = baseStep * prodMult
        
        if let diff = settings?.difficulty {
            newValue = diff.roundValue(newValue)
        }
        
        // Update both the store-level property and the coin struct
        coinsPerStep = newValue
        
        if var currentCoin = coins {
            currentCoin.coinsPerStep = newValue
            coins = currentCoin
        }
    }

    // Step-based methods: Called when new steps come in from watch or phone
    func incrementCoinsFromSteps(_ steps: Int) {
        
        totalSteps += steps
        
        if var currentCoin = coins {
            
            let added = currentCoin.coinsPerStep * Decimal(steps)
            
            let newValue = currentCoin.value + added
            currentCoin.value = min(newValue, Decimal.greatestFiniteMagnitude)
                .roundedDownToWhole()
            
            coins = currentCoin
            totalCoinsFromSteps += added
        }
        
        // After updating coin from steps, push new coin value to watch
        PhoneSessionManager.shared.pushCoinValueToWatch()
        
        // Persist step stats after each increment
        Task {
            await saveStepStats()
        }
    }
}

// MARK: - Persistence Extensions
extension CryptoStore {
    
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
    
    // Saves totalSteps and totalCoinsFromSteps so they’re preserved between launches
    func saveStepStats() async {
        // A simple approach: store them in UserDefaults as basic keys
        UserDefaults.standard.set(totalSteps, forKey: "totalSteps")
        // Convert Decimal -> String for safe storage
        UserDefaults.standard.set("\(totalCoinsFromSteps)", forKey: "totalCoinsFromSteps")
        print("[CryptoStore] Saved step stats: totalSteps = \(totalSteps), totalCoinsFromSteps = \(totalCoinsFromSteps)")
    }
    
    // Loads totalSteps and totalCoinsFromSteps from persistent storage
    func loadStepStats() async {
        let savedSteps = UserDefaults.standard.integer(forKey: "totalSteps")
        let savedCoinsStr = UserDefaults.standard.string(forKey: "totalCoinsFromSteps") ?? "0"
        
        totalSteps = savedSteps
        totalCoinsFromSteps = Decimal(string: savedCoinsStr) ?? 0
        print("[CryptoStore] Loaded step stats: totalSteps = \(totalSteps), totalCoinsFromSteps = \(totalCoinsFromSteps)")
    }

    // Initialize Total Steps Without Incrementing Coins
    func initializeTotalSteps(_ steps: Int) async {
        totalSteps = steps
        totalCoinsFromSteps = 0 // Reset or set as needed
        await saveStepStats()
        print("[CryptoStore] Initialized totalSteps to \(steps).")
    }
}
