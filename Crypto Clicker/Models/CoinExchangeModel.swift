//
//  CoinExchangeModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

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
    
    // Popup properties
    @Published var popupMessage: String? = nil
    @Published var showMessage: Bool = false

    // Perform the exchange based on the coin type
    func performExchange(for type: CoinType, with coins: inout CryptoCoin?) {
        
        guard let coin = coins else {
            popupMessage = "Invalid coin data."
            showPopupWithAnimation()
            return
        }
        
        let totalCost: Int
        
        switch type {
            
        case .bronze:
            
            totalCost = bronzeCost
            
            if coin.value >= totalCost {
                
                coins?.value -= totalCost
                bronzeCoins += 1
                popupMessage = "Successfully exchanged for Bronze Coin!"
                
            } else {
                popupMessage = "Not enough coins for Bronze Coin."
            }
            
        case .silver:
            
            totalCost = silverCost
            
            if coin.value >= totalCost {
                
                coins?.value -= totalCost
                silverCoins += 1
                popupMessage = "Successfully exchanged for Silver Coin!"
                
            } else {
                popupMessage = "Not enough coins for Silver Coin."
            }
        case .gold:
            
            totalCost = goldCost
            
            if coin.value >= totalCost {
                
                coins?.value -= totalCost
                goldCoins += 1
                popupMessage = "Successfully exchanged for Gold Coin!"
                
            } else {
                popupMessage = "Not enough coins for Gold Coin."
            }
        }
        
        showPopupWithAnimation()
    }
    
    private func showPopupWithAnimation() {
        
        withAnimation {
            showMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showMessage = false
            }
        }
    }

    // Methods to get coin information
    func count(for type: CoinType) -> Int {
        switch type {
        case .bronze:
            return bronzeCoins
        case .silver:
            return silverCoins
        case .gold:
            return goldCoins
        }
    }

    func label(for type: CoinType) -> String {
        switch type {
        case .bronze:
            return "Bronze"
        case .silver:
            return "Silver"
        case .gold:
            return "Gold"
        }
    }

    func color(for type: CoinType) -> Color {
        switch type {
        case .bronze:
            return .brown
        case .silver:
            return .gray
        case .gold:
            return .yellow
        }
    }
    
    // Helper to get emoji for each coin type
    func emoji(for type: CoinType) -> String {
        switch type {
        case .bronze:
            return "🥉"
        case .silver:
            return "🥈"
        case .gold:
            return "🥇"
        }
    }
    
    func cost(for coinType: CoinType) -> Int {
        switch coinType {
            case .bronze: return bronzeCost
            case .silver: return silverCost
            case .gold: return goldCost
        }
    }

}

enum CoinType: CaseIterable {
    case bronze, silver, gold
}
