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
    @State private var isCoinPressed = false // For coin click animation
    
    var body: some View {
        
        VStack(spacing: 8) {
            
            // The coin image as a button
            Button(action: {
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isCoinPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        isCoinPressed = false
                    }
                }
                watchManager.tapCoin()
                
                // Trigger haptic feedback
                WKInterfaceDevice.current().play(.click)
            }) {
                ZStack {
                    // Main Coin Image
                    Image("coin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170, height: 170)
                        .shadow(radius: 10)
                        .scaleEffect(isCoinPressed ? 1.15 : 1.0) // Coin scaling effect
                    
                    // Coin Sparkle Effect (Overlay)
                    if isCoinPressed {
                        Circle()
                            .strokeBorder(Color.yellow, lineWidth: 5)
                            .scaleEffect(1.5)
                            .opacity(0)
                            .animation(.easeOut(duration: 0.4), value: isCoinPressed)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, -15)
            
            // The coin total text
            Text("\(watchManager.coinValue)")
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(5)
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .shadow(color: .yellow, radius: 10)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showStats = true
                    }
                }
        }
        .sheet(isPresented: $showStats) {
            StatsView(
                isPresented: $showStats,
                coinsPerSecond: watchManager.coinsPerSecond,
                coinsPerClick: watchManager.coinsPerClick,
                coinsPerStep: watchManager.coinsPerStep,
                totalCoins: watchManager.coinValue,
                totalPowerUpsOwned: watchManager.totalPowerUpsOwned,
                totalExchangedCoins: watchManager.totalExchangedCoins,
                totalSteps: watchManager.totalSteps,
                totalCoinsFromSteps: watchManager.totalCoinsFromSteps,
                totalCoinsFromMiniGames: watchManager.totalCoinsFromMiniGames,
                totalCoinsFromClicks: watchManager.totalCoinsFromClicks,
                totalCoinsFromIdle: watchManager.totalCoinsFromIdle,
                totalCoinsEverEarned: watchManager.totalCoinsEverEarned,
                miniGameWinMultiplier: watchManager.miniGameWinMultiplier
            )
        }
        .onAppear {
            watchManager.startSession()
            watchManager.requestCoinData() // Fetch all stats from the phone

            // Fetch steps immediately on first load
            stepDetector.fetchStepsSinceMidnight()
            print("[ContentView] Fetching initial step and coin data.")
        }
        .onDisappear {
            stepDetector.saveData() // Save steps and coins before exiting
        }
    }
}

// MARK: - Updated StatsView
struct StatsView: View {
    
    @Binding var isPresented: Bool
    
    // All stats to display
    let coinsPerSecond: Decimal
    let coinsPerClick: Decimal
    let coinsPerStep: Decimal
    let totalCoins: Decimal
    let totalPowerUpsOwned: Int
    let totalExchangedCoins: Int
    let totalSteps: Int
    let totalCoinsFromSteps: Decimal
    let totalCoinsFromMiniGames: Decimal
    let totalCoinsFromClicks: Decimal
    let totalCoinsFromIdle: Decimal
    let totalCoinsEverEarned: Decimal
    let miniGameWinMultiplier: Decimal
    
    var body: some View {
        
        ScrollView {
            
            VStack(spacing: 15) {
                
                Text("Statistics")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 10)
                
                // Display all stats
                VStack(alignment: .leading, spacing: 10) {
                    StatRow(title: "👟 Total Steps Taken", value: Decimal(totalSteps))
                    StatRow(title: "🦵 Coins Earned from Steps", value: totalCoinsFromSteps)
                    StatRow(title: "👣 Coins Gained Per Step", value: coinsPerStep)
                    StatRow(title: "⏱️ Coins Gained Per Second", value: coinsPerSecond)
                    StatRow(title: "👆 Coins Gained Per Click", value: coinsPerClick)
                    StatRow(title: "⛏️ Coins Earned By Clicking", value: totalCoinsFromClicks)
                    StatRow(title: "🕰️ Coins Earned From Idle", value: totalCoinsFromIdle)
                    StatRow(title: "💻 Total Power-Ups Owned", value: Decimal(totalPowerUpsOwned))
                    StatRow(title: "🔄 Total Exchanged Coins Owned", value: Decimal(totalExchangedCoins))
                    StatRow(title: "🕹️ Coins Earned From Mini Games", value: totalCoinsFromMiniGames)
                    StatRow(title: "🎲 Mini Game Reward Multiplier (%)", value: miniGameWinMultiplier)
                    StatRow(title: "🪙 Current Coins", value: totalCoins)
                    StatRow(title: "💰 Total Coins Earned", value: totalCoinsEverEarned)
                }

                Button("Close") {
                    isPresented = false
                }
                .font(.headline)
                .padding()
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
    }
}

struct StatRow: View {
    
    let title: String
    let value: Decimal

    var body: some View {
        
        VStack(alignment: .leading) {
            
            Text("\(title):")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Display the value as an integer
            Text("\(Double(truncating: value as NSNumber), specifier: "%.0f")")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
    }
}
