//
//  BlackjackView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import SwiftUI

struct BlackjackView: View {
    
    @EnvironmentObject var model: BlackjackModel
    @EnvironmentObject var exchangeModel: CoinExchangeModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        ZStack {
            // Background
            BackgroundView(type: .blackjack)
                .accessibilityHidden(true) // Prevent background from being read by VoiceOver

            GeometryReader { geometry in
                
                VStack(spacing: 0) {
                    // Top View: Displays balance and coin selection
                    BlackjackTopView(selectedCoin: $model.selectedCoinType)
                        .frame(height: geometry.size.height * 0.18) // 18% of the screen height
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                        .disabled(model.gameState != .waitingForBet)
                        .accessibilityLabel("Coin selection and balance") // VoiceOver
                    
                    // Middle View: Displays cards and values
                    BlackjackMiddleView()
                        .frame(height: geometry.size.height * 0.50) // Adjusted to 50% of the screen height
                        .layoutPriority(1) // Ensures content gets priority over other views
                        .padding(.vertical, 5)
                        .accessibilityLabel("Blackjack game table") // VoiceOver hint

                    // Message View: Displays result and error messages
                    BlackjackMessageView()
                        .fixedSize(horizontal: false, vertical: true) // Ensures height adjusts to content
                        .frame(maxHeight: geometry.size.height * 0.09) // Maximum 9% height for messages
                        .padding(.top, 14)
                        .padding(.bottom, 6)
                        .padding(.horizontal, 8)
                        .accessibilityLabel("Game messages and results") // VoiceOver hint

                    // Bottom View: Manages all controls (betting, hit, stand)
                    BlackjackBottomView()
                        .frame(height: geometry.size.height * 0.18) // Ensures 18% height for controls
                        .padding(.bottom, 10)
                        .accessibilityLabel("Game controls: betting, hit, stand") // VoiceOver hint
                }
            }
        }
        .navigationTitle("Blackjack")
        .accessibilityLabel("Blackjack game screen") // VoiceOver screen title
    }
}

struct BlackjackView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel.shared
        let cryptoStore = CryptoStore()
        let model = BlackjackModel(exchangeModel: exchangeModel, cryptoStore: cryptoStore)

        // Configure the shared instance for preview
        exchangeModel.setExampleCount(for: .dogecoin, count: 1000) // Set Dogecoin count to 1000
                
        return BlackjackView()
            .environmentObject(model)
            .environmentObject(exchangeModel)
    }
}
