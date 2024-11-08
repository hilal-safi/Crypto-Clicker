//
//  CryptoStore.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI

@MainActor

class CryptoStore: ObservableObject {
    
    @Published var coins: CryptoCoin?
    
    // Track quantities of each item
    @Published var chromebook = 0
    @Published var desktop = 0
    @Published var server = 0
    @Published var mineCenter = 0

    
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
            // Set initial value if no data is found
            coins = CryptoCoin(value: 0) // Set your desired initial value here
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
    
    // Purchase item and start timed increment based on item type
    func purchaseItem(itemType: String) {
        if var currentCoin = coins {
            switch itemType {
            case "Chromebook":
                if currentCoin.value >= 50 {
                    chromebook += 1
                    currentCoin.value -= 50
                    startTimedIncrement(itemType: "Chromebook", interval: 10, amount: 1)
                }
            case "Desktop":
                if currentCoin.value >= 200 {
                    desktop += 1
                    currentCoin.value -= 200
                    startTimedIncrement(itemType: "Desktop", interval: 5, amount: 5)
                }
            case "Server":
                if currentCoin.value >= 1000 {
                    server += 1
                    currentCoin.value -= 1000
                    startTimedIncrement(itemType: "Server", interval: 3, amount: 10)
                }
            case "MineCenter":
                if currentCoin.value >= 10000 {
                    mineCenter += 1
                    currentCoin.value -= 10000
                    startTimedIncrement(itemType: "MineCenter", interval: 1, amount: 100)
                }
            default:
                break
            }
            coins = currentCoin
        }
    }
    
    private func startTimedIncrement(itemType: String, interval: TimeInterval, amount: Int) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in  // Ensure the code within this Task is run on the main actor
                if var currentCoin = self.coins {
                    // Increment based on the item purchased
                    switch itemType {
                    case "Chromebook":
                        currentCoin.value += amount * self.chromebook
                    case "Desktop":
                        currentCoin.value += amount * self.desktop
                    case "Server":
                        currentCoin.value += amount * self.server
                    case "MineCenter":
                        currentCoin.value += amount * self.mineCenter
                    default:
                        break
                    }
                    self.coins = currentCoin
                }
            }
        }
    }

}
