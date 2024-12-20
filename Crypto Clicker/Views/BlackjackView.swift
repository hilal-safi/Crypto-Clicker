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
    @State private var showPopup = false

    var body: some View {
        
        ZStack {
            // Background
            BackgroundView(type: .default)

            VStack(spacing: 0) {
                // Top View: Displays balance and coin selection
                BlackjackTopView(
                    selectedCoin: $model.selectedCoinType, // Ensure the correct label matches
                    exchangeModel: exchangeModel
                )
                .padding(.top, 40)

                Spacer()

                // Middle View: Displays cards, values, and game result
                BlackjackMiddleView(model: model)

                Spacer()

                // Bottom View: Manages all controls (betting, hit, stand)
                BlackjackBottomView(model: model)
                    .padding(.bottom, 20)
            }

            // Overlay for Out of Coins
            if exchangeModel.count(for: model.selectedCoinType) <= 0 && showPopup {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack {
                        Text("You're out of \(model.selectedCoinType.rawValue)!")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()

                        Text("Earn more before playing again.")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()

                        Button(action: {
                            showPopup = false // Close popup
                        }) {
                            Text("Close")
                                .font(.headline)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .onAppear {
            showPopup = exchangeModel.count(for: model.selectedCoinType) <= 0
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
