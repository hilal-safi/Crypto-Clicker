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
    @Environment(\.colorScheme) var colorScheme // Detect light or dark mode
    @State private var showResetAlert = false // State variable to control the alert
    @ObservedObject var store: CryptoStore
    
    let saveAction: () -> Void
    
    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                // Add your background image with 50% transparency
                Image("Background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.25) // Set the transparency to 50%

                
                // Apply a white tint in light mode, and a dark tint in dark mode
                Color(colorScheme == .dark ? .black : .white)
                    .opacity(0.45) // Adjust the opacity to make the tint subtle
                    .ignoresSafeArea()

                
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
                        // Large Coin Icon as a Button
                        Button(action: {
                            // Increment the coin value
                            store.incrementCoinValue()
                        }) {
                            Image("bitcoin") // Your coin image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 250, height: 250)
                                .padding()
                        }
                        .sensoryFeedback(.increase, trigger: store.coins?.value)
                        
                        // Display the coin value
                        Text("Coin Value: \(coins?.value ?? 0)")
                            .font(.system(size: 38, weight: .bold, design: .default))
                            .padding()
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
                .navigationBarItems(trailing:
                                        NavigationLink(destination: SettingsView(coins: $coins, store: store)) {
                    Image(systemName: "gearshape.fill")
                        .imageScale(.large)
                        .padding()
                }
                )
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
        
        store.coins = CryptoCoin(value: 5) // Set an initial coin value for the preview
        return ContentView(coins: .constant(store.coins), store: store, saveAction: {
            store.incrementCoinValue() // Simulate an action
        })
        .previewLayout(.sizeThatFits) // Optional: set the preview layout
    }
}
