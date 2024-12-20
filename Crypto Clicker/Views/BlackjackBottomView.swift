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
            // Bet Adjustment Controls Above the Buttons
            HStack(spacing: 5) {
                // Bet Adjustment for 1
                Button(action: {
                    model.betAmount = max(1, model.betAmount - 1)
                }) {
                    Text("-")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                Text("1")
                    .font(.headline)
                    .frame(width: 15, height: 30)
                    .cornerRadius(8)
                Button(action: {
                    model.betAmount += 1
                }) {
                    Text("+")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.trailing)
                
                Button(action: {
                    model.betAmount = max(1, model.betAmount - 100)
                }) {
                    Text("-")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                Text("100")
                    .font(.headline)
                    .frame(width: 35, height: 30)
                    .cornerRadius(8)
                Button(action: {
                    model.betAmount += 100
                }) {
                    Text("+")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }

                Button(action: {
                    model.betAmount = max(1, model.betAmount - 1)
                }) {
                    Text("-")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.leading)
                Text("10000")
                    .font(.headline)
                    .frame(width: 55, height: 30)
                    .cornerRadius(8)
                Button(action: {
                    model.betAmount += 1
                }) {
                    Text("+")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
            }

            // Buttons in a Single Line
            HStack(spacing: 5) {
                // Display Bet Amount
                Text("\(model.betAmount)")
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

                // Hit Button
                Button("Hit") {
                    model.hitPlayer()
                }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.black)
                .cornerRadius(8)

                // Stand Button
                Button("Stand") {
                    model.stand()
                }
                .font(.headline)
                .padding()
                .background(Color.red)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct BlackjackBottomView_Previews: PreviewProvider {
    @StateObject static var model = BlackjackModel(initialBalance: 10000, playerBalance: 5000)

    static var previews: some View {
        BlackjackBottomView(model: model)
    }
}
