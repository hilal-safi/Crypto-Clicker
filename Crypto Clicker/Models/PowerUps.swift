//
//  PowerUps.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import Foundation

class PowerUps: ObservableObject, Codable {
    
    static let shared = PowerUps() // Singleton instance
    
    struct PowerUp: Identifiable, Hashable, Codable {
        
        let id: UUID
        let name: String
        let cost: Int   // The "base cost"
        let coinsPerSecondIncrease: Int
        let coinsPerClickIncrease: Int
        let coinsPerStepIncrease: Int
        let miniGameMultiplierIncrease: Int
        let emoji: String
        let description: String
        let costMultiplier: Double  // Cost multiplier for exponential pricing
        
        // Custom initializer for assigning default id
        init(
            id: UUID = UUID(),
            name: String,
            cost: Int,
            coinsPerSecondIncrease: Int,
            coinsPerClickIncrease: Int,
            coinsPerStepIncrease: Int,
            miniGameMultiplierIncrease: Int,
            emoji: String,
            description: String,
            costMultiplier: Double
        ) {
            self.id = id
            self.name = name
            self.cost = cost
            self.coinsPerSecondIncrease = coinsPerSecondIncrease
            self.coinsPerClickIncrease = coinsPerClickIncrease
            self.coinsPerStepIncrease = coinsPerStepIncrease
            self.miniGameMultiplierIncrease = miniGameMultiplierIncrease
            self.emoji = emoji
            self.description = description
            self.costMultiplier = costMultiplier
        }
    }
    
    @Published var quantities: [String: Int] = [:] // Store power-up quantities dynamically
    
    // Static list of available power-ups
    static let availablePowerUps = [
        
        // Refined existing power-ups:
        PowerUp(
            name: "Coin Clicker",
            cost: 100, // Reduced starting cost
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 1,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "👆",
            description: "A basic tap tool to earn a small boost per click. Ideal for early mining.",
            costMultiplier: 1.07 // ~7% increase each time
        ),
        PowerUp(
            name: "Step Booster",
            cost: 200,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 1,
            miniGameMultiplierIncrease: 0,
            emoji: "🥾",
            description: "Adds +1 coin per step each purchase.",
            costMultiplier: 1.07
        ),
        PowerUp(
            name: "Chromebook",
            cost: 300,
            coinsPerSecondIncrease: 1,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "💻",
            description: "A trusty Chromebook for light-duty mining. Grants +1 coin/second.",
            costMultiplier: 1.07
        ),
        PowerUp(
            name: "5% Bonus Reward",
            cost: 500,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 5,
            emoji: "🎉",
            description: "Adds a 5% bonus to coin rewards after each game.",
            costMultiplier: 1.10
        ),
        PowerUp(
            name: "Upgraded Clicker",
            cost: 1200,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 10,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "💪",
            description: "Enhances your clicks significantly, adding +10 coins/click.",
            costMultiplier: 1.09
        ),
        PowerUp(
            name: "Desktop",
            cost: 3000,
            coinsPerSecondIncrease: 20,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "🖥️",
            description: "A powerful desktop for consistent mining, generating +20 coins/second.",
            costMultiplier: 1.08
        ),
        PowerUp(
            name: "25% Bonus Reward",
            cost: 5000,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 25,
            emoji: "💎",
            description: "Adds a 25% bonus to coin rewards after each game.",
            costMultiplier: 1.12
        ),
        PowerUp(
            name: "Upgraded Step Booster",
            cost: 15000,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 50,
            miniGameMultiplierIncrease: 0,
            emoji: "👟",
            description: "Adds +50 coins per step each purchase.",
            costMultiplier: 1.08
        ),
        PowerUp(
            name: "100% Bonus Reward",
            cost: 20000,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 100,
            emoji: "🏆",
            description: "Doubles the coin rewards after each game.",
            costMultiplier: 1.15
        ),
        PowerUp(
            name: "Server",
            cost: 15000,
            coinsPerSecondIncrease: 100,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "📡",
            description: "A dedicated server for hefty yields, adding +100 coins/second.",
            costMultiplier: 1.10
        ),
        PowerUp(
            name: "Automated Clicker",
            cost: 70000,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 500,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "🦾",
            description: "Automates your clicking with +500 coins per manual click input.",
            costMultiplier: 1.10
        ),
        PowerUp(
            name: "Mine Center",
            cost: 500000,
            coinsPerSecondIncrease: 2000,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "⛏️",
            description: "A full-blown mining center, yielding +2,000 coins/second.",
            costMultiplier: 1.12
        ),
        PowerUp(
            name: "Ultimate Step Booster",
            cost: 500000,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 0,
            coinsPerStepIncrease: 1000,
            miniGameMultiplierIncrease: 0,
            emoji: "🦿",
            description: "Adds +1000 coins per step each purchase.",
            costMultiplier: 1.10
        ),
        PowerUp(
            name: "Robot Assistant",
            cost: 2000000,
            coinsPerSecondIncrease: 5000,
            coinsPerClickIncrease: 20000,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "🤖",
            description: "A cutting-edge robot that mines +5,000 coins/second & boosts clicks by 20,000.",
            costMultiplier: 1.15
        ),
        PowerUp(
            name: "AI Miner",
            cost: 25000000,
            coinsPerSecondIncrease: 10000,
            coinsPerClickIncrease: 50000,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "🧠",
            description: "Harness advanced AI to massively accelerate your cryptomining operations.",
            costMultiplier: 1.18
        ),
        PowerUp(
            name: "Quantum Computer",
            cost: 100000000,
            coinsPerSecondIncrease: 100000,
            coinsPerClickIncrease: 100000,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "🔮",
            description: "Leverage quantum entanglement for mind-boggling mining speed.",
            costMultiplier: 1.20
        ),
        PowerUp(
            name: "Space Mining Colony",
            cost: 1000000000,
            coinsPerSecondIncrease: 1000000,
            coinsPerClickIncrease: 1000000,
            coinsPerStepIncrease: 0,
            miniGameMultiplierIncrease: 0,
            emoji: "🚀",
            description: "Take your operation off-world to extract resources at a cosmic scale.",
            costMultiplier: 1.25
        )
    ]

