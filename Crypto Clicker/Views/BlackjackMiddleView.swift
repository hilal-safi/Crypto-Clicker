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
        
        GeometryReader { geometry in
            
            VStack {
                
                Divider()

                // Dealer's cards and value
                VStack {
                    
                    Text("Dealer's Value: \(model.gameState == .waitingForBet ? "??" : "\(model.dealerSecondCardHidden ? model.dealerHand.first?.value ?? 0 : model.dealerValue)")")
                        .font(.title3)
                        .bold()

                    ScrollView(.horizontal, showsIndicators: false) {
                        
                        HStack(spacing: 10) {
                            
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
                        }
                        .frame(width: geometry.size.width, alignment: .center) // Center horizontally
                        .padding(4)
                    }
                }
                .padding(.horizontal)

                Divider()

                // Player's cards and value
                VStack {
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        
                        HStack(spacing: 10) {
                            
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
                        }
                        .frame(width: geometry.size.width, alignment: .center) // Center horizontally
                        .padding(4)
                    }

                    Text("Player's Value: \(model.gameState == .waitingForBet ? "??" : "\(model.playerValue)")")
                        .font(.title3)
                        .bold()
                }
                .padding(.horizontal)

                Divider()
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center) // Center vertically
        }
    }
}

struct BlackjackMiddleView_Previews: PreviewProvider {
    
    static var previews: some View {
        let exchangeModel = CoinExchangeModel()
        let model = BlackjackModel(exchangeModel: exchangeModel)
        
        model.dealerHand = [Card(suit: "♠️", value: 10), Card(suit: "♦️", value: 5)]
        model.playerHand = [Card(suit: "♣️", value: 7), Card(suit: "♥️", value: 6)]
        
        return BlackjackMiddleView(model: model)
    }
}
