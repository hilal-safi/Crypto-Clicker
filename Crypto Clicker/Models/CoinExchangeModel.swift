//
//  CoinExchangeModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import Foundation

class CoinExchangeModel: ObservableObject {
    
    // Coin types as Ints with persistence
    @Published var bronzeCoins: Int {
        didSet {
            UserDefaults.standard.set(bronzeCoins, forKey: "bronzeCoins")
        }
    }
    
    @Published var silverCoins: Int {
        didSet {
            UserDefaults.standard.set(silverCoins, forKey: "silverCoins")
        }
    }
    
    @Published var goldCoins: Int {
        didSet {
            UserDefaults.standard.set(goldCoins, forKey: "goldCoins")
        }
    }

    // Exchange costs as Ints
    let bronzeCost: Int = 250
    let silverCost: Int = 10000
    let goldCost: Int = 1000000
    
    // Initializer to load saved values
    init() {
        self.bronzeCoins = UserDefaults.standard.integer(forKey: "bronzeCoins")
        self.silverCoins = UserDefaults.standard.integer(forKey: "silverCoins")
        self.goldCoins = UserDefaults.standard.integer(forKey: "goldCoins")
    }

    // Accessor methods
    func getBronzeCoins() -> Int {
        return bronzeCoins
    }

    func getSilverCoins() -> Int {
        return silverCoins
    }

    func getGoldCoins() -> Int {
        return goldCoins
    }

    // Mutator methods
    func setBronzeCoins(_ count: Int) {
        bronzeCoins = count
    }

    func setSilverCoins(_ count: Int) {
        silverCoins = count
    }

    func setGoldCoins(_ count: Int) {
        goldCoins = count
    }
    
    // Perform the exchange based on the coin type
    func performExchange(for type: CoinType, with coins: inout CryptoCoin?) {
        
        guard let coin = coins else { return }
        
        switch type {
            
        case .bronze:
            if coin.value >= bronzeCost {
                coins?.value -= bronzeCost
                bronzeCoins += 1
            }
        case .silver:
            if coin.value >= silverCost {
                coins?.value -= silverCost
                silverCoins += 1
            }
        case .gold:
            if coin.value >= goldCost {
                coins?.value -= goldCost
                goldCoins += 1
            }
        }
    }
}

enum CoinType {
    case bronze, silver, gold
}
