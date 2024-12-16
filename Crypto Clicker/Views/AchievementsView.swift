//
//  AchievementsView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

struct AchievementsView: View {
    
    @ObservedObject private var model = AchievementsModel.shared
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
                            ForEach(model.achievements, id: \.name) { achievement in
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
        
        switch achievementName {
            
        case "Mining Coins":
            return coins?.value ?? 0
        case "Coins Per Second":
            return coinsPerSecond
        case "Coins Per Click":
            return coinsPerClick
            
        default:
            return 0
        }
    }
}

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockCoins = CryptoCoin(value: 10000)

        return AchievementsView (
            coins: .constant(mockCoins),
            coinsPerSecond: 15000,  // Mock value for coins per second
            coinsPerClick: 50     // Mock value for coins per click
        )
    }
}
