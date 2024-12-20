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
                Spacer()
                Text("Gained/Lost: \(playerBalance - initialBalance)")
                    .foregroundColor(playerBalance - initialBalance >= 0 ? .green : .red)
            }
            .font(.subheadline)
            .padding(.horizontal)
            
            Text("Current Balance: \(playerBalance)")
                .font(.headline)
        }
    }
}

struct BlackjackTopView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackTopView(initialBalance: 1000, playerBalance: 900)
    }
}
