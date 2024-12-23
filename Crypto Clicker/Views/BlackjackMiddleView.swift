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
                
                Text("Dealer's Value: \(model.gameState == .waitingForBet ? "??" : "\(model.dealerSecondCardHidden ? model.dealerHand.first?.value ?? 0 : model.dealerValue)")")
                    .font(.title3)
                    .bold()

                ScrollView(.horizontal, showsIndicators: false) {
                    
                    HStack {
                        Spacer(minLength: 0) // For centering

                        if model.gameState == .waitingForBet {
                            // Show two blank cards before the game starts
                            ForEach(0..<2, id: \.self) { _ in
                                BlackjackCardView(card: Card(suit: "🂠", value: 0))
                            }
                        } else {
                            // Show dealer's actual cards during the game
                            ForEach(model.dealerHand.indices, id: \.self) { index in
                                if index == 1 && model.dealerSecondCardHidden {
                                    BlackjackCardView(card: Card(suit: "🂠", value: 0))
                                } else {
                                    BlackjackCardView(card: model.dealerHand[index])
                                }
                            }
                        }

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
                        
                        if model.gameState == .waitingForBet {
                            // Show two blank cards before the game starts
                            ForEach(0..<2, id: \.self) { _ in
                                BlackjackCardView(card: Card(suit: "🂠", value: 0))
                            }
                        } else {
                            // Show player's actual cards during the game
                            ForEach(model.playerHand, id: \.self) { card in
                                BlackjackCardView(card: card)
                            }
                        }
                        Spacer(minLength: 0) // Add spacer for centering
                    }
                }
                
                Text("Player's Value: \(model.gameState == .waitingForBet ? "??" : "\(model.playerValue)")")
                    .font(.title3)
                    .bold()
            }
            .padding(.horizontal)

            Divider()
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
