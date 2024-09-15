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
}
