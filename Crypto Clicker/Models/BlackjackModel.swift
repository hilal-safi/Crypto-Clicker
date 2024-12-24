//
//  BlackjackModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import Foundation

class BlackjackModel: ObservableObject {
    
    @Published var selectedCoinType: CoinType = .dogecoin // Default coin type
    
    @Published var dealerHand: [Card] = []
    @Published var playerHand: [Card] = []
    
    @Published var dealerSecondCardHidden: Bool = true
    
    @Published var dealerValue: Int = 0
    @Published var playerValue: Int = 0
    
    @Published var betPlaced: Bool = false
    @Published var betAmount: Int = 1
    
    @Published var gameState: BlackjackGameState = .waitingForBet
    @Published var gameOver: Bool = false
    @Published var resultMessage: String? = nil

    private var deck: [Card] = []
    private let exchangeModel: CoinExchangeModel

    init(exchangeModel: CoinExchangeModel) {
        
        self.exchangeModel = exchangeModel
        self.deck = createDeck().shuffled()
        
        print("Game initialized with \(selectedCoinType.rawValue) balance: \(exchangeModel.count(for: selectedCoinType))")
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
        
        guard amount > 0, exchangeModel.count(for: selectedCoinType) >= amount else {
            print("Invalid bet. Amount: \(amount), \(selectedCoinType.rawValue) Balance: \(exchangeModel.count(for: selectedCoinType))")
            resultMessage = "Insufficient balance to place the bet."
            return
        }
        
        // Deduct coins and reset game state
        betAmount = amount
        _ = exchangeModel.updateCoinCount(for: selectedCoinType, by: -amount) // Deduct bet amount

        
        // Reset game state
        betPlaced = true
        dealerSecondCardHidden = true // Reset the hidden state
        gameState = .playerTurn
        gameOver = false
        resultMessage = nil
        
        print("Bet placed: \(amount). Remaining \(selectedCoinType.rawValue) balance: \(exchangeModel.count(for: selectedCoinType))")
        startGame()
    }
    
    func startGame() {
        
        print("Starting a new game...")
        
        dealerHand = [drawCard(), drawCard()]
        playerHand = [drawCard(), drawCard()]
        dealerSecondCardHidden = true // Hide dealer's second card initially
        
        calculateHandValues()
        checkForBlackjack()
        
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
        
        if playerValue == 21 {
            print("Player has 21! Automatically standing.")
            stand()
            return
        }

        if playerValue > 21 {
            finalizeGame(withResult: .playerBust, playerValue: playerValue, dealerValue: dealerValue)
        }
    }
    
    func stand() {
        
        guard betPlaced, !gameOver else {
            print("Cannot stand. Either no bet has been placed or the game is over.")
            return
        }
        
        print("Player stands. Dealer's turn.")
        gameState = .dealerTurn
        handleDealerTurn()
    }
    
    func handleDealerTurn() {
        
        guard gameState == .dealerTurn else { return }
        
        dealerSecondCardHidden = false
        print("Dealer's turn starts.")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            if self.dealerValue < 17 {
                
                let card = self.drawCard()
                
                self.dealerHand.append(card)
                self.calculateHandValues()
                
                print("Dealer draws: \(card.suit)\(card.value)")
                
                if self.dealerValue > 21 {
                    self.finalizeGame(withResult: .dealerBust, playerValue: self.playerValue, dealerValue: self.dealerValue)
                    
                } else {
                    self.handleDealerTurn()
                }
            } else {
                print("Dealer stands.")
                self.checkWinCondition()
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
            if card.value == 1 {
                aceCount += 1
                total += 11
            } else if card.value >= 10 {
                total += 10
            } else {
                total += card.value
            }
        }
        while total > 21 && aceCount > 0 {
            total -= 10
            aceCount -= 1
        }
        return total
    }
    
    private func checkForBlackjack() {
        
        let initialValue = calculateHandValue(for: playerHand)
        
        if initialValue == 21 {
            finalizeGame(withResult: .blackjack, playerValue: initialValue, dealerValue: dealerValue)
        }
    }
    
