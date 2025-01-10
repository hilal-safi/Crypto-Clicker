//
//  MiniGamesModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import Foundation

class MiniGamesModel: ObservableObject {
    
    enum MiniGame: String, Codable {
        case blackjack
        case tetris
    }

    @Published var isBlackjackUnlocked: Bool = false
    @Published var isTetrisUnlocked: Bool = false

    /// Unlock cost for each mini-game
    private let unlockCosts: [MiniGame: Decimal] = [
        .blackjack: 1000,
        .tetris: 8000
    ]

    /// Returns the cost to unlock a specific mini-game
    func unlockCost(for game: MiniGame) -> Decimal {
        return unlockCosts[game] ?? 0
    }

    /// Marks a mini-game as unlocked and persists the state
    /// - Parameter game: The mini-game to unlock
    func markAsUnlocked(_ game: MiniGame) {
        switch game {
        case .blackjack:
            isBlackjackUnlocked = true
        case .tetris:
            isTetrisUnlocked = true
        }
        saveUnlockedStates()
    }

    /// Checks if a mini-game is already unlocked
    /// - Parameter game: The mini-game to check
    /// - Returns: True if the game is unlocked
    func isUnlocked(_ game: MiniGame) -> Bool {
        switch game {
        case .blackjack:
            return isBlackjackUnlocked
        case .tetris:
            return isTetrisUnlocked
        }
    }

    /// Save unlocked states to UserDefaults
    func saveUnlockedStates() {
        let unlockedStates = [
            MiniGame.blackjack: isBlackjackUnlocked,
            MiniGame.tetris: isTetrisUnlocked
        ]
        if let data = try? JSONEncoder().encode(unlockedStates) {
            UserDefaults.standard.set(data, forKey: "MiniGamesUnlockedStates")
        }
    }

    /// Load unlocked states from UserDefaults
    func loadUnlockedStates() {
        guard let data = UserDefaults.standard.data(forKey: "MiniGamesUnlockedStates"),
              let unlockedStates = try? JSONDecoder().decode([MiniGame: Bool].self, from: data) else {
            return
        }
        isBlackjackUnlocked = unlockedStates[.blackjack] ?? false
        isTetrisUnlocked = unlockedStates[.tetris] ?? false
    }

    init() {
        loadUnlockedStates()
    }
}
