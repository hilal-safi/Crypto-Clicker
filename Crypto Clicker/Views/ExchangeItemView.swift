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
        HStack {
            // Coin Emoji
            Text(exchangeModel.emoji(for: coinType))
                .font(.system(size: 42)) // Emoji size

            VStack(alignment: .leading, spacing: 4) {
                // Coin Label
                Text(exchangeModel.label(for: coinType))
                    .font(.headline)
                    .foregroundColor(textColor(for: coinType))

                // Coin Count
                Text("Exchanged: \(exchangeModel.count(for: coinType))")
                    .font(.subheadline)
                    .foregroundColor(textColor(for: coinType).opacity(0.9)) // Slightly less opaque for distinction
                
                // Coin Cost
                Text("Cost: \(exchangeModel.cost(for: coinType)) coins")
                    .font(.subheadline)
                    .foregroundColor(textColor(for: coinType).opacity(0.9)) // Slightly less opaque for distinction
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
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(exchangeModel.color(for: coinType)) // Dynamic background color
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    // Helper to determine the text color
    private func textColor(for type: CoinType) -> Color {
        switch type {
        case .gold:
            return .black // Use black text for gold
        default:
            return .white // Use white text for all other types
        }
    }
}

struct ExchangeItemView_Previews: PreviewProvider {
    static var previews: some View {
        let exchangeModel = CoinExchangeModel()
        let coins = CryptoCoin(value: 1000)
        return VStack {
            ExchangeItemView(
                coinType: .bronze,
                exchangeModel: exchangeModel,
                coins: .constant(coins)
            )
            ExchangeItemView(
                coinType: .silver,
                exchangeModel: exchangeModel,
                coins: .constant(coins)
            )
            ExchangeItemView(
                coinType: .gold,
                exchangeModel: exchangeModel,
                coins: .constant(coins)
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
