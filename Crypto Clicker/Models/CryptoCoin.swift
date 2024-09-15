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
    
    init(id: UUID = UUID(), value: Int) {
        
        self.id = id
        self.value = value
    }
}

extension CryptoCoin {
    static let sampleData = CryptoCoin(value: 10)
}
