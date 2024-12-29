//
//  PowerUps.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import Foundation

class PowerUps: ObservableObject, Codable {
    
    struct PowerUp: Identifiable, Hashable, Codable {
        
        let id: UUID
        let name: String
        let cost: Int
        let coinsPerSecondIncrease: Int
        let coinsPerClickIncrease: Int
        let emoji: String
        let description: String
        
        // Custom initializer for assigning default id
        init(
            id: UUID = UUID(),
            name: String,
            cost: Int,
            coinsPerSecondIncrease: Int,
            coinsPerClickIncrease: Int,
            emoji: String,
            description: String
        ) {
            self.id = id
            self.name = name
            self.cost = cost
            self.coinsPerSecondIncrease = coinsPerSecondIncrease
            self.coinsPerClickIncrease = coinsPerClickIncrease
            self.emoji = emoji
            self.description = description
        }
    }
    
    @Published var quantities: [String: Int] = [:] // Store power-up quantities dynamically
    
    // Static list of available power-ups
    static let availablePowerUps = [
        PowerUp(
            name: "Coin Clicker",
            cost: 500,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 1,
            emoji: "👆",
            description: "Adds an additional click, to assist you with mining coins. Increases the coin value per click by 1."
        ),
        PowerUp(
            name: "Chromebook",
            cost: 100,
            coinsPerSecondIncrease: 1,
            coinsPerClickIncrease: 0,
            emoji: "💻",
            description: "A trusty Chromebook to start mining small amounts of crypto. Increases coin value by 1 every second."
        ),
        PowerUp(
            name: "Upgraded Clicker",
            cost: 20000,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 100,
            emoji: "💪",
            description: "Boosts clicks to generate 100 coins per click."
        ),
        PowerUp(
            name: "Desktop",
            cost: 2500,
            coinsPerSecondIncrease: 30,
            coinsPerClickIncrease: 0,
            emoji: "🖥️",
            description: "A powerful desktop for faster mining. Increases coin value by 30 every second."
        ),
        PowerUp(
            name: "Server",
            cost: 50000,
            coinsPerSecondIncrease: 100,
            coinsPerClickIncrease: 0,
            emoji: "📡",
            description: "A dedicated server to mine crypto efficiently. Increases coin value by 100 every second."
        ),
        PowerUp(
            name: "Automated Clicker",
            cost: 100000,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 50000,
            emoji: "🦾",
            description: "Automates 50,000 clicks."
        ),
        PowerUp(
            name: "Mine Center",
            cost: 3000000,
            coinsPerSecondIncrease: 100,
            coinsPerClickIncrease: 0,
            emoji: "⛏️",
            description: "A full mining center for maximum crypto output. Increases coin value by 3000 every second."
        ),
        PowerUp(
            name: "Robot Assistant",
            cost: 10000000,
            coinsPerSecondIncrease: 10000,
            coinsPerClickIncrease: 250000,
            emoji: "🤖",
            description: "Provides 250,000 clicks and 10,000 coins per second."
        )
    ]
    
    init() {
        // Initialize all quantities to zero
        for powerUp in Self.availablePowerUps {
            quantities[powerUp.name] = 0
        }
    }
    
    func purchase(powerUp: PowerUp, coins: inout CryptoCoin, quantity: Int) -> Bool {
        
        let totalCost = powerUp.cost * quantity
        guard coins.value >= totalCost else { return false }
        
        coins.value -= totalCost
        quantities[powerUp.name, default: 0] += quantity
        return true
    }
    
    func quantity(for name: String) -> Int {
        return quantities[name, default: 0]
    }
    
    // Codable conformance for saving and loading data
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
        return quantities[powerUpName, default: 0]
    }

    var totalOwnedPowerUps: Int {
        return quantities.values.reduce(0) { $0 + $1 }
    }
}
