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
                
                if isValidBoard() {
                    TetrisBoardView(
                        board: tetrisModel.board,
                        currentPiece: tetrisModel.currentPiece,
                        landingPiece: tetrisModel.getLandingPiece()
                    )
                    .aspectRatio(CGFloat(tetrisModel.board[0].count) / CGFloat(tetrisModel.board.count), contentMode: .fit)
                    .accessibilityLabel("Tetris Game Board")
                } else {
                    Text("Error: Invalid Board")
                        .font(.headline)
                        .foregroundColor(.red)
                        .accessibilityLabel("Tetris board failed to load")
                }
                
                TetrisMiddleView()
                
                TetrisBottomView()
            }
            .padding(4)

            if tetrisModel.gameState == .gameOver {
                TetrisGameOverView()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: tetrisModel.gameState)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Game Over. Score: \(tetrisModel.score). Play Again?")
            }
        }
        .navigationTitle("Tetris")
        .accessibilityLabel("Tetris Game")
    }
}

// MARK: - Helper Functions
extension TetrisView {

    /// Checks if the board is valid before accessing its elements
    private func isValidBoard() -> Bool {
        return !tetrisModel.board.isEmpty && !tetrisModel.board[0].isEmpty
    }
}

// MARK: - Preview
struct TetrisView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let store = CryptoStore()
        let model = TetrisModel(cryptoStore: store)

        return TetrisView()
            .environmentObject(model)
            .environmentObject(store)
    }
}
