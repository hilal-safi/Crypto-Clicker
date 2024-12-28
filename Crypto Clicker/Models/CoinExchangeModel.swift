//
//  CoinExchangeModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

class CoinExchangeModel: ObservableObject {
    
    /// A simple struct to represent a coin and its properties.
    struct CoinTypeInfo {
        let type: CoinType
        let label: String
        let cost: Int
        var count: Int
        
        let imageName: String
        let backgroundColor: Color
        let textColor: Color
        let glowColor: Color
    }
    
    @Published var availableCoins: [CoinTypeInfo]
    
    // Keep track of exchanged coins in a dictionary (optional)
    @Published var exchangedCoins: [String: Int] = [:]

    // Popup properties
    @Published var popupMessage: String? = nil
    @Published var showMessage: Bool = false
    
    init() {
        self.availableCoins = [
            CoinTypeInfo(
                type: .shibainu,
                label: "Shiba Inu",
                cost: 100,
                count: UserDefaults.standard.integer(forKey: "shibaInuCount"),
                imageName: "shibainu_image",
                backgroundColor: Color(red: 139/255, green: 0, blue: 0), // Red
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
                textColor: .black,
                glowColor: .yellow
            )
        ]
    }
    
    private func saveCoinsToUserDefaults() {
        // Save each coin's count to UserDefaults
        for coinType in availableCoins {
            UserDefaults.standard.set(coinType.count, forKey: "\(coinType.type.rawValue)Count")
        }
    }

    // Perform an exchange for the given coin type
    func performExchange(for type: CoinType, with coins: inout CryptoCoin?) {
        
        guard let coin = coins else {
            popupMessage = "Invalid coin data."
            showPopupWithAnimation()
            return
        }
        
        if let index = availableCoins.firstIndex(where: { $0.type == type }) {
            
            let selectedCoin = availableCoins[index]
            
            if coin.value >= selectedCoin.cost {
                coins?.value -= selectedCoin.cost
                
                // **Important**: Reassign the entire array
                var newList = availableCoins
                var coinInfo = newList[index]
                coinInfo.count += 1
                newList[index] = coinInfo
                availableCoins = newList
                
                popupMessage = "Successfully exchanged for \(selectedCoin.label)!"
                
            } else {
                popupMessage = "Not enough coins for \(selectedCoin.label)."
            }
            
            showPopupWithAnimation()
        }
    }

    // Animate a popup for 3 seconds
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

    // Convenience getters
    func count(for type: CoinType) -> Int {
        availableCoins.first(where: { $0.type == type })?.count ?? 0
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
