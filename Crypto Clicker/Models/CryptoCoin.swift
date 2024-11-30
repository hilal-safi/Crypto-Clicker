//
//  CryptoCoin.swift
//  Crypto Clicker
//
//  Initiates the CryptoCoin
//  Created by Hilal Safi on 2024-09-09.
//

import Foundation

struct CryptoCoin: Identifiable, Codable {
    
    let id: UUID
    var value: Int
    var coinsPerSecond: Int // Tracks coins generated per second
    var coinsPerClick: Int // Tracks coins generated per second
    
    init(id: UUID = UUID(), value: Int, coinsPerSecond: Int = 0, coinsPerClick: Int = 1) {
        
        self.id = id
        self.value = value
        self.coinsPerSecond = coinsPerSecond
        self.coinsPerClick = coinsPerClick
    }
}

extension CryptoCoin {
    static let sampleData = CryptoCoin(value: 10, coinsPerSecond: 0)
}
