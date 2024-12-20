//
//  BlackjackMiddleView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackMiddleView: View {
    
    @ObservedObject var model: BlackjackModel

    var body: some View {
        VStack {
            // Dealer's cards and value
            VStack {
                Text("Dealer's Hand")
                    .font(.headline)
                HStack {
                    ForEach(model.dealerHand, id: \.self) { card in
                        BlackjackCardView(card: card)
                    }
                }
                Text("Dealer's Value: \(model.dealerValue)")
                    .font(.subheadline)
            }
            .padding()

            Divider()

            // Player's cards and value
            VStack {
                Text("Player's Hand")
                    .font(.headline)
                HStack {
                    ForEach(model.playerHand, id: \.self) { card in
                        BlackjackCardView(card: card)
                    }
                }
                Text("Player's Value: \(model.playerValue)")
                    .font(.subheadline)
            }
            .padding()

            Divider()

            // Game result
            if let result = model.gameResult {
                Text(result)
                    .font(.title)
                    .foregroundColor(result.contains("Win") ? .green : .red)
                    .padding()
            } else {
                Text("Place your bet to start!")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
            }
        }
        .padding()
    }
}

struct BlackjackMiddleView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackMiddleView(model: BlackjackModel(initialBalance: 1000, playerBalance: 1000))
    }
}
