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
            
            ZStack {
                // Static button background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(height: 100) // Fixed height for the button

                // Horizontal scrolling content
                ScrollView(.horizontal, showsIndicators: false) {
                    
                    HStack(spacing: 20) {
                        
                        ForEach(PowerUps.powerUps, id: \.name) { powerUp in
                            
                            VStack {
                                Text(powerUp.emoji)
                                    .font(.system(size: 42)) // Icon size remains the same
                                Text("\(store.powerUps.quantity(for: powerUp.name))")
                                    .font(.system(size: 24, weight: .semibold)) // Quantity font remains the same
                            }
                        }
                    }
                    .padding(.horizontal) // Add padding inside the scroll view
                }
                .frame(height: 100) // Match the height of the button background
                .clipShape(RoundedRectangle(cornerRadius: 12)) // Ensure scrolling content respects the button shape
            }
            .frame(width: UIScreen.main.bounds.width * 0.8, height: 100) // Button dimensions remain constant
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
