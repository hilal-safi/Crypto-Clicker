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
    static let shared = AchievementsModel()
    
    @Published var achievements: [Achievement] = [
        Achievement(
            name: "Mining Coins",
            description: "Mine coins to achieve these milestones.",
            tiers: [10, 5000, 100000]
        ),
        Achievement(
            name: "Coins Per Second",
            description: "Earn coins per second to reach these levels.",
            tiers: [5, 250, 10000]
        ),
        Achievement(
            name: "Coins Per Click",
            description: "Increase coins earned per click to these values.",
            tiers: [2, 100, 7500]
        )
    ]
    
    @Published private var progress: [String: Int] = [:] // Tracks progress for each achievement
    private let progressKey = "achievement_progress"

    init() {
        loadProgress()
    }

    // Update progress based on stats
    func updateProgress(coins: Int, coinsPerSecond: Int, coinsPerClick: Int) {
        setProgress(for: "Mining Coins", value: coins)
        setProgress(for: "Coins Per Second", value: coinsPerSecond)
        setProgress(for: "Coins Per Click", value: coinsPerClick)
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
