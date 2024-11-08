//
//  PowerUpInfo.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import Foundation

// Define PowerUpInfo struct in its own file
struct PowerUpInfo: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}
