//
//  ExchangeButtonView.swift
//  Crypto Clicker
//

import SwiftUI

struct ExchangeButtonView: View {
    @ObservedObject var exchangeModel: CoinExchangeModel
    @Binding var coins: CryptoCoin? // Pass the coin value as a binding

    var body: some View {
        NavigationLink(destination: CoinExchangeView(
            coins: $coins,
            exchangeModel: exchangeModel
        )) {
            VStack {
                HStack(spacing: 10) {
                    // Bronze Coin
                    VStack {
                        Text("🥉")
                            .font(.largeTitle)
                        Text("\(exchangeModel.bronzeCoins)")
                            .font(.headline)
                    }

                    // Silver Coin
                    VStack {
                        Text("🥈")
                            .font(.largeTitle)
                        Text("\(exchangeModel.silverCoins)")
                            .font(.headline)
                    }

                    // Gold Coin
                    VStack {
                        Text("🥇")
                            .font(.largeTitle)
                        Text("\(exchangeModel.goldCoins)")
                            .font(.headline)
                    }
                }
                .padding()
            }
            .frame(width: 100, height: 100) // Match PowerButtonView size
            .background(Color.blue.opacity(0.2))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 2)
            )
        }
    }
}

struct ExchangeButtonView_Previews: PreviewProvider {
    static var previews: some View {
        let exchangeModel = CoinExchangeModel()
        exchangeModel.bronzeCoins = 5
        exchangeModel.silverCoins = 3
        exchangeModel.goldCoins = 1

        return NavigationView {
            ExchangeButtonView(exchangeModel: exchangeModel, coins: .constant(CryptoCoin(value: 100)))
        }
        .previewLayout(.sizeThatFits)
    }
}
