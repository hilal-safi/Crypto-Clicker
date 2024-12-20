//
//  ExchangePopupView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-03.
//

import SwiftUI

struct ExchangePopupView: View {
    
    @ObservedObject var model: CoinExchangeModel

    var body: some View {
        if model.showMessage, let message = model.popupMessage {
            Text(message)
                .font(.headline)
                .padding()
                .background(message.contains("Successfully") ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .transition(.move(edge: .top))
                .zIndex(1)
        }
    }
}
struct ExchangePopupView_Previews: PreviewProvider {
    static var previews: some View {
        let mockModel = CoinExchangeModel()
        mockModel.popupMessage = "Example Message"
        mockModel.showMessage = true
        return ExchangePopupView(model: mockModel)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
