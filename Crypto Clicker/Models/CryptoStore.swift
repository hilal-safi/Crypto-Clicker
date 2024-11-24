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
    @Published var powerUps = PowerUps() // Add this property to manage power-ups
    @Published var coinsPerSecond: Int = 0
    private var timer: Timer?

    init() {
        startTimer()
    }

    private static func fileURL() throws -> URL {
        
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
        
        .appendingPathComponent("coins.data")
    }
    
    func load() async throws {
                    
        let fileURL = try Self.fileURL()
        guard let data = try? Data(contentsOf: fileURL) else {
            
            coins = CryptoCoin(value: 0) // Initialize with default value
            return
        }
        let cryptoCoins = try JSONDecoder().decode(CryptoCoin.self, from: data)
        coins = cryptoCoins
    }
    
    func save(coins: CryptoCoin?) async throws {
        
        let task = Task {
            let data = try JSONEncoder().encode(coins)
            let outfile = try Self.fileURL()
            try data.write(to: outfile)
        }
        _ = try await task.value
    }
    
    // Timer to increment coins based on coinsPerSecond
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.incrementCoinsPerSecond()
            }
        }
    }

    private func incrementCoinsPerSecond() {
        guard var currentCoin = coins else { return }
        currentCoin.value += coinsPerSecond
        coins = currentCoin
    }

    // This method increments the coin's value
    func incrementCoinValue() {
        // Check if coins is not nil and increment the value
        if var currentCoin = coins {
            currentCoin.value += 1
            coins = currentCoin // Update the published property
        }
    }
    
    // This method resets the coin's value
    func resetCoinValue() {
        // Check if coins is not nil and reset the value
        if var currentCoin = coins {
            currentCoin.value = 0
            coins = currentCoin // Update the published property
        }
    }
    
    // Purchase a power-up
    func purchasePowerUp(powerUp: PowerUpInfo, quantity: Int) -> Bool {
        guard let currentCoins = coins, currentCoins.value >= powerUp.cost * quantity else {
            return false
        }

        // Deduct the coins for the purchase
        coins?.value -= powerUp.cost * quantity

        // Update the specific power-up quantity in PowerUps
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
            return false
        }

        // Recalculate coinsPerSecond
        recalculateCoinsPerSecond()

        return true
    }

    private func recalculateCoinsPerSecond() {
        coinsPerSecond = (powerUps.chromebook * 1) +
                         (powerUps.desktop * 5) +
                         (powerUps.server * 10) +
                         (powerUps.mineCenter * 20)
    }
    
    deinit {
        timer?.invalidate()
    }
}
