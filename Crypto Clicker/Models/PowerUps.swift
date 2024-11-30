//
//  PowerUps.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import Foundation

class PowerUps: ObservableObject, Codable {
    
    @Published var coinClicker = 0
    @Published var chromebook = 0
    @Published var desktop = 0
    @Published var server = 0
    @Published var mineCenter = 0

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
            cost: 50,
            coinsPerSecondIncrease: 1,
            coinsPerClickIncrease: 0,
            emoji: "💻",
            description: "A trusty Chromebook to start mining small amounts of crypto. Increases coin value by 1 every second."
        ),
        PowerUpInfo(
            name: "Desktop",
            cost: 200,
            coinsPerSecondIncrease: 5,
            coinsPerClickIncrease: 0,
            emoji: "🖥️",
            description: "A powerful desktop for faster mining. Increases coin value by 5 every second."
        ),
        PowerUpInfo(
            name: "Server",
            cost: 1000,
            coinsPerSecondIncrease: 10,
            coinsPerClickIncrease: 0,
            emoji: "📡",
            description: "A dedicated server to mine crypto efficiently. Increases coin value by 10 every second."
        ),
        PowerUpInfo(
            name: "Mine Center",
            cost: 10000,
            coinsPerSecondIncrease: 100,
            coinsPerClickIncrease: 0,
            emoji: "⛏️",
            description: "A full mining center for maximum crypto output. Increases coin value by 100 every second."
        )
    ]
    
    func purchase(powerUp: inout PowerUpInfo, coins: inout CryptoCoin, quantity: Int) -> Bool {
        
        let totalCost = powerUp.cost * quantity
        guard coins.value >= totalCost else { return false }

        coins.value -= totalCost

        switch powerUp.name {
        case "Coin Clicker":
            coinClicker += quantity
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
        case coinClicker, chromebook, desktop, server, mineCenter, quantities
    }

    required init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        coinClicker = try container.decode(Int.self, forKey: .coinClicker)
        chromebook = try container.decode(Int.self, forKey: .chromebook)
        desktop = try container.decode(Int.self, forKey: .desktop)
        server = try container.decode(Int.self, forKey: .server)
        mineCenter = try container.decode(Int.self, forKey: .mineCenter)
        
    }

    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(coinClicker, forKey: .coinClicker)
        try container.encode(chromebook, forKey: .chromebook)
        try container.encode(desktop, forKey: .desktop)
        try container.encode(server, forKey: .server)
        try container.encode(mineCenter, forKey: .mineCenter)
        
    }
    
    init() {}
}

extension PowerUps {
    
    func quantity(for name: String) -> Int {
        
        switch name {
            
        case "Coin Clicker":
            return coinClicker
            
        case "Chromebook":
            return chromebook
            
        case "Desktop":
            return desktop
            
        case "Server":
            return server
            
        case "Mine Center":
            return mineCenter
            
        default:
            return 0
        }
    }
}
