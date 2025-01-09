//
//  BlackjackModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import Foundation

class BlackjackModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedCoinType: CoinType = .dogecoin // Default coin type
    
    // Instead of a single playerHand, store multiple hands.
    @Published var playerHands: [[Card]] = [[]]
    // Track bets per hand if the player splits.
    @Published var playerBets: [Int] = []
    // Which hand the player is currently playing
    @Published var currentHandIndex: Int = 0
    
    // (We keep these for the dealer as is, since the dealer does not split)
    @Published var dealerHand: [Card] = []
    @Published var dealerSecondCardHidden: Bool = true
    
    // For convenience, we provide a computed property that returns the "active" hand
    // the user is currently playing. (If only one hand, index is 0.)
    var currentPlayerHand: [Card] {
        get { playerHands[currentHandIndex] }
        set { playerHands[currentHandIndex] = newValue }
    }
    
    // Values for the dealer and a single “active” player hand
    @Published var dealerValue: Int = 0
    @Published var playerValue: Int = 0
    
    // Track the base bet. Each split hand also uses this amount.
    @Published var betAmount: Int = 1
    @Published var betPlaced: Bool = false
    
    // Game flow
    @Published var gameState: BlackjackGameState = .waitingForBet
    @Published var gameOver: Bool = false
    @Published var resultMessage: String? = nil
    
    // Flags for special rules
    @Published var hasDoubledDown: Bool = false
    @Published var hasSplit: Bool = false
    
    // MARK: - Internal Data
    
    let exchangeModel: CoinExchangeModel     // Reference exchangeModel externally if needed:
    let cryptoStore: CryptoStore // Access CryptoStore as a dependency

    var deck: [Card] = []
    
    // MARK: - Init
    
    init(exchangeModel: CoinExchangeModel, cryptoStore: CryptoStore) {
        self.exchangeModel = exchangeModel
        self.cryptoStore = cryptoStore
        self.deck = createDeck().shuffled()
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
        return deck
    }
    
    func drawCard() -> Card {
        if deck.isEmpty {
            deck = createDeck().shuffled()
        }
        return deck.removeFirst()
    }
    
    // MARK: - Game Setup / Betting
    
    func placeBet(amount: Int) {
        
        guard amount > 0, exchangeModel.count(for: selectedCoinType) >= amount else {
            resultMessage = "Insufficient balance to place the bet."
            return
        }
        
        // Deduct coins and reset state
        betAmount = amount
        exchangeModel.updateCoinCount(for: selectedCoinType, by: -amount) // Deduct bet for the initial hand
        
        betPlaced = true
        gameState = .playerTurn
        gameOver = false
        resultMessage = nil
        
        hasDoubledDown = false
        hasSplit = false
        
        dealerSecondCardHidden = true
        startGame()
    }
    
    func startGame() {
        // Create fresh deck if needed
        if deck.count < 15 {
            deck = createDeck().shuffled()
        }
        
        // Clear old data
        dealerHand.removeAll()
        playerHands.removeAll()
        playerBets.removeAll()
        
        // Initialize with ONE player hand
        playerHands.append([])
        playerBets.append(betAmount)
        currentHandIndex = 0
        
        // Deal
        dealerHand = [drawCard(), drawCard()]
        playerHands[0] = [drawCard(), drawCard()]
        
        // Update display values
        calculateValues()
        checkForBlackjack()
    }
    
    // MARK: - Player Actions
    
    func hitPlayer() {
        guard betPlaced, !gameOver, gameState == .playerTurn else { return }
        
        currentPlayerHand.append(drawCard())
        calculateValues()
        
        // If this hand hits 21, auto-stand
        if playerValue == 21 {
            stand()
            return
        }
        
        // If this hand busts
        if playerValue > 21 {
            // Move on to the next hand or end
            nextHandOrDealer()
        }
    }
    
    func stand() {
        guard betPlaced, !gameOver, gameState == .playerTurn else { return }
        nextHandOrDealer()
    }
    
    func doubleDown() {
        // A typical rule: can only double on first 2 cards (and possibly after split).
        guard gameState == .playerTurn,
              currentPlayerHand.count == 2,
              !hasDoubledDown else {
            return
        }
        
        // Check if user can afford doubling
        let costToDouble = playerBets[currentHandIndex]
        if exchangeModel.count(for: selectedCoinType) < costToDouble {
            resultMessage = "Insufficient balance to Double Down."
            return
        }
        
        // Deduct additional bet
        exchangeModel.updateCoinCount(for: selectedCoinType, by: -costToDouble)
        playerBets[currentHandIndex] += costToDouble
        
        // One more card
        currentPlayerHand.append(drawCard())
        
        // Mark that we doubled
        hasDoubledDown = true
        
        // Stand automatically after doubling
        nextHandOrDealer()
    }
    
    func split() {
        // Can only split if:
        // - Exactly 2 cards in the current hand
        // - They have the same *rank*
        // - We haven't already split (or remove this check if multiple splits)
        guard gameState == .playerTurn,
              currentPlayerHand.count == 2,
              canSplit(hand: currentPlayerHand),
              !hasSplit else {
            return
        }
        
        // Check if user can afford another bet
        if exchangeModel.count(for: selectedCoinType) < betAmount {
            resultMessage = "Insufficient balance to split."
            return
        }
        
        // Deduct another full bet for the second hand
        exchangeModel.updateCoinCount(for: selectedCoinType, by: -betAmount)
        
        hasSplit = true
        
        // Separate the two cards
        let cardOne = currentPlayerHand[0]
        let cardTwo = currentPlayerHand[1]
        
        // Replace current hand with [cardOne]
        playerHands[currentHandIndex] = [cardOne]
        
        // Add the new second hand
        playerHands.append([cardTwo])
        playerBets.append(betAmount)
        
        // Deal one extra card to each new hand
        playerHands[currentHandIndex].append(drawCard())            // hand A
        playerHands[playerHands.count - 1].append(drawCard())       // hand B
        
        calculateValues()
    }
    
    // If the player has more hands to play, move to the next; otherwise do dealer.
    func nextHandOrDealer() {
        
        if playerValue > 21 {
            // “Bust” message for this hand, if desired
        }
        
        // Move to next hand
        if currentHandIndex < playerHands.count - 1 {
            currentHandIndex += 1
            hasDoubledDown = false // reset for the next hand
            calculateValues()
        } else {
            // If no more hands, go to dealer
            gameState = .dealerTurn
            handleDealerTurn()
        }
    }
    
    // MARK: - Dealer Actions
    
    func handleDealerTurn() {
        
        guard gameState == .dealerTurn else { return }
        
        dealerSecondCardHidden = false
        
        // Dealer draws to 17 with a short delay for “visual” effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.dealerValue < 17 {
                self.dealerHand.append(self.drawCard())
                self.calculateValues()
                
                if self.dealerValue > 21 {
                    // Dealer bust
                    self.checkWinCondition()
                } else {
                    self.handleDealerTurn()
                }
            } else {
                self.checkWinCondition()
            }
        }
    }
    
    // MARK: - Value Calculations
    
    // REMOVED `private` so it can be used in BlackjackMiddleView:
    func calculateHandValue(for hand: [Card]) -> Int {
        
        var total = 0
        var aceCount = 0
        
        for card in hand {
            // Aces as 11 initially
            if card.value == 1 {
                aceCount += 1
                total += 11
            }
            else if card.value >= 10 {
                total += 10
            }
            else {
                total += card.value
            }
        }
        
        // If we bust but have aces counting as 11, reduce them to 1
        while total > 21 && aceCount > 0 {
            total -= 10
            aceCount -= 1
        }
        
        return total
    }
    
    func calculateValues() {
        // Update the dealer’s display value
        dealerValue = calculateHandValue(for: dealerHand)
        // Update the player's current-hand display value
        playerValue = calculateHandValue(for: currentPlayerHand)
    }
    
    func canSplit(hand: [Card]) -> Bool {
        // Flatten J/Q/K (value 11..13) to 10 so e.g. K+Q can be split
        let first = rankValue(hand[0])
        let second = rankValue(hand[1])
        return first == second
    }
    
    func rankValue(_ card: Card) -> Int {
        if card.value >= 10 {
            return 10
        }
        return card.value
    }
    
    // MARK: - Special Checks
    
    func checkForBlackjack() {
        // If the very first player hand is exactly 21:
        if calculateHandValue(for: playerHands[0]) == 21 {
            finalizeGame(withResult: .blackjack,
                         playerValue: 21,
                         dealerValue: dealerValue)
        }
    }
    
    func checkWinCondition() {
        
        let dealerFinalValue = calculateHandValue(for: dealerHand)
        
        for (handIndex, hand) in playerHands.enumerated() {
            
            let playerFinalValue = calculateHandValue(for: hand)
            let betForHand = playerBets[handIndex]
            
            if playerFinalValue > 21 {
                // Player bust
                finalizeSingleHand(result: .playerBust,
                                   playerValue: playerFinalValue,
                                   dealerValue: dealerFinalValue,
                                   bet: betForHand)
            }
            else if dealerFinalValue > 21 {
                // Dealer bust
                finalizeSingleHand(result: .dealerBust,
                                   playerValue: playerFinalValue,
                                   dealerValue: dealerFinalValue,
                                   bet: betForHand)
            }
            else if playerFinalValue > dealerFinalValue {
                // Player wins
                finalizeSingleHand(result: .playerWin,
                                   playerValue: playerFinalValue,
                                   dealerValue: dealerFinalValue,
                                   bet: betForHand)
            }
            else if dealerFinalValue > playerFinalValue {
                // Dealer wins
                finalizeSingleHand(result: .dealerWin,
                                   playerValue: playerFinalValue,
                                   dealerValue: dealerFinalValue,
                                   bet: betForHand)
            }
            else {
                // tie
                finalizeSingleHand(result: .tie,
                                   playerValue: playerFinalValue,
                                   dealerValue: dealerFinalValue,
                                   bet: betForHand)
            }
        }
        
        // Once all hands are settled, we finish
        gameOver = true
        gameState = .gameOver
    }
    
    /// Called once for each hand at the end of the round.
    func finalizeSingleHand(
        result: BlackjackGameResult,
        playerValue: Int,
        dealerValue: Int,
        bet: Int
    ) {
        var exchangeReward = 0
        var cryptoStoreReward: Decimal = 0

        switch result {
        case .blackjack:
            exchangeReward = bet * 3
            cryptoStoreReward = 1000
            resultMessage = "You Win! Blackjack! You earned \(exchangeReward) \(selectedCoinType.rawValue) and 1000 coins."

        case .playerWin:
            exchangeReward = bet * 2
            cryptoStoreReward = 500
            resultMessage = "You Win! Your \(playerValue) beats the dealer's \(dealerValue). You earned \(exchangeReward) \(selectedCoinType.rawValue) and 500 coins."

        case .playerBust:
            exchangeReward = 0
            cryptoStoreReward = 0
            resultMessage = "You Lose! Bust with \(playerValue). No coins earned."

        case .dealerWin:
            exchangeReward = 0
            cryptoStoreReward = 0
            resultMessage = "You Lose! Dealer's \(dealerValue) beats your \(playerValue). No coins earned."

        case .dealerBust:
            exchangeReward = bet * 2
            cryptoStoreReward = 500
            resultMessage = "You Win! Dealer busted with \(dealerValue). You earned \(exchangeReward) \(selectedCoinType.rawValue) and 500 coins."

        case .tie:
            exchangeReward = bet
            cryptoStoreReward = 0
            resultMessage = "It's a Tie! Both you and the dealer scored \(playerValue). No coins earned."
        }

        // Update exchange coin rewards
        exchangeModel.updateCoinCount(for: selectedCoinType, by: exchangeReward)

        // Update CryptoStore rewards using DispatchQueue
        DispatchQueue.main.async {
            self.cryptoStore.addCoinsFromMiniGame(cryptoStoreReward)
        }
    }
    
    func finalizeGame(withResult result: BlackjackGameResult,
                      playerValue: Int,
                      dealerValue: Int) {
        gameOver = true
        gameState = .gameOver

        if result == .blackjack {
            let exchangeReward = betAmount * 3
            let cryptoStoreReward: Decimal = 1000

            // Update exchange coin rewards
            exchangeModel.updateCoinCount(for: selectedCoinType, by: exchangeReward)

            // Update CryptoStore rewards using DispatchQueue
            DispatchQueue.main.async {
                self.cryptoStore.addCoinsFromMiniGame(cryptoStoreReward)
            }

            resultMessage = "You got a Blackjack! You earned \(exchangeReward) \(selectedCoinType.rawValue) and 1000 coins."
        }
    }
    
    func endGame() {
        gameOver = true
        resultMessage = resultMessage ?? "Game Over! Start a new round."
    }
    
    func resetGame() {
        
        dealerHand.removeAll()
        playerHands.removeAll()
        playerBets.removeAll()
        
        dealerSecondCardHidden = true
        
        dealerValue = 0
        playerValue = 0
        
        betAmount = 1
        betPlaced = false
        
        gameState = .waitingForBet
        gameOver = false
        resultMessage = nil
        
        hasDoubledDown = false
        hasSplit = false
        currentHandIndex = 0
    }
    
    // MARK: - For the UI messages
    
    func currentMessage() -> (text: String, type: MessageType) {
        
        // If there's already a result message (e.g. "You Win!"), display that
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

        // Otherwise, show a status message based on gameState
        switch gameState {
            
        case .waitingForBet:
            return ("Place your bet to start!", .info)
            
        case .playerTurn:
            // If multiple hands, specify which hand is active
            if playerHands.count > 1 {
                let message = "Now playing Hand #\(currentHandIndex + 1) of \(playerHands.count)."
                return (message, .info)
            } else {
                // Single hand
                return ("Your turn! Hit, stand, split, or double down.", .info)
            }
            
        case .dealerTurn:
            return ("Dealer's turn. Please wait...", .info)
            
        case .gameOver:
            return ("Game over. Reset to start a new round.", .info)
        }
    }
}

// MARK: - Supporting Types

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
