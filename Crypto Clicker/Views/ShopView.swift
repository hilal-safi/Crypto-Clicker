//
//  ShopView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI

struct ShopView: View {
    
    @ObservedObject var store: CryptoStore
    @Binding var coins: CryptoCoin?
    @StateObject private var model: ShopModel

    init(store: CryptoStore, coins: Binding<CryptoCoin?>) {
        _store = ObservedObject(wrappedValue: store)
        _coins = coins
        _model = StateObject(wrappedValue: ShopModel(store: store)) // StateObject created here
    }

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                BackgroundView(type: .store)

                VStack(spacing: 16) { // Reduced spacing for a more compact layout
                    
                    // Popup for Purchase Messages
                    ShopPopupView(model: model)

                    // Display Current Coins
                    Text("Coins: \(coins?.value ?? 0)")
                        .font(.headline)
                        .padding(.top)

                    // List of Power-Ups
                    ScrollView {
                        
                        LazyVStack(spacing: 16) { // Reduced spacing between items
                            
                            ForEach(PowerUps.powerUps, id: \.name) { powerUp in
                                ShopItemView(powerUp: powerUp, model: model)
                            }
                        }
                        .padding(.horizontal, 16) // Reduced horizontal padding
                    }
                }
                .padding(.horizontal, 12) // Overall padding for the entire view
            }
            .navigationTitle("Store") // Title is now part of the NavigationStack
            .navigationBarTitleDisplayMode(.inline) // Keeps the title inline for a cleaner look
        }
    }
}

struct ShopView_Previews: PreviewProvider {
    static var previews: some View {
        let store = CryptoStore()
        let coins = CryptoCoin(value: 1000)
        return ShopView(store: store, coins: .constant(coins))
    }
}
