//
//  CoinStatsPopupView.swift
//  Crypto Clicker Watch App
//
//  Created by Hilal Safi on 2025-01-15.
//

import SwiftUI

struct CoinStatsPopupView: View {
    
    @Binding var isPresented: Bool
    
    // All stats to display
    let coinsPerSecond: Decimal
    let coinsPerClick: Decimal
    let coinsPerStep: Decimal
    let totalCoins: Decimal
    let totalPowerUpsOwned: Int
    let totalExchangedCoins: Int
    let localSteps: Int // local steps from watch
    let totalCoinsFromSteps: Decimal
    let totalCoinsFromMiniGames: Decimal
    let totalCoinsFromClicks: Decimal
    let totalCoinsFromIdle: Decimal
    let totalCoinsEverEarned: Decimal
    let miniGameWinMultiplier: Decimal
    let totalCoinsSpent: Decimal
    
    var body: some View {
        
        ScrollView {
            VStack(spacing: 15) {
                
                Text("Statistics")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 10)
                    // Accessibility: Mark “Statistics” as a heading
                    .accessibilityAddTraits(.isHeader)
                
                VStack(alignment: .leading, spacing: 10) {
                    StatisticRow(title: "👟 Total Steps Taken", value: Decimal(WatchSessionManager.shared.totalSteps))
                    StatisticRow(title: "🦵 Coins Earned from Steps", value: totalCoinsFromSteps)
                    StatisticRow(title: "👣 Coins Gained Per Step", value: coinsPerStep)
                    StatisticRow(title: "⏱️ Coins Gained Per Second", value: coinsPerSecond)
                    StatisticRow(title: "👆 Coins Gained Per Click", value: coinsPerClick)
                    StatisticRow(title: "⛏️ Coins Earned By Clicking", value: totalCoinsFromClicks)
                    StatisticRow(title: "🕰️ Coins Earned From Idle", value: totalCoinsFromIdle)
                    StatisticRow(title: "💻 Total Power-Ups Owned", value: Decimal(totalPowerUpsOwned))
                    StatisticRow(title: "🔄 Total Exchanged Coins Owned", value: Decimal(totalExchangedCoins))
                    StatisticRow(title: "🕹️ Coins Earned From Mini Games", value: totalCoinsFromMiniGames)
                    StatisticRow(title: "🎲 Mini Game Reward Multiplier (%)", value: miniGameWinMultiplier)
                    StatisticRow(title: "🪙 Current Coins", value: totalCoins)
                    StatisticRow(title: "🛒 Total Coins Spent", value: totalCoinsSpent)
                    StatisticRow(title: "💰 Total Coins Earned", value: totalCoinsEverEarned)
                }
                
                Button("Close") {
                    isPresented = false
                }
                .font(.headline)
                .padding()
                .foregroundColor(.white)
                .cornerRadius(8)
                // Accessibility for button
                .accessibilityLabel("Close statistics")
            }
            .padding()
        }
        // Accessibility: Identified as a separate “page” or “sheet”
        .accessibilityElement(children: .contain)
    }
}

/// A single row displaying a title and a decimal value
struct StatisticRow: View {
    
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(Double(truncating: value as NSNumber), specifier: "%.0f")")
    }
}

struct CoinStatsPopupView_Previews: PreviewProvider {
    
    @State static var isPresented = true
    
    static var previews: some View {
        CoinStatsPopupView(
            isPresented: $isPresented,
            coinsPerSecond: 1,
            coinsPerClick: 1,
            coinsPerStep: 1,
            totalCoins: 100,
            totalPowerUpsOwned: 2,
            totalExchangedCoins: 5,
            localSteps: 50,
            totalCoinsFromSteps: 20,
            totalCoinsFromMiniGames: 10,
            totalCoinsFromClicks: 30,
            totalCoinsFromIdle: 40,
            totalCoinsEverEarned: 200,
            miniGameWinMultiplier: 10,
            totalCoinsSpent: 150
        )
    }
}