    private static var initialized = false
    
    private init() {
        
        if Self.initialized {
            fatalError("[ERROR] Multiple instances of PowerUps are being created!")
        }
        Self.initialized = true
        
        for powerUp in Self.availablePowerUps {
            quantities[powerUp.name] = 0
        }
    }

    func resetAll() {
        quantities = [:]
    }
    
    // MARK: - Next Cost for a Single Additional Power-Up
    func nextCost(for powerUp: PowerUp) -> Decimal {
        
        let owned = quantities[powerUp.name, default: 0]
        
        // We'll get the cost of exactly one more item at index = owned
        let costForOneMore = itemCost(powerUp: powerUp, index: owned)
        
        // Ensure it doesn't exceed Decimal.greatestFiniteMagnitude
        return min(costForOneMore, Decimal.greatestFiniteMagnitude)
            .roundedDownToWhole()
    }

    // MARK: - Total Cost for Purchasing a Specific Quantity
    func totalCost(for powerUp: PowerUp, quantity: Int) -> Decimal {
        
        let owned = quantities[powerUp.name, default: 0]
        var total: Decimal = 0
        
        for i in 0..<quantity {
            let index = owned + i  // cost of the i-th new item
            var cost = itemCost(powerUp: powerUp, index: index)
            
            if cost > Decimal.greatestFiniteMagnitude {
                cost = Decimal.greatestFiniteMagnitude
            }
            let newTotal = total + cost
            if newTotal > Decimal.greatestFiniteMagnitude {
                return Decimal.greatestFiniteMagnitude
            }
            total = newTotal
        }
        return total.roundedDownToWhole()
    }
    
