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
    @State private var initialCoins: Int = 0 // Track initial coin count

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
            
            // New line for coins won/lost
            HStack {
                
                Text("Coins Won/Lost:")
                    .font(.headline)
                
                let coinDifference = exchangeModel.count(for: selectedCoin) - initialCoins
                
                Spacer()

                Text(coinDifference >= 0 ? "+\(coinDifference)" : "\(coinDifference)")
                    .font(.headline)
                    .bold()
                    .foregroundColor(coinDifference >= 0 ? .green : .red)
            }
            .padding(.horizontal)
        }
        .padding()
        
        .onAppear {
            // Set initial coin count when the view appears
            initialCoins = exchangeModel.count(for: selectedCoin)
        }
    }
}

struct BlackjackTopView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel()
        
        return BlackjackTopView(selectedCoin: .constant(.dogecoin), exchangeModel: exchangeModel)
    }
}
