//
//  BlackjackBottomView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackBottomView: View {
    
    @Environment(\.colorScheme) var colorScheme // Detect light or dark mode
    @ObservedObject var model: BlackjackModel

    var body: some View {
        
        VStack(spacing: 10) {
            
            HStack {
                Text("Bet Amount:")
                    .font(.title2)

                // Display Bet Amount
                Text("\(model.betAmount)")
                    .font(.title2)
                    .bold()
            }

            
            // Bet Adjustment Controls (only visible when the game has not started)
            if model.gameState == .waitingForBet {
                HStack(spacing: 15) {
                    betAdjustmentView(amount: 1)
                    betAdjustmentView(amount: 100)
                    betAdjustmentView(amount: 10000)
                }
            }

            // Buttons in a Single Line
            HStack(spacing: 5) {

                if model.gameOver {
                    // Single "New Game" button when the game is over
                    Button(action: {
                        model.resetGame()
                    }) {
                        Text("New Game")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    // Place Bet Button (only visible when the game has not started)
                    if model.gameState == .waitingForBet {
                        Button("Place Bet") {
                            model.placeBet(amount: model.betAmount)
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    
                    // Hit and Stand Buttons (only visible when the game has started)
                    if model.gameState == .playerTurn {
                        
                        Button("Hit") {
                            model.hitPlayer()
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        
                        Button("Stand") {
                            model.stand()
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        
                        // Disabled Double Down Button
                        Button("Double Down") {}
                            .font(.headline)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(true) // Greyed out and disabled

                        // Disabled Split Button
                        Button("Split") {}
                            .font(.headline)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(true) // Greyed out and disabled

                    }
                }
            }
        }
        .padding()
    }

    // Helper function to create bet adjustment controls
    private func betAdjustmentView(amount: Int) -> some View {
        HStack(spacing: 2) {
            Button(action: {
                model.betAmount = max(1, model.betAmount - amount)
            }) {
                Text("-")
                    .font(.headline)
                    .frame(width: 30, height: 30)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 2)
                    )
            }

            Text("\(amount)")
                .font(.headline)
                .frame(width: CGFloat(amount == 1 ? 15 : amount == 100 ? 35 : 65), height: 30)
                .cornerRadius(8)

            Button(action: {
                model.betAmount += amount
            }) {
                Text("+")
                    .font(.headline)
                    .frame(width: 30, height: 30)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 2)
                    )
            }
        }
    }
}

struct BlackjackBottomView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel()
        let model = BlackjackModel(exchangeModel: exchangeModel)
        
        BlackjackBottomView(model: model)
    }
}
