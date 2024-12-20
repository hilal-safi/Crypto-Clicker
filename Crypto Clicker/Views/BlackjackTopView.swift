//
//  BlackjackTopView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackTopView: View {
    let initialBalance: Int
    let playerBalance: Int
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Initial: \(initialBalance)")
                    .font(.title3)
                Spacer()
                Text("Gained/Lost: \(playerBalance - initialBalance)")
                    .font(.title3)
                    .foregroundColor(playerBalance - initialBalance >= 0 ? .green : .red)
            }
            .font(.subheadline)
            .padding(.horizontal)
            
            Text("Current Balance: \(playerBalance)")
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding(.top)
    }
}

struct BlackjackTopView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackTopView(initialBalance: 1000, playerBalance: 900)
    }
}
