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

    var body: some View {
        
        HStack(spacing: 16) {
            
            if tetrisModel.gameState == .notStarted || tetrisModel.gameState == .gameOver {
                // Start game button
                Button(action: {
                    HapticFeedbackModel.triggerStrongHaptic() // Strong haptic feedback
                    tetrisModel.startGame()
                }) {
                    Text("Start Game")
                        .font(.title2) // Match font size to control buttons
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 50) // Match height to control buttons
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, -12) // Smaller top padding
                
            } else {
                // Control buttons during the game
                controlButton(symbol: "arrow.left",
                              action: {
                                      HapticFeedbackModel.triggerStrongHaptic() // Strong haptic feedback
                                      tetrisModel.moveCurrentPieceLeft()
                              },
                              disabled: tetrisModel.gameState == .paused)
                
                controlButton(symbol: "arrow.clockwise",
                              action: {
                                      HapticFeedbackModel.triggerStrongHaptic() // Strong haptic feedback
                                      tetrisModel.rotateCurrentPiece()
                              },
                              disabled: tetrisModel.gameState == .paused,
                              color: .orange)
                
                controlButton(symbol: "arrow.down.circle",
                              action: {
                                    HapticFeedbackModel.triggerStrongHaptic() // Strong haptic feedback
                                    tetrisModel.fastDrop()
                              },
                              disabled: tetrisModel.gameState == .paused,
                              color: .red)
                
                controlButton(symbol: "arrow.right",
                              action: {
                                    HapticFeedbackModel.triggerStrongHaptic() // Strong haptic feedback
                                    tetrisModel.moveCurrentPieceRight()
                              },
                              disabled: tetrisModel.gameState == .paused)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }

    /// Creates a styled button with conditional disabling and greyed-out appearance
    private func controlButton(symbol: String, action: @escaping () -> Void, disabled: Bool, color: Color = Color.blue) -> some View {
        
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title) // Adjust icon size for better visibility
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
