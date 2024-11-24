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
    @State private var selectedQuantities: [String: Int] = [:]
    @State private var totalCost: Int = 0
    @State private var selectedPowerUp: PowerUpInfo? = nil
    @State private var showConfirmation: Bool = false
    @State private var purchaseMessage: String? = nil // Message for purchase success or failure
    @State private var showMessage: Bool = false // Toggles the visibility of the popup message

    var body: some View {
        
        VStack(spacing: 10) {
            // Store Title
            Text("Store")
                .font(.largeTitle)
                .bold()
                .padding(.top, 10)

            // Popup Notification for Purchase
            if showMessage, let message = purchaseMessage {
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

            // Display Current Coins
            Text("Coins: \(coins?.value ?? 0)")
                .font(.headline)
                .padding(.top, -5)

            // List of Power-Ups
            ScrollView {
                LazyVStack(spacing: 20) {
                    
                    ForEach(PowerUps.powerUps, id: \.name) { powerUp in
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(powerUp.emoji)
                                    .font(.largeTitle)
                                    .padding()
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(powerUp.name)
                                        .font(.headline)
                                    Text(powerUp.description)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }

                            // Cost Breakdown
                            HStack {
                                Text("Cost: \(powerUp.cost) coins each")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                                Text("Selected: \(selectedQuantities[powerUp.name] ?? 0)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                                Text("Total: \((selectedQuantities[powerUp.name] ?? 0) * powerUp.cost) coins")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }

                            // Quantity Selector and Purchase Button
                            HStack {
                                Button(action: {
                                    decrementQuantity(for: powerUp.name)
                                }) {
                                    Text("-")
                                        .frame(width: 32, height: 32)
                                        .background(Color.red.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }

                                Text("\(selectedQuantities[powerUp.name] ?? 0)")
                                    .font(.title2)
                                    .frame(width: 40)

                                Button(action: {
                                    incrementQuantity(for: powerUp.name)
                                }) {
                                    Text("+")
                                        .frame(width: 32, height: 32)
                                        .background(Color.green.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }

                                Spacer()

                                // Purchase Button
                                Button("Purchase") {
                                    selectedPowerUp = powerUp
                                    showConfirmation = true
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled((selectedQuantities[powerUp.name] ?? 0) == 0)
                            }
                        }
                        .padding(12) // Adjusted padding for more space
                        .frame(maxWidth: .infinity) // Expand to full width
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                }
                .padding(.horizontal, 5) // Added horizontal padding
                .padding(.top, 4) // Ensure the first item is fully visible
            }
            .padding(.bottom, 1) // Adjusted bottom padding
        }
        .padding(.horizontal, 10) // Reduced overall horizontal padding
        
        .alert(item: $selectedPowerUp) { powerUp in
            Alert(
                title: Text("Confirm Purchase"),
                message: Text("Buy \(selectedQuantities[powerUp.name] ?? 0) \(powerUp.name)(s) for \((selectedQuantities[powerUp.name] ?? 0) * powerUp.cost) coins?"),
                primaryButton: .default(Text("Confirm")) {
                    handlePurchase(for: powerUp)
                },
                secondaryButton: .cancel()
            )
        }
    }

    // Increment Quantity
    private func incrementQuantity(for name: String) {
        selectedQuantities[name, default: 0] += 1
        calculateTotalCost()
    }

    // Decrement Quantity
    private func decrementQuantity(for name: String) {
        if let currentQuantity = selectedQuantities[name], currentQuantity > 0 {
            selectedQuantities[name] = currentQuantity - 1
            calculateTotalCost()
        }
    }

    // Handle Purchase
    private func handlePurchase(for powerUp: PowerUpInfo) {
        guard let quantity = selectedQuantities[powerUp.name], quantity > 0 else { return }
        let success = store.purchasePowerUp(powerUp: powerUp, quantity: quantity)

        // Set message based on success or failure
        purchaseMessage = success
            ? "Purchase of \(quantity) \(powerUp.name)(s) successful!"
            : "Purchase failed. Not enough coins."

        // Show the popup message
        withAnimation {
            showMessage = true
        }

        // Hide message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showMessage = false
            }
        }

        if success {
            selectedQuantities[powerUp.name] = 0
            calculateTotalCost()
        }
    }

    // Calculate Total Cost
    private func calculateTotalCost() {
        totalCost = PowerUps.powerUps.reduce(0) { result, powerUp in
            result + (selectedQuantities[powerUp.name] ?? 0) * powerUp.cost
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
