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
    // If you need it, also @ObservedObject var blackjackModel: BlackjackModel
    
    // Track initial and current coin counts locally
    @State private var initialCoins: Int = 0
    @State private var currentCoins: Int = 0

    var coinDifference: Int {
        currentCoins - initialCoins
    }

    var body: some View {
        VStack {
            coinSelector()
            coinDetails()
        }
        .padding()
        .onAppear {
            print("[DEBUG] BlackjackTopView appeared.")
            // Grab the counts for the *initial* coin selection
            updateCoins()
        }
        // If the user changes coin selection in coinSelector:
        .onChange(of: selectedCoin) { newCoin in
            print("[DEBUG] Selected coin changed to: \(newCoin.rawValue)")
            updateCoins()
        }
        // Listen for changes to the entire array of coins
        .onReceive(exchangeModel.$availableCoins) { newCoins in
            // newCoins is the updated array
            print("[DEBUG] onReceive triggered for availableCoins. newCoins: \(newCoins.map { "\($0.type.rawValue):\($0.count)" })")
            updateCurrentCoinCount()
        }
    }

    // MARK: - Private UI Builders

    private func coinSelector() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(exchangeModel.availableCoins, id: \.type) { coin in
                    Button {
                        selectedCoin = coin.type
                    } label: {
                        VStack {
                            Image(coin.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 42, height: 42)
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
            .padding(12)
        }
        .background(Color.gray.opacity(0.4))
        .cornerRadius(10)
    }

    private func coinDetails() -> some View {
        HStack(spacing: 20) {
            coinTypeView()
            Spacer()
            initialCoinView()
            Spacer()
            coinChangeView()
        }
    }

    private func coinTypeView() -> some View {
        VStack {
            Text("\(selectedCoin.rawValue.capitalized):")
                .font(.headline)
            Text("\(currentCoins)")
                .font(.body)
                .onAppear {
                    print("[DEBUG] CoinTypeView displayed. Current coins: \(currentCoins)")
                }
        }
    }

    private func initialCoinView() -> some View {
        VStack {
            Text("Initial:")
                .font(.headline)
            Text("\(initialCoins)")
                .font(.body)
                .onAppear {
                    print("[DEBUG] InitialCoinView displayed. Initial coins: \(initialCoins)")
                }
        }
    }

    private func coinChangeView() -> some View {
        VStack {
            Text("Change:")
                .font(.headline)
            if coinDifference == 0 {
                Text("\(coinDifference)")
                    .font(.body)
                    .foregroundColor(.primary)
                    .onAppear {
                        print("[DEBUG] CoinChangeView displayed. Coin difference: \(coinDifference)")
                    }
            } else {
                Text(coinDifference > 0 ? "+\(coinDifference)" : "\(coinDifference)")
                    .font(.body)
                    .foregroundColor(coinDifference > 0 ? .green : .red)
                    .onAppear {
                        print("[DEBUG] CoinChangeView displayed. Coin difference: \(coinDifference)")
                    }
            }
        }
    }

    // MARK: - Private Methods

    /// Called whenever we switch to a new coin or appear the first time
    private func updateCoins() {
        initialCoins = exchangeModel.count(for: selectedCoin)
        currentCoins = initialCoins
        print("[DEBUG] Updated coins. Initial coins: \(initialCoins), Current coins: \(currentCoins)")
    }

    /// Called whenever `availableCoins` changes, so we re-check how many of the *selectedCoin* we have
    private func updateCurrentCoinCount() {
        let newCount = exchangeModel.count(for: selectedCoin)
        if currentCoins != newCount {
            print("[DEBUG] Updating current coin count. Old count: \(currentCoins), New count: \(newCount)")
            currentCoins = newCount
        }
    }
}

struct BlackjackTopView_Previews: PreviewProvider {
    static var previews: some View {
        // Example usage
        let exchangeModel = CoinExchangeModel()
        BlackjackTopView(
            selectedCoin: .constant(.dogecoin),
            exchangeModel: exchangeModel
        )
    }
}
