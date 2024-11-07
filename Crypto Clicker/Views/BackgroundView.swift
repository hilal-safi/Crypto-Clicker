//
//  BackgroundView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import SwiftUI

struct BackgroundView: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        ZStack {
            // Background image with transparency and blur
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.3) // Set the transparency to 30%
                .blur(radius: 2)
            
            // White or black tint based on color scheme
            Color(colorScheme == .dark ? .black : .white)
                .opacity(0.5) // Adjust the opacity to make the tint subtle
                .ignoresSafeArea()
        }
    }
}

struct BackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundView(colorScheme: .light) // Preview for light mode
        BackgroundView(colorScheme: .dark) // Preview for dark mode
    }
}
