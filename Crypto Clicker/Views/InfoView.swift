//
//  InfoView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

struct InfoView: View {
    
    @Environment(\.dismiss) var dismiss // Environment variable to dismiss the sheet

    var body: some View {
        
        VStack(alignment: .center, spacing: 16) {
            
            Text("Welcome to Crypto Clicker!")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
                .padding()
                .accessibilityLabel("Welcome to Crypto Clicker!") // VoiceOver
            
            Text("""
                 This game allows you to generate and manage your own cryptocurrency.
                 Tap the coin to increase its value, purchase power-ups to automate earnings,
                 and exchange your coins for Bronze, Silver, or Gold coins!
                 """)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .accessibilityLabel("Crypto Clicker lets you mine, upgrade, and exchange cryptocurrency in the game.") // VoiceOver summary
            
            Spacer()

            Button(action: {
                dismiss() // Dismiss the view when tapped
            }) {
                Text("Close")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .accessibilityLabel("Close information screen") // VoiceOver
        }
        .padding()
    }
}

struct InfoView_Previews: PreviewProvider {
    
    static var previews: some View {
        InfoView()
    }
}
