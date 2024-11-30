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
    @StateObject private var exchangeModel = CoinExchangeModel()  // Add CoinExchangeModel
    @State private var errorWrapper: ErrorWrapper?
    @StateObject private var settings = SettingsModel() // Shared settings
    
    var body: some Scene {
        
        WindowGroup {
    
            ContentView(
                
                coins: $store.coins,
                store: store,
                powerUps: store.powerUps, // Access power-ups directly from the store
                exchangeModel: exchangeModel, // Pass exchangeModel
                
                saveAction: {
                    Task {
                        do {
                            await store.saveCoins()
                            await store.savePowerUps() // Save power-ups
                            
                        } catch {
                            errorWrapper = ErrorWrapper(error: error, guidance: "Try again later.")
                        }
                    }
                }
            )
            .environmentObject(settings) // Provide settings to all views

            .task {
                do {
                    await store.loadCoins()
                    await store.loadPowerUps() // Load power-ups
                    
                } catch {
                    errorWrapper = ErrorWrapper(error: error, guidance: "Crypto Clicker will load sample data and continue.")
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
