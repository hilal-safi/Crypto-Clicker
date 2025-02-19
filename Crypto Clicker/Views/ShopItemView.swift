//
//  ShopItemView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-25.
//

import SwiftUI

struct ShopItemView: View {
    
    @EnvironmentObject var store: CryptoStore
    let powerUp: PowerUps.PowerUp
    @Binding var coins: CryptoCoin?
    @EnvironmentObject var powerUps: PowerUps
    @EnvironmentObject var shopModel: ShopModel
    
    @State private var quantity: Int = 0    // Default to 0
    @State private var nextCost: Decimal = 0 // Tracks the cost of the *next single* item
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        VStack(spacing: 12) {
            
            // MARK: - Header: Emoji, Name, Description
            HStack {
                Text(powerUp.emoji)
                    .font(.system(size: 60))
                    .frame(width: 72, height: 68)
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.gray.opacity(0.8)
                            : Color.black.opacity(0.3),
                        radius: 12
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(powerUp.name)
                        .font(.title2)
                        .bold()
                    
                    Text(powerUp.description)
                        .font(.subheadline)
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 8)
            }
            
            // MARK: - Owned and Quantity
            HStack(spacing: 16) {
                
                dynamicHStack(
                    label: "Owned:",
                    value: Decimal(powerUps.quantities[powerUp.name, default: 0]),
                    color: .primary
                )
                
                Divider()
                    .frame(height: 24)
                    .background(Color.primary.opacity(0.3))
                
                dynamicHStack(
                    label: "Quantity:",
                    value: Decimal(quantity),
                    color: .primary
                )
            }
            
            // MARK: - Cost Group
            HStack(spacing: 16) {
                dynamicHStack(
                    label: "Base Cost:",
                    value: Decimal(powerUp.cost),
                    color: .blue
                )
                
                Divider()
                    .frame(height: 24)
                    .background(Color.blue.opacity(0.3))
                
                dynamicHStack(
                    label: "Next Cost:",
                    value: nextCost,
                    color: .purple
                )
            }
            
            // MARK: - Buffs Group
            HStack(spacing: 16) {
                dynamicHStack(
                    label: "Coins/Sec:",
                    value: Decimal(powerUp.coinsPerSecondIncrease),
                    color: .green
                )
                
                Divider()
                    .frame(height: 24)
                    .background(Color.green.opacity(0.3))
                
                dynamicHStack(
                    label: "Coins/Click:",
                    value: Decimal(powerUp.coinsPerClickIncrease),
                    color: .green
                )
            }
            
            // MARK: - Total Cost for current "quantity"
            dynamicHStack(
                label: "Total Cost:",
                value: piecewiseTotalCost(),
                color: .primary
            )
            
            // MARK: - Quantity Selector + Purchase Button
            HStack(spacing: 12) {
                
                quantityButton(label: "-5", step: -5, width: 44, color: .red)
                quantityButton(label: "-1", step: -1, width: 44, color: .red)

                Button(action: handlePurchase) {
                    Text("Buy")
                        .font(.headline)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .accessibilityLabel("Buy \(quantity) \(powerUp.name)(s)")
                
                quantityButton(label: "+1", step: 1, width: 44, color: .green)
                quantityButton(label: "+5", step: 5, width: 44, color: .green)
            }
        }
        .padding()
        .background(
            BlurView(style: .systemMaterial, reduction: 0.7)
        )
        .cornerRadius(12)
        .shadow(radius: 5)
        .onAppear {
            nextCost = piecewiseNextCost()
        }
    }
}

// MARK: - Purchase Logic
fileprivate extension ShopItemView {
    
    /// Handles the purchase of power-ups
    func handlePurchase() {
        guard quantity > 0 else {
            shopModel.updateMessage("Cannot purchase 0 of \(powerUp.name). Increase quantity first!", success: false)
            return
        }
        
        let cost = piecewiseTotalCost()
        guard let currentCoins = coins?.value, currentCoins >= cost else {
            shopModel.updateMessage("Not enough coins to buy \(quantity) \(powerUp.name)(s).", success: false)
            return
        }
        
        // Purchase the power-up
        shopModel.handlePurchase(for: powerUp, quantity: quantity)
    }
}

