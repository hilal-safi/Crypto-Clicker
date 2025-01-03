//
//  CoinView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI
import AudioToolbox

struct CoinView: View {
    
    @Binding var coinValue: Decimal
    @ObservedObject var settings: SettingsModel // Observe changes in settings
    let incrementAction: () -> Void
    @State private var isCoinPressed = false // State to control animation

    var body: some View {
        
        Button(action: {
            // Trigger animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.3)) {
                isCoinPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCoinPressed = false
                }
            }
            
            // Increment the coin value
            incrementAction()
            
            // Play sound if sounds are enabled
            if settings.enableSounds {
                AudioServicesPlaySystemSound(1104) // "Tock" sound
            }
            
            // Trigger haptic feedback if enabled
            if settings.enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            
        }) {
            Image("Coin")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .scaleEffect(isCoinPressed ? 1.2 : 1.0) // Apply scaling effect
                .foregroundColor(.yellow)
                .shadow(radius: 10)
                .padding()
        }
        .buttonStyle(PlainButtonStyle()) // Prevent default button styling
    }
}

struct CoinView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        CoinView(
            coinValue: .constant(10),
            settings: SettingsModel() // Provide an instance of SettingsModel
        ) {
            print("Coin incremented!")
        }
    }
}
