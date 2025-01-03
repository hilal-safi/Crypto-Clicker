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

    @Published var coinsPerSecond: Decimal = 0
    @Published var coinsPerClick: Decimal = 1
    
    // Hold a reference to the user's settings so we can access .difficulty.productionMultiplier and costMultiplier
    @Published var settings: SettingsModel?

    private var timer: Timer?
    
    // Initializer
    init() {
        Task {
            await loadCoins()
            await loadPowerUps()
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

    // Reset all power-ups
    func resetPowerUps() {
        
        powerUps.resetAll() // Reinitialize to default values by removing all powerups
        recalculateCoinsPerSecond()
        recalculateCoinsPerClick()

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
}
