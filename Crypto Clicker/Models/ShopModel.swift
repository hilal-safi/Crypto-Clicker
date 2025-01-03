//
//  ShopModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-25.
//

import Foundation
import SwiftUI

@MainActor
class ShopModel: ObservableObject {
    
    @Published var selectedQuantities: [String: Int] = [:]
    @Published var totalCost: Int = 0
    @Published var purchaseMessage: String = "Welcome to the Power Up Store!" // Default message
    @Published var messageBackgroundColor: Color = .gray // Default background color is grey

    private let store: CryptoStore

    init(store: CryptoStore) {
        self.store = store
    }

    func handlePurchase(for powerUp: PowerUps.PowerUp, quantity: Int) {
        // Ensure quantity is valid
        guard quantity > 0 else {
            updateMessage("Invalid quantity for \(powerUp.name).", success: false)
            return
        }

        // Attempt the purchase through the store
        let success = store.purchasePowerUp(powerUp: powerUp, quantity: quantity)

        // Update the message with specific details
        let message = success
            ? "Successfully purchased \(quantity) \(powerUp.name)(s)!"
            : "Failed to purchase \(quantity) \(powerUp.name)(s). Not enough coins."

        updateMessage(message, success: success)

        if success {
            // Reset quantity and recalculate cost on successful purchase
            selectedQuantities[powerUp.name] = 0
            calculateTotalCost()
        }
    }
    
    private func calculateTotalCost() {
        // Calculate the total cost of selected items
        totalCost = PowerUps.availablePowerUps.reduce(0) { result, powerUp in
            result + (selectedQuantities[powerUp.name] ?? 0) * powerUp.cost
        }
    }
    
    func updateMessage(_ text: String, success: Bool) {
        // Update the message and background color
        purchaseMessage = text
        messageBackgroundColor = success ? .green : .red

        // Reset message and background color after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.purchaseMessage = "Welcome to the Power Up Store!"
            self.messageBackgroundColor = .gray // Reset to default
        }
    }
    
    func clearAllQuantities() {
        selectedQuantities.removeAll()
    }
}
