//
//  BlackjackBottomView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-19.
//

import SwiftUI

struct BlackjackBottomView: View {
    @Binding var betAmount: Int
    @Binding var gameResult: String?
    @Binding var betPlaced: Bool
    let playerBalance: Int
    let placeBetAction: () -> Void
    let hitAction: () -> Void
    let standAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Current Bet Slider
            Slider(value: Binding(
                get: { Double(betAmount) },
                set: { betAmount = Int($0) }),
                   in: 1...Double(min(playerBalance, 1000)),
                   step: 1)
            .padding(.horizontal)
            .disabled(gameResult != nil || playerBalance < 1)
            
            Text("Current Bet: \(betAmount)")
                .font(.subheadline)
            
            // Game Controls
            HStack(spacing: 16) {
                Button("Bet", action: placeBetAction)
                    .disabled(playerBalance < betAmount || playerBalance == 0)
                
                Button("Hit", action: hitAction)
                    .disabled(!betPlaced || gameResult != nil)
                
                Button("Stand", action: standAction)
                    .disabled(!betPlaced || gameResult != nil)
            }
            .font(.title2)
        }
        .padding(.bottom, UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 16)
    }
}

struct BlackjackBottomView_Previews: PreviewProvider {
    @State static var betAmount = 100
    @State static var gameResult: String? = nil
    @State static var betPlaced = false
    
    static var previews: some View {
        BlackjackBottomView(
            betAmount: $betAmount,
            gameResult: $gameResult,
            betPlaced: $betPlaced,
            playerBalance: 900,
            placeBetAction: {},
            hitAction: {},
            standAction: {}
        )
    }
}
