//
//  AchievementsModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import Foundation
import SwiftUI

struct Achievement {
    let name: String
    let description: String
    let tiers: [Int] // Milestones for the achievement
}

class AchievementsModel: ObservableObject {
    
    static let shared = AchievementsModel(exchangeModel: CoinExchangeModel(), powerUps: PowerUps())
    @Published var achievements: [Achievement] = []
    
    let exchangeModel: CoinExchangeModel
    let powerUps: PowerUps
    
    @Published private var progress: [String: Int] = [:] // Tracks progress for each achievement
    private let progressKey = "achievement_progress"

    init(exchangeModel: CoinExchangeModel, powerUps: PowerUps) {
        self.exchangeModel = exchangeModel
        self.powerUps = powerUps
        loadProgress() // Load progress after initializing stored properties
        generateAchievements() // Generate achievements after stored properties are initialized
        syncInitialProgress() // Sync initial progress based on current state
    }
    
    // Dynamically generate achievements based on available coin types and power-ups
    private func generateAchievements() {
        // Add original achievements
        achievements.append(
            Achievement(
                name: "Mining Coins",
                description: "Mine coins to achieve these milestones.",
                tiers: [10, 5000, 100000]
            )
        )
        achievements.append(
            Achievement(
                name: "Coins Per Second",
                description: "Earn coins per second to reach these levels.",
                tiers: [5, 250, 10000]
            )
        )
        achievements.append(
            Achievement(
                name: "Coins Per Click",
                description: "Increase coins earned per click to these values.",
                tiers: [2, 100, 7500]
            )
        )
        
        // Add achievements for exchanged coins
        for coin in exchangeModel.availableCoins {
            achievements.append(
                Achievement(
                    name: "Exchanged \(coin.label)",
                    description: "Exchange \(coin.label) to achieve milestones.",
                    tiers: [1, 200, 5000]
                )
            )
        }

        // Add achievements for power-ups
        for powerUp in PowerUps.availablePowerUps {
            achievements.append(
                Achievement(
                    name: "\(powerUp.name) Ownership",
                    description: "Own \(powerUp.name) to reach these levels.",
                    tiers: [1, 200, 5000]
                )
            )
        }

        // Add general achievements
        achievements.append(
            Achievement(
                name: "Total Exchanged Coins",
                description: "Exchange coins to achieve these totals.",
                tiers: [100, 10000, 100000]
            )
        )
        achievements.append(
            Achievement(
                name: "Total Power-Ups Owned",
                description: "Own power-ups to achieve these totals.",
                tiers: [100, 10000, 100000]
            )
        )
    }

    // Sync initial progress with current state
    private func syncInitialProgress() {
        // Sync progress for each coin type
        for coin in exchangeModel.availableCoins {
            let progressValue = exchangeModel.getExchangedCount(for: coin.type)
            setProgress(for: "Exchanged \(coin.label)", value: progressValue)
        }

        // Sync progress for each power-up
        for powerUp in PowerUps.availablePowerUps {
            let progressValue = powerUps.getOwnedCount(for: powerUp.name)
            setProgress(for: "\(powerUp.name) Ownership", value: progressValue)
        }

        // Sync total progress
        let totalCoinsExchanged = exchangeModel.totalExchangedCoins
        setProgress(for: "Total Exchanged Coins", value: totalCoinsExchanged())

        let totalPowerUpsOwned = powerUps.totalOwnedPowerUps
        setProgress(for: "Total Power-Ups Owned", value: totalPowerUpsOwned)
        
        saveProgress() // Save the updated progress
    }

    // Update progress based on stats
    func updateProgress(statistics: [String: Int]) {
        for (achievementName, value) in statistics {
            setProgress(for: achievementName, value: value)
        }
        saveProgress()
    }

    // Set progress for a specific achievement
    func setProgress(for achievementName: String, value: Int) {
        progress[achievementName] = max(progress[achievementName] ?? 0, value)
    }

    // Get progress for a specific achievement
    func getProgress(for achievementName: String) -> Int {
        return progress[achievementName] ?? 0
    }

    // Get progress for power-ups
    func getProgressForPowerUps(named name: String) -> Int {
        return powerUps.getOwnedCount(for: name)
    }

    // Get progress for coins
    func getProgressForCoins(named name: String) -> Int {
        return exchangeModel.availableCoins.first(where: { $0.label == name })?.count ?? 0
    }
    
    // Persistence
    private func saveProgress() {
        UserDefaults.standard.set(progress, forKey: progressKey)
    }

    private func loadProgress() {
        if let savedProgress = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] {
            progress = savedProgress
        }
    }
}
