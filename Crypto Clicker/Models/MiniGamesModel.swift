//
//  MiniGamesModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import Foundation

class MiniGamesModel: ObservableObject {
    @Published var isBlackjackUnlocked: Bool = false
    @Published var isTetrisUnlocked: Bool = false

    /// Unlocks a mini-game if sufficient coins are available
    /// - Parameters:
    ///   - miniGame: The mini-game to unlock (Blackjack or Tetris)
    ///   - coins: The current coin value
    /// - Returns: Boolean indicating if the unlock was successful
    func unlock(miniGame: MiniGame, coins: inout Decimal) -> Bool {
        
        switch miniGame {
            
        case .blackjack:
            if coins >= 1000 {
                coins -= 1000
                isBlackjackUnlocked = true
                return true
            }
        case .tetris:
            if coins >= 5000 {
                coins -= 5000
                isTetrisUnlocked = true
                return true
            }
        }
        return false
    }
    
    enum MiniGame {
        case blackjack, tetris
    }
}
