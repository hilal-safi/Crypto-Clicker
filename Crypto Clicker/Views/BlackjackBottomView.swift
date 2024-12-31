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
                Text("\(model.betAmount)")
                    .font(.title2)
                    .bold()
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
            }

            HStack(spacing: 5) {
                
                if model.gameOver {
                    Button(action: {
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
                    
                } else {
                    
                    // Place Bet (only visible if waiting)
                    if model.gameState == .waitingForBet {
                        HStack {
                            betAdjustmentView(amount: 500)
                            Spacer()
                            Button("Place Bet") {
                                model.placeBet(amount: model.betAmount)
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                        }
                        Spacer()
                        betAdjustmentView(amount: 10000)
                    }
                    
                    // Hit / Stand / Double / Split (only visible if player's turn)
                    if model.gameState == .playerTurn {
                        
                        Button("Hit") {
                            model.hitPlayer()
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        
                        Button("Stand") {
                            model.stand()
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.black)
                        .cornerRadius(8)

                        Button("Double Down") {
                            model.doubleDown()
                        }
                        .font(.headline)
                        .padding()
                        .background(canDoubleDown ? Color.orange : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(!canDoubleDown)
                        
                        Button("Split") {
                            model.split()
                        }
                        .font(.headline)
                        .padding()
                        .background(canSplit ? Color.purple : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(!canSplit)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Private Helpers
    
    private var canDoubleDown: Bool {
        guard model.gameState == .playerTurn else { return false }
        guard model.currentPlayerHand.count == 2 else { return false }
        guard !model.hasDoubledDown else { return false }
        
        let costToDouble = model.playerBets[model.currentHandIndex]
        
        // Now that `exchangeModel` is internal, we can reference it here
        return model.exchangeModel.count(for: model.selectedCoinType) >= costToDouble
    }
    
    private var canSplit: Bool {
        guard model.gameState == .playerTurn else { return false }
        guard model.currentPlayerHand.count == 2 else { return false }
        guard !model.hasSplit else { return false }
        
        return model.canSplit(hand: model.currentPlayerHand)
    }
    
    private func betAdjustmentView(amount: Int) -> some View {
        HStack(spacing: 2) {
            Button(action: {
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

            Text("\(amount)")
                .font(.headline)
                .frame(width: dynamicWidth(for: amount), height: 30)

            Button(action: {
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
        }
    }
    
    private func dynamicWidth(for amount: Int) -> CGFloat {
        if amount <= 10 {
            return 25 // Slightly larger width for 1 and 5
        }
        let digitCount = String(amount).count
        return CGFloat(digitCount * 12) // Standard dynamic width for other values
    }}

struct BlackjackBottomView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel.shared
        let model = BlackjackModel(exchangeModel: exchangeModel)
            
        BlackjackBottomView()
            .environmentObject(model)
    }
}
