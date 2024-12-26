//
//  CoinExchangeView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

struct CoinExchangeView: View {
    
    @Binding var coins: CryptoCoin?
    @EnvironmentObject var exchangeModel: CoinExchangeModel
    
    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                BackgroundView(type: .store)

                VStack(spacing: 16) { // Reduced spacing for a more compact layout
                    
                    ExchangePopupView()
                    
                    // Display Current Coins
                    Text("Coins: \(coins?.value ?? 0)")
                        .font(.headline)
                        .padding(.top)

                    // List of Coin Exchanges
                    ScrollView {
                        
                        LazyVStack(spacing: 16) { // Reduced spacing between items
                            
                            ForEach(CoinType.allCases, id: \.self) { coinType in
                                ExchangeItemView(coinType: coinType, coins: $coins)
                            }
                        }
                        .padding(.horizontal, 16) // Reduced horizontal padding
                    }
                }
                .padding(.horizontal, 12) // Overall padding for the entire view
            }
            .navigationTitle("Exchange Coins") // Title is now part of the NavigationStack
            .navigationBarTitleDisplayMode(.inline) // Keeps the title inline for a cleaner look
        }
    }
}

struct CoinExchangeView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let coins = CryptoCoin(value: 1000)
        return CoinExchangeView(coins: .constant(coins))
    }
}
