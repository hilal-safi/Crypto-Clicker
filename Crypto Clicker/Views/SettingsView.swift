//
//  SettingsView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-15.
//

import SwiftUI

struct SettingsView: View {
    
    @Binding var coins: CryptoCoin?
    @ObservedObject var store: CryptoStore
    @ObservedObject var settings: SettingsModel
    
    @State private var showResetAlert = false
    @State private var selectedAppearanceMode = 0 // 0 = Auto, 1 = Light, 2 = Dark

    var body: some View {
        
        VStack(spacing: 20) {
            
            // Coin Size Setting
            VStack(alignment: .leading) {
                
                HStack {
                    Image(systemName: "bitcoinsign.circle")
                    Text("Coin Size")
                        .font(.headline)
                }
                
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
            .padding()
            Divider()
            
            // Enable Haptics Setting
            Toggle(isOn: $settings.enableHaptics) {
                HStack {
                    Image(systemName: "hand.tap.fill")
                    Text("Enable Haptics")
                        .font(.headline)
                }
            }
            .padding()
            Divider()
            
            // Enable Sounds Setting
            Toggle(isOn: $settings.enableSounds) {
                HStack {
                    Image(systemName: "speaker.wave.2")
                    Text("Enable Sounds")
                        .font(.headline)
                }
            }
            .padding()
            Divider()
            
            // Dark/Light/Auto Mode Setting
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "moon.circle")
                    Text("Appearance Mode")
                        .font(.headline)
                }
                
                Picker("Appearance Mode", selection: $settings.appearanceMode) { // Bind directly to appearanceMode
                    Text("Auto").tag(SettingsModel.AppearanceMode.auto)
                    Text("Light").tag(SettingsModel.AppearanceMode.light)
                    Text("Dark").tag(SettingsModel.AppearanceMode.dark)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding()
            Divider()
            
            // Reset progress button
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

