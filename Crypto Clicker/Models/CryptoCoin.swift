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
    var value: Decimal
    var coinsPerSecond: Decimal // Tracks coins generated per second
    var coinsPerClick: Decimal // Tracks coins generated per second
    var coinsPerStep: Decimal // Tracks coins generated per step (for Apple Watch app)
    
    init(
        id: UUID = UUID(),
        value: Decimal,
        coinsPerSecond: Decimal = 0,
        coinsPerClick: Decimal = 1,
        coinsPerStep: Decimal = 1) {
        
        self.id = id
        self.value = value
        self.coinsPerSecond = coinsPerSecond
        self.coinsPerClick = coinsPerClick
        self.coinsPerStep = coinsPerStep
    }
}

extension CryptoCoin {
    
    static let sampleData = CryptoCoin(
        value: Decimal(10),
        coinsPerSecond: Decimal(0),
        coinsPerClick: Decimal(1),
        coinsPerStep: Decimal(1))
}
