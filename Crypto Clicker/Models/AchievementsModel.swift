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
    var currentProgress: Int // Track the current progress
    let image: String // Add image property
}

class AchievementsModel: ObservableObject {
    
    static let shared = AchievementsModel(
        exchangeModel: CoinExchangeModel.shared,
        powerUps: PowerUps.shared
    )
    
    @Published var achievements: [Achievement] = []
    
    var coins: CryptoCoin?
    let exchangeModel: CoinExchangeModel
    @Published var powerUps: PowerUps = PowerUps.shared // Use the shared instance

    @Published private var progress: [String: Int] = [:] // Tracks progress for each achievement
    
    private let progressKey = "achievement_progress"
    private var hasSyncedInitialProgress = false // Flag to track if progress has been synced

    init(exchangeModel: CoinExchangeModel, powerUps: PowerUps) {
        
        self.exchangeModel = exchangeModel
        self.powerUps = powerUps
        
        loadProgress() // Load progress after initializing stored properties
        generateAchievements() // Generate achievements after stored properties are initialized
        syncInitialProgress() // Sync initial progress based on current state
        print("[DEBUG] AchievementsModel initialized with ID: \(ObjectIdentifier(self).hashValue)")
    }
    
    // Dynamically generate achievements based on available coin types and power-ups
    private func generateAchievements() {
        
        achievements.append(
            
            Achievement(
                name: "Mining Coins",
                description: "Mine coins to achieve these milestones.",
                tiers: [10, 5000, 100000],
                currentProgress: 0, // Initial value for progress
                image: "💰"
            )
        )
        achievements.append(
            
            Achievement(
                name: "Coins Per Second",
                description: "Earn coins per second to reach these levels.",
                tiers: [5, 250, 10000],
                currentProgress: 0, // Initial value for progress
                image: "💵"
            )
        )
        achievements.append(
            
            Achievement(
                
                name: "Coins Per Click",
                description: "Increase coins earned per click to these values.",
                tiers: [2, 100, 7500],
                currentProgress: 0, // Initial value for progress
                image: "💸"
            )
        )
        
        // Add achievements for exchanged coins
        for coin in exchangeModel.availableCoins {
            
            achievements.append(
                
                Achievement(
                    name: "Exchanged \(coin.label)",
                    description: "Exchange \(coin.label) to achieve milestones.",
                    tiers: [1, 200, 5000],
                    currentProgress: 0, // Initial value for progress
                    image: coin.imageName // Use the coin's image name
                )
            )
        }

        // Add achievements for power-ups
        for powerUp in PowerUps.availablePowerUps {
            
            achievements.append(
                
                Achievement(
                    name: "\(powerUp.name) Ownership",
                    description: "Own \(powerUp.name) to reach these levels.",
                    tiers: [1, 200, 5000],
                    currentProgress: 0, // Initial value for progress
                    image: powerUp.emoji // Use the power-up's emoji
                )
            )
        }

        // Add general achievements
        achievements.append(
            Achievement(
                name: "Total Exchanged Coins",
                description: "Exchange coins to achieve these totals.",
                tiers: [100, 10000, 100000],
                currentProgress: 0, // Initial value for progress
                image: "🏆"
            )
        )
        achievements.append(
            Achievement(
                name: "Total Power-Ups Owned",
                description: "Own power-ups to achieve these totals.",
                tiers: [100, 10000, 100000],
                currentProgress: 0, // Initial value for progress
                image: "🏆"
            )
        )
    }

    // Sync initial progress with current state
    private func syncInitialProgress() {
        
        guard !hasSyncedInitialProgress else {
            print("[DEBUG] Initial progress already synced. Skipping.")
            return
        }
        hasSyncedInitialProgress = true // Set the flag to true to prevent re-execution

        print("[DEBUG] Starting syncInitialProgress in AchievementsModel with ID: \(ObjectIdentifier(self).hashValue)")

        // Sync progress for each coin type
        for coin in exchangeModel.availableCoins {
            let progressValue = exchangeModel.getExchangedCount(for: coin.type)
            print("[DEBUG] Syncing progress for coin: \(coin.label) - Value: \(progressValue)")
            setProgress(for: "Exchanged \(coin.label)", value: progressValue)
        }

        // Sync progress for each power-up
        for powerUp in PowerUps.availablePowerUps {
            let progressValue = powerUps.getOwnedCount(for: powerUp.name)
            print("[DEBUG] Syncing progress for power-up: \(powerUp.name) - Owned Count: \(progressValue)")
            if progressValue == 0 {
                print("[DEBUG] WARNING: Power-up \(powerUp.name) shows zero ownership.")
            }
            setProgress(for: "\(powerUp.name) Ownership", value: progressValue)
        }
        
        // Sync total exchanged coins owned
        let totalCoinsExchanged = exchangeModel.totalExchangedCoins()
        print("[DEBUG] Total coins exchanged: \(totalCoinsExchanged)")
        setProgress(for: "Total Exchanged Coins", value: totalCoinsExchanged)

        print("[DEBUG] Syncing initial progress for power-ups (MODEL FILE):")
        powerUps.debugQuantities()

        // Sync total power-ups owned
        let totalPowerUpsOwned = powerUps.calculateTotalOwned()
        print("[DEBUG] Total power-ups owned: \(totalPowerUpsOwned)")
        setProgress(for: "Total Power-Ups Owned", value: totalPowerUpsOwned)

        // Calculate and sync coins per second
        let coinsPerSecond = powerUps.calculateCoinsPerSecond()
        print("[DEBUG] Coins per second: \(coinsPerSecond)")
        setProgress(for: "Coins Per Second", value: coinsPerSecond)

        // Calculate and sync coins per click
        let coinsPerClick = powerUps.calculateCoinsPerClick()
        print("[DEBUG] Coins per click: \(coinsPerClick)")
        setProgress(for: "Coins Per Click", value: coinsPerClick)

        saveProgress() // Save the updated progress
    }
    
