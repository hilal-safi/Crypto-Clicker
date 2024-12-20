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
        VStack {
            Text("\(card.value)")
            Text(card.suit)
        }
        .frame(width: 50, height: 75)
        .background(Color.white)
        .cornerRadius(5)
        .shadow(radius: 5)
    }
}

struct BlackjackCardView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackCardView(card: Card.example)
    }
}
