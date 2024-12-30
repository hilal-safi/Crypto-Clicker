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

    let store: CryptoStore
    @ObservedObject var powerUps: PowerUps // ObservedObject for PowerUps
    let exchangeModel: CoinExchangeModel
    
    @State private var hasAppeared = false // Flag to track if the view has already appeared

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                // Background
                BackgroundView(type: .achievements)
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    
                    Text("Achievements")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, -12)
                    
                    // Achievements list
                    ScrollView {
                        
                        LazyVStack(spacing: 12) {
                            getAchievementsList()
                        }
                        .padding(.horizontal, 14)
                    }
                    .padding(.top, 8) // Reduce padding above the list to bring it closer to the title
                }
                .padding(.horizontal, 10)
            }
        }
        .onAppear {
            // Only run the refresh when the page loads
            if !hasAppeared {
                
                hasAppeared = true
                achievements.refreshProgress(coins: coins,
                                             coinsPerSecond: store.coinsPerSecond,
                                             coinsPerClick: store.coinsPerClick)
            }
        }
        .onDisappear {
            hasAppeared = false // Reset the flag when the view disappears
        }
    }
    
    private func getAchievementsList() -> some View {
        
        ForEach(achievements.achievements, id: \.name) { achievement in
            
            AchievementItemView(
                achievement: achievement,
                progress: achievements.getProgress(for: achievement.name)
            )
        }
    }

}

struct AchievementsView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let mockCoins = CryptoCoin(value: 10000)
        let mockExchangeModel = CoinExchangeModel()
        let mockPowerUps = PowerUps.shared
        let mockStore = CryptoStore()
        let mockAchievementsModel = AchievementsModel(exchangeModel: mockExchangeModel, powerUps: mockPowerUps)

        return AchievementsView(
            coins: .constant(mockCoins),
            store: mockStore,
            powerUps: mockPowerUps,
            exchangeModel: mockExchangeModel
        )
        .environmentObject(mockAchievementsModel) // Add the environment object here
    }
}
