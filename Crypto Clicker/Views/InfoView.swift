//
//  InfoView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

struct InfoView: View {
    var body: some View {
        VStack(alignment: .center) {
            Text("Welcome to Crypto Clicker!")
                .font(.largeTitle)
                .padding()

            Text("""
                 This game allows you to generate and manage your own cryptocurrency.
                 Tap the coin to increase its value, purchase power-ups to automate earnings,
                 and exchange your coins for Bronze, Silver, or Gold coins!
                 """)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()

            Button("Close") {
                // Dismiss the sheet (auto-handled by SwiftUI)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView()
    }
}
