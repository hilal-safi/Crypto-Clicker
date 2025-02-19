//
//  BackgroundView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import SwiftUI

struct BackgroundView: View {
    
    @Environment(\.colorScheme) var colorScheme // Use environment's color scheme
    
    /// Enum representing different background types for various screens in the app.
    enum BackgroundType {
        case store, settings, achievements, minigames, blackjack, `default`
    }

    let type: BackgroundType // Background type for the current view

    var body: some View {
        
        GeometryReader { geometry in
            ZStack {
                backgroundImage(for: type, geometry: geometry) // Dynamically load background image
                adaptiveOverlay // Add overlay for better contrast
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true) // Background should not interfere with VoiceOver navigation
    }
    
    // MARK: - Helper Views

    /// Provides the appropriate background image with common styling.
    /// - Parameters:
    ///   - type: The type of background to be displayed.
    ///   - geometry: Geometry proxy for determining screen size.
    /// - Returns: A resizable background image view.
    private func backgroundImage(for type: BackgroundType, geometry: GeometryProxy) -> some View {
        
        let imageName: String
        
        // Determine the correct background image based on the type
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
            .opacity(0.3) // Reduce opacity for better readability
            .blur(radius: 2) // Slight blur effect for aesthetic enhancement
            .accessibilityHidden(true) // Prevent VoiceOver from reading image
    }
    
    /// Adds an adaptive overlay for dark/light mode to improve contrast and readability.
    private var adaptiveOverlay: some View {
        
        Color(colorScheme == .dark ? .black : .white)
            .opacity(0.5) // Adjust transparency for readability
            .ignoresSafeArea()
            .accessibilityHidden(true) // Background overlay should not be interactive
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
