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
    @EnvironmentObject var powerUps: PowerUps // Ensure PowerUps is observed globally

    var body: some View {
        
        NavigationLink(destination: ShopView(store: store, coins: $coins)) {
            
            ZStack {
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(height: 100)
                    .accessibilityHidden(true) // Hide background from VoiceOver

                PowerUpScrollView(store: store)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Power-ups list") // VoiceOver for power-ups
            }
            
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 1)
            )
            
            .onAppear {
                store.recalculateCoinsPerSecond()
                store.recalculateCoinsPerClick()
            }
        }
        .accessibilityLabel("Open Power-ups Shop") // VoiceOver label
        .accessibilityHint("Tap to purchase and upgrade power-ups") // VoiceOver hint
    }
}

struct PowerButtonView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let store = CryptoStore()
        let coins = CryptoCoin(value: Decimal(1000))
        return NavigationView {
            PowerButtonView(store: store, coins: .constant(coins))
                .environmentObject(PowerUps.shared) // Ensure global injection
        }
    }
}
