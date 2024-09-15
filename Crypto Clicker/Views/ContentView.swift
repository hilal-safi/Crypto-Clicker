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
    @State private var settings = false
    @ObservedObject var store: CryptoStore
    
    let saveAction: () -> Void
    
    var body: some View {
        
        NavigationStack {
            
            VStack {
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
                            .frame(width: 200, height: 200)
                            .padding()
                    }
                    
                    // Display the coin value
                    Text("Coin Value: \(coins?.value ?? 0)")
                        .font(.largeTitle)
                        .padding()
                    
                    Button(action: {
                        settings.toggle()
                    }) {
                        Text("Settings")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Crypto Clicker") // Set title on the left
        }
        .sheet(isPresented: $settings) {
            VStack {
                
                Text("Settings")
                    .font(.title)
                    .padding()
                
                Spacer()
                
                Button(action: {
                    store.resetCoinValue()
                }) {
                    Text("Reset Coins")
                        .font(.headline)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.bottom)

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
        return ContentView(coins: .constant(store.coins), store: store, saveAction: {// Simulate an action
            store.incrementCoinValue() // Increment the value})
        })
        .previewLayout(.sizeThatFits) // Optional: set the preview layout
    }
}
