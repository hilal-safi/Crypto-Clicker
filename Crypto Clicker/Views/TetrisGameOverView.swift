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

    var body: some View {
        
        VStack {
            
            VStack(spacing: 20) {
                
                Text("Game Over")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Your Score: \(tetrisModel.score)")
                    .font(.title2)
                    .foregroundColor(.primary)

                Text("You earned \(reward.formatted(.number)) coins!")
                    .font(.title2)
                    .foregroundColor(.primary)

                Button(action: {
                    tetrisModel.gameState = .notStarted
                }) {
                    Text("Play Again")
                        .font(.title2)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
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
            reward = tetrisModel.calculateReward()
        }
    }
}

struct TetrisGameOverView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let model = TetrisModel(cryptoStore: CryptoStore())
        return TetrisGameOverView()
            .environmentObject(model)
    }
}
