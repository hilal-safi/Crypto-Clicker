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

            // Display Message
            Text(exchangeModel.message)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 2)
            
            Text("Coins: \(coins?.value ?? 0)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(exchangeModel.messageBackgroundColor)
        .cornerRadius(8)
        .animation(.easeInOut, value: exchangeModel.messageBackgroundColor)
    }

}

struct ExchangeMessageView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let coins = CryptoCoin(value: Decimal(1000))
        ExchangeMessageView(coins: .constant(coins))
            .environmentObject(CoinExchangeModel.shared)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
