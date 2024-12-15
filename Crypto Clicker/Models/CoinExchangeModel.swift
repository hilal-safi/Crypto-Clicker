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
                imageName: "ShibaInu",
                backgroundColor: Color(red: 139 / 255, green: 0 / 255, blue: 0 / 255), // Red background
                textColor: .white,
                glowColor: .orange // Orange glow
            ),
            CoinTypeInfo(
                type: .xrp,
                label: "XRP",
                cost: 5000,
                count: UserDefaults.standard.integer(forKey: "xrpCount"),
                imageName: "XRP",
                backgroundColor: .black, // Black background
                textColor: .white,
                glowColor: .white // White glow
            ),
            CoinTypeInfo(
                type: .cardano,
                label: "Cardano",
                cost: 10000,
                count: UserDefaults.standard.integer(forKey: "cardanoCount"),
                imageName: "Cardano",
                backgroundColor: Color(red: 135 / 255, green: 206 / 255, blue: 250 / 255), // Blue background
                textColor: .black,
                glowColor: .cyan // Cyan glow
            ),
            CoinTypeInfo(
                type: .dogecoin,
                label: "Dogecoin",
                cost: 250,
                count: UserDefaults.standard.integer(forKey: "dogecoinCount"),
                imageName: "Dogecoin",
                backgroundColor: Color(red: 205 / 255, green: 127 / 255, blue: 50 / 255), // Bronze background
                textColor: .white,
                glowColor: Color.brown // Bronze glow
            ),
            CoinTypeInfo(
                type: .solana,
                label: "Solana",
                cost: 400000,
                count: UserDefaults.standard.integer(forKey: "solanaCount"),
                imageName: "Solana",
                backgroundColor: .purple, // Purple background
                textColor: .white,
                glowColor: Color(hue: 0.8, saturation: 0.7, brightness: 0.8) // Vibrant purple glow
            ),
            CoinTypeInfo(
                type: .ethereum,
                label: "Ethereum",
                cost: 1000000,
                count: UserDefaults.standard.integer(forKey: "ethereumCount"),
                imageName: "Ethereum",
                backgroundColor: Color(red: 211 / 255, green: 211 / 255, blue: 211 / 255), // Silver background
                textColor: .black,
                glowColor: Color.gray // Silver glow
            ),
            CoinTypeInfo(
                type: .bitcoin,
                label: "Bitcoin",
                cost: 10000000,
                count: UserDefaults.standard.integer(forKey: "bitcoinCount"),
                imageName: "Bitcoin",
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
}

enum CoinType: String, CaseIterable {
    case shibainu, xrp, cardano, dogecoin, solana, ethereum, bitcoin
}
