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

    // Reset all power-ups
    func resetPowerUps() {
        powerUps = PowerUps() // Reinitialize to default values
        recalculateCoinsPerSecond()
        recalculateCoinsPerClick()

        Task {
            await savePowerUps()
        }
    }

    // Purchase a power-up
    func purchasePowerUp(powerUp: PowerUpInfo, quantity: Int) -> Bool {
        
        guard let currentCoins = coins, currentCoins.value >= powerUp.cost * quantity else {
            print("Not enough coins to purchase \(powerUp.name). Required: \(powerUp.cost * quantity), Available: \(coins?.value ?? 0)")
            return false
        }

        coins?.value -= powerUp.cost * quantity
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
    private func recalculateCoinsPerSecond() {
        
        coinsPerSecond = powerUps.quantities.reduce(0) { total, entry in
            
            let powerUpName = entry.key
            let quantity = entry.value
            
            if let powerUp = PowerUps.powerUps.first(where: { $0.name == powerUpName }) {
                return total + (powerUp.coinsPerSecondIncrease * quantity)
            }
            return total
        }
    }

    // Recalculate coinsPerClick based on power-ups
    private func recalculateCoinsPerClick() {
        
        coinsPerClick = powerUps.quantities.reduce(1) { total, entry in
            
            let powerUpName = entry.key
            let quantity = entry.value
            
            if let powerUp = PowerUps.powerUps.first(where: { $0.name == powerUpName }) {
                return total + (powerUp.coinsPerClickIncrease * quantity)
            }
            return total
        }
    }
}

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
                coins = CryptoCoin(value: 0)
                return
            }
            
            coins = try JSONDecoder().decode(CryptoCoin.self, from: data)
            
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
                powerUps = PowerUps() // Initialize with default values
                recalculateCoinsPerSecond()
                recalculateCoinsPerClick()
                return
            }
            
            powerUps = try JSONDecoder().decode(PowerUps.self, from: data)
            recalculateCoinsPerSecond() // Recalculate coinsPerSecond after loading power-ups
            recalculateCoinsPerClick()
            
        } catch {
            print("Failed to load power-ups: \(error)")
        }
    }
}
