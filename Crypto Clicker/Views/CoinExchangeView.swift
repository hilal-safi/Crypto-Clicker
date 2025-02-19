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
                
                // Background with accessibility
                BackgroundView(type: .store)
                    .accessibilityHidden(true) // Background should not interfere with VoiceOver

                VStack(spacing: 16) { // Reduced spacing for a more compact layout
                                        
                    ExchangeMessageView(coins: $coins) // Message Area
                        .padding(.horizontal, 8) // Overall padding for the entire view
                        .padding(.top, -4)
                        .accessibilityLabel("Exchange message and status") // VoiceOver
                    
                    // List of Coin Exchanges
                    ScrollView {
                        
                        LazyVStack(spacing: 20) { // Reduced spacing between items
                            
                            ForEach(CoinType.allCases, id: \.self) { coinType in
                                ExchangeItemView(coinType: coinType, coins: $coins)
                                    .accessibilityLabel("Exchange option for \(coinType.rawValue.capitalized)") // VoiceOver
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .padding(.top, 4)
                    .accessibilityHint("Scroll to view available coin exchanges") // VoiceOver hint
                }
                .padding(.horizontal, 10) // Overall padding for the entire view
                .padding(.top, 4)
            }
            .navigationTitle("Exchange Coins") // Title is now part of the NavigationStack
            .navigationBarTitleDisplayMode(.inline) // Keeps the title inline for a cleaner look
            .accessibilityLabel("Exchange Coins screen") // VoiceOver screen title
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
