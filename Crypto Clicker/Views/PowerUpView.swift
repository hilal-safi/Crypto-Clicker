//
//  PowerUpView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import SwiftUI

struct PowerUpView: View {
    @ObservedObject var store: CryptoStore
    @State private var isShopPresented = false  // Controls ShopView presentation
    @State private var selectedPowerUp: PowerUpInfo? = nil  // Holds the selected power-up for info popup

    var body: some View {
        VStack(spacing: 20) {
            Text("Power-Ups Owned")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                // Chromebook power-up
                powerUpRow(title: "💻 Chromebook", quantity: store.chromebook, description: "Increases coin value by 1 every 10 seconds.")
                
                // Desktop power-up
                powerUpRow(title: "🖥️ Desktop", quantity: store.desktop, description: "Increases coin value by 5 every 5 seconds.")
                
                // Server power-up
                powerUpRow(title: "🖲️ Server", quantity: store.server, description: "Increases coin value by 10 every 3 seconds.")
                
                // Mine Center power-up
                powerUpRow(title: "🏭 Mine Center", quantity: store.mineCenter, description: "Increases coin value by 100 every second.")
            }
            .font(.title2)
            
            // Store Button
            Button(action: {
                isShopPresented = true  // Show ShopView as a nested sheet
            }) {
                Text("Store")
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
            .sheet(isPresented: $isShopPresented) {  // Present ShopView as a sheet
                ShopView(coins: $store.coins, store: store)
            }
            
            Spacer()
        }
        .padding()
        .alert(item: $selectedPowerUp) { powerUp in
            Alert(
                title: Text(powerUp.title),
                message: Text(powerUp.description),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Helper function to define power-up rows with info button
    private func powerUpRow(title: String, quantity: Int, description: String) -> some View {
        HStack {
            Text("\(title):")
            Spacer()
            Text("\(quantity)")
            Button(action: {
                // Set selectedPowerUp with title and description
                selectedPowerUp = PowerUpInfo(title: title, description: description)
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }
}

struct PowerUpView_Previews: PreviewProvider {
    static var previews: some View {
        let store = CryptoStore()
        store.chromebook = 1
        store.desktop = 2
        store.server = 3
        store.mineCenter = 4
        return PowerUpView(store: store)
    }
}
