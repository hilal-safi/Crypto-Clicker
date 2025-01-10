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
            Text("Score: \(tetrisModel.score)")
                .font(.title3)
                .bold()
            
            Spacer()
            
            Button(action: { tetrisModel.pauseGame() }) {
                
                Text(tetrisModel.gameState == .paused ? "Resume" : "Pause")
                    .font(.body)
                    .padding(7.5)
                    .bold()
                    .background(tetrisModel.gameState == .notStarted ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(tetrisModel.gameState == .notStarted) // Disable when the game hasn't started
        }
        .padding(.horizontal, 14)
        .padding(.bottom, -4)
    }
}

struct TetrisTopView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let model = TetrisModel(cryptoStore: CryptoStore())
        
        return TetrisTopView()
            .environmentObject(model)
    }
}
