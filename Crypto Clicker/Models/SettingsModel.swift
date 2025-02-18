//
//  SettingsModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import Foundation
import SwiftUI

class SettingsModel: ObservableObject {
    
    // MARK: - Initializer

    init() {
        // Appearance mode
        self.appearanceMode = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "auto") ?? .auto
        
        // Load haptics from UserDefaults or default to true
        self.enableHaptics = UserDefaults.standard.object(forKey: "enableHaptics") as? Bool ?? true
        
        // Sounds
        self.enableSounds  = UserDefaults.standard.object(forKey: "enableSounds")  as? Bool ?? false
        
        // Difficulty
        let storedDifficulty = UserDefaults.standard.string(forKey: "difficulty") ?? "normal"
        self.difficulty = Difficulty(rawValue: storedDifficulty) ?? .normal
        
        // Make sure the initial state is reflected
        HapticFeedbackModel.hapticsEnabled = enableHaptics
    }
    
    // MARK: - Enums
    
    // Light, dark and auto themes
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
    
    // Difficulty setting
    enum Difficulty: String, CaseIterable, Identifiable {
        
        case easy, normal, hard
        var id: String { self.rawValue }
        
        // Production multiplier:
        var productionMultiplier: Double {
            
            switch self {
                case .easy:   return 1.15 // Easy = 15% extra to coin generation
                case .normal: return 1.0 // Normal = no change
                case .hard:   return 0.85 // Hard = 15% less to coin generation
            }
        }
        
        // Cost multiplier:
        var costMultiplier: Double {
            
            switch self {
                case .easy:   return 0.85 // Easy = 15% cheaper costs
                case .normal: return 1.0 // Normal = no change
                case .hard:   return 1.15 // Hard = 15% higher costs
            }
        }
        
        // Round the value according to difficulty:
        func roundValue(_ value: Decimal) -> Decimal {
            
            switch self {
                
                // Easy => round **up** (ceil)
                case .easy:
                    return value.roundedUpToWhole()
                
                // Normal => round down
                case .normal:
                    return value.roundedDownToWhole()
                
                // Hard => round down
                case .hard:
                    return value.roundedDownToWhole()
            }
        }
    }
    
    enum ResetType: CaseIterable {
        
        case coins, powerUps, exchangedCoins, achievements, steps, miniGames, all

        var description: String {
            switch self {
            case .coins: return "Reset your coin value to 0."
            case .powerUps: return "Remove all your power-ups."
            case .exchangedCoins: return "Reset all exchanged coins."
            case .achievements: return "Reset all achievements."
            case .steps: return "Reset total steps and coins from steps."
            case .miniGames: return "Reset all unlocked mini-games."
            case .all: return "Reset everything."
            }
        }

        var buttonLabel: String {
            switch self {
            case .coins: return "💰 Reset Coins 💰"
            case .powerUps: return "💻 Remove Power-Ups 💻"
            case .exchangedCoins: return "🪙 Reset Exchanged Coins 🪙"
            case .achievements: return "🏆 Reset Achievements 🏆"
            case .steps: return "👟 Reset Steps 👟"
            case .miniGames: return "🎮 Reset Mini-Games 🎮"
            case .all: return "⚠️ Remove All ⚠️"
            }
        }
    }

    // MARK: - Published Properties
    
    @Published var refreshTrigger: Int = 0 // Triggers a view refresh
    @Published var resetExchangedCoins: Bool = false // To reset exchanged coins

    @Published var appearanceMode: AppearanceMode {
        didSet {
            refreshTrigger += 1 // Force refresh on change
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }
    
    @Published var enableHaptics: Bool {
        didSet {
            // Whenever the user toggles haptics in Settings,
            // update the static flag in HapticFeedbackModel.
            HapticFeedbackModel.hapticsEnabled = enableHaptics
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
        
    // Reset handler logic centralized in the model
    @MainActor
    func handleReset(
        type: ResetType,
        store: CryptoStore,
        powerUps: PowerUps,
        coinExchange: CoinExchangeModel,
        achievements: AchievementsModel,
        miniGames: MiniGamesModel
    ) {
        switch type {
            case .coins:
                store.resetCoinValue()
            
            case .powerUps:
                store.resetPowerUps()
            
            case .exchangedCoins:
                coinExchange.resetExchangedCoins()
            
            case .achievements:
                achievements.resetAchievements()
            
            case .steps:
                store.resetSteps()
                PhoneSessionManager.shared.resetWatchLocalSteps()

            case .miniGames:
                miniGames.resetMiniGames()
            
            case .all:
                store.resetCoinValue()
                store.resetPowerUps()
                store.resetSteps()
                PhoneSessionManager.shared.resetWatchLocalSteps()
                coinExchange.resetExchangedCoins()
                achievements.resetAchievements()
                miniGames.resetMiniGames() // Locks the minigames previously unlocked
                store.resetStats() // Resets all other stats
            }
    }
}
