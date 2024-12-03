//
//  PowerUps.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import Foundation

class PowerUps: ObservableObject, Codable {
    
    @Published var quantities: [String: Int] = [:] // Store power-up quantities dynamically

    static let powerUps = [
        PowerUpInfo(
            name: "Coin Clicker",
            cost: 500,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 1,
            emoji: "👆",
            description: "Adds an additional click, to assist you with mining coins. Increases the coin value per click by 1."
        ),
        PowerUpInfo(
            name: "Chromebook",
            cost: 100,
            coinsPerSecondIncrease: 1,
            coinsPerClickIncrease: 0,
            emoji: "💻",
            description: "A trusty Chromebook to start mining small amounts of crypto. Increases coin value by 1 every second."
        ),
        PowerUpInfo(
            name: "Upgraded Clicker",
            cost: 20000,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 100,
            emoji: "💪",
            description: "Boosts clicks to generate 100 coins per click."
        ),
        PowerUpInfo(
            name: "Desktop",
            cost: 2500,
            coinsPerSecondIncrease: 25,
            coinsPerClickIncrease: 0,
            emoji: "🖥️",
            description: "A powerful desktop for faster mining. Increases coin value by 25 every second."
        ),
        PowerUpInfo(
            name: "Server",
            cost: 50000,
            coinsPerSecondIncrease: 100,
            coinsPerClickIncrease: 0,
            emoji: "📡",
            description: "A dedicated server to mine crypto efficiently. Increases coin value by 100 every second."
        ),
        PowerUpInfo(
            name: "Automated Clicker",
            cost: 100000,
            coinsPerSecondIncrease: 0,
            coinsPerClickIncrease: 50000,
            emoji: "🦾",
            description: "Automates 50,000 clicks."
        ),
        PowerUpInfo(
            name: "Mine Center",
            cost: 3000000,
            coinsPerSecondIncrease: 100,
            coinsPerClickIncrease: 0,
            emoji: "⛏️",
            description: "A full mining center for maximum crypto output. Increases coin value by 3000 every second."
        ),
        PowerUpInfo(
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
        for powerUp in Self.powerUps {
            quantities[powerUp.name] = 0
        }
    }

    func purchase(powerUp: PowerUpInfo, coins: inout CryptoCoin, quantity: Int) -> Bool {
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
}
