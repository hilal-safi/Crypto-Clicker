//
//  ShopView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI

struct ShopView: View {
    @ObservedObject var store: CryptoStore
    @Binding var coins: CryptoCoin?
    @State private var selectedPowerUps: [PowerUpInfo: Int] = [:] // Tracks selected power-ups and their quantities
    @State private var purchaseResult: String? // To display the purchase result
    @State private var showConfirmation: Bool = false // Controls confirmation alert

    var body: some View {
        VStack(spacing: 20) {
            // Coins and Coins Per Second Display
            VStack {
                Text("Coins: \(coins?.value ?? 0)")
                    .font(.headline)
                Text("Coins Per Second: \(store.coinsPerSecond)")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            .padding()

            // List of Power-Ups
            List(PowerUps.powerUps) { powerUp in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(powerUp.emoji)
                            .font(.system(size: 32))
                        VStack(alignment: .leading) {
                            Text(powerUp.name)
                                .font(.headline)
                            Text(powerUp.description)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            // Cost Breakdown
                            Text("Cost: \(powerUp.cost) coins each")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text("Selected: \(selectedPowerUps[powerUp] ?? 0)")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                            Text("Total: \(powerUp.cost * (selectedPowerUps[powerUp] ?? 0)) coins")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }

                    // Quantity Selector
                    HStack {
                        Stepper("Quantity: \(selectedPowerUps[powerUp] ?? 0)", value: Binding(
                            get: { selectedPowerUps[powerUp] ?? 0 },
                            set: { selectedPowerUps[powerUp] = $0 }
                        ), in: 0...10)
                        .labelsHidden()
                        .frame(width: 150)

                        Spacer()
                    }
                }
                .padding()
            }

            Spacer()

            // Purchase Button
            Button(action: {
                showConfirmation = true
            }) {
                Text("Purchase")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedPowerUps.values.reduce(0, +) == 0 ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(selectedPowerUps.values.reduce(0, +) == 0) // Disable if no items are selected
            .padding()
            .alert(isPresented: $showConfirmation) {
                Alert(
                    title: Text("Confirm Purchase"),
                    message: Text("Confirm purchasing selected power-ups?"),
                    primaryButton: .default(Text("Confirm")) {
                        handlePurchase()
                    },
                    secondaryButton: .cancel()
                )
            }

            // Success or Failure Message
            if let result = purchaseResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(result.contains("success") ? .green : .red)
                    .padding(.top)
            }
        }
        .navigationTitle("Shop")
    }

    private func handlePurchase() {
        guard let currentCoins = coins else { return }
        var purchaseSuccessful = true

        // Iterate through selected items and attempt to purchase them
        for (powerUp, quantity) in selectedPowerUps {
            if quantity > 0 {
                let success = store.purchasePowerUp(powerUp: powerUp, quantity: quantity)
                if !success {
                    purchaseSuccessful = false
                    purchaseResult = "Failed to purchase \(quantity) \(powerUp.name)(s). Insufficient coins."
                    break
                }
            }
        }

        if purchaseSuccessful {
            purchaseResult = "Purchase successful! Enjoy your new power-ups."
            selectedPowerUps.removeAll() // Clear selections after a successful purchase
        }

        // Automatically clear the message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            purchaseResult = nil
        }
    }
}

struct ShopView_Previews: PreviewProvider {
    static var previews: some View {
        let store = CryptoStore()
        let coins = CryptoCoin(value: 1000)
        return ShopView(store: store, coins: .constant(coins))
    }
}
