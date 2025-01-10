//
//  CoinExchangeModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

class CoinExchangeModel: ObservableObject {
    
    static let shared: CoinExchangeModel = {
        let instance = CoinExchangeModel()
        return instance
    }()
    
    private(set) var store: CryptoStore? // Make it private(set) to prevent external modification
    
    func configureStore(_ store: CryptoStore) {
        self.store = store
    }

    // A simple struct to represent a coin and its properties.
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
    
    // Reference to difficulty settings and cost rounding
    @Published var settings: SettingsModel? = nil
        
    // Keep track of exchanged coins in a dictionary (optional)
    @Published var availableCoins: [CoinTypeInfo]
    @Published var exchangedCoins: [String: Int] = [:]
    private let exchangeKey = "coin_exchange_data"

    // Message and background color for the exchange message
    @Published var message: String = "Welcome to the Coin Exchange"
    @Published var messageBackgroundColor: Color = Color.gray // Default background color is grey

    private init() {

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
        
        loadExchangeData()
    }
    
    private func saveCoinsToUserDefaults() {
        
        for coinType in availableCoins {
            let key = "\(coinType.type.rawValue)_Count"
            UserDefaults.standard.set(coinType.count, forKey: key)
        }
        UserDefaults.standard.synchronize() // Ensure data is saved immediately
    }
    
    private func loadExchangeData() {
        
        for (index, coinType) in availableCoins.enumerated() {
            let key = "\(coinType.type.rawValue)_Count"
            let count = UserDefaults.standard.integer(forKey: key)
            availableCoins[index].count = count
        }
    }
    
    /// Returns the final cost for `quantity` coins of the given `coinType` after difficulty multiplier + rounding.
    func calculateCost(for coinInfo: CoinTypeInfo, quantity: Int) -> Decimal {
        
        // 1) Multiply base cost by difficulty cost multiplier
        let baseCost = Decimal(coinInfo.cost)
        let costMultiplier = Decimal(settings?.difficulty.costMultiplier ?? 1.0)
        
        var perCoinCost = baseCost * costMultiplier
        
        // 2) Round per-coin cost
        if let diff = settings?.difficulty {
            perCoinCost = diff.roundValue(perCoinCost)
        }
        
        // 3) Multiply by quantity
        var totalCost = perCoinCost * Decimal(quantity)
        
        // 4) Optionally round final cost again
        if let diff = settings?.difficulty {
            totalCost = diff.roundValue(totalCost)
        }
        return totalCost
    }
    
    /// Actually subtract the cost from user's coins and increment the coin count.
    func performExchange(for type: CoinType, quantity: Int, with coins: inout CryptoCoin?) {
        
        guard let store = store else {
            updateMessage("Error: Store not configured.", backgroundColor: .red)
            return
        }

        guard let coins = coins else {
            updateMessage("Invalid coin data.", backgroundColor: .red)
            return
        }
        
        guard let index = availableCoins.firstIndex(where: { $0.type == type }) else {
            updateMessage("Coin type not found.", backgroundColor: .red)
            return
        }
        
        var coinInfo = availableCoins[index]
        
        let finalCost = calculateCost(for: coinInfo, quantity: quantity)
        
        // Check if user has enough coins
        guard coins.value >= finalCost else {
            updateMessage("Not enough coins for \(quantity) \(coinInfo.label).", backgroundColor: .red)
            return
        }
        
        Task { @MainActor in
            store.spendCoins(amount: finalCost) // Call spendCoins on the main actor
        }

        // Update count
        coinInfo.count += quantity
        availableCoins[index] = coinInfo
        saveCoinsToUserDefaults()
        
        updateMessage("Successfully purchased \(quantity) \(coinInfo.label).", backgroundColor: .green)
    }

    // Update message with background color and reset after a delay
    func updateMessage(_ text: String, backgroundColor: Color) {
        
        message = text
        messageBackgroundColor = backgroundColor

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.message = "Welcome to the Coin Exchange"
            self.messageBackgroundColor = Color.gray // Reset to grey
        }
    }

    // MARK: - Convenience getters
    func count(for type: CoinType) -> Int {
        availableCoins.first(where: { $0.type == type })?.count ?? 0
    }
    
    // Count of all the owned coins
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
    
    func resetExchangedCoins() {
        
        for index in availableCoins.indices {
            availableCoins[index].count = 0
        }
        exchangedCoins.removeAll()
        saveCoinsToUserDefaults() // Save changes
    }
    
    // Update coin count dynamically
    func updateCoinCount(for type: CoinType, by amount: Int) {

        guard let index = availableCoins.firstIndex(where: { $0.type == type }) else {
            return
        }
        
        var newList = availableCoins
        var coinInfo = newList[index]
        
        let newCount = max(0, coinInfo.count + amount)
        coinInfo.count = newCount
        newList[index] = coinInfo
        
        availableCoins = newList
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
