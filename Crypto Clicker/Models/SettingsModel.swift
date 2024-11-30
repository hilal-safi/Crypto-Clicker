//
//  SettingsModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import Foundation
import SwiftUI

class SettingsModel: ObservableObject {
    
    enum AppearanceMode: String, CaseIterable, Identifiable {
        
        case auto, light, dark
        
        var id: String { self.rawValue }
        
        var colorScheme: ColorScheme? {
            switch self {
            case .auto: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    @Published var appearanceMode: AppearanceMode {
        didSet {
            refreshTrigger += 1 // Force refresh on change
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    @Published var refreshTrigger: Int = 0 // Triggers a view refresh

    @Published var enableHaptics: Bool {
        didSet {
            UserDefaults.standard.set(enableHaptics, forKey: "enableHaptics")
        }
    }
    
    @Published var enableSounds: Bool {
        didSet {
            UserDefaults.standard.set(enableSounds, forKey: "enableSounds")
        }
    }
    
    @Published var coinSize: Double {
        didSet {
            UserDefaults.standard.set(coinSize, forKey: "coinSize")
        }
    }
    
    init() {
        self.appearanceMode = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "auto") ?? .auto
        self.enableHaptics = UserDefaults.standard.object(forKey: "enableHaptics") as? Bool ?? true
        self.enableSounds = UserDefaults.standard.object(forKey: "enableSounds") as? Bool ?? false
        self.coinSize = UserDefaults.standard.object(forKey: "coinSize") as? Double ?? 2 // Default to medium size
    }
}
