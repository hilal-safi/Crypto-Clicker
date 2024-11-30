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
    @Environment(\.colorScheme) var colorScheme // Use environment color scheme

    @ObservedObject var store: CryptoStore
    @ObservedObject var powerUps: PowerUps
    @ObservedObject var exchangeModel: CoinExchangeModel
    @StateObject private var settings = SettingsModel() // Use local state object for settings

    @State private var isInfoPresented = false // State to control Info sheet presentation
    @State private var isAchievementsPresented = false // State to control AchievementsView

    let saveAction: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Background view
                BackgroundView(type: .default)

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
                        // Display the coin's current value with dynamic layout
                        if let coinValue = coins?.value, coinValue >= 100000 {
                            VStack(spacing: 4) { // Coin value on a new line for large numbers
                                Text("Coin Value")
                                    .font(.system(size: 38, weight: .bold, design: .default))
                                Text("\(coinValue)")
                                    .font(.system(size: 32, weight: .medium))
                            }
                        } else {
                            Text("Coin Value: \(coins?.value ?? 0)")
                                .font(.system(size: 38, weight: .bold, design: .default))
                                .padding(.bottom, 4) // Adjust padding for small values
                        }

                        Text("Coins / Sec: \(store.coinsPerSecond)")
                            .font(.system(size: 24, design: .default))
                            .padding(.top, 4)
                        
                        Text("Coins / Click: \(store.coinsPerClick)")
                            .font(.system(size: 24, design: .default))
                            .padding(.top, 4)

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
            }
        }
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
        store.coins = CryptoCoin(value: 5)

        return ContentView(
            coins: .constant(store.coins),
            store: store,
            powerUps: powerUps,
            exchangeModel: exchangeModel,
            saveAction: {
                store.incrementCoinValue()
            }
        )
        .previewLayout(.sizeThatFits)
    }
}
