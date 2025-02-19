//
//  TetrisMiddleView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import SwiftUI

struct TetrisMiddleView: View {
    
    @EnvironmentObject var tetrisModel: TetrisModel
    @EnvironmentObject var cryptoStore: CryptoStore

    var body: some View {
        
        HStack {
            
            VStack {
                
                Text("Top Score:")
                    .font(.headline)
                    .bold()
                    .accessibilityLabel("Top Score")

                Text(formattedNumber(tetrisModel.topScore))
                    .font(.title3)
                    .bold()
                    .accessibilityLabel("Your top score is \(formattedNumber(tetrisModel.topScore))")
            }

            Spacer()

            VStack(spacing: 4) {
                
                Text("Next:")
                    .font(.title3)
                    .bold()
                    .accessibilityLabel("Next piece")

                ZStack {
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 95, height: 55)
                        .cornerRadius(8)

                    if tetrisModel.gameState == .notStarted || tetrisModel.nextPiece == nil {
                        Text("❓")
                            .font(.system(size: 40))
                            .accessibilityLabel("Next piece is unknown")
                        
                    } else if let next = tetrisModel.nextPiece {
                        
                        TetrisPieceView(piece: next)
                            .frame(width: 50, height: 50)
                            .scaleEffect(1.5) // Scale the piece up
                            .offset(next.nextPieceOffset())
                            .accessibilityLabel("Next piece is a \(next.type.name)")
                    }
                }
            }

            Spacer()

            VStack {
                
                Text("Total Coins:")
                    .font(.headline)
                    .bold()
                    .accessibilityLabel("Total Coins")

                if let coins = cryptoStore.coins {
                    Text(formattedNumber(coins.value))
                        .font(.title3)
                        .bold()
                        .accessibilityLabel("You have \(formattedNumber(coins.value)) coins")
                } else {
                    Text("0")
                        .font(.title3)
                        .bold()
                        .accessibilityLabel("You have 0 coins")
                }
            }
        }
        .padding(.horizontal, 8)
    }

    /// Formats numbers with commas for better readability and accessibility.
    private func formattedNumber(_ value: Int?) -> String {
        guard let value = value else { return "0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    /// Overloaded function for Decimal numbers.
    private func formattedNumber(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }
}

struct TetrisMiddleView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let model = TetrisModel(cryptoStore: CryptoStore())
        
        return TetrisMiddleView()
            .environmentObject(model)
            .environmentObject(CryptoStore())
    }
}
