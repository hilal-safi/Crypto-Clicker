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
    @ObservedObject var powerUps: PowerUps
    @EnvironmentObject var coinExchange: CoinExchangeModel
    @EnvironmentObject var achievements: AchievementsModel
    @StateObject private var miniGames = MiniGamesModel()

    @ObservedObject var settings: SettingsModel
    
    @State private var showResetAlert = false
    @State private var resetType: SettingsModel.ResetType?
    @State private var refreshID = UUID() // Unique ID to refresh the view
    
    var body: some View {
        
        ZStack {
            
            BackgroundView(type: .settings)
            
            ScrollView {
                
                VStack(spacing: 16) {
                    
                    settingsSection(title: "Haptics", icon: "hand.tap.fill") {
                        
                        Toggle(isOn: $settings.enableHaptics) {
                            Text("Enable Haptics")
                        }
                    }
                    
                    settingsSection(title: "Sounds", icon: "speaker.wave.2") {
                        
                        Toggle(isOn: $settings.enableSounds) {
                            Text("Enable Sounds")
                        }
                    }
                    
                    settingsSection(title: "Appearance", icon: "paintpalette.fill") {
                        
                        Picker("Appearance Mode", selection: $settings.appearanceMode) {
                            ForEach(SettingsModel.AppearanceMode.allCases) { mode in
                                Text(mode.rawValue.capitalized).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    settingsSection(title: "Difficulty", icon: "tortoise.fill") {
                        
                        Picker("Difficulty", selection: $settings.difficulty) {
                            ForEach(SettingsModel.Difficulty.allCases) { difficulty in
                                Text(difficulty.rawValue.capitalized).tag(difficulty)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: settings.difficulty) {
                            store.recalculateCoinsPerSecond()
                            store.recalculateCoinsPerClick()
                        }
                    }
                    
                    settingsSection(title: "Reset Options", icon: "trash.fill") {
                        
                        ForEach(SettingsModel.ResetType.allCases, id: \.self) { resetType in
                            
                            Button(action: {
                                self.resetType = resetType
                                showResetAlert = true
                            }) {
                                Text(resetType.buttonLabel)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        BlurView(style: .systemMaterial)
                                            .cornerRadius(10)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.red, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Settings")
            .alert("Reset Confirmation", isPresented: $showResetAlert) {
                
                Button("Reset", role: .destructive) {
                    
                    if let resetType = resetType {
                        
                        settings.handleReset(
                            type: resetType,
                            store: store,
                            powerUps: powerUps,
                            coinExchange: coinExchange,
                            achievements: achievements,
                            miniGames: miniGames
                        )
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(resetType?.description ?? "")
            }
        }
    }

    private func settingsSection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            content()
        }
        .padding()
        .background(
            BlurView(style: .systemMaterial)
                .cornerRadius(12)
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let ExchangeModel = CoinExchangeModel.shared
        let PowerUps = PowerUps.shared
        let Store = CryptoStore()
        let Settings = SettingsModel()
        let AchievementsModel = AchievementsModel.shared

        SettingsView(
            coins: .constant(CryptoCoin(value: Decimal(10))),
            store: Store,
            powerUps: PowerUps,
            settings: Settings
        )
        .environmentObject(ExchangeModel)
        .environmentObject(AchievementsModel)
    }
}
