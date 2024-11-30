//
//  CoinStatsPopupView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-30.
//

import SwiftUI

struct CoinStatsPopupView: View {
    
    let coinsPerSecond: Int
    let coinsPerClick: Int
    let totalCoins: Int
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Apply a lighter blur to the background
            VisualEffectBlurView(style: .systemThinMaterial) // Reduced blur effect
                .ignoresSafeArea()
                .onTapGesture {
                    onClose() // Dismiss popup when tapping outside
                }

            // Popup content
            VStack(spacing: 20) {
                Text("Statistics")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 10) {
                    StatisticRow(title: "Coins/Sec", value: coinsPerSecond)
                    StatisticRow(title: "Coins/Click", value: coinsPerClick)
                    StatisticRow(title: "Total Coins", value: totalCoins)
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
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
            .frame(width: UIScreen.main.bounds.width * 0.8) // 80% of screen width
        }
    }
}

// Helper view for visual effect blur
struct VisualEffectBlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// StatisticRow remains the same
struct StatisticRow: View {
    
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text("\(title):")
                .font(.headline)
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)

            Spacer()

            Text("\(value)")
                .font(.headline)
                .foregroundColor(.black)
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
            onClose: {}
        )
        .previewLayout(.sizeThatFits)
    }
}
