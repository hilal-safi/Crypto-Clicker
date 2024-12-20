//
//  BlackjackMiddleView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackMiddleView: View {
    let dealerHand: [Card]
    let playerHand: [Card]
    let dealerValue: Int
    let playerValue: Int
    let betPlaced: Bool
    
    var body: some View {
        
        if betPlaced {
            
            VStack(spacing: 20) {
                // Dealer's Hand
                dealerSection
                
                // Player's Hand
                playerSection
            }
        } else {
            Spacer()
                .frame(height: 200) // Placeholder space when the game has not started
        }
    }
    
    private var dealerSection: some View {
        VStack {
            Text("Dealer")
                .font(.headline)
            HStack {
                ForEach(dealerHand, id: \.self) { card in
                    BlackjackCardView(card: card)
                }
            }
            Text("Value: \(dealerValue)")
                .font(.title2)
                .bold()
        }
        .padding()
    }
    
    private var playerSection: some View {
        VStack {
            Text("Player")
                .font(.headline)
            HStack {
                ForEach(playerHand, id: \.self) { card in
                    BlackjackCardView(card: card)
                }
            }
            Text("Value: \(playerValue)")
                .font(.title2)
                .bold()
        }
        .padding()
    }
    
    // Helper method to calculate dynamic card width
    private func calculateCardWidth() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let cardCount = max(playerHand.count, dealerHand.count)
        let maxCards = max(cardCount, 5)
        return screenWidth / CGFloat(maxCards) - 10
    }
}

struct BlackjackMiddleView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackMiddleView(
            dealerHand: [.example],
            playerHand: [.example],
            dealerValue: 20,
            playerValue: 21,
            betPlaced: true
        )
    }
}
