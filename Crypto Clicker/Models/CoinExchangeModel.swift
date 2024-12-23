//
//  CoinExchangeModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

class CoinExchangeModel: ObservableObject {
    
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
    
    @Published var coinTypes: [CoinTypeInfo] {
        didSet {
            saveCoinsToUserDefaults()
        }
    }
    
    @Published var exchangedCoins: [String: Int] = [:]
    
    // Popup properties
    @Published var popupMessage: String? = nil
    @Published var showMessage: Bool = false
    
    init() {
        self.coinTypes = [
            CoinTypeInfo(
                type: .shibainu,
                label: "Shiba Inu",
                cost: 100,
                count: UserDefaults.standard.integer(forKey: "shibaInuCount"),
                imageName: "shibainu_image",
                backgroundColor: Color(red: 139 / 255, green: 0 / 255, blue: 0 / 255), // Red background
                textColor: .white,
                glowColor: .orange // Orange glow
            ),
            CoinTypeInfo(
                type: .dogecoin,
                label: "Dogecoin",
                cost: 250,
                count: UserDefaults.standard.integer(forKey: "dogecoinCount"),
                imageName: "dogecoin_image",
                backgroundColor: Color(red: 205 / 255, green: 127 / 255, blue: 50 / 255), // Bronze background
                textColor: .white,
                glowColor: Color.brown // Bronze glow
            ),
            CoinTypeInfo(
                type: .xrp,
                label: "XRP",
                cost: 5000,
                count: UserDefaults.standard.integer(forKey: "xrpCount"),
                imageName: "xrp_image",
                backgroundColor: .black, // Black background
                textColor: .white,
                glowColor: .white // White glow
            ),
            CoinTypeInfo(
                type: .cardano,
                label: "Cardano",
                cost: 10000,
                count: UserDefaults.standard.integer(forKey: "cardanoCount"),
                imageName: "cardano_image",
                backgroundColor: Color(red: 135 / 255, green: 206 / 255, blue: 250 / 255), // Blue background
                textColor: .black,
                glowColor: .cyan // Cyan glow
            ),
            CoinTypeInfo(
                type: .solana,
                label: "Solana",
                cost: 400000,
                count: UserDefaults.standard.integer(forKey: "solanaCount"),
                imageName: "solana_image",
                backgroundColor: .purple, // Purple background
                textColor: .white,
                glowColor: Color(hue: 0.8, saturation: 0.7, brightness: 0.8) // Vibrant purple glow
            ),
            CoinTypeInfo(
                type: .ethereum,
                label: "Ethereum",
                cost: 1000000,
                count: UserDefaults.standard.integer(forKey: "ethereumCount"),
                imageName: "ethereum_image",
                backgroundColor: Color(red: 211 / 255, green: 211 / 255, blue: 211 / 255), // Silver background
                textColor: .black,
                glowColor: Color.gray // Silver glow
            ),
            CoinTypeInfo(
                type: .bitcoin,
                label: "Bitcoin",
                cost: 10000000,
                count: UserDefaults.standard.integer(forKey: "bitcoinCount"),
                imageName: "bitcoin_image",
                backgroundColor: Color(red: 255 / 255, green: 215 / 255, blue: 0 / 255), // Gold background
                textColor: .black,
                glowColor: Color.yellow // Gold glow
            )
        ]
    }
    
    private func saveCoinsToUserDefaults() {
        for coinType in coinTypes {
            UserDefaults.standard.set(coinType.count, forKey: "\(coinType.type.rawValue)Count")
        }
    }

    // Perform the exchange based on the coin type
    func performExchange(for type: CoinType, with coins: inout CryptoCoin?) {
        
        guard let coin = coins else {
            popupMessage = "Invalid coin data."
            showPopupWithAnimation()
            return
        }
        
        if let index = coinTypes.firstIndex(where: { $0.type == type }) {
            
            let selectedCoin = coinTypes[index]
            
            if coin.value >= selectedCoin.cost {
                
                coins?.value -= selectedCoin.cost
                coinTypes[index].count += 1
                popupMessage = "Successfully exchanged for \(selectedCoin.label)!"
                
            } else {
                popupMessage = "Not enough coins for \(selectedCoin.label)."
            }
            
            showPopupWithAnimation()
        }
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

    // Helper methods
    func count(for type: CoinType) -> Int {
        return coinTypes.first(where: { $0.type == type })?.count ?? 0
    }

    func image(for type: CoinType) -> String {
        return coinTypes.first(where: { $0.type == type })?.imageName ?? "placeholderImage"
    }
    
    func backgroundColor(for type: CoinType) -> Color {
        return coinTypes.first(where: { $0.type == type })?.backgroundColor ?? .black
    }

    func textColor(for type: CoinType) -> Color {
        return coinTypes.first(where: { $0.type == type })?.textColor ?? .white
    }

    func glowColor(for type: CoinType) -> Color {
        return coinTypes.first(where: { $0.type == type })?.glowColor ?? .clear
    }
    
    var allCoinViews: [CoinTypeInfo] {
        return coinTypes
    }
    
    // Methods related to Blackjack
    
    func updateCoinCount(for type: CoinType, by amount: Int) {
        if let index = coinTypes.firstIndex(where: { $0.type == type }) {
            coinTypes[index].count = max(0, coinTypes[index].count + amount)
        }
    }

    func setExampleCount(for coin: CoinType, count: Int) {
        if let index = coinTypes.firstIndex(where: { $0.type == coin }) {
            coinTypes[index].count = count
        }
    }
    
    
    func rewardCoins(for type: CoinType, amount: Int) {
        if let index = coinTypes.firstIndex(where: { $0.type == type }) {
            coinTypes[index].count += amount
            popupMessage = "\(amount) \(coinTypes[index].label) coins rewarded!"
            showPopupWithAnimation()
        }
    }

    func refundBet(for type: CoinType, amount: Int) {
        rewardCoins(for: type, amount: amount) // Refund is the same as reward
    }
}

enum CoinType: String, CaseIterable {
    case shibainu, xrp, cardano, dogecoin, solana, ethereum, bitcoin
}
