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
                        Text("\(quantity(for: powerUp.name))")
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

    private func quantity(for name: String) -> Int {
        switch name {
        case "Chromebook":
            return store.powerUps.chromebook
        case "Desktop":
            return store.powerUps.desktop
        case "Server":
            return store.powerUps.server
        case "Mine Center":
            return store.powerUps.mineCenter
        default:
            return 0
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