    func checkWinCondition() {
        
        let playerFinalValue = calculateHandValue(for: playerHand)
        let dealerFinalValue = calculateHandValue(for: dealerHand)
        
        if playerFinalValue > 21 {
            finalizeGame(withResult: .playerBust, playerValue: playerFinalValue, dealerValue: dealerFinalValue)
            
        } else if dealerFinalValue > 21 {
            finalizeGame(withResult: .dealerBust, playerValue: playerFinalValue, dealerValue: dealerFinalValue)
            
        } else if playerFinalValue > dealerFinalValue {
            finalizeGame(withResult: .playerWin, playerValue: playerFinalValue, dealerValue: dealerFinalValue)
            
        } else if dealerFinalValue > playerFinalValue {
            finalizeGame(withResult: .dealerWin, playerValue: playerFinalValue, dealerValue: dealerFinalValue)
            
        } else {
            finalizeGame(withResult: .tie, playerValue: playerFinalValue, dealerValue: dealerFinalValue)
        }
    }
    
    func finalizeGame(withResult result: BlackjackGameResult, playerValue: Int, dealerValue: Int) {
        
        gameOver = true
        gameState = .gameOver

        var reward = 0
        
        switch result {
        
        case .blackjack:
            reward = betAmount * 3 // 3x reward for Blackjack
            resultMessage = "You Win! Blackjack! You earned \(reward) \(selectedCoinType.rawValue)."
            
        case .playerWin:
            reward = betAmount * 2 // 2x reward for regular win
            resultMessage = "You Win! Your \(playerValue) beats the dealer's \(dealerValue). You earned \(reward) \(selectedCoinType.rawValue)."
        
        case .playerBust:
            resultMessage = "You Lose! Bust with \(playerValue). You lost \(betAmount) \(selectedCoinType.rawValue)."
        
        case .dealerWin:
            resultMessage = "You Lose! Dealer's \(dealerValue) beats your \(playerValue). You lost \(betAmount) \(selectedCoinType.rawValue)."
        
        case .dealerBust:
            reward = betAmount * 2
            resultMessage = "You Win! Dealer busted with \(dealerValue). You earned \(reward) \(selectedCoinType.rawValue)."
        
        case .tie:
            reward = betAmount // Refund the bet
            resultMessage = "It's a Tie! Both you and the dealer scored \(playerValue)."
        }

        // Update the coin balance using CoinExchangeModel
        let newBalance = exchangeModel.updateCoinCount(for: selectedCoinType, by: reward)

        print("Game Over: \(resultMessage ?? "No message.") Balance updated by \(reward). New balance: \(newBalance).")
    }
    
    func endGame() {
        gameOver = true
        resultMessage = resultMessage ?? "Game Over! Start a new round."
        print("Game over. Ready for a new game.")
    }
    
    func resetGame() {
        
        dealerHand = []
        playerHand = []
        
        dealerSecondCardHidden = true
        
        dealerValue = 0
        playerValue = 0
        
        betAmount = 1
        
        betPlaced = false
        gameState = .waitingForBet
        
        gameOver = false
        resultMessage = nil
                
        print("Game reset. Ready for a new round.")
    }
    
    func currentMessage() -> (text: String, type: MessageType) {
        
        if let resultMessage = resultMessage {
            
            switch resultMessage {
            case _ where resultMessage.contains("Win"):
                return (resultMessage, .win)
                
            case _ where resultMessage.contains("Lose"):
                return (resultMessage, .loss)
                
            case _ where resultMessage.contains("Tie"):
                return (resultMessage, .tie)
                
            default:
                return (resultMessage, .info)
            }
        }
        
        switch gameState {
            
        case .waitingForBet:
            return ("Place your bet to start!", .info)
            
        case .playerTurn:
            return ("Your turn! Hit or stand.", .info)
            
        case .dealerTurn:
            return ("Dealer's turn. Please wait...", .info)
        
        case .gameOver:
            return ("Game over. Reset to start a new round.", .info)
        }
    }
}

enum MessageType {
    case win
    case loss
    case tie
    case info
}

enum BlackjackGameResult {
    case playerBust
    case dealerBust
    case playerWin
    case dealerWin
    case blackjack
    case tie
}

enum BlackjackGameState {
    case waitingForBet
    case playerTurn
    case dealerTurn
    case gameOver
}
