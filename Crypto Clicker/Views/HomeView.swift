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
    var saveAction: () -> Void
    
    @Environment(\.colorScheme) var colorScheme // Detect light or dark mode
    @State private var showResetAlert = false // State variable to control the alert


    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to Crypto Clicker!")
                    .font(.largeTitle)
                    .padding()

                // Button to navigate to ContentView
                NavigationLink(destination: ContentView(coins: $coins, store: store, saveAction: saveAction)) {
                    Text("Start Game")
                        .font(.title2)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Home")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(coins: .constant(CryptoCoin.sampleData), store: CryptoStore(), saveAction: {})
    }
}
