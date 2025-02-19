//
//  TetrisGameOverView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import SwiftUI

struct TetrisGameOverView: View {
    
    @EnvironmentObject var tetrisModel: TetrisModel
    @State private var reward: Decimal = 0
    @State private var isButtonDisabled = false // Prevents multiple clicks

    var body: some View {
        
        VStack {
            
            VStack(spacing: 20) {
                
                Text("Game Over")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .accessibilityLabel("Game Over Screen")
                
                Text("Your Score: \(formattedScore(tetrisModel.score))")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .accessibilityLabel("Your score is \(formattedScore(tetrisModel.score))")
                
                Text("You earned \(reward.formatted(.number)) coins!")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .accessibilityLabel("You earned \(reward.formatted(.number)) coins.")
                
                Button(action: {
                    
                    guard !isButtonDisabled else { return } // Prevent rapid multiple clicks
                    
                    isButtonDisabled = true
                    
                    HapticFeedbackModel.triggerStrongHaptic() // Provide haptic feedback
                    
                    tetrisModel.startGame() // Use startGame() to reset the game
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isButtonDisabled = false
                    }
                }) {
                    Text("Play Again")
                        .font(.title2)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .accessibilityLabel("Play Again Button")
                }
                .disabled(isButtonDisabled)
            }
            .padding(32)
            
            .background(
                ZStack {
                    BlurView(style: .systemMaterial)
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.4), lineWidth: 2)
                }
            )
            .cornerRadius(16)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BlurView(style: .systemMaterial).ignoresSafeArea())
        .onAppear {
            if tetrisModel.gameState == .gameOver {
                reward = tetrisModel.calculateReward()
            }
        }
    }
    
    /// Formats the score for accessibility and readability.
    private func formattedScore(_ score: Int) -> String {
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        return formatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }
}

struct TetrisGameOverView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let model = TetrisModel(cryptoStore: CryptoStore())
        
        return TetrisGameOverView()
            .environmentObject(model)
    }
}
