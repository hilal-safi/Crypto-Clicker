//
//  ExchangeMessageView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-29.
//

import SwiftUI

struct ExchangeMessageView: View {
    
    @EnvironmentObject var exchangeModel: CoinExchangeModel
    
    var body: some View {
        Text(exchangeModel.message ?? "No message available")
            .font(.headline)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .frame(maxWidth: .infinity)
    }
}

struct ExchangeMessageView_Previews: PreviewProvider {
    static var previews: some View {
        ExchangeMessageView()
            .environmentObject(CoinExchangeModel())
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
