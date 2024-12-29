//
//  CoinExchangeModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

class CoinExchangeModel: ObservableObject {
    
    static let shared = CoinExchangeModel() // Singleton instance

    /// A simple struct to represent a coin and its properties.
    struct CoinTypeInfo {
        
        let type: CoinType
        let label: String
        let cost: Int
        var count: Int
        
        let imageName: String
        let backgroundColor: Color
        let secondaryColor: Color
        let textColor: Color
        let glowColor: Color
    }
    
    @Published var availableCoins: [CoinTypeInfo]
    
    // Keep track of exchanged coins in a dictionary (optional)
    @Published var exchangedCoins: [String: Int] = [:]
    private let exchangeKey = "coin_exchange_data"

    // Message property
    @Published var message: String? = nil

    init() {

        self.availableCoins = [
            CoinTypeInfo(
                type: .shibainu,
                label: "Shiba Inu",
                cost: 100,
                count: UserDefaults.standard.integer(forKey: "shibaInuCount"),
                imageName: "shibainu_image",
                backgroundColor: Color(red: 139/255, green: 0, blue: 0), // Red
                secondaryColor: Color(red: 255/255, green: 99/255, blue: 71/255), // Tomato
                textColor: .white,
                glowColor: .orange
            ),
            CoinTypeInfo(
                type: .dogecoin,
                label: "Dogecoin",
                cost: 250,
                count: UserDefaults.standard.integer(forKey: "dogecoinCount"),
                imageName: "dogecoin_image",
                backgroundColor: Color(red: 205/255, green: 127/255, blue: 50/255), // Bronze
                secondaryColor: Color(red: 244/255, green: 164/255, blue: 96/255), // SandyBrown
                textColor: .white,
                glowColor: .brown
            ),
            CoinTypeInfo(
                type: .xrp,
                label: "XRP",
                cost: 5000,
                count: UserDefaults.standard.integer(forKey: "xrpCount"),
                imageName: "xrp_image",
                backgroundColor: .black,
                secondaryColor: Color(red: 105/255, green: 105/255, blue: 105/255), // DimGray
                textColor: .white,
                glowColor: .white
            ),
            CoinTypeInfo(
                type: .cardano,
                label: "Cardano",
                cost: 10000,
                count: UserDefaults.standard.integer(forKey: "cardanoCount"),
                imageName: "cardano_image",
                backgroundColor: Color(red: 135/255, green: 206/255, blue: 250/255), // Blue
                secondaryColor: Color(red: 70/255, green: 130/255, blue: 180/255), // SteelBlue
                textColor: .black,
                glowColor: .cyan
            ),
            CoinTypeInfo(
                type: .solana,
                label: "Solana",
                cost: 400000,
                count: UserDefaults.standard.integer(forKey: "solanaCount"),
                imageName: "solana_image",
                backgroundColor: .purple,
                secondaryColor: (Color(red: 128/255, green: 0, blue: 128/255)), // Deep Violet
                textColor: .white,
                glowColor: Color(hue: 0.8, saturation: 0.7, brightness: 0.8)
            ),
            CoinTypeInfo(
                type: .ethereum,
                label: "Ethereum",
                cost: 1000000,
                count: UserDefaults.standard.integer(forKey: "ethereumCount"),
                imageName: "ethereum_image",
                backgroundColor: Color(red: 211/255, green: 211/255, blue: 211/255), // Silver
                secondaryColor:(Color(red: 105/255, green: 105/255, blue: 105/255)), // Dark Grey
                textColor: .black,
                glowColor: .gray
            ),
            CoinTypeInfo(
                type: .bitcoin,
                label: "Bitcoin",
                cost: 10000000,
                count: UserDefaults.standard.integer(forKey: "bitcoinCount"),
                imageName: "bitcoin_image",
                backgroundColor: Color(red: 255/255, green: 215/255, blue: 0/255), // Gold
                secondaryColor: (Color(red: 184/255, green: 134/255, blue: 11/255)), // Dark gold
                textColor: .black,
                glowColor: .yellow
            )
        ]
        
        // Add debug log for instance ID
        let instanceID = ObjectIdentifier(self).hashValue
        print("[DEBUG] CoinExchangeModel initialized with ID: \(instanceID)")

        loadExchangeData()
    }
    
