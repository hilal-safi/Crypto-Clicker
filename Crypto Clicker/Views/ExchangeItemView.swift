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
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(coinInfo.label)
                            .font(.title2)
                            .foregroundColor(coinInfo.textColor)
                            .bold()
                        
                        Text("Exchanged: \(coinInfo.count)")
                            .font(.headline)
                            .foregroundColor(coinInfo.textColor)
                        
                        // We can *display* the cost with difficulty as well
                        let perCoinCost = exchangeModel.calculateCost(for: coinInfo, quantity: 1)
                        Text("Cost per coin: \(formatted(perCoinCost)) coins")
                            .font(.headline)
                            .foregroundColor(coinInfo.textColor)
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
                }
                
                // Total cost using difficulty-based logic
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
                }

                // Quantity Selector
                HStack(spacing: 6) {
                    Button(action: {
                        quantity = max(1, quantity - 1)
                    }) {
                        Text("-1")
                            .frame(width: 40, height: 40)
                            .background(coinInfo.textColor.opacity(0.8))
                            .cornerRadius(8)
                            .foregroundColor(.red)
                            .bold()
                    }

                    Button(action: {
                        quantity = max(1, quantity - 20)
                    }) {
                        Text("-20")
                            .frame(width: 48, height: 40)
                            .background(coinInfo.textColor.opacity(0.8))
                            .cornerRadius(8)
                            .foregroundColor(.red)
                            .bold()
                    }

                    Button(action: {
                        quantity = max(1, quantity - 500)
                    }) {
                        Text("-500")
                            .frame(width: 55, height: 40)
                            .background(coinInfo.textColor.opacity(0.8))
                            .cornerRadius(8)
                            .foregroundColor(.red)
                            .bold()
                    }

                    Button(action: {
                        quantity += 1
                    }) {
                        Text("+1")
                            .frame(width: 40, height: 40)
                            .background(coinInfo.textColor.opacity(0.8))
                            .cornerRadius(8)
                            .foregroundColor(.green)
                            .bold()
                    }

                    Button(action: {
                        quantity += 20
                    }) {
                        Text("+20")
                            .frame(width: 48, height: 40)
                            .background(coinInfo.textColor.opacity(0.8))
                            .cornerRadius(8)
                            .foregroundColor(.green)
                            .bold()
                    }

                    Button(action: {
                        quantity += 500
                    }) {
                        Text("+500")
                            .frame(width: 55, height: 40)
                            .background(coinInfo.textColor.opacity(0.8))
                            .cornerRadius(8)
                            .foregroundColor(.green)
                            .bold()
                    }
                }

                // Exchange Button
                Button(action: {
                    exchangeModel.performExchange(for: coinType, quantity: quantity, with: &coins)
                }) {
                    Text("Exchange")
                        .font(.headline)
                        .foregroundColor(coinInfo.textColor.opacity(0.9))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(coinInfo.secondaryColor)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(coinInfo.backgroundColor)
            .cornerRadius(12)
            .shadow(color: coinInfo.glowColor, radius: 5, x: 0, y: 0)
        }
    }
    
    // Format decimals with commas
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
