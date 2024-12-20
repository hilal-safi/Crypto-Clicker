//
//  BlackjackMiddleView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackMiddleView: View {
    
    @ObservedObject var model: BlackjackModel

    var body: some View {
        
        VStack {
            
            // Dealer's cards and value
            VStack {
                
                Text("Dealer's Value: \(model.dealerValue)")
                    .font(.title3)
                    .bold()

                ScrollView(.horizontal, showsIndicators: false) {
                    
                    HStack {
                        
                        Spacer(minLength: 0) // For centering

                        ForEach(model.dealerHand, id: \.self) { card in
                            BlackjackCardView(card: card)
                        }
                        .frame(alignment: .center)

                        Spacer(minLength: 0) // Add spacer for centering
                    }
                    .frame(alignment: .center)
                }
            }
            .padding(.horizontal)
            
            Divider()

            // Player's cards and value
            VStack {
                                
                ScrollView(.horizontal, showsIndicators: false) {
                    
                    HStack {
                        
                        Spacer(minLength: 0) // For centering
                        
                        ForEach(model.playerHand, id: \.self) { card in
                            BlackjackCardView(card: card)
                        }
                        Spacer(minLength: 0) // Add spacer for centering
                    }
                }
                Text("Player's Value: \(model.playerValue)")
                    .font(.title3)
                    .bold()
            }
            .padding(.horizontal)

            Divider()

            // Game result
            switch model.gameState {
                
            case .waitingForBet:
                
                Text("Place your bet to start!")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                
            case .playerTurn:
                
                Text("Select your action")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding()
                
            case .dealerTurn:
                
                Text("Dealer's turn. Please wait...")
                    .font(.headline)
                    .foregroundColor(.purple)
                    .padding()
                
            case .playerWin:
                
                Text("You Win!")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding()
                
            case .dealerWin:
                
                Text("You Lose!")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding()
                
            case .tie:
                
                Text("It's a Draw!")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding()
                
            case .playerBust:
                
                Text("You Lose! Bust!")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding()
                
            case .dealerBust:
                
                Text("You Win! Dealer Bust!")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding()
            }
        }
    }
}

struct BlackjackMiddleView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel()
        let model = BlackjackModel(exchangeModel: exchangeModel)
        
        BlackjackMiddleView(model: model)
    }
}