    // MARK: - Item Cost by Index
    // This is where we do piecewise logic:
    ///  - For index < 500 -> exponent-based
    ///  - For index >= 500 -> apply a small linear or minimal growth each item
    private func itemCost(powerUp: PowerUp, index: Int) -> Decimal {
        
        let base = Decimal(powerUp.cost).roundedDownToWhole()
        
        if index < 500 {
            // Normal exponent
            let effectiveMultiplier = adjustedMultiplier(powerUp.costMultiplier, index)
            var cost = base * powDecimal(effectiveMultiplier, index)
            
            if cost > Decimal.greatestFiniteMagnitude {
                cost = Decimal.greatestFiniteMagnitude
            }
            return cost.roundedDownToWhole()
            
        } else {
            // Past 500, do minimal growth. For example, let’s do +1% each item beyond 1000
            // Or you could do linear increments, e.g. cost = costAt999 + (index - 999)*500
            // Here we’ll do an example of a minimal 1.005^(index-999) growth from cost at 999.
            
            let costAt499 = itemCost(powerUp: powerUp, index: 499)
            // We'll do a small factor (e.g. 1.005^(index-999)):
            let beyond = index - 499
            var cost = costAt499 * powDecimal(Decimal(1.005), beyond)
            
            if cost > Decimal.greatestFiniteMagnitude {
                cost = Decimal.greatestFiniteMagnitude
            }
            return cost.roundedDownToWhole()
        }
    }

    // MARK: - Custom Decimal exponent
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
    
    // MARK: - Purchase Method
    func purchase(powerUp: PowerUp, coins: inout CryptoCoin, quantity: Int) -> Bool {
        
        let totalCost = self.totalCost(for: powerUp, quantity: quantity)
        if totalCost > Decimal.greatestFiniteMagnitude {
            print("[ERROR] Calculated cost is too large (NaN risk). Purchase canceled.")
            return false
        }
        
        guard coins.value >= totalCost else {
            print("[ERROR] Not enough coins to purchase \(quantity) \(powerUp.name). Required: \(totalCost), Available: \(coins.value)")
            return false
        }

        // Deduct cost
        coins.value = (coins.value - totalCost).roundedDownToWhole()
        
        // Increase quantity
        quantities[powerUp.name, default: 0] += quantity
        print("[INFO] Purchased \(quantity) \(powerUp.name). Remaining coins: \(coins.value)")
        return true
    }
    
    // MARK: - Additional Utility
    func quantity(for name: String) -> Int {
        quantities[name, default: 0]
    }
    
    // Codable conformance
    enum CodingKeys: CodingKey {
        case quantities
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quantities = try container.decode([String: Int].self, forKey: .quantities)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(quantities, forKey: .quantities)
    }
    
    // For Achievements
    func getOwnedCount(for powerUpName: String) -> Int {
        return quantities[powerUpName] ?? 0
    }
    
    func calculateTotalOwned() -> Int {
        quantities.values.reduce(0, +)
    }

    func calculateCoinsPerSecond() -> Int {
        PowerUps.availablePowerUps.reduce(0) { total, powerUp in
            let q = quantities[powerUp.name, default: 0]
            return total + (powerUp.coinsPerSecondIncrease * q)
        }
    }

    func calculateCoinsPerClick() -> Int {
        PowerUps.availablePowerUps.reduce(0) { total, powerUp in
            let q = quantities[powerUp.name, default: 0]
            return total + (powerUp.coinsPerClickIncrease * q)
        }
    }
        
    func debugQuantities() {
        print("[DEBUG] Power-Up Quantities:")
        for (key, value) in quantities {
            print("[DEBUG] \(key): \(value)")
        }
        let total = quantities.values.reduce(0, +)
        print("[DEBUG] Calculated total owned power-ups: \(total)")
    }
    
    // MARK: - Adjusted Multiplier (0..999 only)
    // You can still keep some "diminishing returns" logic for <1000 if you like.
    private func adjustedMultiplier(_ baseMultiplier: Double, _ countSoFar: Int) -> Decimal {
        // Example: If user has over 50 => half. If user has over 120 => quarter, etc.
        // Tweak as needed, but won't affect indexes >= 1000 (those skip here).
        
        if countSoFar >= 120 {
            // Quarter of the original
            return Decimal(baseMultiplier / 4.0)
        } else if countSoFar >= 50 {
            // Half of the original
            return Decimal(baseMultiplier / 2.0)
        } else {
            // Normal multiplier
            return Decimal(baseMultiplier)
        }
    }
}
