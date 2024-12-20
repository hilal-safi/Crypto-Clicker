//
//  MiniGamesView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import SwiftUI

struct MiniGamesView: View {

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                // Background
                BackgroundView(type: .achievements)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Mini Games")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Spacer()

                    // Navigation link to the Blackjack game
                    NavigationLink(destination: BlackjackView(model: BlackjackModel(initialBalance: 1000, playerBalance: 1000))) {
                        Text("Play Blackjack")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue) // Button background color
                            .foregroundColor(.white) // Button text color
                            .cornerRadius(8) // Rounded corners
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            .navigationTitle("Mini Games")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MiniGamesView_Previews: PreviewProvider {
    
    static var previews: some View {
        return MiniGamesView()
    }
}