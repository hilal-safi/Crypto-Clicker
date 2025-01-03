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
    @EnvironmentObject var powerUps: PowerUps

    init(store: CryptoStore, coins: Binding<CryptoCoin?>) {
        _store = ObservedObject(wrappedValue: store)
        _coins = coins
        _model = StateObject(wrappedValue: ShopModel(store: store))
    }

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                BackgroundView(type: .store)

                VStack(spacing: 12) {
                    
                    // Purchase Message Bar
                    ShopMessageView(coins: $coins)
                        .environmentObject(model)
                        .padding(.horizontal, 8)
                        .padding(.top, -10)

                    // List of Power-Ups
                    ScrollView {
                        
                        LazyVStack(spacing: 20) {
                            
                            Spacer().frame(height: 2)
                            
                            ForEach(PowerUps.availablePowerUps, id: \.name) { powerUp in
                                ShopItemView(powerUp: powerUp, coins: $coins)
                                    .environmentObject(model)
                                    .environmentObject(store)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 20)
            }
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Reset all item quantities (or your entire shop model) each time it appears
                model.clearAllQuantities()
            }
        }
    }
}

struct ShopView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let store = CryptoStore()
        let coins = CryptoCoin(value: Decimal(1000))
        
        return ShopView(store: store, coins: .constant(coins))
            .environmentObject(PowerUps.shared)
    }
}
