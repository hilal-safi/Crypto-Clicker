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
    
    @ObservedObject var settings: SettingsModel // Observe changes in settings

    
    @State private var showResetAlert = false // Control alert state

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Coin Size")
                    .font(.headline)
                
                Slider(value: $settings.coinSize, in: 1...3, step: 1)
                    .padding(.vertical)
                
                HStack {
                    Text("Small")
                    Spacer()
                    Text("Medium")
                    Spacer()
                    Text("Large")
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            }
            Divider()
            
            Toggle("Enable Sounds", isOn: $settings.enableSounds)
                .padding(.vertical)
            Divider()
            
            Toggle("Enable Haptics", isOn: $settings.enableHaptics)
                .padding(.vertical)
            
            Spacer()
            
            Button(action: {
                showResetAlert = true
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
                    store.resetCoinValue()
                    coins?.value = 0
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
        
        SettingsView(
            coins: .constant(CryptoCoin(value: 10)),
            store: CryptoStore(),
            settings: SettingsModel() // Provide an instance of SettingsModel
        )
    }
}

