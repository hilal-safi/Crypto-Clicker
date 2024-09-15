//
//  Crypto_ClickerApp.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI

@main

struct Crypto_ClickerApp: App {
    
    @StateObject private var store = CryptoStore()
    @State private var errorWrapper: ErrorWrapper?
    
    var body: some Scene {
        
        WindowGroup {
            
            ContentView(coins: $store.coins, store: store) {
                
                Task {
                    do {
                        try await store.save(coins: store.coins)
                    } catch {
                        errorWrapper = ErrorWrapper(error: error,
                                                    guidance: "Try again later.")
                    }
                }
            }
            .task {
                do {
                    try await store.load()
                } catch {
                    errorWrapper = ErrorWrapper(error: error,
                                                guidance: "Crypto Clicker will load sample data and continue.")
                }
            }
            .sheet(item: $errorWrapper) {
                
                store.coins = CryptoCoin.sampleData
                
            } content: { wrapper in
                    
                ErrorView(errorWrapper: wrapper)
            }
        }
    }
}
