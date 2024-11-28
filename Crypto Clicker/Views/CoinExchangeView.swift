//
//  CoinExchangeView.swift
//  Crypto Clicker
//

import SwiftUI

struct CoinExchangeView: View {
    @Binding var coins: CryptoCoin? // Binding to the coin value
    @ObservedObject var exchangeModel: CoinExchangeModel

    var body: some View {
        VStack {
            Text("Coin Exchange")
                .font(.largeTitle)
                .padding()

            Text("Your Coins: \(coins?.value ?? 0)") // Display current coin value

            HStack {
                Button("Buy Bronze 🥉 for 250") {
                    if let currentValue = coins?.value, currentValue >= 250 {
                        coins?.value = currentValue - 250
                        exchangeModel.bronzeCoins += 1
                    }
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Buy Silver 🥈 for 10,000") {
                    if let currentValue = coins?.value, currentValue >= 10000 {
                        coins?.value = currentValue - 10000
                        exchangeModel.silverCoins += 1
                    }
                }
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Buy Gold 🥇 for 1,000,000") {
                    if let currentValue = coins?.value, currentValue >= 1000000 {
                        coins?.value = currentValue - 1000000
                        exchangeModel.goldCoins += 1
                    }
                }
                .padding()
                .background(Color.yellow)
                .foregroundColor(.black)
                .cornerRadius(10)
            }
            .padding()
        }
        .padding()
    }
}

struct CoinExchangeView_Previews: PreviewProvider {
    static var previews: some View {
        let exchangeModel = CoinExchangeModel()
        return CoinExchangeView(coins: .constant(CryptoCoin(value: 10000)), exchangeModel: exchangeModel)
    }
}
