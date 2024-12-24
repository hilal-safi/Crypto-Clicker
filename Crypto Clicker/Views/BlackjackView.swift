//
//  BlackjackView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import SwiftUI

struct BlackjackView: View {
    
    @ObservedObject var model: BlackjackModel
    @ObservedObject var exchangeModel: CoinExchangeModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            BackgroundView(type: .blackjack)

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Top View: Displays balance and coin selection
                    BlackjackTopView(
                        selectedCoin: $model.selectedCoinType,
                        exchangeModel: exchangeModel
                    )
                    .frame(height: geometry.size.height * 0.18) // 18% of the screen height
                    .padding(.vertical, 8)
                    .disabled(model.gameState != .waitingForBet)

                    // Middle View: Displays cards and values
                    BlackjackMiddleView(model: model)
                        .frame(height: geometry.size.height * 0.50) // Adjusted to 52% of the screen height
                        .layoutPriority(1) // Ensures content gets priority over other views
                        .padding(.vertical, 5)

                    // Message View: Displays result and error messages
                    BlackjackMessageView(model: model)
                        .fixedSize(horizontal: false, vertical: true) // Ensures height adjusts to content
                        .padding(.horizontal, 16)
                        .frame(maxHeight: geometry.size.height * 0.10) // Maximum 10% height for messages
                        .padding(.vertical, 8)

                    // Bottom View: Manages all controls (betting, hit, stand)
                    BlackjackBottomView(model: model)
                        .frame(height: geometry.size.height * 0.20) // Ensures 20% height for controls
                        .padding(.bottom, 10)
                }
            }
        }
    }
}

struct BlackjackView_Previews: PreviewProvider {
    
    static var previews: some View {
        let exchangeModel = CoinExchangeModel()
        exchangeModel.setExampleCount(for: .dogecoin, count: 1000) // Set Dogecoin count to 1000
        
        let model = BlackjackModel(exchangeModel: exchangeModel)
        
        return BlackjackView(model: model, exchangeModel: exchangeModel)
    }
}
