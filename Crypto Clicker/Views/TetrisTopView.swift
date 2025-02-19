//
//  TetrisTopView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import SwiftUI

struct TetrisTopView: View {
    @EnvironmentObject var tetrisModel: TetrisModel

    var body: some View {
        
        HStack {
            Text("Score: \(formattedScore())")
                .font(.title3)
                .bold()
                .accessibilityLabel("Current Score: \(formattedScore())")

            Spacer()
            
            Button(action: {
                if tetrisModel.gameState != .notStarted {
                    HapticFeedbackModel.triggerLightHaptic() // Haptic feedback for interaction
                    tetrisModel.pauseGame()
                }
            }) {
                Text(tetrisModel.gameState == .paused ? "Resume" : "Pause")
                    .font(.body)
                    .padding(10) // Increased padding for better tap area
                    .bold()
                    .background(buttonBackgroundColor())
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .accessibilityLabel(tetrisModel.gameState == .paused ? "Resume Game" : "Pause Game")
            }
            .disabled(tetrisModel.gameState == .notStarted) // Disable when the game hasn't started
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4) // Adjusted padding for layout consistency
    }
}

// MARK: - Helper Functions
extension TetrisTopView {

    /// Ensures the score is always valid and formatted
    private func formattedScore() -> String {
        return max(0, tetrisModel.score).formatted(.number)
    }

    /// Determines the button color based on the game state
    private func buttonBackgroundColor() -> Color {
        return tetrisModel.gameState == .notStarted ? Color.gray.opacity(0.6) : Color.blue
    }
}

// MARK: - Preview
struct TetrisTopView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let model = TetrisModel(cryptoStore: CryptoStore())
        
        return TetrisTopView()
            .environmentObject(model)
    }
}
