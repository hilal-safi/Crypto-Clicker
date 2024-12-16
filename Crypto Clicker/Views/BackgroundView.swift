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
        case store, settings, achievements, `default`
    }

    let type: BackgroundType
    
    var body: some View {
        
        ZStack {
            
            switch type {
                
            case .store:
                // Background image with transparency and blur for store
                Image("StoreBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.3)
                    .blur(radius: 2)
                
                // Adaptive color overlay
                Color(colorScheme == .dark ? .black : .white)
                    .opacity(0.5)
                    .ignoresSafeArea()

            case .settings:
                // Background image with transparency and blur for settings
                Image("SettingsBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.3)
                    .blur(radius: 2)
                
                // Adaptive color overlay
                Color(colorScheme == .dark ? .black : .white)
                    .opacity(0.5)
                    .ignoresSafeArea()
                
            case .achievements:
                // Background image with transparency and blur for settings
                Image("AchievementsBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.3)
                    .blur(radius: 2)
                
                // Adaptive color overlay
                Color(colorScheme == .dark ? .black : .white)
                    .opacity(0.5)
                    .ignoresSafeArea()


            case .default:
                // Default background image with transparency and blur
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
            
            BackgroundView(type: .default)
                .environment(\.colorScheme, .light)
        }
    }
}
