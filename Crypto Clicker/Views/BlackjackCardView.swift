//
//  BlackjackCardView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import SwiftUI

struct BlackjackCardView: View {
    let card: Card

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(radius: 3)
                .frame(width: 80, height: 120)
            
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

struct BlackjackCardView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackCardView(card: Card.example)
    }
}
