//
//  PowerUps.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import Foundation

class PowerUps: ObservableObject, Codable {
    
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
            description: "A trusty Chromebook to start mining small amounts of crypto. Increases coin value by 1 every second."
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
    
    enum CodingKeys: CodingKey {
        case chromebook, desktop, server, mineCenter
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chromebook = try container.decode(Int.self, forKey: .chromebook)
        desktop = try container.decode(Int.self, forKey: .desktop)
        server = try container.decode(Int.self, forKey: .server)
        mineCenter = try container.decode(Int.self, forKey: .mineCenter)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(chromebook, forKey: .chromebook)
        try container.encode(desktop, forKey: .desktop)
        try container.encode(server, forKey: .server)
        try container.encode(mineCenter, forKey: .mineCenter)
    }

    init() {}

}
