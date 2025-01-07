//
//  AchievementsModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import Foundation
import SwiftUI

struct Achievement: Identifiable {
    let id = UUID() // Unique identifier
    let name: String
    let description: String
    let tiers: [Int] // Milestones for the achievement
    var currentProgress: Int // Track the current progress
    let image: String // Add image property
}

class AchievementsModel: ObservableObject {
    
    static let shared = AchievementsModel()

    @Published var achievements: [Achievement] = []
    @Published private var progress: [String: Int] = [:] // Tracks progress for each achievement

    var coins: CryptoCoin?
    var store: CryptoStore? // Reference to the store for accessing steps data
    let exchangeModel: CoinExchangeModel
    @Published var powerUps: PowerUps = PowerUps.shared // Use the shared instance

    private let progressKey = "achievement_progress"
    private var hasSyncedInitialProgress = false // Flag to track if progress has been synced

    // Remove direct dependency on CoinExchangeModel and PowerUps
    private init() {
        
        self.exchangeModel = CoinExchangeModel.shared
        self.powerUps = PowerUps.shared
        
        defer {
            loadProgress()
        }
    }

    @MainActor
    func configureDependencies(exchangeModel: CoinExchangeModel, powerUps: PowerUps, store: CryptoStore) {

        self.store = store
        generateAchievements(exchangeModel: exchangeModel, powerUps: powerUps)
        syncInitialProgress(exchangeModel: exchangeModel, powerUps: powerUps)
    }
    
    // Dynamically generate achievements based on available coin types and power-ups
    private func generateAchievements(exchangeModel: CoinExchangeModel, powerUps: PowerUps) {

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
        
        // Step related achievements
        achievements.append(
            Achievement(
                name: "Total Steps Taken",
                description: "Achieve these steps milestones.",
                tiers: [1000, 10000, 100000],
                currentProgress: 0,
                image: "👣"
            )
        )
        achievements.append(
            Achievement(
                name: "Coins Earned from Steps",
                description: "Earn these coins from your steps.",
                tiers: [10000, 500000, 10000000],
                currentProgress: 0,
                image: "👞"
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
    @MainActor
    private func syncInitialProgress(exchangeModel: CoinExchangeModel, powerUps: PowerUps) {

        guard !hasSyncedInitialProgress else {
            return
        }
        
        hasSyncedInitialProgress = true // Set the flag to true to prevent re-execution

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
        
        // Sync total exchanged coins owned
        let totalCoinsExchanged = exchangeModel.totalExchangedCoins()
        setProgress(for: "Total Exchanged Coins", value: totalCoinsExchanged)

        // Sync total power-ups owned
        let totalPowerUpsOwned = powerUps.calculateTotalOwned()
        setProgress(for: "Total Power-Ups Owned", value: totalPowerUpsOwned)

        // Calculate and sync coins per second
        let coinsPerSecond = powerUps.calculateCoinsPerSecond()
        setProgress(for: "Coins Per Second", value: coinsPerSecond)

        // Calculate and sync coins per click
        let coinsPerClick = powerUps.calculateCoinsPerClick()
        setProgress(for: "Coins Per Click", value: coinsPerClick)

        
        // Sync step-related achievements if store is available
        if let store = self.store {
            
            let totalStepsTaken = store.totalSteps
            setProgress(for: "Total Steps Taken", value: totalStepsTaken)
            
            let coinsFromStepsInt = NSDecimalNumber(decimal: store.totalCoinsFromSteps).intValue
            setProgress(for: "Coins Earned from Steps", value: coinsFromStepsInt)
        }

        saveProgress() // Save the updated progress
    }
    
    private func progress(for achievementName: String) -> Int {
        let progressValue = progress[achievementName] ?? 0
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
        progress[achievementName] = updatedValue
    }
    
    // Get progress for a specific achievement
    func getProgress(for achievementName: String) -> Int {
        if let cachedProgress = progress[achievementName] {
            return cachedProgress
        }
        return 0
    }
        
    // Refresh achievement progress
    @MainActor
    func refreshProgress(coins: CryptoCoin?, coinsPerSecond: Decimal, coinsPerClick: Decimal) {
        
        guard let coins = coins else {
            return
        }

        for i in 0..<achievements.count {
            
            let achievement = achievements[i]

            switch achievement.name {
                
            case "Mining Coins":
                let value = coins.value
                achievements[i].currentProgress = NSDecimalNumber(decimal: value).intValue
                setProgressDecimal(for: "Mining Coins", value: value)

            case "Coins Per Second":
                achievements[i].currentProgress = NSDecimalNumber(decimal: coinsPerSecond).intValue
                setProgressDecimal(for: "Coins Per Second", value: coinsPerSecond)

            case "Coins Per Click":
                achievements[i].currentProgress = NSDecimalNumber(decimal: coinsPerClick).intValue
                setProgressDecimal(for: "Coins Per Click", value: coinsPerClick)
                
            case "Total Steps Taken":
                if let store = self.store {
                    let steps = store.totalSteps
                    achievements[i].currentProgress = steps
                    setProgress(for: "Total Steps Taken", value: steps)
                }

            case "Coins Earned from Steps":
                if let store = self.store {
                    let coinsFromSteps = NSDecimalNumber(decimal: store.totalCoinsFromSteps).intValue
                    achievements[i].currentProgress = coinsFromSteps
                    setProgress(for: "Coins Earned from Steps", value: coinsFromSteps)
                }

            case let name where name.contains("Exchanged"):
                
                let coinLabel = name.replacingOccurrences(of: "Exchanged ", with: "")
                
                if let coin = exchangeModel.availableCoins.first(where: { $0.label == coinLabel }) {
                    let exchangedCount = exchangeModel.getExchangedCount(for: coin.type)
                    achievements[i].currentProgress = exchangedCount
                    setProgress(for: name, value: exchangedCount)
                }

            case let name where name.contains("Ownership"):
                
                let powerUpName = name.replacingOccurrences(of: " Ownership", with: "")
                let ownedCount = powerUps.getOwnedCount(for: powerUpName)
                
                achievements[i].currentProgress = ownedCount
                setProgress(for: name, value: ownedCount)

            case "Total Exchanged Coins":
                let totalExchanged = exchangeModel.totalExchangedCoins()
                achievements[i].currentProgress = totalExchanged
                setProgress(for: "Total Exchanged Coins", value: totalExchanged)

            case "Total Power-Ups Owned":
                let totalPowerUpsOwned = powerUps.calculateTotalOwned()
                achievements[i].currentProgress = totalPowerUpsOwned
                setProgress(for: "Total Power-Ups Owned", value: totalPowerUpsOwned)

            default:
                break
            }
        }
        saveProgress()
    }
    
    // Set progress for achievements using Decimal
    func setProgressDecimal(for achievementName: String, value: Decimal) {
        // Convert to Int for compatibility with existing progress dictionary
        let intValue = NSDecimalNumber(decimal: value).intValue
        let updatedValue = max(progress[achievementName] ?? 0, intValue)
        progress[achievementName] = updatedValue
    }
    
    // Persistence
    func saveProgress() {
        UserDefaults.standard.set(progress, forKey: progressKey)
    }

    func loadProgress() {
        if let savedProgress = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] {
            progress = savedProgress
        }
    }
    
    // Reset achievements completely
    func resetAchievements() {
        
        for i in 0..<achievements.count {
            achievements[i].currentProgress = 0
            setProgress(for: achievements[i].name, value: 0)
        }
        saveProgress()
    }
}
