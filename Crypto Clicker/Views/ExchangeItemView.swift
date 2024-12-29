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
                HStack {
                    // Coin Image
                    Image(coinInfo.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .shadow(color: coinInfo.glowColor, radius: 10, x: 0, y: 0) // Glow effect

                    VStack(alignment: .leading, spacing: 4) {
                        // Coin Label
                        Text(coinInfo.label)
                            .font(.headline)
                            .foregroundColor(coinInfo.textColor)

                        // Coin Count
                        Text("Exchanged: \(coinInfo.count)")
                            .font(.subheadline)
                            .foregroundColor(coinInfo.textColor.opacity(0.9))

                        // Coin Cost
                        Text("Cost per unit: \(coinInfo.cost) coins")
                            .font(.subheadline)
                            .foregroundColor(coinInfo.textColor.opacity(0.9))
                    }
                    Spacer()
                }

                // Quantity and Total Cost
                HStack {
                    Text("Quantity:")
                        .font(.subheadline)
                        .foregroundColor(coinInfo.textColor.opacity(0.9))
                    Spacer()
                    Text("\(quantity)")
                        .font(.headline)
                        .foregroundColor(coinInfo.textColor.opacity(0.9))
                }

                HStack {
                    Text("Total Cost:")
                        .font(.subheadline)
                        .foregroundColor(coinInfo.textColor.opacity(0.9))
                    Spacer()
                    Text("\(quantity * coinInfo.cost) coins")
                        .font(.headline)
                        .foregroundColor(coinInfo.textColor.opacity(0.9))
                }

                // Quantity Selector
                HStack(spacing: 8) {
                    Button(action: {
                        quantity = max(1, quantity - 1)
                    }) {
                        Text("-1")
                            .frame(width: 40, height: 40)
                            .background(coinInfo.secondaryColor)
                            .cornerRadius(8)
                            .foregroundColor(coinInfo.textColor.opacity(0.9))
                    }

                    Button(action: {
                        quantity = max(1, quantity - 20)
                    }) {
                        Text("-20")
                            .frame(width: 40, height: 40)
                            .background(coinInfo.secondaryColor)
                            .cornerRadius(8)
                            .foregroundColor(coinInfo.textColor.opacity(0.9))
                    }

                    Button(action: {
                        quantity = max(1, quantity - 500)
                    }) {
                        Text("-500")
                            .frame(width: 40, height: 40)
                            .background(coinInfo.secondaryColor)
                            .cornerRadius(8)
                            .foregroundColor(coinInfo.textColor.opacity(0.9))
                    }

                    Button(action: {
                        quantity += 1
                    }) {
                        Text("+1")
                            .frame(width: 40, height: 40)
                            .background(coinInfo.secondaryColor)
                            .cornerRadius(8)
                            .foregroundColor(coinInfo.textColor.opacity(0.9))
                    }

                    Button(action: {
                        quantity += 20
                    }) {
                        Text("+20")
                            .frame(width: 40, height: 40)
                            .background(coinInfo.secondaryColor)
                            .cornerRadius(8)
                            .foregroundColor(coinInfo.textColor.opacity(0.9))
                    }

                    Button(action: {
                        quantity += 500
                    }) {
                        Text("+500")
                            .frame(width: 40, height: 40)
                            .background(coinInfo.secondaryColor)
                            .cornerRadius(8)
                            .foregroundColor(coinInfo.textColor.opacity(0.9))
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
}

struct ExchangeItemView_Previews: PreviewProvider {
    static var previews: some View {
        let coins = CryptoCoin(value: 1000)

        return VStack {
            ExchangeItemView(
                coinType: .dogecoin,
                coins: .constant(coins)
            )
            .environmentObject(CoinExchangeModel())

            ExchangeItemView(
                coinType: .ethereum,
                coins: .constant(coins)
            )
            .environmentObject(CoinExchangeModel())

            ExchangeItemView(
                coinType: .bitcoin,
                coins: .constant(coins)
            )
            .environmentObject(CoinExchangeModel())
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
