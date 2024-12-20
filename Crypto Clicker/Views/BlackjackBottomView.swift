//
//  BlackjackBottomView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackBottomView: View {
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
            HStack(spacing: 15) {
                // Display Bet Amount
                Text("Bet: \(model.betAmount)")
                    .font(.headline)
                    .padding()

                // Place Bet Button
                Button("Place Bet") {
                    model.placeBet(amount: model.betAmount)
                }
                .font(.headline)
                .padding()
                .background(Color.green)
                .foregroundColor(.black)
                .cornerRadius(8)
                .disabled(model.betPlaced)

                // Hit Button
                Button("Hit") {
                    model.hitPlayer()
                }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.black)
                .cornerRadius(8)
                .disabled(!model.betPlaced || model.gameOver)

                // Stand Button
                Button("Stand") {
                    model.stand()
                }
                .font(.headline)
                .padding()
                .background(Color.red)
                .foregroundColor(.black)
                .cornerRadius(8)
                .disabled(!model.betPlaced || model.gameOver)
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
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
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
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
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
