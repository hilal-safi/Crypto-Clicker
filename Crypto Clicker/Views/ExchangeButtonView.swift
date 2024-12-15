//
//  ExchangeButtonView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-28.
//

import SwiftUI

struct ExchangeButtonView: View {
    
    @ObservedObject var exchangeModel: CoinExchangeModel
    @Binding var coins: CryptoCoin?

    var body: some View {
        
        NavigationLink(
            destination: CoinExchangeView(coins: $coins, exchangeModel: exchangeModel)
        ) {
            ScrollView(.horizontal, showsIndicators: false) { // Add horizontal scroll
                HStack(spacing: 20) {
                    coinTypeViews // Sub-expression for ForEach
                }
            }
            .padding(.vertical, 8) // Reduced vertical padding
            .padding(.horizontal, 12) // Adjust horizontal padding
            .background(Color.blue.opacity(0.1)) // Light blue background tint
            .cornerRadius(12) // Rounded corners
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 1) // Outline for the button
            )
        }
    }
    
    // Sub-expression for coin type views
    private var coinTypeViews: some View {
        
        ForEach(CoinType.allCases, id: \.self) { coinType in
            coinView(for: coinType)
        }
    }

    // Sub-expression for individual coin view
    private func coinView(for coinType: CoinType) -> some View {
        
        VStack {
            
            Image(exchangeModel.image(for: coinType))
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48) // Adjust the size of the image
            
            Text("\(exchangeModel.count(for: coinType))")
                .font(.system(size: 24, weight: .semibold)) // Display the coin count
                .foregroundColor(.blue) // Ensure the text matches the UI style
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
