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
    
    @ObservedObject var settings: SettingsModel
    
    @State private var showResetAlert = false
    @State private var resetType: ResetType? = nil // Track the type of reset action
    @State private var refreshID = UUID() // Unique ID to refresh the view

    var body: some View {
        
        ZStack {
            
            BackgroundView(type: .settings)
            
            VStack {
                
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
                
                // Appearance Mode Setting
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "moon.circle")
                        Text("Appearance Mode")
                            .font(.headline)
                    }
                    
                    Picker("Appearance Mode", selection: $settings.appearanceMode) {
                        ForEach(SettingsModel.AppearanceMode.allCases) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: settings.appearanceMode) {
                        refreshID = UUID() // Trigger a view refresh when appearanceMode changes
                    }
                }
                .padding()
                Divider()
                
                // Reset Buttons
                createResetButton(text: "Reset Coins", resetType: .coins, description: "This will reset your coin value to 0.")
                createResetButton(text: "Remove PowerUps", resetType: .powerUps, description: "This will remove all your powerups.")
                createResetButton(text: "Remove Exchanged Coins", resetType: .exchangedCoins, description: "This will reset all exchanged coins and remove ownership of any traded values.")
                createResetButton(text: "Reset Achievements", resetType: .achievements, description: "This will reset all your achievements.")
                createResetButton(text: "Remove All", resetType: .all, description: "This will reset all coins, power-ups, exchanged coins, and achievements.")

                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
        }
        .id(refreshID) // Force view to refresh by changing the ID
        .alert("Are you sure?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                handleReset()
            }
        } message: {
            Text(resetType?.description ?? "")
        }
    }
    
    private func createResetButton(text: String, resetType: ResetType, description: String) -> some View {
        
        Button(action: {
            self.resetType = resetType
            self.showResetAlert = true
        }) {
            Text(text)
                .foregroundColor(.red)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
        }
    }

    private func handleReset() {
        guard let resetType = resetType else { return }

        switch resetType {
        case .coins:
            store.resetCoinValue()
            coins?.value = 0
            achievements.refreshProgress(coins: coins, coinsPerSecond: store.coinsPerSecond, coinsPerClick: store.coinsPerClick)

        case .powerUps:
            debugPowerUps()
            store.resetPowerUps()
            debugPowerUps()
            achievements.refreshProgress(coins: coins, coinsPerSecond: store.coinsPerSecond, coinsPerClick: store.coinsPerClick)

        case .exchangedCoins:
            debugExchangedCoins()
            coinExchange.resetExchangedCoins()
            debugExchangedCoins()
            achievements.refreshProgress(coins: coins, coinsPerSecond: store.coinsPerSecond, coinsPerClick: store.coinsPerClick)

        case .achievements:
            achievements.resetAchievements()

        case .all:
            // Reset everything
            store.resetCoinValue()
            coins?.value = 0
            store.resetPowerUps()
            coinExchange.resetExchangedCoins()
            achievements.resetAchievements()
            debugPowerUps()
            debugExchangedCoins()
        }
    }

    // Debug function for power-ups
    private func debugPowerUps() {
        print("[DEBUG] Power-Ups Quantities IN SETTINGS:")
        for powerUp in PowerUps.availablePowerUps {
            let ownedCount = powerUps.getOwnedCount(for: powerUp.name)
            print("  - \(powerUp.name): \(ownedCount)")
        }
    }

    // Debug function for exchanged coins
    private func debugExchangedCoins() {
        print("[DEBUG] Exchanged Coins Quantities IN SETTINGS:")
        for coin in coinExchange.availableCoins {
            let exchangedCount = coinExchange.getExchangedCount(for: coin.type)
            print("  - \(coin.label): \(exchangedCount)")
        }
    }}

enum ResetType {
    
    case coins, powerUps, exchangedCoins, achievements, all
    
    var description: String {
        
        switch self {
            
        case .coins: 
            return "This will reset your coin value to 0."
            
        case .powerUps:
            return "This will remove all your powerups."
            
        case .exchangedCoins:
            return "This will reset all exchanged coins and remove ownership of any traded values."
            
        case .achievements:
            return "This will reset all your achievements."
            
        case .all:
            return "This will reset all coins, power-ups, exchanged coins, and achievements."
        }
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
            coins: .constant(CryptoCoin(value: 10)),
            store: Store,
            powerUps: PowerUps,
            settings: Settings
        )
        .environmentObject(ExchangeModel)
        .environmentObject(AchievementsModel)
    }
}
