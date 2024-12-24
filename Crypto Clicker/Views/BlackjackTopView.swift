//
//  BlackjackTopView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackTopView: View {
    
    @Binding var selectedCoin: CoinType
    @ObservedObject var exchangeModel: CoinExchangeModel
    @State private var initialCoins: Int = 0 // Track initial coin count
    @State private var currentCoins: Int = 0 // Track current coin count dynamically

    var coinDifference: Int {
        currentCoins - initialCoins
    }

    var body: some View {
        
        VStack {
            
            // Coin Selector
            ScrollView(.horizontal, showsIndicators: false) {
                
                HStack(spacing: 16) {
                    
                    ForEach(exchangeModel.allCoinViews, id: \.type) { coin in
                        
                        Button(action: {
                            selectedCoin = coin.type
                            updateCoins()
                            
                        }) {
                            VStack {
                                
                                Image(coin.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 42, height: 42) // Adjust image size
                            }
                            .padding(10)
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
            .padding(12)
            .background(Color.gray.opacity(0.4))
            .cornerRadius(10)
            
            // HStack for coin details
            HStack(spacing: 20) {
                
                VStack {
                    
                    Text("\(selectedCoin.rawValue.capitalized):")
                        .font(.headline)
                    
                    Text("\(currentCoins)")
                        .font(.body)
                }
                Spacer()
                
                VStack {
                    
                    Text("Initial:")
                        .font(.headline)
                    
                    Text("\(initialCoins)")
                        .font(.body)
                }
                Spacer()
                
                VStack {
                    
                    Text("Change:")
                        .font(.headline)
                    
                    if coinDifference == 0 {
                        
                        Text("\(coinDifference)")
                            .font(.body)
                            .foregroundColor(.primary) // Default color for zero
                        
                    } else {
                        Text(coinDifference > 0 ? "+\(coinDifference)" : "\(coinDifference)")
                            .font(.body)
                            .foregroundColor(coinDifference > 0 ? .green : .red)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            updateCoins()
        }
        .onChange(of: selectedCoin) {
            updateCoins()
        }
        .onReceive(exchangeModel.$coinTypes) { _ in
            updateCurrentCoinCount()
        }
    }
    
    private func updateCoins() {
        // Update both initial and current coin counts
        initialCoins = exchangeModel.count(for: selectedCoin)
        currentCoins = initialCoins
    }
    
    private func updateCurrentCoinCount() {
        // Dynamically update the current coin count whenever the model changes
        currentCoins = exchangeModel.count(for: selectedCoin)
    }
}

struct BlackjackTopView_Previews: PreviewProvider {
    
    static var previews: some View {
        let exchangeModel = CoinExchangeModel()
        return BlackjackTopView(selectedCoin: .constant(.dogecoin), exchangeModel: exchangeModel)
    }
}
