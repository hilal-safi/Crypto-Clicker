//
//  CardModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import Foundation

struct Card: Identifiable, Hashable {
    
    let id = UUID()
    let suit: String
    let value: Int

    // Generate a standard deck of 52 cards
    static func generateDeck() -> [Card] {
        let ranksWithValues = [
            ("A", 1), ("2", 2), ("3", 3), ("4", 4), ("5", 5),
            ("6", 6), ("7", 7), ("8", 8), ("9", 9), ("10", 10),
            ("J", 10), ("Q", 10), ("K", 10)
        ]
        let suits = ["♠️", "♥️", "♦️", "♣️"]

        return suits.flatMap { suit in
            ranksWithValues.map { rank, value in
                Card(suit: suit, value: value)
            }
        }
    }
    
    var displayValue: String {
        switch value {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(value)"
        }
    }
    static let example = Card(suit: "♥️", value: 10)
}
