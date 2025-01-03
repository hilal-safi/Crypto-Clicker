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
                
                quantityButton(label: "-1",   step: -1,   width: 40, color: .red)
                quantityButton(label: "-20",  step: -20,  width: 48, color: .red)
                
                Button(action: {
                    guard quantity > 0 else {
                        shopModel.updateMessage(
                            "Cannot purchase 0 of \(powerUp.name). Increase quantity first!",
                            success: false
                        )
                        return
                    }
                    
                    let cost = piecewiseTotalCost()
                    guard let currentCoins = coins?.value, currentCoins >= cost else {
                        shopModel.updateMessage(
                            "Not enough coins to buy \(quantity) \(powerUp.name)(s).",
                            success: false
                        )
                        return
                    }
                    // Purchase
                    shopModel.handlePurchase(for: powerUp, quantity: quantity)
                    
                }) {
                    Text("Buy")
                        .font(.headline)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                quantityButton(label: "+1",   step: 1,   width: 40, color: .green)
                quantityButton(label: "+20",  step: 20,  width: 48, color: .green)
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

// MARK: - Piecewise Exponent / Minimal Growth Summation
extension ShopItemView {
    
    /// Calculate cost for the *next single* item (beyond the current quantity).
    private func piecewiseNextCost() -> Decimal {
        let owned = powerUps.quantities[powerUp.name, default: 0]
        let indexForNextItem = owned + quantity
        
        var cost = itemCost(index: indexForNextItem)
        
        // Multiply by difficulty
        cost *= Decimal(store.settings?.difficulty.costMultiplier ?? 1.0)
        
        return clampAndRound(cost)
    }
    
    /// Calculate total cost for the entire "quantity" in a more performant piecewise way.
    private func piecewiseTotalCost() -> Decimal {
        guard quantity > 0 else { return 0 }
        
        let owned = powerUps.quantities[powerUp.name, default: 0]
        let start = owned
        let end   = owned + quantity - 1
        
        // If it’s all below 500 (for example), we do exponent sum
        // If it’s all >= 500, do minimal growth sum
        // If partial overlap, sum them in two segments (split at 499).
        
        var sum = Decimal(0)
        
        if end < 500 {
            // Entire range in exponent zone
            sum = exponentSumRange(startIndex: start, endIndex: end)
        }
        else if start >= 500 {
            // Entire range in minimal growth zone
            sum = minimalGrowthSumRange(startIndex: start, endIndex: end)
        }
        else {
            // Split at 499
            let part1 = exponentSumRange(startIndex: start, endIndex: 499)
            let part2 = minimalGrowthSumRange(startIndex: 500, endIndex: end)
            sum = part1 + part2
        }
        
        // Multiply entire sum by difficulty
        let diff = Decimal(store.settings?.difficulty.costMultiplier ?? 1.0)
        return clampAndRound(sum * diff)
    }
    
    // MARK: - 1) Summation for exponent zone
    private func exponentSumRange(startIndex: Int, endIndex: Int) -> Decimal {
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
    
    // MARK: - 2) Summation for minimal growth zone (index >= 500)
    private func minimalGrowthSumRange(startIndex: Int, endIndex: Int) -> Decimal {
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
    private func itemCost(index: Int) -> Decimal {
        let base = Decimal(powerUp.cost)
        
        if index < 500 {
            // Normal exponent zone
            let cost = base * powDecimal(Decimal(powerUp.costMultiplier), index)
            return clampAndRound(cost)
        } else {
            // Minimal growth after 500
            let costAt499 = base * powDecimal(Decimal(powerUp.costMultiplier), 499)
            // For example, 1.005^(index - 499)
            let offset = index - 499
            let cost = costAt499 * powDecimal(Decimal(1.005), offset)
            return clampAndRound(cost)
        }
    }
}

// MARK: - Utility
extension ShopItemView {
    
    // Clamp & round down to whole
    private func clampAndRound(_ value: Decimal) -> Decimal {
        let clamped = value > Decimal.greatestFiniteMagnitude
            ? Decimal.greatestFiniteMagnitude
            : value
        return clamped.roundedDownToWhole()
    }
    
    // Our improved exponent function
    private func powDecimal(_ base: Decimal, _ exponent: Int) -> Decimal {
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
extension ShopItemView {
    
    // Format big decimals with commas
    private func formattedDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
    
    // Show large or short text with vertical expansion
    @ViewBuilder
    private func dynamicHStack(label: String, value: Decimal, color: Color) -> some View {
        let clamped = (value > Decimal.greatestFiniteMagnitude)
            ? Decimal.greatestFiniteMagnitude
            : value
        let displayValue = clampAndRound(clamped)
        let formattedValue = formattedDecimal(displayValue)
        
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
    
    private func quantityButton(label: String, step: Int, width: CGFloat, color: Color) -> some View {
        Button {
            let newQ = max(0, quantity + step)
            quantity = newQ
            // Update next cost each time quantity changes
            nextCost = piecewiseNextCost()
        } label: {
            Text(label)
                .frame(width: width, height: 40)
                .background(color.opacity(0.7))
                .cornerRadius(8)
                .foregroundColor(.white)
                .bold()
        }
    }
}

// MARK: - Preview
struct ShopItemView_Previews: PreviewProvider {
    static var previews: some View {
        let mockCoins = CryptoCoin(value: Decimal(1000))
        let mockStore = CryptoStore()
        
        ShopItemView(
            powerUp: PowerUps.availablePowerUps.first!,
            coins: .constant(mockCoins)
        )
        .environmentObject(PowerUps.shared)
        .environmentObject(mockStore)
    }
}
