//
//  MiniGamesView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import SwiftUI

struct MiniGamesView: View {
    
    @EnvironmentObject var exchangeModel: CoinExchangeModel
    @EnvironmentObject var blackjackModel: BlackjackModel

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                // Background
                BackgroundView(type: .minigames)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    
                    Text("Mini Games")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, -12)

                    Spacer()
                    
                    // Navigation link to the Blackjack game
                    NavigationLink(destination: BlackjackView()) {
                        Text("Play Blackjack")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue) // Button background color
                            .foregroundColor(.white) // Button text color
                            .cornerRadius(8) // Rounded corners
                    }
                                        
                    NavigationLink(destination: TetrisView()) {
                        Text("Play Tetris")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

struct MiniGamesView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel.shared
        let cryptoStore = CryptoStore()
        let model = BlackjackModel(exchangeModel: exchangeModel, cryptoStore: cryptoStore)
                
        return MiniGamesView()
            .environmentObject(CoinExchangeModel.shared)
            .environmentObject(model)
    }
}
