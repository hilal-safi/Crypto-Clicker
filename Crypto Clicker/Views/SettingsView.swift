//
//  SettingsView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-15.
//

import SwiftUI

struct SettingsView: View {
    @Binding var coins: CryptoCoin? // Receive the coin binding
    @ObservedObject var store: CryptoStore // Receive the store instance
    
    @State private var showResetAlert = false // Control alert state

    var body: some View {
        VStack {

            // Other settings controls (e.g., toggles)
            Toggle("Enable Sounds", isOn: .constant(true))
            Toggle("Enable Notifications", isOn: .constant(false))

            Spacer()

            // Reset coins button
            Button(action: {
                showResetAlert = true // Trigger the alert when the button is pressed
            }) {
                Text("Reset Coins")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
            }
            .alert("Are you sure?", isPresented: $showResetAlert) {
                
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    store.resetCoinValue() // Call the reset function from CryptoStore
                    coins?.value = 0 // Reset the amount in the coins Binding
                }
            } message: {
                Text("This will reset your coin value to 0.")
            }

            Spacer()
        }
        .padding()
        .navigationBarTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(coins: .constant(CryptoCoin(value: 10)), store: CryptoStore()) // Example preview
    }
}
