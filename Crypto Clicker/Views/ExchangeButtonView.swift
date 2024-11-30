//
//  ExchangeButtonView.swift
//  Crypto Clicker
//

import SwiftUI

struct ExchangeButtonView: View {
    @ObservedObject var exchangeModel: CoinExchangeModel
    @Binding var coins: CryptoCoin?

    var body: some View {
        
        NavigationLink(destination: CoinExchangeView(coins: $coins, exchangeModel: exchangeModel)) {

            HStack(spacing: 20) {
                
                ForEach(CoinType.allCases, id: \.self) { coinType in
                    
                    VStack {
                        Text(exchangeModel.emoji(for: coinType)) // Use emoji from the model
                            .font(.system(size: 42)) // Emoji icon for the coin type
                        Text("\(exchangeModel.count(for: coinType))")
                            .font(.system(size: 24, weight: .semibold)) // Display the coin count
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1)) // Light blue background tint
            .cornerRadius(12) // Rounded corners
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 1) // Outline for the button
            )
        }
    }
}

struct ExchangeButtonView_Previews: PreviewProvider {
    static var previews: some View {
        let exchangeModel = CoinExchangeModel()
        let coins = CryptoCoin(value: 1000)
        return NavigationView {
            ExchangeButtonView(exchangeModel: exchangeModel, coins: .constant(coins))
        }
    }
}
