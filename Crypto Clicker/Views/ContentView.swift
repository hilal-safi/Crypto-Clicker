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
    @EnvironmentObject var settings: SettingsModel

    @ObservedObject var store: CryptoStore
    @ObservedObject var powerUps: PowerUps
    @ObservedObject var exchangeModel: CoinExchangeModel

    @State private var isInfoPresented = false
    @State private var selectedTab: Tab = .content // Default to the game tab
    @State private var showStatsPopup = false // State for the stats popup

    let saveAction: () -> Void
    
    enum Tab {
        case achievements, content, minigames
    }

    var body: some View {
        
        ZStack {

            NavigationStack {
                
                VStack {
                    
                    TabView(selection: $selectedTab) {
                        // Achievements Tab
                        AchievementsView (
                            coins: $coins,
                            coinsPerSecond: store.coinsPerSecond, // Pass coinsPerSecond
                            coinsPerClick: store.coinsPerClick    // Pass coinsPerClick
                        )
                        .tabItem {
                            VStack {
                                Image(systemName: "trophy.fill")
                                Text("Achievements")
                            }
                        }
                        .tag(Tab.achievements)

                        // Main Game Tab
                        gameContentView
                            .tabItem {
                                
                                VStack {
                                    Image(systemName: "bitcoinsign.circle.fill")
                                }
                            }
                            .tag(Tab.content)

                        // Mini Games Tab
                        MiniGamesView(exchangeModel: exchangeModel)
                            .tabItem {
                                
                                VStack {
                                    Image(systemName: "gamecontroller.fill")
                                    Text("Mini Games")
                                }
                            }
                            .tag(Tab.minigames)
                    }
                    .background(Color.clear) // Ensure TabView background doesn't override the ZStack
                }
                .toolbar {
                    // Top navigation bar buttons
                    ToolbarItem(placement: .navigationBarTrailing) {
                        
                        NavigationLink(destination: SettingsView(coins: $coins, store: store, settings: settings)) {
                            Image(systemName: "gearshape.fill")
                                .imageScale(.large)
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        
                        Button(action: {
                            isInfoPresented = true
                        }) {
                            Image(systemName: "info.circle")
                                .imageScale(.large)
                        }
                        .sheet(isPresented: $isInfoPresented) {
                            InfoView()
                        }
                    }
                }
            }
        }
        .preferredColorScheme(settings.appearanceMode.colorScheme) // Dynamically apply appearance mode
        .onChange(of: scenePhase) {
            if scenePhase == .inactive {
                saveAction()
            }
        }
    }
    
    // Extracted game content view for readability
    private var gameContentView: some View {
        
        ZStack {
            // Background view always visible
            BackgroundView(type: .default)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                
                if coins == nil {
                    // Show Start Button if coin is not initialized
                    Button(action: {
                        coins = CryptoCoin(value: 0)
                    }) {
                        Text("Start Game")
                            .font(.title2)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                } else {
                    // Game content
                    CoinNumberView (
                        
                        coinValue: Binding(
                            get: { coins?.value ?? 0 },
                            set: { coins?.value = $0 }
                        ),
                        showStatsPopup: $showStatsPopup // Pass the binding for the popup
                    )
                    
                    CoinView(
                        coinValue: Binding(
                            get: { coins?.value ?? 0 },
                            set: { coins?.value = $0 }
                        ),
                        settings: settings
                    ) {
                        store.incrementCoinValue()
                    }
                    
                    PowerButtonView(store: store, coins: $coins)
                        .frame(width: UIScreen.main.bounds.width * 0.85)
                    
                    ExchangeButtonView(exchangeModel: exchangeModel, coins: $coins)
                        .frame(width: UIScreen.main.bounds.width * 0.85)
                }
            }
            // Popup overlay for coin stats
            if showStatsPopup {
                
                CoinStatsPopupView(
                    
                    coinsPerSecond: store.coinsPerSecond,
                    coinsPerClick: store.coinsPerClick,
                    totalCoins: coins?.value ?? 0,
                    
                    onClose: {
                        showStatsPopup = false
                    }
                )
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let store = CryptoStore()
        let powerUps = PowerUps()
        let exchangeModel = CoinExchangeModel()
        store.coins = CryptoCoin(value: 100)

        return ContentView (
            
            coins: .constant(store.coins),
            store: store,
            powerUps: powerUps,
            exchangeModel: exchangeModel,
            saveAction: { store.incrementCoinValue() }
        )
        .environmentObject(SettingsModel())
    }
}
