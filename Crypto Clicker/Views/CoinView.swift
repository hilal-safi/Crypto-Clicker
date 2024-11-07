//
//  CoinView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI
import AudioToolbox

struct CoinView: View {
    
    @Binding var coinValue: Int
    @ObservedObject var settings: SettingsModel // Observe changes in settings
    let incrementAction: () -> Void
    
    var body: some View {
        Button(action: {
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
            Image("bitcoin")
                .resizable()
                .scaledToFit()
                .frame(width: 75 + (90 * CGFloat(settings.coinSize)), height: 75 + (90 * CGFloat(settings.coinSize)))
                .padding()
        }
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
