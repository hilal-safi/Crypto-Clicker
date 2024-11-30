//
//  PowerButtonView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import SwiftUI

struct PowerButtonView: View {
    @ObservedObject var store: CryptoStore
    @Binding var coins: CryptoCoin?

    var body: some View {
        
        NavigationLink(destination: ShopView(store: store, coins: $coins)) {
            
            HStack(spacing: 20) {
                
                ForEach(PowerUps.powerUps, id: \.name) { powerUp in
                    
                    VStack {
                        Text(powerUp.emoji)
                            .font(.system(size: 42)) // Increased icon size
                        Text("\(store.powerUps.quantity(for: powerUp.name))")
                            .font(.system(size: 24, weight: .semibold)) // Slightly larger quantity font
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1)) // Light blue background tint
            .cornerRadius(12) // Rounded corners
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 1) // Outline for the button
            )
        }
    }
}

struct PowerButtonView_Previews: PreviewProvider {
    static var previews: some View {
        let store = CryptoStore()
        let coins = CryptoCoin(value: 1000)
        return NavigationView {
            PowerButtonView(store: store, coins: .constant(coins))
        }
    }
}
