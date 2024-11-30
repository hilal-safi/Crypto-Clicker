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
    @Published var powerUps = PowerUps()
    
    @Published var coinsPerSecond: Int = 0
    @Published var coinsPerClick: Int = 1

    private var timer: Timer?

    // Initializer
    init() {
        Task {
            await loadCoins()
            await loadPowerUps()
        }
        startTimer()
    }

    // Timer to increment coins based on coinsPerSecond
    private func startTimer() {
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            
            Task { @MainActor in
                self.incrementCoinsPerSec()
            }
        }
    }

    private func incrementCoinsPerSec() {
        
        if var currentCoin = coins {
            
            currentCoin.value += coinsPerSecond
            coins = currentCoin
        }
    }

    // Increment coin value manually
    func incrementCoinValue() {
        
        if var currentCoin = coins {
            
            currentCoin.value += coinsPerClick
            coins = currentCoin
        }
    }

    // Reset coin value
    func resetCoinValue() {
        
        if var currentCoin = coins {
            
            currentCoin.value = 0
            coins = currentCoin
        }
    }
    
    // Reset all powerups
    func resetPowerUps() {
        print("resetPowerUps called") // Debugging statement

        // Reset all power-up counts and values
        powerUps = PowerUps() // Reinitialize to default values

        // Recalculate derived properties
        recalculateCoinsPerSecond()
        recalculateCoinsPerClick()

        // Save the reset state
        Task {
            await savePowerUps()
        }

        print("Power-ups have been reset to default values.") // Debugging statement
    }

    // Purchase a power-up
    func purchasePowerUp(powerUp: PowerUpInfo, quantity: Int) -> Bool {
        
        // Ensure enough coins are available
        guard let currentCoins = coins, currentCoins.value >= powerUp.cost * quantity else {
            print("Not enough coins to purchase \(powerUp.name). Required: \(powerUp.cost * quantity), Available: \(coins?.value ?? 0)")
            return false
        }

        // Deduct coins
        coins?.value -= powerUp.cost * quantity
        print("Coins deducted. New value: \(coins?.value ?? 0)")

        // Handle Coins Per Click Power-Up
        if powerUp.name == "Coin Clicker" {
            
            coinsPerClick += powerUp.coinsPerClickIncrease * quantity
            powerUps.coinClicker += quantity
            print("Coins Per Click updated. New value: \(coins?.coinsPerClick ?? 1)")
            
        } else {
            // Handle other power-ups
            switch powerUp.name {
            case "Chromebook":
                powerUps.chromebook += quantity
            case "Desktop":
                powerUps.desktop += quantity
            case "Server":
                powerUps.server += quantity
            case "Mine Center":
                powerUps.mineCenter += quantity
            default:
                print("Unknown power-up: \(powerUp.name)")
                return false
            }

            // Recalculate coins per second
            recalculateCoinsPerSecond()
            recalculateCoinsPerClick()
        }

        // Save updated state
        Task {
            await saveCoins()
            await savePowerUps()
        }

        return true
    }

    deinit {
        timer?.invalidate()
    }
}

extension CryptoStore {
    
    // File URLs
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

    // Save Coins
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

    // Load Coins
    func loadCoins() async {
        do {
            let fileURL = try Self.coinsFileURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                coins = CryptoCoin(value: 0)
                return
            }
            coins = try JSONDecoder().decode(CryptoCoin.self, from: data)
        } catch {
            print("Failed to load coins: \(error)")
        }
    }

    // Save Power-Ups
    func savePowerUps() async {
        do {
            let data = try JSONEncoder().encode(powerUps)
            let fileURL = try Self.powerUpsFileURL()
            try data.write(to: fileURL)
        } catch {
            print("Failed to save power-ups: \(error)")
        }
    }

    // Load Power-Ups
    func loadPowerUps() async {
        do {
            let fileURL = try Self.powerUpsFileURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                powerUps = PowerUps() // Initialize with default values
                recalculateCoinsPerSecond()
                return
            }
            powerUps = try JSONDecoder().decode(PowerUps.self, from: data)
            recalculateCoinsPerSecond() // Recalculate coinsPerSecond after loading power-ups
        } catch {
            print("Failed to load power-ups: \(error)")
        }
    }
    
    // Recalculate coinsPerSecond based on power-ups
    private func recalculateCoinsPerSecond() {
        coinsPerSecond = (powerUps.chromebook * 1) +
                         (powerUps.desktop * 5) +
                         (powerUps.server * 10) +
                         (powerUps.mineCenter * 100)
    }
    
    // Recalculate coinsPerClick based on power-ups
    private func recalculateCoinsPerClick() {
        coinsPerClick = powerUps.coinClicker + 1 // +1 ensures the base click value
    }

}
