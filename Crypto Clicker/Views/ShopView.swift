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
    
    // MARK: - Subviews
    
    /// The purchase message bar view.
    private var purchaseMessageBar: some View {
        
        ShopMessageView(coins: $coins)
            .environmentObject(model)
            .padding(.horizontal, 8)
            .padding(.top, -10)
            .accessibilityLabel("Purchase Message Bar")
    }
    
    /// The scrollable list of power-ups.
    private var powerUpsList: some View {
        
        ScrollView {
            
            LazyVStack(spacing: 20) {
                
                Spacer().frame(height: 2)
                
                // Error handling: Ensure power-ups exist before looping
                if PowerUps.availablePowerUps.isEmpty {
                    
                    Text("No power-ups available")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                        .accessibilityLabel("No power-ups available in the store")
                    
                } else {
                    
                    ForEach(PowerUps.availablePowerUps, id: \.name) { powerUp in
                        
                        ShopItemView(powerUp: powerUp, coins: $coins)
                            .environmentObject(model)
                            .environmentObject(store)
                            .accessibilityLabel("\(powerUp.name), cost: \(Decimal(powerUp.cost).formattedCoinValue()) coins")
                    }
                }
            }
            .padding(.horizontal, 12)
            .animation(.easeInOut(duration: 0.3), value: PowerUps.availablePowerUps.count)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                BackgroundView(type: .store)
                VStack(spacing: 12) {
                    purchaseMessageBar
                    powerUpsList
                }
                .padding(.horizontal, 10)
                .padding(.top, 20)
            }
            
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.inline)
            
            .onAppear {
                // Ensure reset is only called when needed
                if !model.selectedQuantities.isEmpty {
                    model.clearAllQuantities()
                }
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
