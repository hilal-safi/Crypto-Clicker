//
//  Crypto_ClickerApp.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI

@main
struct Crypto_ClickerApp: App {
    
    // Declare your @StateObject properties, but don’t initialize them inline
    @StateObject private var store: CryptoStore
    @StateObject private var exchangeModel: CoinExchangeModel
    @StateObject private var settings: SettingsModel
    @StateObject private var achievements: AchievementsModel
    @StateObject private var blackjackModel: BlackjackModel

    @State private var errorWrapper: ErrorWrapper?
    
    init() {
        // Create local instances first (no references to `self`)
        let st = CryptoStore()
        let ex = CoinExchangeModel.shared
        let set = SettingsModel()
        let am = AchievementsModel.shared
        am.configureDependencies(exchangeModel: ex, powerUps: st.powerUps)
        let bm = BlackjackModel(exchangeModel: ex)
        st.configureSettings(set)
        ex.settings = set
        
        // Start the phone session manager
        PhoneSessionManager.shared.startSession(with: st)
        
        // Wrap each local instance in a StateObject
        _store = StateObject(wrappedValue: st)
        _exchangeModel = StateObject(wrappedValue: ex)
        _settings = StateObject(wrappedValue: set)
        _achievements = StateObject(wrappedValue: am)
        _blackjackModel = StateObject(wrappedValue: bm)
    }
    
    var body: some Scene {
        
        WindowGroup {
            
            ContentView(
                coins: $store.coins,
                store: store,
                powerUps: store.powerUps,
                saveAction: {
                    Task {
                        do {
                            await store.saveCoins()
                            await store.savePowerUps()
                        } catch {
                            errorWrapper = ErrorWrapper(error: error, guidance: "Try again later.")
                        }
                    }
                }
            )
            .environmentObject(settings)
            .environmentObject(exchangeModel)
            .environmentObject(achievements)
            .environmentObject(blackjackModel)
            .environmentObject(PowerUps.shared) 

            .task {
                do {
                    await store.loadCoins()
                    await store.loadPowerUps()
                } catch {
                    errorWrapper = ErrorWrapper(error: error, guidance: "Crypto Clicker will load sample data and continue.")
                }
            }
            .sheet(item: $errorWrapper) {
                // Fallback data
                store.coins = CryptoCoin.sampleData
            } content: { wrapper in
                ErrorView(errorWrapper: wrapper)
            }
        }
    }
}
