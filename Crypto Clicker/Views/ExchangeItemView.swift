//
//  ExchangeItemView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-30.
//

import SwiftUI

struct ExchangeItemView: View {
    
    let coinType: CoinType
    @EnvironmentObject var exchangeModel: CoinExchangeModel
    @Binding var coins: CryptoCoin?
    @State private var quantity: Int = 1 // State for quantity selection

    var body: some View {
        
        if let coinInfo = exchangeModel.availableCoins.first(where: { $0.type == coinType }) {
            
            VStack(spacing: 12) {
                
                // Coin image / info
                HStack {
                    
                    Image(coinInfo.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .shadow(color: coinInfo.glowColor, radius: 10, x: 0, y: 0)
                        .accessibilityLabel("\(coinInfo.label) icon") // VoiceOver label
                    
                    VStack(alignment: .leading, spacing: 4) {
                        
                        Text(coinInfo.label)
                            .font(.title2)
                            .foregroundColor(coinInfo.textColor)
                            .bold()
                            .accessibilityLabel("Coin type: \(coinInfo.label)") // VoiceOver
                        
                        Text("Exchanged: \(coinInfo.count)")
                            .font(.headline)
                            .foregroundColor(coinInfo.textColor)
                            .accessibilityLabel("\(coinInfo.count) coins exchanged") // VoiceOver
                        
                        // Display the cost per coin
                        let perCoinCost = exchangeModel.calculateCost(for: coinInfo, quantity: 1)
                        
                        Text("Cost per coin: \(formatted(perCoinCost)) coins")
                            .font(.headline)
                            .foregroundColor(coinInfo.textColor)
                            .accessibilityLabel("Cost per \(coinInfo.label): \(formatted(perCoinCost)) coins") // VoiceOver
                    }
                    Spacer()
                }
                
                // Quantity
                HStack {
                    
                    Text("Quantity:")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(coinInfo.textColor)
                    
                    Spacer()
                    
                    Text("\(quantity)")
                        .font(.headline)
                        .foregroundColor(coinInfo.textColor)
                        .accessibilityLabel("Selected quantity: \(quantity)") // VoiceOver
                }
                
                // Total cost
                let totalCost = exchangeModel.calculateCost(for: coinInfo, quantity: quantity)
                
                HStack {
                    
                    Text("Total Cost:")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(coinInfo.textColor)
                    
                    Spacer()
                    
                    Text("\(formatted(totalCost)) coins")
                        .font(.headline)
                        .foregroundColor(coinInfo.textColor)
                        .accessibilityLabel("Total cost: \(formatted(totalCost)) coins") // VoiceOver
                }

                // Quantity Selector with adjusted button sizes
                HStack(spacing: 6) {
                    quantityButton(label: "-1", amount: -1, width: 40, color: .red)
                    quantityButton(label: "-20", amount: -20, width: 48, color: .red)
                    quantityButton(label: "-500", amount: -500, width: 55, color: .red)
                    quantityButton(label: "+1", amount: 1, width: 40, color: .green)
                    quantityButton(label: "+20", amount: 20, width: 48, color: .green)
                    quantityButton(label: "+500", amount: 500, width: 55, color: .green)
                }
                .accessibilityLabel("Adjust quantity of \(coinInfo.label) for exchange") // VoiceOver
                
                // Exchange Button
                Button(action: {
                    
                    if coins?.value ?? 0 >= totalCost {
                        exchangeModel.performExchange(for: coinType, quantity: quantity, with: &coins)
                        
                    } else {
                        // Error handling: Show message if not enough coins
                        print("Error: Not enough coins to exchange.")
                    }
                    
                }) {
                    Text("Exchange")
                        .font(.headline)
                        .foregroundColor(coinInfo.textColor.opacity(0.9))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(coinInfo.secondaryColor)
                        .cornerRadius(8)
                }
                .accessibilityLabel("Exchange \(quantity) \(coinInfo.label)") // VoiceOver
                .accessibilityHint("Tap to complete the exchange") // VoiceOver hint
            }
            .padding()
            .background(coinInfo.backgroundColor)
            .cornerRadius(12)
            .shadow(color: coinInfo.glowColor, radius: 5, x: 0, y: 0)
        }
    }
    
    /// Helper function to create quantity buttons with adjustable size
    private func quantityButton(label: String, amount: Int, width: CGFloat, color: Color) -> some View {
        
        Button(action: {
            quantity = max(1, quantity + amount)
        }) {
            Text(label)
                .frame(width: width, height: 40)
                .background(coinInfo(for: coinType)?.textColor.opacity(0.8) ?? .gray)
                .cornerRadius(8)
                .foregroundColor(color)
                .bold()
        }
        .accessibilityLabel("\(label) quantity") // VoiceOver
    }
    
    /// Helper function to retrieve coin info safely
    private func coinInfo(for type: CoinType) -> CoinExchangeModel.CoinTypeInfo? {
        return exchangeModel.availableCoins.first(where: { $0.type == type })
    }
    
    /// Format decimals with commas
    private func formatted(_ value: Decimal) -> String {
        
        let formatter = NumberFormatter()
        
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

struct ExchangeItemView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let coins = CryptoCoin(value: Decimal(1000))
        
        return VStack {
            ExchangeItemView(
                coinType: .dogecoin,
                coins: .constant(coins)
            )
            .environmentObject(CoinExchangeModel.shared)

            ExchangeItemView(
                coinType: .ethereum,
                coins: .constant(coins)
            )
            .environmentObject(CoinExchangeModel.shared)

            ExchangeItemView(
                coinType: .bitcoin,
                coins: .constant(coins)
            )
            .environmentObject(CoinExchangeModel.shared)
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
