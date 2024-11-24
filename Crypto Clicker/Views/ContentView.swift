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
    @ObservedObject var store: CryptoStore
    @ObservedObject var powerUps: PowerUps
    let colorScheme: ColorScheme
    @ObservedObject var settings: SettingsModel
    let saveAction: () -> Void
    
    @State private var isShopPresented = false  // State to control ShopView presentation

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                // Background view now automatically uses the environment's color scheme
                BackgroundView()

                VStack {
                    Spacer()
                    
                    // Display the coin's current value
                    Text("Coin Value: \(coins?.value ?? 0)")
                        .font(.system(size: 38, weight: .bold, design: .default))
                        .padding()
                    
                    Text("Coins / Sec: \(store.coinsPerSecond)")
                        .font(.system(size: 24, design: .default))


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
                    
                    Spacer()
                    
                    // Power button to display power-ups owned
                    PowerButtonView(store: store, coins: $coins)

                    Spacer()
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
        let settings = SettingsModel()
        store.coins = CryptoCoin(value: 5)
        
        return ContentView(
            coins: .constant(store.coins),
            store: store,
            powerUps: powerUps,
            colorScheme: .light,
            settings: settings,
            saveAction: {
                store.incrementCoinValue()
            }
        )
        .previewLayout(.sizeThatFits)
    }
}
