//
//  BlackjackTopView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackTopView: View {
    
    @Binding var selectedCoin: CoinType
    @EnvironmentObject var exchangeModel: CoinExchangeModel
    
    // We only track the "initial" coin count, as a baseline
    @State private var initialCoins: Int = 0
    
    // Current coin count is fetched directly from the model at any moment
    private var currentCoins: Int {
        exchangeModel.count(for: selectedCoin)
    }
    
    // Difference is computed from current minus initial
    private var coinDifference: Int {
        currentCoins - initialCoins
    }

    var body: some View {
        
        VStack {
            coinSelector()
            coinDetails()
        }
        .padding()
        .onAppear {
            // Record the initial coins for the *selectedCoin* on first appear
            initialCoins = exchangeModel.count(for: selectedCoin)
        }
        // If the user changes coin selection in coinSelector:
        .onChange(of: selectedCoin) { _, newCoin in
            // Update our baseline for the newly selected coin
            initialCoins = exchangeModel.count(for: newCoin)
        }
    }
    
    // MARK: - Private UI Builders
    
    /// Displays a horizontal scrollable coin selection bar.
    private func coinSelector() -> some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            
            HStack(spacing: 16) {
                
                ForEach(exchangeModel.availableCoins, id: \.type) { coin in
                    coinButton(for: coin)
                }
            }
            .padding(12)
        }
        .background(Color.gray.opacity(0.4))
        .cornerRadius(10)
        .accessibilityLabel("Select a coin type for betting") // VoiceOver
    }
    
    /// Creates a button for selecting a specific cryptocurrency coin.
    private func coinButton(for coin: CoinExchangeModel.CoinTypeInfo) -> some View {
        
        Button {
            // Switch the selected coin
            selectedCoin = coin.type
            
        } label: {
            
            VStack {
                Image(coin.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .accessibilityLabel("\(coin.type.rawValue.capitalized)") // VoiceOver
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
    
    /// Displays details about the selected coin, including current amount and changes.
    private func coinDetails() -> some View {
        
        HStack(spacing: 20) {
            
            VStack {
                Text("\(selectedCoin.rawValue.capitalized):")
                    .font(.headline)
                    .accessibilityLabel("Selected coin: \(selectedCoin.rawValue.capitalized)") // VoiceOver
                
                // Read the "current" coins straight from the model
                Text("\(currentCoins)")
                    .font(.body)
                    .accessibilityLabel("Current balance: \(currentCoins) coins") // VoiceOver
            }
            
            Spacer()
            initialCoinView()
            Spacer()
            coinChangeView()
        }
    }

    /// Displays the initial amount of selected coins.
    private func initialCoinView() -> some View {
        
        VStack {
            Text("Initial:")
                .font(.headline)
            
            Text("\(initialCoins)")
                .font(.body)
                .accessibilityLabel("Initial balance: \(initialCoins) coins") // VoiceOver
        }
    }

    /// Displays the change in the number of coins compared to the initial amount.
    private func coinChangeView() -> some View {
        
        VStack {
            Text("Change:")
                .font(.headline)
            
            if coinDifference == 0 {
                Text("\(coinDifference)")
                    .font(.body)
                    .foregroundColor(.primary)
                    .accessibilityLabel("No change in coin balance") // VoiceOver
            } else {
                Text(coinDifference > 0 ? "+\(coinDifference)" : "\(coinDifference)")
                    .font(.body)
                    .foregroundColor(coinDifference > 0 ? .green : .red)
                    .accessibilityLabel(coinDifference > 0
                        ? "Increased by \(coinDifference) coins"
                        : "Decreased by \(abs(coinDifference)) coins") // VoiceOver
            }
        }
    }
}

struct BlackjackTopView_Previews: PreviewProvider {
    
    static var previews: some View {
        // This preview uses a mock environment to display the view.
        // (The real app environment is defined in your @main App.)
        BlackjackTopView(selectedCoin: .constant(.dogecoin))
            .environmentObject(CoinExchangeModel.shared)
    }
}
