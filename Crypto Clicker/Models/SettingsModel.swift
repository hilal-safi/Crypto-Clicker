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
            case .auto:  return nil
            case .light: return .light
            case .dark:  return .dark
            }
        }
    }
    
    // NEW: Difficulty setting
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy, normal, hard
        
        var id: String { self.rawValue }
        
        // Production multiplier:
        // - Easy = +15% to coin generation
        // - Normal = no change
        // - Hard = -15% to coin generation
        var productionMultiplier: Double {
            
            switch self {
                case .easy:   return 1.15
                case .normal: return 1.0
                case .hard:   return 0.85
            }
        }
        
        // Cost multiplier:
        // - Easy = -15% cheaper costs
        // - Normal = no change
        // - Hard = +15% cost
        var costMultiplier: Double {
            
            switch self {
                case .easy:   return 0.85
                case .normal: return 1.0
                case .hard:   return 1.15
            }
        }
        
        // Round the value according to difficulty:
        // - Easy => round **up** (ceil)
        // - Normal => round down
        // - Hard => round down
        func roundValue(_ value: Decimal) -> Decimal {
            switch self {
                
                case .easy:
                    return value.roundedUpToWhole()
                
                case .normal:
                    return value.roundedDownToWhole()
                
                case .hard:
                    return value.roundedDownToWhole()
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var appearanceMode: AppearanceMode {
        didSet {
            refreshTrigger += 1 // Force refresh on change
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }
    
    @Published var refreshTrigger: Int = 0 // Triggers a view refresh
    
    @Published var resetExchangedCoins: Bool = false // To reset exchanged coins

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
    
    // Difficulty property
    @Published var difficulty: Difficulty {
        didSet {
            refreshTrigger += 1
            UserDefaults.standard.set(difficulty.rawValue, forKey: "difficulty")
        }
    }
        
    // MARK: - Initializer
    
    init() {
        // Appearance mode
        self.appearanceMode = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "auto") ?? .auto
        
        // Haptics & Sounds
        self.enableHaptics = UserDefaults.standard.object(forKey: "enableHaptics") as? Bool ?? true
        self.enableSounds  = UserDefaults.standard.object(forKey: "enableSounds")  as? Bool ?? false
        
        // Difficulty
        let storedDifficulty = UserDefaults.standard.string(forKey: "difficulty") ?? "normal"
        self.difficulty = Difficulty(rawValue: storedDifficulty) ?? .normal
    }
}
