//
//  BlackjackMessageView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-23.
//

import SwiftUI

struct BlackjackMessageView: View {
    
    @ObservedObject var model: BlackjackModel
    @Environment(\.colorScheme) var colorScheme // Detect light or dark mode
    
    var body: some View {
        
        // Message content
        VStack {
            
            if let resultMessage = model.resultMessage {
                
                // Show game result message
                Text(resultMessage)
                    .font(.title2)
                    .foregroundColor(colorScheme == .dark ? .white : .black) // Black in light mode, white in dark mode
                    .bold()
                    .multilineTextAlignment(.center) // Center-align long text
                    .lineLimit(nil) // Allow unlimited lines
                    .padding()
                
            } else {
                
                // Show messages based on the game state
                switch model.gameState {
                    
                case .waitingForBet:
                    
                    if model.betAmount <= 0 {
                        
                        Text("Bet amount must be greater than 0.")
                            .font(.title2)
                            .foregroundColor(.red)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding()
                        
                    } else if model.betAmount > model.exchangeModel.count(for: model.selectedCoinType) {
                        
                        Text("Bet exceeds available coins.")
                            .font(.title2)
                            .foregroundColor(.red)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding()
                        
                    } else {
                        
                        Text("Place your bet to start!")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding()
                    }
                    
                case .playerTurn:
                    
                    Text("Select your action")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .bold()
                        .padding()
                    
                case .dealerTurn:
                    
                    Text("Dealer's turn. Please wait...")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding()
                    
                case .playerWin:
                    
                    Text("You Win!")
                        .font(.title2)
                        .foregroundColor(.green)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding()
                    
                case .dealerWin:
                    
                    Text("You Lose!")
                        .font(.title2)
                        .foregroundColor(.red)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding()
                    
                case .tie:
                    
                    Text("It's a Draw!")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding()
                    
                case .playerBust:
                    
                    Text("You Lose! Bust!")
                        .font(.title2)
                        .foregroundColor(.red)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding()
                    
                case .dealerBust:
                    
                    Text("You Win! Dealer Bust!")
                        .font(.title2)
                        .foregroundColor(.green)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding()
                }
            }
        }
    }
}

struct BlackjackMessageView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel()
        let model = BlackjackModel(exchangeModel: exchangeModel)
        
        model.gameState = .waitingForBet
        
        return BlackjackMessageView(model: model)
            .environment(\.colorScheme, .light)
    }
}
