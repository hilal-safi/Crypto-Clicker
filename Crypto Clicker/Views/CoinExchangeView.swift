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
                                        
                    ExchangeMessageView(coins: $coins) // Message Area
                        .padding(.horizontal, 8) // Overall padding for the entire view
                        .padding(.top, -4)
                    
                    // List of Coin Exchanges
                    ScrollView {
                        
                        LazyVStack(spacing: 20) { // Reduced spacing between items
                            
                            ForEach(CoinType.allCases, id: \.self) { coinType in
                                ExchangeItemView(coinType: coinType, coins: $coins)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 10) // Overall padding for the entire view
                .padding(.top, 4)
            }
            .navigationTitle("Exchange Coins") // Title is now part of the NavigationStack
            .navigationBarTitleDisplayMode(.inline) // Keeps the title inline for a cleaner look
        }
    }
}

struct CoinExchangeView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let coins = CryptoCoin(value: Decimal(1000))
        return CoinExchangeView(coins: .constant(coins))
            .environmentObject(CoinExchangeModel.shared)
    }
}
