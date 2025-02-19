//
//  ShopMessageView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-30.
//

import SwiftUI

struct ShopMessageView: View {
    
    @EnvironmentObject var model: ShopModel
    @Binding var coins: CryptoCoin?

    var body: some View {
        VStack {
            
            // Display Message
            Text(model.purchaseMessage.isEmpty ? "No recent purchases" : model.purchaseMessage)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 2)
                .accessibilityLabel("Purchase Message: \(model.purchaseMessage.isEmpty ? "No recent purchases" : model.purchaseMessage)")

            Text("Coins: \(coins?.value.formattedCoinValue() ?? "0")")
                .font(.headline)
                .foregroundColor(.white)
                .accessibilityLabel("Current Coins: \(coins?.value.formattedCoinValue() ?? "0")")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(model.messageBackgroundColor)
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.3), value: model.messageBackgroundColor)
    }
}

struct ShopMessageView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let model = ShopModel(store: CryptoStore())
        let coins = CryptoCoin(value: Decimal(1000))
        
        return ShopMessageView(coins: .constant(coins))
            .environmentObject(model)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
