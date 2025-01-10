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
                
                Text("\(tetrisModel.topScore)")
                    .font(.title3)
                    .bold()
            }

            Spacer()

            VStack(spacing: 4) {
                
                Text("Next:")
                    .font(.title3)
                    .bold()
                
                ZStack {
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 95, height: 55)
                        .cornerRadius(8)

                    if tetrisModel.gameState == .notStarted || tetrisModel.nextPiece == nil {
                        Text("❓")
                            .font(.system(size: 40))
                        
                    } else if let next = tetrisModel.nextPiece {
                        
                        TetrisPieceView(piece: next)
                            .frame(width: 50, height: 50)
                            .scaleEffect(1.5) // Scale the piece up
                            .offset(next.nextPieceOffset())
                    }
                }
            }

            Spacer()

            VStack {
                
                Text("Total Coins:")
                    .font(.headline)
                    .bold()
                
                if let coins = cryptoStore.coins {
                    Text("\(coins.value.formatted(.number))")
                        .font(.title3)
                        .bold()
                }
            }
        }
        .padding(.horizontal, 8)
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
