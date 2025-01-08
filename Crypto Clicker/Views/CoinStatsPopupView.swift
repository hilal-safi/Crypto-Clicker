//
//  CoinStatsPopupView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-30.
//

import SwiftUI

struct CoinStatsPopupView: View {
    
    let coinsPerSecond: Decimal
    let coinsPerClick: Decimal
    let totalCoins: Decimal
    let totalPowerUpsOwned: Int
    let totalExchangedCoins: Int
    let totalSteps: Int
    let totalCoinsFromSteps: Decimal
    let onClose: () -> Void

    @Environment(\.colorScheme) var colorScheme // Detect the system or app-specific color scheme

    var body: some View {
        
        ZStack {
            // Add blur to everything behind the popup using BlurView
            BlurView(
                style: colorScheme == .dark ? .systemMaterialDark : .systemMaterialLight,
                reduction: 0.9
            )
            .ignoresSafeArea()
            .onTapGesture {
                onClose() // Dismiss popup when tapping outside
            }

            // Popup content
            VStack(spacing: 20) {
                
                Text("Statistics")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black) // Adjust text color
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 10) {
                    StatisticRow(
                        title: "Coins/Sec",
                        value: coinsPerSecond,
                        colorScheme: colorScheme
                    )
                    StatisticRow(
                        title: "Coins/Click",
                        value: coinsPerClick,
                        colorScheme: colorScheme
                    )
                    StatisticRow(
                        title: "Total Coins",
                        value: totalCoins,
                        colorScheme: colorScheme
                    )
                    StatisticRow(
                        title: "Power-Ups Owned",
                        value: Decimal(totalPowerUpsOwned),
                        colorScheme: colorScheme
                    )
                    StatisticRow(
                        title: "Exchanged Coins",
                        value: Decimal(totalExchangedCoins),
                        colorScheme: colorScheme
                    )
                    StatisticRow(
                        title: "Total Steps",
                        value: Decimal(totalSteps),
                        colorScheme: colorScheme
                    )
                    StatisticRow(
                        title: "Coins from Steps",
                        value: totalCoinsFromSteps,
                        colorScheme: colorScheme
                    )
                }

                Button("Close") {
                    onClose() // Dismiss popup
                }
                .font(.headline)
                .padding()
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
                
            }
            .padding()
            .background(colorScheme == .dark ? Color.black : Color.white)
            .cornerRadius(16)
            .shadow(color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), radius: 10)
            .frame(width: UIScreen.main.bounds.width * 0.9) // 90% of screen width
            .offset(y: -UIScreen.main.bounds.height * 0.1) // Slightly higher but not cut off
        }
    }
}

// Updated StatisticRow remains the same
struct StatisticRow: View {
    
    let title: String
    let value: Decimal
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Text("\(title):")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .multilineTextAlignment(.leading)

            Spacer()

            Text("\(value)")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .multilineTextAlignment(.trailing)
                .lineLimit(nil) // Allow multiline wrapping for large values
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CoinStatsPopupView_Previews: PreviewProvider {
    
    static var previews: some View {
        CoinStatsPopupView(
            coinsPerSecond: 5_000_000,
            coinsPerClick: 10_000_000,
            totalCoins: 100_000_000,
            totalPowerUpsOwned: 25,
            totalExchangedCoins: 100,
            totalSteps: 5000, // NEW: Example total steps
            totalCoinsFromSteps: 50_000, // NEW: Example coins from steps
            onClose: {}
        )
        .previewLayout(.sizeThatFits)
        .environment(\.colorScheme, .dark) // Preview in dark mode
        .previewDisplayName("Dark Mode")

        CoinStatsPopupView(
            coinsPerSecond: 5_000_000,
            coinsPerClick: 10_000_000,
            totalCoins: 100_000_000,
            totalPowerUpsOwned: 25,
            totalExchangedCoins: 100,
            totalSteps: 5000, // NEW: Example total steps
            totalCoinsFromSteps: 50_000, // NEW: Example coins from steps
            onClose: {}
        )
        .previewLayout(.sizeThatFits)
        .environment(\.colorScheme, .light) // Preview in light mode
        .previewDisplayName("Light Mode")
    }
}
