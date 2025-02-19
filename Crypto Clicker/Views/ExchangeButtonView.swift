//
//  ExchangeButtonView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-28.
//

import SwiftUI

struct ExchangeButtonView: View {
    
    @EnvironmentObject var exchangeModel: CoinExchangeModel
    @Binding var coins: CryptoCoin?
    
    var body: some View {
        
        NavigationLink(
            destination: CoinExchangeView(coins: $coins)
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(exchangeModel.allCoinViews, id: \.type) { coinInfo in
                        coinView(for: coinInfo)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 1)
            )
        }
        .accessibilityLabel("Exchange coins") // VoiceOver label
        .accessibilityHint("Tap to exchange coins for different types") // VoiceOver hint
    }
    
    /// Creates a coin display view with image and count.
    private func coinView(for coinInfo: CoinExchangeModel.CoinTypeInfo) -> some View {
        
        VStack {
            Image(coinInfo.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityLabel("\(coinInfo.type.rawValue) icon") // VoiceOver label

            Text("\(coinInfo.count)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.blue)
                .accessibilityLabel("\(coinInfo.count) \(coinInfo.type.rawValue)") // VoiceOver label
        }
    }
}

struct ExchangeButtonView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let coins = CryptoCoin(value: Decimal(1000))
        
        return NavigationView {
            ExchangeButtonView(coins: .constant(coins))
        }
        .environmentObject(CoinExchangeModel.shared)
    }
}
