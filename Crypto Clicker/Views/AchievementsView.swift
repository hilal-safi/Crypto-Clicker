//
//  AchievementsView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

struct AchievementsView: View {
    
    @EnvironmentObject var achievements: AchievementsModel
    @Binding var coins: CryptoCoin?

    let coinsPerSecond: Int
    let coinsPerClick: Int

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                // Background
                BackgroundView(type: .achievements)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    
                    Text("Achievements")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)

                    // Achievements list
                    ScrollView {
                        
                        LazyVStack(spacing: 12) {
                            ForEach(achievements.achievements, id: \.name) { achievement in
                                AchievementItemView(
                                    achievement: achievement,
                                    progress: progress(for: achievement.name)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 12)
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // Get progress dynamically based on achievement type
    private func progress(for achievementName: String) -> Int {
        var progressValue: Int

        switch achievementName {
        case "Mining Coins":
            progressValue = coins?.value ?? 0
        case "Coins Per Second":
            progressValue = coinsPerSecond
        case "Coins Per Click":
            progressValue = coinsPerClick
        case let name where name.contains("Exchanged"):
            progressValue = achievements.getProgress(for: achievementName)
            print("Progress for \(achievementName): \(progressValue)") // Debugging log
        case let name where name.contains("Ownership"):
            progressValue = achievements.getProgress(for: achievementName)
            print("Progress for \(achievementName): \(progressValue)") // Debugging log
        default:
            progressValue = 0
        }

        print("Final Progress for \(achievementName): \(progressValue)") // Final debugging log
        return progressValue
    }
    
    private func progressForPowerUps(name: String) -> Int {
        let value = AchievementsModel.shared.getProgressForPowerUps(named: name)
        print("Power-Up progress for \(name): \(value)") // Debugging log
        return value
    }

    private func progressForCoins(name: String) -> Int {
        let value = AchievementsModel.shared.getProgressForCoins(named: name)
        print("Coin progress for \(name): \(value)") // Debugging log
        return value
    }
}

struct AchievementsView_Previews: PreviewProvider {

    static var previews: some View {
        // Mock data
        let mockCoins = CryptoCoin(value: 10000)
        let mockExchangeModel = CoinExchangeModel()
        let mockPowerUps = PowerUps() // Use actual PowerUps initialization

        return AchievementsView(
            coins: .constant(mockCoins),
            coinsPerSecond: 15000,  // Example value
            coinsPerClick: 50       // Example value
        )
        .environmentObject(AchievementsModel(
            exchangeModel: mockExchangeModel,
            powerUps: mockPowerUps
        ))
    }
}
