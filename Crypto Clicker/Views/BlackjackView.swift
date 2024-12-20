//
//  BlackjackView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-18.
//

import SwiftUI

struct BlackjackView: View {
    @ObservedObject var model: BlackjackModel
    @State private var gameResult: String = ""

    var body: some View {
        VStack {
            BlackjackTopView(initialBalance: model.initialBalance, playerBalance: model.playerBalance)
            
            BlackjackMiddleView(
                dealerHand: model.dealerHand,
                playerHand: model.playerHand,
                dealerValue: model.dealerValue,
                playerValue: model.playerValue,
                betPlaced: model.betPlaced
            )
            
            Button(action: {
                gameResult = model.checkWinCondition()
            }) {
                Text("Check Result")
            }
            
            Text(gameResult)
        }
    }
}

struct BlackjackView_Previews: PreviewProvider {
    static var previews: some View {
        BlackjackView(model: BlackjackModel(initialBalance: 1000, playerBalance: 1000))
    }
}