    private func saveCoinsToUserDefaults() {
        for coinType in availableCoins {
            let key = "\(coinType.type.rawValue)_Count"
            UserDefaults.standard.set(coinType.count, forKey: key)
        }
        UserDefaults.standard.synchronize() // Ensure data is saved immediately
        print("[DEBUG] Coins saved to UserDefaults individually.")
    }
    
    private func loadExchangeData() {
        for (index, coinType) in availableCoins.enumerated() {
            let key = "\(coinType.type.rawValue)_Count"
            let count = UserDefaults.standard.integer(forKey: key)
            availableCoins[index].count = count
        }
        print("[DEBUG] Coins loaded from UserDefaults: \(availableCoins.map { "\($0.type.rawValue): \($0.count)" })")
    }
    
    // Perform the exchange based on the coin type
    func performExchange(for type: CoinType, quantity: Int, with coins: inout CryptoCoin?) {
        // Check if coin data is valid
        guard let coin = coins else {
            updateMessage("Invalid coin data.")
            return
        }

        // Locate the coin type in the availableCoins array
        if let index = availableCoins.firstIndex(where: { $0.type == type }) {
            let selectedCoin = availableCoins[index]
            let totalCost = selectedCoin.cost * quantity

            // Check if the user has enough coins
            if coin.value >= totalCost {
                
                coins?.value -= totalCost

                // Update the coin count
                availableCoins[index].count += quantity

                // Update the exchangedCoins dictionary
                exchangedCoins[type.rawValue, default: 0] += quantity

                // Save updates to UserDefaults
                saveCoinsToUserDefaults()

                updateMessage("Successfully exchanged \(quantity) \(selectedCoin.label)!")
            } else {
                updateMessage("Not enough coins for \(quantity) \(selectedCoin.label).")
            }
        } else {
            updateMessage("Coin type not found.")
        }
    }
    
    func updateMessage(_ newMessage: String) {
        message = newMessage
        print("[DEBUG] Message updated: \(newMessage)")
    }

    // Convenience getters
    func count(for type: CoinType) -> Int {
        availableCoins.first(where: { $0.type == type })?.count ?? 0
    }
    
    func totalExchangedCoins() -> Int {
        availableCoins.reduce(0) { $0 + $1.count }
    }
    
    func getExchangedCount(for coinType: CoinType) -> Int {
        return availableCoins.first(where: { $0.type == coinType })?.count ?? 0
    }

    func image(for type: CoinType) -> String {
        availableCoins.first(where: { $0.type == type })?.imageName ?? "placeholderImage"
    }
    
    func backgroundColor(for type: CoinType) -> Color {
        availableCoins.first(where: { $0.type == type })?.backgroundColor ?? .black
    }

    func textColor(for type: CoinType) -> Color {
        availableCoins.first(where: { $0.type == type })?.textColor ?? .white
    }

    func glowColor(for type: CoinType) -> Color {
        availableCoins.first(where: { $0.type == type })?.glowColor ?? .clear
    }
    
    var allCoinViews: [CoinTypeInfo] {
        return availableCoins
    }
    
    // MARK: - Update coin count dynamically and return the updated value
    func updateCoinCount(for type: CoinType, by amount: Int) {

        guard let index = availableCoins.firstIndex(where: { $0.type == type }) else {
            return
        }
        
        // Reassign the array instead of doing an in-place mutation
        var newList = availableCoins
        var coinInfo = newList[index]
        
        let newCount = max(0, coinInfo.count + amount)
        coinInfo.count = newCount
        newList[index] = coinInfo
        
        // Reassigning availableCoins publishes the change to SwiftUI
        availableCoins = newList
        
        // Persist the updated coin count
        saveCoinsToUserDefaults()
    }
    
    // For preview/demo usage
    func setExampleCount(for coin: CoinType, count: Int) {
        
        guard let index = availableCoins.firstIndex(where: { $0.type == coin }) else { return }
        
        var newList = availableCoins
        var coinInfo = newList[index]
        
        coinInfo.count = count
        newList[index] = coinInfo
        availableCoins = newList
    }
}

enum CoinType: String, CaseIterable {
    case shibainu, dogecoin, xrp, cardano, solana, ethereum, bitcoin
}
