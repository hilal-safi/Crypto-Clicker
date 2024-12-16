//
//  MiniGamesView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import SwiftUI

struct MiniGamesView: View {
    
    var body: some View {
        
        ZStack {
            
            BackgroundView(type: .default)

            VStack {
                Text("Mini Games")
                    .font(.largeTitle)
                    .padding()
                
                Text("Choose a mini game to play!")
                    .font(.headline)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Mini Games")
        }
    }
}

struct MiniGamesView_Previews: PreviewProvider {
    static var previews: some View {
        MiniGamesView()
    }
}
