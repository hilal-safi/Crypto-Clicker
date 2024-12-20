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
        VStack(spacing: 8) {
            Text("Dealer's Hand (Value: \(dealerValue))")
                .font(.headline)
            HStack {
                ForEach(dealerHand) { card in
                    BlackjackCardView(card: card)
                        .aspectRatio(2/3, contentMode: .fit)
                        .frame(maxWidth: calculateCardWidth(), maxHeight: calculateCardWidth() * 1.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.bottom, 8)
    }
    
    private var playerSection: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(playerHand) { card in
                    BlackjackCardView(card: card)
                        .aspectRatio(2/3, contentMode: .fit)
                        .frame(maxWidth: calculateCardWidth(), maxHeight: calculateCardWidth() * 1.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Text("Your Hand (Value: \(playerValue))")
                .font(.headline)
        }
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
