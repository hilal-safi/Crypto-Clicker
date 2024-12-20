//
//  BlackjackModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import Foundation

class BlackjackModel: ObservableObject {
    @Published var initialBalance: Int
    @Published var playerBalance: Int
    @Published var dealerHand: [Card] = []
    @Published var playerHand: [Card] = []
    @Published var dealerValue: Int = 0
    @Published var playerValue: Int = 0
    @Published var betPlaced: Bool = false

    private var deck: [Card] = []
    private var betAmount: Int = 0
    
    init(initialBalance: Int, playerBalance: Int) {
        self.initialBalance = initialBalance
        self.playerBalance = playerBalance
        self.deck = createDeck().shuffled()
    }
    
    // MARK: - Deck and Card Management
    
    func createDeck() -> [Card] {
        let suits = ["♠", "♥", "♦", "♣"]
        let values = (1...13).map { $0 }
        
        return suits.flatMap { suit in
            values.map { value in
                Card(suit: suit, value: value)
            }
        }
    }
    
    func drawCard() -> Card {
        guard !deck.isEmpty else {
            deck = createDeck().shuffled() // Reset the deck if it's empty
            return drawCard()
        }
        return deck.removeFirst()
    }
    
    // MARK: - Game Logic
    
    func placeBet(amount: Int) {
        guard amount > 0, playerBalance >= amount else { return }
        betAmount = amount
        playerBalance -= amount
        betPlaced = true
        startGame()
    }
    
    func startGame() {
        dealerHand = [drawCard(), drawCard()]
        playerHand = [drawCard(), drawCard()]
        calculateHandValues()
    }
    
    func hitPlayer() {
        guard betPlaced else { return }
        playerHand.append(drawCard())
        calculateHandValues()
    }
    
    func stand() {
        guard betPlaced else { return }
        while dealerValue < 17 { // Dealer must hit until the value is 17 or more
            dealerHand.append(drawCard())
            calculateHandValues()
        }
        let gameResult = checkWinCondition()
        print(gameResult) // Optional: Replace with your UI update logic
    }
    
    private func calculateHandValues() {
        playerValue = calculateHandValue(for: playerHand)
        dealerValue = calculateHandValue(for: dealerHand)
    }
    
    private func calculateHandValue(for hand: [Card]) -> Int {
        var total = 0
        var aceCount = 0
        
        for card in hand {
            if card.value == 1 { // Ace
                aceCount += 1
                total += 11 // Count ace as 11 initially
            } else if card.value >= 10 {
                total += 10 // Face cards are worth 10
            } else {
                total += card.value
            }
        }
        
        while total > 21 && aceCount > 0 {
            total -= 10 // Convert an ace from 11 to 1
            aceCount -= 1
        }
        
        return total
    }
    
    func checkWinCondition() -> String {
        if playerValue > 21 {
            return "Bust! Dealer Wins."
        } else if dealerValue > 21 {
            playerBalance += betAmount * 2
            return "Dealer Bust! You Win."
        } else if playerValue > dealerValue {
            playerBalance += betAmount * 2
            return "You Win!"
        } else if playerValue < dealerValue {
            return "Dealer Wins."
        } else {
            playerBalance += betAmount // Return the bet amount on a draw
            return "It's a Draw."
        }
    }
    
    func resetGame() {
        dealerHand = []
        playerHand = []
        dealerValue = 0
        playerValue = 0
        betPlaced = false
        betAmount = 0
    }
}
