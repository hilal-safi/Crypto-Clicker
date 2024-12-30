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

                VStack(spacing: 12) { // Reduced spacing for a more compact layout
                    
                    // Fixed MessageView for Purchase Messages
                    ShopMessageView(coins: $coins)
                        .environmentObject(model)
                        .padding(.horizontal, 8)
                        .padding(.top, -10)

                    // List of Power-Ups
                    ScrollView {
                        
                        LazyVStack(spacing: 20) {
                            
                            // Add top padding to prevent shadow cutoff
                            Spacer().frame(height: 2) // Add space above the first item

                            ForEach(PowerUps.availablePowerUps, id: \.name) { powerUp in
                            
                                ShopItemView(powerUp: powerUp, coins: $coins)
                                    .environmentObject(model)
                                    .environmentObject(store)
                            }
                        }
                        .padding(.horizontal, 16) // Reduced horizontal padding
                    }
                }
                .padding(.horizontal, 12) // Overall padding for the entire view
                .padding(.top, 20) // Add extra padding at the top
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
