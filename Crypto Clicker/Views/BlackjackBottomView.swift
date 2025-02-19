//
//  BlackjackBottomView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackBottomView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var model: BlackjackModel
    
    var body: some View {
        
        VStack(spacing: 10) {
            
            // Display current bet
            HStack {
                
                Text("Bet Amount:")
                    .font(.title2)
                    .accessibilityLabel("Bet Amount") // VoiceOver accessibility
                
                Text("\(model.betAmount)")
                    .font(.title2)
                    .bold()
                    .accessibilityLabel("Current bet: \(model.betAmount) coins") // VoiceOver
            }
            
            // Bet Adjustment (only if waitingForBet)
            if model.gameState == .waitingForBet {
                
                HStack(spacing: 15) {
                    betAdjustmentView(amount: 1)
                    Spacer()
                    betAdjustmentView(amount: 5)
                    Spacer()
                    betAdjustmentView(amount: 10)
                }
                .accessibilityHint("Adjust your bet amount") // VoiceOver hint
            }
            
            HStack(spacing: 5) {
                
                if model.gameOver {
                    Button(action: {
                        HapticFeedbackModel.triggerNormalHaptic() // Normal haptic feedback
                        model.resetGame()
                    }) {
                        Text("New Game")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Start a new game") // VoiceOver
                    
                } else {
                    
                    // Place Bet (only visible if waiting)
                    if model.gameState == .waitingForBet {
                        
                        HStack {
                            
                            betAdjustmentView(amount: 500)
                            Spacer()
                            
                            Button("Place Bet") {
                                HapticFeedbackModel.triggerStrongHaptic() // Strong haptic feedback
                                model.placeBet(amount: model.betAmount)
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .accessibilityLabel("Place bet of \(model.betAmount) coins") // VoiceOver
                        }
                        Spacer()
                        betAdjustmentView(amount: 10000)
                    }
                    
                    // Hit / Stand / Double / Split (only visible if player's turn)
                    if model.gameState == .playerTurn {
                        
                        Button("Hit") {
                            HapticFeedbackModel.triggerStrongHaptic() // Strong haptic feedback
                            model.hitPlayer()
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .accessibilityLabel("Hit: Draw another card") // VoiceOver
                        
                        Button("Stand") {
                            HapticFeedbackModel.triggerStrongHaptic() // Strong haptic feedback
                            model.stand()
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .accessibilityLabel("Stand: Keep current hand") // VoiceOver
                        
                        Button("Double Down") {
                            HapticFeedbackModel.triggerNormalHaptic() // Normal haptic feedback
                            model.doubleDown()
                        }
                        .font(.headline)
                        .padding()
                        .background(canDoubleDown ? Color.orange : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(!canDoubleDown)
                        .accessibilityLabel("Double Down: Double your bet") // VoiceOver
                        .accessibilityHint(canDoubleDown ? "You can double down" : "Double down is unavailable") // VoiceOver hint
                        
                        Button("Split") {
                            HapticFeedbackModel.triggerNormalHaptic() // Normal haptic feedback
                            model.split()
                        }
                        .font(.headline)
                        .padding()
                        .background(canSplit ? Color.purple : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(!canSplit)
                        .accessibilityLabel("Split: Split your hand") // VoiceOver
                        .accessibilityHint(canSplit ? "You can split your hand" : "Split is unavailable") // VoiceOver hint
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Private Helpers
    
    /// Determines if the player can double down based on game state
    private var canDoubleDown: Bool {
        
        guard model.gameState == .playerTurn else { return false }
        guard model.currentPlayerHand.count == 2 else { return false }
        guard !model.hasDoubledDown else { return false }
        
        let costToDouble = model.playerBets[model.currentHandIndex]
        
        // Check if the player has enough coins to double down
        return model.exchangeModel.count(for: model.selectedCoinType) >= costToDouble
    }
    
    /// Determines if the player can split their hand
    private var canSplit: Bool {
        
        guard model.gameState == .playerTurn else { return false }
        guard model.currentPlayerHand.count == 2 else { return false }
        guard !model.hasSplit else { return false }
        
        return model.canSplit(hand: model.currentPlayerHand)
    }
    
    /// Creates a view for adjusting the bet amount
    private func betAdjustmentView(amount: Int) -> some View {
        
        HStack(spacing: 2) {
            
            Button(action: {
                HapticFeedbackModel.triggerLightHaptic() // Light haptic feedback
                model.betAmount = max(1, model.betAmount - amount)
            }) {
                Text("-")
                    .font(.headline)
                    .frame(width: 30, height: 30)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 2)
                    )
            }
            .accessibilityLabel("Decrease bet by \(amount) coins") // VoiceOver
            
            Text("\(amount)")
                .font(.headline)
                .frame(width: dynamicWidth(for: amount), height: 30)
                .accessibilityHidden(true) // Hides amount from VoiceOver to avoid repetition
            
            Button(action: {
                HapticFeedbackModel.triggerLightHaptic() // Light haptic feedback
                model.betAmount += amount
            }) {
                Text("+")
                    .font(.headline)
                    .frame(width: 30, height: 30)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 2)
                    )
            }
            .accessibilityLabel("Increase bet by \(amount) coins") // VoiceOver
        }
    }
    
    /// Dynamically determines width based on the number of digits in the bet amount
    private func dynamicWidth(for amount: Int) -> CGFloat {
        
        if amount <= 10 {
            return 25 // Slightly larger width for 1 and 5
        }
        
        let digitCount = String(amount).count
        return CGFloat(digitCount * 12) // Standard dynamic width for other values
    }
}

struct BlackjackBottomView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel.shared
        let cryptoStore = CryptoStore()
        let model = BlackjackModel(exchangeModel: exchangeModel, cryptoStore: cryptoStore)
        
        BlackjackBottomView()
            .environmentObject(model)
    }
}
