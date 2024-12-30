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
            Text(model.purchaseMessage)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 2)
            
            Text("Coins: \(coins?.value ?? 0)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(model.messageBackgroundColor)
        .cornerRadius(8)
        .animation(.easeInOut, value: model.messageBackgroundColor)
    }
}

struct ShopMessageView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let model = ShopModel(store: CryptoStore())
        let coins = CryptoCoin(value: 1000)
        
        return ShopMessageView(coins: .constant(coins))
            .environmentObject(model)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
