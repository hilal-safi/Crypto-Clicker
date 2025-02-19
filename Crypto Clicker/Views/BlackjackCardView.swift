//
//  BlackjackCardView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import SwiftUI

struct BlackjackCardView: View {
    
    let card: Card
    @Environment(\.colorScheme) var colorScheme // Access the current color scheme

    var body: some View {
        
        ZStack {
            
            // Background of the card with adaptive color for light/dark mode
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    Color(
                        colorScheme == .dark
                            ? Color(red: 0.7, green: 0.7, blue: 0.7) // Gray for dark mode
                            : Color(red: 1, green: 1, blue: 1) // White for light mode
                    )
                )
                .shadow(radius: 3)
                .frame(width: 80, height: 120)
                .accessibilityHidden(true) // Background should not be read by VoiceOver
            
            if card.value == 0 {
                // Placeholder for the back of the card
                Image("Coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .accessibilityLabel("Card is face down") // VoiceOver description
                
            } else {
                
                VStack {
                    
                    Text(card.displayValue)
                        .font(.title)
                        .bold()
                        .foregroundColor(card.suit == "♠" || card.suit == "♣" ? .black : .red)
                        .accessibilityLabel("Card value: \(card.displayValue)") // VoiceOver

                    Text(card.suit)
                        .font(.largeTitle)
                        .foregroundColor(card.suit == "♠" || card.suit == "♣" ? .black : .red)
                        .accessibilityLabel("Suit: \(suitDescription(for: card.suit))") // VoiceOver
                }
            }
        }
        .accessibilityElement(children: .combine) // Treat the card as a single element
    }
    
    /// Provides a descriptive name for the suit symbol for accessibility.
    private func suitDescription(for suit: String) -> String {
        switch suit {
            case "♠": return "Spades"
            case "♣": return "Clubs"
            case "♦": return "Diamonds"
            case "♥": return "Hearts"
            default: return "Unknown suit"
        }
    }
}

struct BlackjackCardView_Previews: PreviewProvider {
    
    static var previews: some View {
        BlackjackCardView(card: Card.example)
    }
}
