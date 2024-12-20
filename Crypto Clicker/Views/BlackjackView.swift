//
//  BlackjackView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import SwiftUI

struct BlackjackView: View {
    
    @ObservedObject var model: BlackjackModel

    var body: some View {
        
        ZStack {
            // Background
            BackgroundView(type: .default)

            VStack(spacing: 0) {
                // Top View: Displays balance
                BlackjackTopView(
                    initialBalance: model.initialBalance,
                    playerBalance: model.playerBalance
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
            if model.playerBalance <= 0 {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack {
                        Text("You're out of coins!")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()

                        Text("Earn more before playing again.")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()

                        Button(action: {
                            // Navigate to earn coins or reset
                        }) {
                            Text("Earn Coins")
                                .font(.headline)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }
}

struct BlackjackView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackView(model: BlackjackModel(initialBalance: 1000, playerBalance: 1000))
    }
}
