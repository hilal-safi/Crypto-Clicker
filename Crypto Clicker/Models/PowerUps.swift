//
//  PowerUps.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import Foundation

class PowerUps: ObservableObject {
    @Published var chromebook = 0
    @Published var desktop = 0
    @Published var server = 0
    @Published var mineCenter = 0

    static let powerUps = [
        PowerUpInfo(
            name: "Chromebook",
            cost: 50,
            coinsPerSecondIncrease: 1,
            emoji: "💻",
            description: "A trusty Chromebook to start mining small amounts of crypto. Increases coin value by 1 every seconds."
        ),
        PowerUpInfo(
            name: "Desktop",
            cost: 200,
            coinsPerSecondIncrease: 5,
            emoji: "🖥️",
            description: "A powerful desktop for faster mining. Increases coin value by 5 every second."
        ),
        PowerUpInfo(
            name: "Server",
            cost: 1000,
            coinsPerSecondIncrease: 10,
            emoji: "📡",
            description: "A dedicated server to mine crypto efficiently. Increases coin value by 10 every second."
        ),
        PowerUpInfo(
            name: "Mine Center",
            cost: 10000,
            coinsPerSecondIncrease: 100,
            emoji: "⛏️",
            description: "A full mining center for maximum crypto output. Increases coin value by 100 every second."
        )
    ]

    func purchase(powerUp: PowerUpInfo, coins: inout CryptoCoin, quantity: Int) -> Bool {
        let totalCost = powerUp.cost * quantity
        guard coins.value >= totalCost else { return false }

        coins.value -= totalCost

        switch powerUp.name {
        case "Chromebook":
            chromebook += quantity
        case "Desktop":
            desktop += quantity
        case "Server":
            server += quantity
        case "Mine Center":
            mineCenter += quantity
        default:
            break
        }
        return true
    }
}
