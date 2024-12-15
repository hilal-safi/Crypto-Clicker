//
//  ExchangeItemView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-30.
//

import SwiftUI

struct ExchangeItemView: View {
    
    let coinType: CoinType
    @ObservedObject var exchangeModel: CoinExchangeModel
    @Binding var coins: CryptoCoin?

    var body: some View {
        if let coinInfo = exchangeModel.coinTypes.first(where: { $0.type == coinType }) {
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
                    Text("Cost: \(coinInfo.cost) coins")
                        .font(.subheadline)
                        .foregroundColor(coinInfo.textColor.opacity(0.9))
                }

                Spacer()

                // Exchange Button
                Button(action: {
                    exchangeModel.performExchange(for: coinType, with: &coins)
                }) {
                    Text("Exchange")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .cornerRadius(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black) // Black background
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2) // White border
                        )
                        .foregroundColor(.white) // Text color

                }
            }
            .padding()
            .background(coinInfo.backgroundColor) // Use dynamic background color
            .cornerRadius(12)
            .shadow(color: coinInfo.glowColor, radius: 5, x: 0, y: 0) // Glow effect for the item card
        }
    }
}

struct ExchangeItemView_Previews: PreviewProvider {
    static var previews: some View {
        let exchangeModel = CoinExchangeModel()
        let coins = CryptoCoin(value: 1000)
        return VStack {
            ExchangeItemView(
                coinType: .dogecoin,
                exchangeModel: exchangeModel,
                coins: .constant(coins)
            )
            ExchangeItemView(
                coinType: .ethereum,
                exchangeModel: exchangeModel,
                coins: .constant(coins)
            )
            ExchangeItemView(
                coinType: .bitcoin,
                exchangeModel: exchangeModel,
                coins: .constant(coins)
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
