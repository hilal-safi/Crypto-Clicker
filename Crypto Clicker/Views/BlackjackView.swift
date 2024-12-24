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
                    .frame(height: geometry.size.height * 0.16) // Adjusted to 16% of the screen height
                    .padding(.top, 20)
                    .disabled(model.gameState != .waitingForBet)

                    // Middle View: Displays cards and values
                    BlackjackMiddleView(model: model)
                        .frame(height: geometry.size.height * 0.55) // Adjusted to 55% of the screen height
                        .layoutPriority(1) // Higher priority to avoid getting cut off
                        .padding(.vertical, 10)

                    // Message View: Displays result and error messages
                    BlackjackMessageView(model: model)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    Color(colorScheme == .dark ? .gray : .lightGray)
                                        .opacity(0.8)
                                )
                                .padding()
                        )
                        .frame(height: geometry.size.height * 0.03) // 3% of the screen height

                    // Bottom View: Manages all controls (betting, hit, stand)
                    BlackjackBottomView(model: model)
                        .frame(height: geometry.size.height * 0.25) // 25% of the screen height
                        .padding(.bottom, 16) // Adjusted padding to prevent cutoff
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
