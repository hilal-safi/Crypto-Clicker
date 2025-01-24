//
//  ContentView.swift
//  Crypto Clicker Watch App
//
//  Created by Hilal Safi on 2025-01-04.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    
    @ObservedObject var watchManager = WatchSessionManager.shared
    @StateObject var stepDetector = StepDetection() // Keep for step detection
    
    @State private var showStats = false // Controls stats popup

    var body: some View {
        
        VStack(spacing: 8) {
            
            // The coin image as a button
            CoinView(watchManager: watchManager)
                .padding(.top, -15)
            
            // The coin total text
            CoinNumberView(watchManager: watchManager, showStats: $showStats)
        }
        // Show stats in a sheet
        .sheet(isPresented: $showStats) {
            CoinStatsPopupView(
                isPresented: $showStats,
                coinsPerSecond: watchManager.coinsPerSecond,
                coinsPerClick: watchManager.coinsPerClick,
                coinsPerStep: watchManager.coinsPerStep,
                totalCoins: watchManager.coinValue,
                totalPowerUpsOwned: watchManager.totalPowerUpsOwned,
                totalExchangedCoins: watchManager.totalExchangedCoins,
                localSteps: watchManager.localSteps,
                totalCoinsFromSteps: watchManager.totalCoinsFromSteps,
                totalCoinsFromMiniGames: watchManager.totalCoinsFromMiniGames,
                totalCoinsFromClicks: watchManager.totalCoinsFromClicks,
                totalCoinsFromIdle: watchManager.totalCoinsFromIdle,
                totalCoinsEverEarned: watchManager.totalCoinsEverEarned,
                miniGameWinMultiplier: watchManager.miniGameWinMultiplier,
                totalCoinsSpent: watchManager.totalCoinsSpent
            )
        }
        .sheet(item: $stepDetector.errorWrapper) { wrapper in
            // Present the ErrorView when an error occurs
            ErrorView(errorWrapper: wrapper)
        }
        .onAppear {
            watchManager.startSession()
            watchManager.requestCoinData()
            stepDetector.fetchStepsNow() // immediate fetch if user opens watch app

            print("[ContentView] Fetching initial step and coin data.")
        }
        .onDisappear {
            watchManager.syncPendingSteps()
        }
        // Accessibility grouping
        .accessibilityElement(children: .contain)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
