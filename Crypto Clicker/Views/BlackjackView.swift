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

            GeometryReader { geometry in
                
                VStack(spacing: 0) {
                    // Top View: Displays balance and coin selection
                    BlackjackTopView(selectedCoin: $model.selectedCoinType)
                    .frame(height: geometry.size.height * 0.18) // 18% of the screen height
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                    .disabled(model.gameState != .waitingForBet)

                    // Middle View: Displays cards and values
                    BlackjackMiddleView()
                        .frame(height: geometry.size.height * 0.50) // Adjusted to 52% of the screen height
                        .layoutPriority(1) // Ensures content gets priority over other views
                        .padding(.vertical, 5)

                    // Message View: Displays result and error messages
                    BlackjackMessageView()
                        .fixedSize(horizontal: false, vertical: true) // Ensures height adjusts to content
                        .frame(maxHeight: geometry.size.height * 0.09) // Maximum 9% height for messages
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    // Bottom View: Manages all controls (betting, hit, stand)
                    BlackjackBottomView()
                        .frame(height: geometry.size.height * 0.18) // Ensures 18% height for controls
                        .padding(.bottom, 10)
                }
            }
        }
    }
}

struct BlackjackView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel()
        let model = BlackjackModel(exchangeModel: exchangeModel)

        exchangeModel.setExampleCount(for: .dogecoin, count: 1000) // Set Dogecoin count to 1000
                
        return BlackjackView()
            .environmentObject(model)
            .environmentObject(exchangeModel)
    }
}
