//
//  BlackjackMiddleView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackMiddleView: View {
    
    @EnvironmentObject var model: BlackjackModel

    var body: some View {
        GeometryReader { geometry in
            
            VStack {
                
                // MARK: - Dealer Section
                Divider()
                
                VStack {
                    // Dealer's value
                    if model.gameState == .waitingForBet {
                        Text("Dealer's Value: ??")
                            .font(.title3)
                            .bold()
                    } else if model.dealerSecondCardHidden {
                        // Dealer's face-up card is hidden
                        if let firstCard = model.dealerHand.first, firstCard.value == 1 {
                            // Dealer's first card is an Ace
                            Text("Dealer's Value: 1 or 11 + ??")
                                .font(.title3)
                                .bold()
                        } else {
                            // Normal case
                            Text("Dealer's Value: \(model.dealerHand.first?.value ?? 0) + ??")
                                .font(.title3)
                                .bold()
                        }
                    } else {
                        // Dealer's full value revealed
                        Text("Dealer's Value: \(model.dealerValue)")
                            .font(.title3)
                            .bold()
                    }
                    
                    // Dealer's cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            if model.gameState == .waitingForBet {
                                // Show two placeholders before the game starts
                                ForEach(0..<2, id: \.self) { _ in
                                    BlackjackCardView(card: Card(suit: "🂠", value: 0))
                                }
                            } else {
                                // Show dealer's cards, hiding the second if needed
                                ForEach(model.dealerHand.indices, id: \.self) { index in
                                    if index == 1 && model.dealerSecondCardHidden {
                                        BlackjackCardView(card: Card(suit: "🂠", value: 0))
                                    } else {
                                        BlackjackCardView(card: model.dealerHand[index])
                                    }
                                }
                            }
                        }
                        .frame(width: geometry.size.width, alignment: .center) // Always center dealer's cards
                        .padding(4)
                    }
                }
                .padding(.horizontal)
                
                Divider()

                // MARK: - Player Section
                if model.gameState == .waitingForBet {
                    
                    // Placeholder for player's hand before bet
                    HStack(spacing: 10) {
                        ForEach(0..<2, id: \.self) { _ in
                            BlackjackCardView(card: Card(suit: "🂠", value: 0))
                        }
                    }
                    .frame(width: geometry.size.width, alignment: .center) // Centered before the game
                    .padding(4)
                    
                    Text("Player's Value: ??")
                        .font(.title3)
                        .bold()
                    
                } else {
                    
                    // Scrollable layout for player hands
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            
                            ForEach(model.playerHands.indices, id: \.self) { handIndex in
                                
                                // Highlight the active hand only if split
                                VStack {
                                    HStack(spacing: 10) {
                                        ForEach(model.playerHands[handIndex], id: \.self) { card in
                                            BlackjackCardView(card: card)
                                        }
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                (model.playerHands.count > 1 && handIndex == model.currentHandIndex)
                                                    ? Color.blue.opacity(0.8) // Highlight only if split
                                                    : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                                    
                                    // Show value for this hand
                                    let value = model.calculateHandValue(for: model.playerHands[handIndex])
                                    Text("Value: \(value)")
                                        .font(.title3)
                                        .bold()
                                }
                                .padding(4)
                                
                                // Divider between hands (only if split)
                                if model.playerHands.count > 1 && handIndex < model.playerHands.count - 1 {
                                    Divider()
                                        .frame(height: 120)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(
                            width: geometry.size.width * (model.playerHands.count > 1 ? 2 : 1), // Allow room for scrolling if split
                            alignment: model.playerHands.count == 1 ? .center : .leading // Center if 1 hand, left-align if split
                        )
                    }
                }
                
                Divider()
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
    }
}

struct BlackjackMiddleView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel.shared
        let model = BlackjackModel(exchangeModel: exchangeModel)
        
        // Example data for preview
        model.dealerHand = [Card(suit: "♠", value: 1), Card(suit: "♦", value: 5)]
        model.playerHands = [
            [Card(suit: "♣", value: 7), Card(suit: "♥", value: 6)],
            [Card(suit: "♠", value: 10), Card(suit: "♠", value: 1)]
        ]
        model.playerBets = [50, 50]
        model.currentHandIndex = 1 // Highlight the second hand
        model.gameState = .playerTurn // Show hands during player's turn
        
        return BlackjackMiddleView()
            .environmentObject(model)
    }
}
