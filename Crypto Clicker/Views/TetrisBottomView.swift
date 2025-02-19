//
//  TetrisBottomView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import SwiftUI
import UIKit

struct TetrisBottomView: View {
    
    @EnvironmentObject var tetrisModel: TetrisModel
    @State private var isButtonDisabled = false // Prevents multiple rapid clicks

    var body: some View {
        
        HStack(spacing: 16) {
            
            if tetrisModel.gameState == .notStarted || tetrisModel.gameState == .gameOver {
                // Start game button
                Button(action: {
                    guard !isButtonDisabled else { return } // Prevent multiple clicks
                    isButtonDisabled = true
                    HapticFeedbackModel.triggerStrongHaptic() // Strong haptic feedback
                    
                    tetrisModel.startGame()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { // Re-enable after 1.5s
                        isButtonDisabled = false
                    }
                }) {
                    Text("Start Game")
                        .font(.title2) // Match font size to control buttons
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 50) // Match height to control buttons
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .accessibilityLabel("Start new Tetris game")
                }
                .padding(.top, -12) // Smaller top padding
                
            } else {
                // Control buttons during the game
                controlButton(symbol: "arrow.left",
                              action: tetrisModel.moveCurrentPieceLeft,
                              disabled: tetrisModel.gameState == .paused,
                              label: "Move Left")

                controlButton(symbol: "arrow.clockwise",
                              action: tetrisModel.rotateCurrentPiece,
                              disabled: tetrisModel.gameState == .paused,
                              color: .orange,
                              label: "Rotate Piece")

                controlButton(symbol: "arrow.down.circle",
                              action: tetrisModel.fastDrop,
                              disabled: tetrisModel.gameState == .paused,
                              color: .red,
                              label: "Fast Drop")

                controlButton(symbol: "arrow.right",
                              action: tetrisModel.moveCurrentPieceRight,
                              disabled: tetrisModel.gameState == .paused,
                              label: "Move Right")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: tetrisModel.gameState)
    }

    /// Creates a styled button with conditional disabling, accessibility, and color adjustments
    private func controlButton(symbol: String, action: @escaping () -> Void, disabled: Bool, color: Color = Color.blue, label: String) -> some View {
        
        Button(action: {
            guard !isButtonDisabled else { return } // Prevent spam clicks
            isButtonDisabled = true
            HapticFeedbackModel.triggerStrongHaptic()
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isButtonDisabled = false } // Delay re-enabling
        }) {
            Image(systemName: symbol)
                .font(.title) // Adjust icon size for better visibility
                .accessibilityLabel(label)
        }
        .padding()
        .frame(width: 80, height: 50) // Fixed size for all buttons
        .background(disabled ? Color.gray.opacity(0.8) : color)
        .foregroundColor(disabled ? .white.opacity(0.9) : .white)
        .cornerRadius(8)
        .disabled(disabled)
    }
}

struct TetrisBottomView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let model = TetrisModel(cryptoStore: CryptoStore())
        
        return TetrisBottomView()
            .environmentObject(model)
    }
}
