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

            VStack(spacing: 0) {
                // Top View: Displays balance and coin selection
                BlackjackTopView(
                    selectedCoin: $model.selectedCoinType, // Ensure the correct label matches
                    exchangeModel: exchangeModel
                )
                .padding(.top, 30)
                .disabled(model.gameState != .waitingForBet) // Disable coin selection while the game is active

                Spacer()

                // Middle View: Displays cards and values
                BlackjackMiddleView(model: model)

                Spacer()

                // Message View: Displays result and error messages
                BlackjackMessageView(model: model)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                Color(colorScheme == .dark ? .gray : .lightGray)
                                    .opacity(0.7)
                            )
                            .padding()
                    )

                Spacer()

                // Bottom View: Manages all controls (betting, hit, stand)
                BlackjackBottomView(model: model)
                    .padding(.bottom, 20)
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
