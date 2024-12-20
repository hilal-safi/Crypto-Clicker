//
//  BlackjackTopView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi.
//

import SwiftUI

struct BlackjackTopView: View {
    
    @Binding var selectedCoin: CoinType
    @ObservedObject var exchangeModel: CoinExchangeModel
    
    var body: some View {
        
        VStack {
            // Coin Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(exchangeModel.allCoinViews, id: \.type) { coin in
                        Button(action: {
                            selectedCoin = coin.type
                        }) {
                            VStack {
                                Image(coin.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32) // Adjust image size
                            }
                            .padding()
                            .background(selectedCoin == coin.type ? Color.blue.opacity(0.4) : Color.gray.opacity(0.4))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedCoin == coin.type ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.4))
            .cornerRadius(10)
            
            // Display current coin count
            HStack {
                
                Text("Available \(selectedCoin.rawValue.capitalized):")
                    .font(.headline)
                
                Spacer()
                
                Text("\(exchangeModel.count(for: selectedCoin))")
                    .font(.headline)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct BlackjackTopView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel()
        
        return BlackjackTopView(selectedCoin: .constant(.dogecoin), exchangeModel: exchangeModel)
    }
}
