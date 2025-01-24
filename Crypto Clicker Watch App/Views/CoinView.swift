//
//  CoinView.swift
//  Crypto Clicker Watch App
//
//  Created by Hilal Safi on 2025-01-15.
//

import SwiftUI
import WatchKit

/// A view that displays and handles the watch coin’s tap interactions.
struct CoinView: View {
    
    @ObservedObject var watchManager: WatchSessionManager
    
    /// Local state for button-press animation
    @State private var isCoinPressed = false
    
    var body: some View {
        
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isCoinPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    isCoinPressed = false
                }
            }
            // Tap coin on the phone side
            watchManager.tapCoin()
            
            // Trigger haptic feedback
            WKInterfaceDevice.current().play(.click)
        }) {
            ZStack {
                // Main Coin Image
                Image("coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .shadow(radius: 10)
                    .scaleEffect(isCoinPressed ? 1.15 : 1.0)
                
                // Coin Sparkle Effect (Overlay)
                if isCoinPressed {
                    Circle()
                        .strokeBorder(Color.yellow, lineWidth: 5)
                        .scaleEffect(1.5)
                        .opacity(0)
                        .animation(.easeOut(duration: 0.4), value: isCoinPressed)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        // **Accessibility**: Provide a clear label describing the coin button
        .accessibilityLabel("Tap coin to earn coins.")
        .accessibilityAddTraits(.isButton)
    }
}

struct CoinView_Previews: PreviewProvider {
    static var previews: some View {
        CoinView(watchManager: WatchSessionManager.shared)
    }
}
