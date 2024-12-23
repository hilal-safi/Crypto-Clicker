//
//  BackgroundView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import SwiftUI

struct BackgroundView: View {
    
    @Environment(\.colorScheme) var colorScheme // Use environment's color scheme
    
    enum BackgroundType {
        case store, settings, achievements, minigames, blackjack, `default`
    }

    let type: BackgroundType
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundImage(for: type, geometry: geometry)
                adaptiveOverlay
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Views

    /// Provides the appropriate background image with common styling.
    private func backgroundImage(for type: BackgroundType, geometry: GeometryProxy) -> some View {
        
        let imageName: String
        
        switch type {
            case .store: imageName = "StoreBackground"
            case .settings: imageName = "SettingsBackground"
            case .achievements: imageName = "AchievementsBackground"
            case .minigames: imageName = "MiniGamesBackground"
            case .blackjack: imageName = "BlackjackBackground"
            case .default: imageName = "Background"
        }
        
        return Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height) // Match screen size
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2) // Center the image
            .opacity(0.3)
            .blur(radius: 2)
    }
    
    /// Adds an adaptive overlay for dark/light mode.
    private var adaptiveOverlay: some View {
        
        Color(colorScheme == .dark ? .black : .white)
            .opacity(0.5)
            .ignoresSafeArea()
    }
}

struct BackgroundView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        Group {
            BackgroundView(type: .store)
                .environment(\.colorScheme, .light)
            
            BackgroundView(type: .settings)
                .environment(\.colorScheme, .dark)
            
            BackgroundView(type: .achievements)
                .environment(\.colorScheme, .light)
            
            BackgroundView(type: .blackjack)
                .environment(\.colorScheme, .dark)
            
            BackgroundView(type: .default)
                .environment(\.colorScheme, .light)
        }
    }
}
