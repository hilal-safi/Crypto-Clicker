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
        
        ZStack {
            // Add a border to the BackgroundView to make the card more dintinct
            BackgroundView(type: .store)
                .overlay(
                    VStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5)) // Grey border
                            .frame(height: 6) // Thin line
                            .ignoresSafeArea(edges: .horizontal) // Ensure it spans the entire width
                        Spacer()
                    }
                )

            VStack(spacing: 20) {
                // Store Title
                Text("Store")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 26)

                // Popup for Purchase Messages
                ShopPopupView(model: model)

                // Display Current Coins
                Text("Coins: \(coins?.value ?? 0)")
                    .font(.headline)
                    .padding(.top, -5)

                // List of Power-Ups
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(PowerUps.powerUps, id: \.name) { powerUp in
                            ShopItemView(powerUp: powerUp, model: model)
                        }
                    }
                    .padding(.horizontal, 24) // Adds padding around the cards
                    .padding(.top, 4) // Ensure the first item is fully visible
                }
            }
            .padding(.horizontal, 16) // Overall padding for the entire view
        }
        //.padding(.bottom, 2) // Reduce the gap at the bottom of the screen
    }
}

struct ShopView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let store = CryptoStore()
        let coins = CryptoCoin(value: 1000)
        return ShopView(store: store, coins: .constant(coins))
    }
}
