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
            
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    Color(
                        colorScheme == .dark
                            ? Color(red: 0.5, green: 0.5, blue: 0.5) // Darker grey for dark mode
                            : Color(red: 1, green: 1, blue: 1) // Lighter grey for light mode
                    )
                )
                .shadow(radius: 3)
                .frame(width: 80, height: 120)
            
            if card.value == 0 {
                // Placeholder for the back of the card
                Image("Coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)

            } else {

                VStack {
                    
                    Text(card.displayValue)
                        .font(.title)
                        .bold()
                        .foregroundColor(card.suit == "♠" || card.suit == "♣" ? .black : .red)
                    
                    Text(card.suit)
                        .font(.largeTitle)
                        .foregroundColor(card.suit == "♠" || card.suit == "♣" ? .black : .red)
                }
            }
        }
    }
}

struct BlackjackCardView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackCardView(card: Card.example)
    }
}
