//
//  ContentView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI

struct ContentView: View {
    
    @Binding var coins: CryptoCoin?
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var settings: SettingsModel // Use EnvironmentObject for shared settings

    @ObservedObject var store: CryptoStore
    @ObservedObject var powerUps: PowerUps
    @ObservedObject var exchangeModel: CoinExchangeModel

    @State private var isInfoPresented = false // State to control Info sheet presentation
    @State private var isAchievementsPresented = false // State to control AchievementsView
    @State private var showStatsPopup = false // State to control stats popup visibility

    let saveAction: () -> Void

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                // Background view
                BackgroundView(type: .default)
                    .blur(radius: showStatsPopup ? 8 : 0) // Add blur when popup is open
                    .animation(.easeInOut, value: showStatsPopup) // Smooth transition

                VStack(spacing: 12) { // Reduced spacing between elements
                    Spacer(minLength: 10)

                    if coins == nil {
                        // Show Start Button if coin is not initialized
                        Button(action: {
                            coins = CryptoCoin(value: 0) // Initialize the coin
                        }) {
                            Text("Start Game")
                                .font(.title2)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        // Show message if coin value is 0
                        if coins?.value == 0 {
                            VStack(spacing: 15) {
                                Text("Coin Value: 0")
                                    .font(.title2) // Larger font for emphasis
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)

                                Text("Click the coin below to mine it and increase the value!")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 20)
                        } else {
                            // Coin Value as an invisible button to show popup
                            Button(action: {
                                showStatsPopup = true
                            }) {
                                if let coinValue = coins?.value {
                                    Text("\(coinValue)")
                                        .font(.system(size: 38, weight: .bold))
                                        .padding(.bottom, 4)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        // CoinView handles the increment action
                        CoinView(
                            coinValue: Binding(
                                get: { coins?.value ?? 0 },
                                set: { newValue in coins?.value = newValue }
                            ),
                            settings: settings
                        ) {
                            store.incrementCoinValue()
                        }

                        Spacer(minLength: 10)

                        // Power button to display power-ups owned
                        PowerButtonView(store: store, coins: $coins)
                            .frame(width: UIScreen.main.bounds.width * 0.95) // Set to 95% of screen width
                        
                        // Exchange button to display Bronze, Silver, Gold coins
                        ExchangeButtonView(exchangeModel: exchangeModel, coins: $coins)
                        
                        Spacer()
                    }

                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingsView(
                            coins: $coins,
                            store: store,
                            settings: settings
                        )) {
                            Image(systemName: "gearshape.fill")
                                .imageScale(.large)
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            isInfoPresented = true
                        }) {
                            Image(systemName: "info.circle")
                                .imageScale(.large)
                        }
                        .sheet(isPresented: $isInfoPresented) {
                            InfoView() // Reference to the external InfoView file
                        }
                    }
                    ToolbarItem(placement: .principal) { // Add Trophy Icon in the center
                        Button(action: {
                            isAchievementsPresented = true
                        }) {
                            Image(systemName: "trophy.fill")
                                .imageScale(.large)
                                .foregroundColor(.yellow)
                        }
                        .sheet(isPresented: $isAchievementsPresented) {
                            AchievementsView() // Present AchievementsView
                        }
                    }
                }
                
                // Popup overlay for coin stats
                if showStatsPopup {
                    CoinStatsPopupView(
                        coinsPerSecond: store.coinsPerSecond,
                        coinsPerClick: store.coinsPerClick,
                        totalCoins: coins?.value ?? 0,
                        onClose: {
                            showStatsPopup = false
                        }
                    )
                }
            }
        }
        .preferredColorScheme(settings.appearanceMode.colorScheme) // Dynamically apply appearance mode
        .onChange(of: scenePhase) {
            if scenePhase == .inactive {
                saveAction()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        
        let store = CryptoStore()
        let powerUps = PowerUps()
        let exchangeModel = CoinExchangeModel()
        store.coins = CryptoCoin(value: 100)

        return ContentView(
            coins: .constant(store.coins),
            store: store,
            powerUps: powerUps,
            exchangeModel: exchangeModel,
            saveAction: {
                store.incrementCoinValue()
            }
        )
        .environmentObject(SettingsModel()) // Inject the shared SettingsModel
        .previewLayout(.sizeThatFits)
    }
}
