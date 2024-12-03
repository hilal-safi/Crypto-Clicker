//
//  ShopPopupView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-25.
//

import SwiftUI

struct ShopPopupView: View {
    
    @ObservedObject var model: ShopModel

    var body: some View {
        if model.showMessage, let message = model.purchaseMessage {
            Text(message)
                .font(.headline)
                .padding()
                .background(message.contains("successful") ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .transition(.move(edge: .top))
                .zIndex(1)
        }
    }
}

struct ShopPopupView_Previews: PreviewProvider {
    static var previews: some View {
        let mockModel = ShopModel(store: CryptoStore())
        ShopPopupView(model: mockModel)
    }
}
