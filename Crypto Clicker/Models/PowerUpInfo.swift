//
//  PowerUpInfo.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import Foundation

// Define PowerUpInfo struct in its own file

struct PowerUpInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let cost: Int
    let coinsPerSecondIncrease: Int
    let emoji: String
    let description: String

    // Ensure equality is based on unique `id`
    static func == (lhs: PowerUpInfo, rhs: PowerUpInfo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
