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
    @Published var purchaseMessage: String? = nil
    @Published var showMessage: Bool = false

    private let store: CryptoStore

    init(store: CryptoStore) {
        self.store = store
    }

    func incrementQuantity(for name: String) {
        selectedQuantities[name, default: 0] += 1
        calculateTotalCost()
    }

    func decrementQuantity(for name: String) {
        if let currentQuantity = selectedQuantities[name], currentQuantity > 0 {
            selectedQuantities[name] = currentQuantity - 1
            calculateTotalCost()
        }
    }

    func handlePurchase(for powerUp: PowerUpInfo) {
        
        guard let quantity = selectedQuantities[powerUp.name], quantity > 0 else { return }
        let success = store.purchasePowerUp(powerUp: powerUp, quantity: quantity)

        purchaseMessage = success
            ? "Purchase of \(quantity) \(powerUp.name)(s) successful!"
            : "Purchase failed. Not enough coins."

        // Show the popup message with animation
        withAnimation {
            showMessage = true
        }

        // Hide message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showMessage = false
            }
        }

        if success {
            selectedQuantities[powerUp.name] = 0
            calculateTotalCost()
        }
    }

    private func calculateTotalCost() {
        
        totalCost = PowerUps.powerUps.reduce(0) { result, powerUp in
            result + (selectedQuantities[powerUp.name] ?? 0) * powerUp.cost
        }
    }
}
