//
//  HomeView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import SwiftUI

struct HomeView: View {
    
    @Binding var coins: CryptoCoin?
    var store: CryptoStore
    @ObservedObject var powerUps: PowerUps
    var saveAction: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var settings = SettingsModel()

    var body: some View {
        
        NavigationView {
            ZStack {
                // Background view
                BackgroundView(type: .default)
                
                VStack {
                    
                    Spacer()
                    Text("Welcome to Crypto Clicker!")
                        .font(.largeTitle)
                        .padding()
                    
                    // Check if the coin has been initialized, otherwise show the Start button
                    if coins == nil {
                        
                        Button(action: {
                            // Initialize the coin with a starting value if not set
                            coins = CryptoCoin(value: 10)
                        }) {
                            Text("Start Game")
                                .font(.title2)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        
                        NavigationLink(destination: ContentView(
                            coins: $coins,
                            store: store,
                            powerUps: powerUps,
                            colorScheme: colorScheme,
                            settings: settings,
                            saveAction: saveAction
                        )) {
                            Text("Play Game")
                                .font(.title2)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            
            .navigationTitle("Home")
            
            .navigationBarItems(trailing:
                NavigationLink(destination: SettingsView(
                    coins: $coins,
                    store: store,
                    settings: settings
                )) {
                    Image(systemName: "gearshape.fill")
                        .imageScale(.large)
                        .padding()
                }
            )
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let store = CryptoStore()
        let powerUps = PowerUps() // Updated reference
        
        HomeView(
            coins: .constant(nil),
            store: store,
            powerUps: powerUps,
            saveAction: {}
        )
    }
}
