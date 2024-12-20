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
            // Bet Adjustment Controls
            HStack(spacing: 15) {
                betAdjustmentView(amount: 1)
                betAdjustmentView(amount: 100)
                betAdjustmentView(amount: 10000)
            }

            // Buttons in a Single Line
            HStack(spacing: 5) {
                VStack {
                    Text("Bet Amount:")
                    
                    // Display Bet Amount
                    Text("\(model.betAmount)")
                        .font(.title2)
                        .bold()
                }

                // Place Bet Button
                Button("Place Bet") {
                    model.placeBet(amount: model.betAmount)
                }
                .font(.headline)
                .padding()
                .background(model.gameState == .waitingForBet ? Color.green : Color.gray)
                .foregroundColor(.black)
                .cornerRadius(8)
                .allowsHitTesting(model.gameState == .waitingForBet) // Enable/disable interaction

                // Hit Button
                Button("Hit") {
                    model.hitPlayer()
                }
                .font(.headline)
                .padding()
                .background(model.gameState == .playerTurn ? Color.blue : Color.gray)
                .foregroundColor(.black)
                .cornerRadius(8)
                .allowsHitTesting(model.gameState == .playerTurn) // Enable/disable interaction

                // Stand Button
                Button("Stand") {
                    model.stand()
                }
                .font(.headline)
                .padding()
                .background(model.gameState == .playerTurn ? Color.red : Color.gray)
                .foregroundColor(.black)
                .cornerRadius(8)
                .allowsHitTesting(model.gameState == .playerTurn) // Enable/disable interaction
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
    @StateObject static var model = BlackjackModel(initialBalance: 10000, playerBalance: 5000)

    static var previews: some View {
        BlackjackBottomView(model: model)
    }
}
