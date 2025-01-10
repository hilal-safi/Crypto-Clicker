//
//  HapticFeedbackModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import UIKit

class HapticFeedbackModel {
    
    /// Triggers light haptic feedback.
    static func triggerLightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Triggers normal (medium) haptic feedback.
    static func triggerNormalHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Triggers strong haptic feedback.
    static func triggerStrongHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}
