//
//  TetrisView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-07.
//

import SwiftUI

struct TetrisView: View {
    
    @EnvironmentObject var tetrisModel: TetrisModel
    @EnvironmentObject var cryptoStore: CryptoStore

    var body: some View {
        
        ZStack {
            
            BackgroundView(type: .minigames)
            
            VStack {
                
                TetrisTopView()
                
                TetrisBoardView(
                    board: tetrisModel.board,
                    currentPiece: tetrisModel.currentPiece,
                    landingPiece: tetrisModel.getLandingPiece()
                )
                .aspectRatio(CGFloat(tetrisModel.board[0].count) / CGFloat(tetrisModel.board.count), contentMode: .fit)
                
                TetrisMiddleView()
                
                TetrisBottomView()
            }
            .padding(4)

            if tetrisModel.gameState == .gameOver {
                TetrisGameOverView()
            }
        }
        .navigationTitle("Tetris")
    }
}

struct TetrisView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let store = CryptoStore()
        let model = TetrisModel(cryptoStore: store)

        return TetrisView()
            .environmentObject(model)
            .environmentObject(store)
    }
}
