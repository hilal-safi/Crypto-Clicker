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
    @StateObject private var tetrisModel: TetrisModel

    @State private var errorWrapper: ErrorWrapper?
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Create local instances first (no references to `self`)
        let st = CryptoStore()
        let ex = CoinExchangeModel.shared
        ex.configureStore(st) // Configure the store for CoinExchangeModel
        let set = SettingsModel()
        let am = AchievementsModel.shared
        am.configureDependencies(exchangeModel: ex, powerUps: st.powerUps, store: st)
        let bm = BlackjackModel(exchangeModel: ex, cryptoStore: st)
        let tm = TetrisModel(cryptoStore: st)
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
        _tetrisModel = StateObject(wrappedValue: tm)
    }
    
    var body: some Scene {
        
        WindowGroup {
            
            ContentView(coins: $store.coins, store: store, powerUps: store.powerUps, saveAction: {
                    Task {
                        do {
                            await store.saveCoins()
                            await store.savePowerUps()
                            await store.saveStats()
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
            .environmentObject(tetrisModel)
            .environmentObject(PowerUps.shared)

            .task {
                do {
                    await store.loadCoins()
                    await store.loadPowerUps()
                    await store.loadStats()
                } catch {
                    errorWrapper = ErrorWrapper(error: error, guidance: "Crypto Clicker will load sample data and continue.")
                }
            }
            
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    // Each time the phone app becomes active, we request fresh steps
                    PhoneSessionManager.shared.requestWatchFetchStepsNow()
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
