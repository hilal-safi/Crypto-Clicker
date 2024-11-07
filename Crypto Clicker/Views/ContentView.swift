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
    let colorScheme: ColorScheme
    @ObservedObject var settings: SettingsModel // Accept SettingsModel as a parameter
    let saveAction: () -> Void

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                // Use BackgroundView for consistent background
                BackgroundView(colorScheme: colorScheme)

                VStack {
                    
                    Spacer() // Add some space between the title and the buttons
                    
                    // Check if coins is nil and display Start button
                    if coins == nil {
                        Button(action: {
                            // Initialize the coin value
                            store.coins = CryptoCoin(value: 10) // Set your desired initial value here
                        }) {
                            Text("Start")
                                .font(.largeTitle)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else {
                        // Use CoinView when coins is not nil
                        if let _ = coins {
                            CoinView(
                                coinValue: Binding(
                                    get: { coins?.value ?? 0 },
                                    set: { newValue in coins?.value = newValue }
                                ),
                                settings: settings // Pass SettingsModel to CoinView
                            ) {
                                store.incrementCoinValue()
                            }

                            Text("Coin Value: \(coins?.value ?? 0)")
                                .font(.system(size: 38, weight: .bold, design: .default))
                                .padding()
                        }
                    }

                    // Add the Store Button
                    NavigationLink(destination: ShopView()) {
                        Text("Store")
                            .font(.title2)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)


                    Spacer() // Add space at the bottom
                }
                .navigationBarTitle("Crypto Clicker")

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
        let settings = SettingsModel() // Initialize SettingsModel here
        store.coins = CryptoCoin(value: 5)
        
        return ContentView(
            coins: .constant(store.coins),
            store: store,
            colorScheme: .light,
            settings: settings,  // Pass SettingsModel to the preview
            saveAction: {
                store.incrementCoinValue()
            }
        )
        .previewLayout(.sizeThatFits)
    }
}
