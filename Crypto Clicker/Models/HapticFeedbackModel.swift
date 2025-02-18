//
//  HapticFeedbackModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import UIKit

class HapticFeedbackModel {
    
    /// This flag is toggled by your app's SettingsModel. If false, no haptics occur.
    static var hapticsEnabled: Bool = true

    /// Triggers light haptic feedback.
    static func triggerLightHaptic() {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Triggers normal (medium) haptic feedback.
    static func triggerNormalHaptic() {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Triggers strong haptic feedback.
    static func triggerStrongHaptic() {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}
