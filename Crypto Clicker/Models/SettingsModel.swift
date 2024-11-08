//
//  SettingsModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import SwiftUI
import Combine

class SettingsModel: ObservableObject {
    
    @Published var enableSounds: Bool = false
    @Published var enableHaptics: Bool = true
    @Published var coinSize: Double = 2.0 // Default to "Medium"
    @Published var appearanceMode: AppearanceMode = .auto // Track selected mode
    
    enum AppearanceMode: String, CaseIterable, Identifiable {
        case auto, light, dark
        var id: String { self.rawValue }
    }

    var selectedColorScheme: ColorScheme? {
        switch appearanceMode {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return nil // Defaults to system setting for auto mode
        }
    }
}
