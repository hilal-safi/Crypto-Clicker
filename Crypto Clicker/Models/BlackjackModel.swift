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
    @Published var betAmount: Int = 0
    
    @Published var gameState: BlackjackGameState = .waitingForBet
    @Published var gameOver: Bool = false
    @Published var resultMessage: String? = nil
    
    private var deck: [Card] = []
    
    init(initialBalance: Int, playerBalance: Int) {
        self.initialBalance = initialBalance
        self.playerBalance = playerBalance
        self.deck = createDeck().shuffled()
        print("Game initialized with player balance: \(playerBalance)")
    }
    
    // MARK: - Deck and Card Management
    
    func createDeck() -> [Card] {
        
        let suits = ["♠", "♥", "♦", "♣"]
        let values = (1...13).map { $0 }
        
        let deck = suits.flatMap { suit in
            values.map { value in
                Card(suit: suit, value: value)
            }
        }
        
        print("Deck created with \(deck.count) cards.")
        
        return deck
    }
    
    func drawCard() -> Card {
        
        if deck.isEmpty {
            print("Deck is empty. Creating and shuffling a new deck.")
            deck = createDeck().shuffled()
        }
        
        let card = deck.removeFirst()
        print("Drew card: \(card.suit)\(card.value)")
        
        return card
    }
    
    // MARK: - Game Logic
    
    func placeBet(amount: Int) {
        
        guard amount > 0, playerBalance >= amount else {
            print("Invalid bet. Amount: \(amount), Player Balance: \(playerBalance)")
            return
        }
        
        // Clear previous round data only when placing a new bet
        deck = createDeck().shuffled() // Reset deck here
        dealerHand = []
        playerHand = []
        dealerValue = 0
        playerValue = 0

        betAmount = amount
        playerBalance -= amount
        betPlaced = true
        gameState = .playerTurn
        
        print("Bet placed: \(amount). Player balance is now: \(playerBalance)")
        startGame()
    }
    
    func startGame() {
        
        print("Starting a new game...")
        
        dealerHand = [drawCard(), drawCard()]
        playerHand = [drawCard(), drawCard()]
        calculateHandValues()
        
        print("Game started. Dealer Hand: \(dealerHand), Player Hand: \(playerHand)")
    }
    
    func hitPlayer() {
        
        guard betPlaced, !gameOver else {
            print("Cannot hit. Either no bet has been placed or the game is over.")
            return
        }
        
        let card = drawCard()
        playerHand.append(card)
        
        print("Player hits and draws: \(card.suit)\(card.value)")
        calculateHandValues()
        
        if playerValue > 21 {
            
            gameState = .playerBust
            resultMessage = "You Lose! Bust!"
            gameOver = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.resetGame()
            }

            print("Player busts. Game over.")
        }
    }
    
    func stand() {
        
        guard betPlaced, !gameOver else {
            print("Cannot stand. Either no bet has been placed or the game is over.")
            return
        }
        print("Player stands. Dealer's turn.")
        gameState = .dealerTurn
        
        // Start the dealer's turn
        handleDealerTurn()
    }
    
    func handleDealerTurn() {
        
        guard gameState == .dealerTurn else { return }

        print("Dealer's turn starts.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            if self.dealerValue < 17 {
                // Dealer draws a card
                let card = self.drawCard()
                self.dealerHand.append(card)
                self.calculateHandValues()
                print("Dealer draws: \(card.suit)\(card.value)")

                if self.dealerValue > 21 {
                    // Dealer busts
                    self.gameState = .dealerBust
                    self.resultMessage = "You Win! Dealer Bust!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.resetGame()
                    }
                } else {
                    // Continue dealer's turn
                    self.handleDealerTurn()
                }
            } else {
                // Dealer stands
                print("Dealer stands.")
                let result = self.checkWinCondition()
                self.resultMessage = result
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.resetGame()
                }
            }
        }
    }
    
    private func calculateHandValues() {
        
        playerValue = calculateHandValue(for: playerHand)
        dealerValue = calculateHandValue(for: dealerHand)
        
        print("Player Value: \(playerValue), Dealer Value: \(dealerValue)")
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
            
            resultMessage = "You Lose! Bust!"
            gameState = .dealerWin
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.resetGame()
            }
            
            print("Player busts. Dealer wins.")
            return resultMessage!
            
        } else if dealerValue > 21 {
            
            resultMessage = "You Win! Dealer Bust!"
            gameState = .playerWin
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.resetGame()
            }

            print("Dealer busts. Player wins.")
            return resultMessage!
            
        } else if playerValue > dealerValue {
            
            resultMessage = "You Win!"
            gameState = .playerWin
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.resetGame()
            }

            print("Player wins with \(playerValue) over Dealer's \(dealerValue).")
            return resultMessage!
            
        } else if dealerValue > playerValue {
            
            resultMessage = "You Lose!"
            gameState = .dealerWin
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.resetGame()
            }

            print("Dealer wins with \(dealerValue) over Player's \(playerValue).")
            return resultMessage!
            
        } else {
            
            resultMessage = "It's a Draw!"
            gameState = .tie
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.resetGame()
            }

            print("It's a draw. Player: \(playerValue), Dealer: \(dealerValue).")
            return resultMessage!
        }
    }
    
    
    enum BlackjackGameState {
        case waitingForBet
        case playerTurn
        case dealerTurn
        case playerWin
        case dealerWin
        case tie
        case playerBust
        case dealerBust
    }
    
    func resetGame() {
        betPlaced = false
        betAmount = 0
        resultMessage = nil
        gameOver = false
        gameState = .waitingForBet
        print("Game has been reset. Ready for a new round.")
    }
}
