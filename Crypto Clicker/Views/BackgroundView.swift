//
//  BackgroundView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import SwiftUI

struct BackgroundView: View {
    @Environment(\.colorScheme) var colorScheme // Use environment's color scheme
    
    var body: some View {
        ZStack {
            // Background image with transparency and blur
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.3)
                .blur(radius: 2)
            
            // Adaptive color overlay
            Color(colorScheme == .dark ? .black : .white)
                .opacity(0.5)
                .ignoresSafeArea()
        }
    }
}

struct BackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BackgroundView().environment(\.colorScheme, .light)
            BackgroundView().environment(\.colorScheme, .dark)
        }
    }
}
