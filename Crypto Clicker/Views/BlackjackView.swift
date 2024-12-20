//
//  BlackjackView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import SwiftUI

struct BlackjackView: View {
    @ObservedObject var model: BlackjackModel
    @State private var gameResult: String?

    var body: some View {
        ZStack {
            // Background
            BackgroundView(type: .default)

            VStack(spacing: 0) {
                // Top View: Fixed at the top
                BlackjackTopView(
                    initialBalance: model.initialBalance,
                    playerBalance: model.playerBalance
                )
                .padding(.top, 40)
                
                Spacer()

                // Middle View: Displays dealer and player cards
                BlackjackMiddleView(
                    dealerHand: model.dealerHand,
                    playerHand: model.playerHand,
                    dealerValue: model.dealerValue,
                    playerValue: model.playerValue,
                    betPlaced: model.betPlaced
                )
                .onAppear {
                    debugPrint("Dealer Hand: \(model.dealerHand)")
                    debugPrint("Player Hand: \(model.playerHand)")
                }

                Spacer()

                // Game Result Display
                if let result = gameResult {
                    Text(result)
                        .font(.headline)
                        .foregroundColor(result.contains("Win") ? .green : .red)
                        .padding()
                }

                // Start Game Button (Initial round only)
                if !model.betPlaced && model.playerHand.isEmpty && model.dealerHand.isEmpty {
                    Button(action: {
                        gameResult = nil
                        model.startGame()
                    }) {
                        Text("Start Game")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }

                // Bottom View: Handles betting and game controls
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