// MARK: - Cost Calculation Logic
fileprivate extension ShopItemView {
    
    /// Calculate cost for the *next single* item (beyond the current quantity).
    func piecewiseNextCost() -> Decimal {
        let owned = powerUps.quantities[powerUp.name, default: 0]
        let indexForNextItem = owned + quantity
        var cost = itemCost(index: indexForNextItem)
        
        // Multiply by difficulty
        cost *= Decimal(store.settings?.difficulty.costMultiplier ?? 1.0)
        
        return clampAndRound(cost)
    }
    
    /// Calculate total cost for the entire "quantity" in a more performant piecewise way.
    func piecewiseTotalCost() -> Decimal {
        guard quantity > 0 else { return 0 }
        
        let owned = powerUps.quantities[powerUp.name, default: 0]
        let start = owned
        let end = owned + quantity - 1
        var sum = Decimal(0)
        
        if end < 500 {
            sum = exponentSumRange(startIndex: start, endIndex: end)
        } else if start >= 500 {
            sum = minimalGrowthSumRange(startIndex: start, endIndex: end)
        } else {
            let part1 = exponentSumRange(startIndex: start, endIndex: 499)
            let part2 = minimalGrowthSumRange(startIndex: 500, endIndex: end)
            sum = part1 + part2
        }
        
        let difficultyMultiplier = Decimal(store.settings?.difficulty.costMultiplier ?? 1.0)
        return clampAndRound(sum * difficultyMultiplier)
    }
    
    func exponentSumRange(startIndex: Int, endIndex: Int) -> Decimal {
        guard startIndex <= endIndex else { return 0 }
        var total = Decimal(0)
        for i in startIndex...endIndex {
            let c = clampAndRound(itemCost(index: i))
            let newSum = total + c
            if newSum > Decimal.greatestFiniteMagnitude {
                return Decimal.greatestFiniteMagnitude
            }
            total = newSum
        }
        return total
    }
    
    func minimalGrowthSumRange(startIndex: Int, endIndex: Int) -> Decimal {
        guard startIndex <= endIndex else { return 0 }
        var total = Decimal(0)
        for i in startIndex...endIndex {
            let c = clampAndRound(itemCost(index: i))
            let newSum = total + c
            if newSum > Decimal.greatestFiniteMagnitude {
                return Decimal.greatestFiniteMagnitude
            }
            total = newSum
        }
        return total
    }
    
    /// itemCost for a given index
    /// If `index < 500`, exponent-based; else minimal growth logic.
    func itemCost(index: Int) -> Decimal {
        let base = Decimal(powerUp.cost)
        if index < 500 {
            let cost = base * powDecimal(Decimal(powerUp.costMultiplier), index)
            return clampAndRound(cost)
        } else {
            let costAt499 = base * powDecimal(Decimal(powerUp.costMultiplier), 499)
            let offset = index - 499
            let cost = costAt499 * powDecimal(Decimal(1.005), offset)
            return clampAndRound(cost)
        }
    }
}

// MARK: - Utility Functions
fileprivate extension ShopItemView {
    
    // Clamp & round down to whole
    func clampAndRound(_ value: Decimal) -> Decimal {
        let clamped = value > Decimal.greatestFiniteMagnitude ? Decimal.greatestFiniteMagnitude : value
        return clamped.roundedDownToWhole()
    }
    
    // Our improved exponent function
    func powDecimal(_ base: Decimal, _ exponent: Int) -> Decimal {
        if exponent <= 0 { return 1 }
        var result = Decimal(1)
        for _ in 0..<exponent {
            result *= base
            if result > Decimal.greatestFiniteMagnitude {
                return Decimal.greatestFiniteMagnitude
            }
        }
        return result
    }
}

// MARK: - UI Helpers
fileprivate extension ShopItemView {
    
    // Format big decimals with commas
    func formattedDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
    
    // Show large or short text with vertical expansion
    @ViewBuilder
    func dynamicHStack(label: String, value: Decimal, color: Color) -> some View {
        let formattedValue = formattedDecimal(value)
        HStack(alignment: .top) {
            Text(label)
                .font(.body)
                .bold()
                .foregroundColor(color)
            Spacer()
            Text(formattedValue)
                .font(.headline)
                .foregroundColor(color)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.trailing)
        }
    }
    
    func quantityButton(label: String, step: Int, width: CGFloat, color: Color) -> some View {
        Button {
            quantity = max(0, quantity + step)
            nextCost = piecewiseNextCost()
        } label: {
            Text(label)
                .frame(width: width, height: 40)
                .background(color.opacity(0.7))
                .cornerRadius(8)
                .foregroundColor(.white)
                .bold()
                .accessibilityLabel("\(step > 0 ? "Increase" : "Decrease") quantity by \(abs(step))")
        }
    }
}

// MARK: - Preview
struct ShopItemView_Previews: PreviewProvider {
    static var previews: some View {
        let mockCoins = CryptoCoin(value: Decimal(1000))
        let mockStore = CryptoStore()
        return ShopItemView(
            powerUp: PowerUps.availablePowerUps.first!,
            coins: .constant(mockCoins)
        )
        .environmentObject(PowerUps.shared)
        .environmentObject(mockStore)
    }
}