    private func progress(for achievementName: String) -> Int {
        let progressValue = progress[achievementName] ?? 0
        print("Progress for \(achievementName): \(progressValue)") // Debug log
        return progressValue
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
        let updatedValue = max(progress[achievementName] ?? 0, value)
        print("Setting progress for \(achievementName): \(updatedValue)") // Debug log
        progress[achievementName] = updatedValue
    }
    
    // Get progress for a specific achievement
    func getProgress(for achievementName: String) -> Int {
        if let cachedProgress = progress[achievementName] {
            return cachedProgress
        }
        // No need to recompute progress unless explicitly triggered
        print("[DEBUG] Progress for \(achievementName) is already cached.")
        return 0
    }
    
    // Get progress for power-ups
    func getProgressForPowerUps(named name: String) -> Int {
        let ownedCount = powerUps.getOwnedCount(for: name)
        print("Fetching power-up progress for \(name): \(ownedCount)") // Debug log
        return ownedCount
    }
    
    // Get progress for coins
    func getProgressForCoins(named name: String) -> Int {
        if let coin = exchangeModel.availableCoins.first(where: { name.contains($0.label) }) {
            let exchangedCount = exchangeModel.getExchangedCount(for: coin.type)
            print("Fetching coin progress for \(coin.label): \(exchangedCount)") // Debug log
            return exchangedCount
        }
        print("Fetching coin progress for \(name): 0 (No match found)") // Debug log
        return 0
    }
    
    // Refresh achievement progress
    func refreshProgress(coins: CryptoCoin?, coinsPerSecond: Int, coinsPerClick: Int) {
        guard let coins = coins else {
            print("[DEBUG] Coins are nil. Skipping refresh.")
            return
        }

        print("[DEBUG] Refreshing progress with values:")
        print("[DEBUG] Coins: \(coins.value), Coins Per Second: \(coinsPerSecond), Coins Per Click: \(coinsPerClick)")

        for i in 0..<achievements.count {
            let achievement = achievements[i]
            print("[DEBUG] Refreshing achievement: \(achievement.name)")

            switch achievement.name {
            case "Mining Coins":
                let value = coins.value
                achievements[i].currentProgress = value
                setProgress(for: "Mining Coins", value: value)

            case "Coins Per Second":
                achievements[i].currentProgress = coinsPerSecond
                setProgress(for: "Coins Per Second", value: coinsPerSecond)

            case "Coins Per Click":
                achievements[i].currentProgress = coinsPerClick
                setProgress(for: "Coins Per Click", value: coinsPerClick)

            case let name where name.contains("Exchanged"):
                let value = getProgress(for: name)
                achievements[i].currentProgress = value

            case let name where name.contains("Ownership"):
                let powerUpName = name.replacingOccurrences(of: " Ownership", with: "")
                let ownedCount = powerUps.getOwnedCount(for: powerUpName)
                print("[DEBUG] Refreshing achievement: \(name) - Owned Count: \(ownedCount)")
                achievements[i].currentProgress = ownedCount
                setProgress(for: name, value: ownedCount)

            case "Total Exchanged Coins":
                let totalExchanged = exchangeModel.totalExchangedCoins()
                achievements[i].currentProgress = totalExchanged
                setProgress(for: "Total Exchanged Coins", value: totalExchanged)

            case "Total Power-Ups Owned":
                let totalPowerUpsOwned = powerUps.calculateTotalOwned()
                print("[DEBUG] Total power-ups owned: \(totalPowerUpsOwned)")
                achievements[i].currentProgress = totalPowerUpsOwned
                setProgress(for: "Total Power-Ups Owned", value: totalPowerUpsOwned)

            default:
                print("[DEBUG] No specific logic for '\(achievement.name)'.")
            }
        }

        print("[DEBUG] Finished refreshing progress.")
        saveProgress()
    }
    
    // Persistence
    private func saveProgress() {
        print("[DEBUG] Saving achievement progress to UserDefaults: \(progress)")

        UserDefaults.standard.set(progress, forKey: progressKey)
    }

    private func loadProgress() {
        if let savedProgress = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] {
            progress = savedProgress
        } else {
            print("[DEBUG] No saved progress found. Initializing empty dictionary.")
        }
        print("[DEBUG] Loaded progress: \(progress)")
    }

    // Test Method for Isolating AchievementsModel
    func isolateAndTest() {
        print("[DEBUG] Testing AchievementsModel in isolation...")
        generateAchievements()
        syncInitialProgress()
        print("[DEBUG] Achievements: \(achievements)")
        print("[DEBUG] Current Progress: \(progress)")
    }
}
