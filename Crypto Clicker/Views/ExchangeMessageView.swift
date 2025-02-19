//
//  ExchangeMessageView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-29.
//

import SwiftUI

struct ExchangeMessageView: View {
    
    @EnvironmentObject var exchangeModel: CoinExchangeModel
    @Binding var coins: CryptoCoin?

    var body: some View {
        
        VStack {

            // Display exchange message with accessibility support
            Text(exchangeModel.message)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 2)
                .accessibilityLabel("Exchange message: \(exchangeModel.message)") // VoiceOver support
            
            // Display current coin balance with error handling
            if let coinValue = coins?.value {
                Text("Coins: \(formatted(coinValue))")
                    .font(.headline)
                    .foregroundColor(.white)
                    .accessibilityLabel("Current coin balance: \(formatted(coinValue))") // VoiceOver
            } else {
                Text("Coins: 0")
                    .font(.headline)
                    .foregroundColor(.white)
                    .accessibilityLabel("Current coin balance: 0") // VoiceOver
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(exchangeModel.messageBackgroundColor)
        .cornerRadius(8)
        .animation(.easeInOut, value: exchangeModel.messageBackgroundColor)
    }
    
    /// Helper function to format decimals with commas
    private func formatted(_ value: Decimal) -> String {
        
        let formatter = NumberFormatter()
        
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

struct ExchangeMessageView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let coins = CryptoCoin(value: Decimal(1000))
        return ExchangeMessageView(coins: .constant(coins))
            .environmentObject(CoinExchangeModel.shared)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
