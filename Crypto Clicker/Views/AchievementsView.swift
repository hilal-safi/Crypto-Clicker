//
//  AchievementsView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import SwiftUI

struct AchievementsView: View {
    
    @ObservedObject var achievementsModel = AchievementsModel.shared
    @Binding var coins: CryptoCoin?

    let store: CryptoStore
    @ObservedObject var powerUps: PowerUps // ObservedObject for PowerUps
    let exchangeModel: CoinExchangeModel
    
    @State private var hasAppeared = false // Flag to track if the view has already appeared
    @State private var viewID = UUID() // Unique ID to force view reload

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
                        .accessibilityLabel("Achievements Screen") // VoiceOver: Descriptive screen title
                    
                    // Achievements list
                    ScrollView {
                        
                        // Add top padding to prevent shadow cutoff
                        Spacer().frame(height: 16) // Add space above the first item

                        LazyVStack(spacing: 18) {
                            getAchievementsList()
                        }
                        .padding(.horizontal, 18)
                    }
                    .padding(.top, 8) // Reduce padding above the list to bring it closer to the title
                    .accessibilityHint("Scroll through to view unlocked and pending achievements") // VoiceOver hint
                }
                .padding(.horizontal, 2)
            }
        }
        .id(viewID) // Attach the unique ID to the view
        .onAppear {
            hasAppeared = true
            
            // Ensure achievements are refreshed safely
            do {
                try refreshAchievements()
            } catch {
                print("Error refreshing achievements: \(error.localizedDescription)") // Error handling
            }
        }
        .onDisappear {
            hasAppeared = false // Reset the flag when the view disappears
        }
    }
    
    private func getAchievementsList() -> some View {
        
        ForEach(achievementsModel.achievements, id: \.id) { achievement in
            AchievementItemView(achievement: achievement, achievementsModel: achievementsModel)
                .accessibilityLabel("Achievement: \(achievement.name)") // VoiceOver: Achievement name
                .accessibilityHint("Progress: \(achievement.currentProgress) out of \(achievement.tiers.max() ?? 0)") // VoiceOver progress hint
        }
    }
    
    /// Refreshes the achievements by reloading progress
    /// Ensures safe execution by catching potential errors
    private func refreshAchievements() throws {
        
        achievementsModel.loadProgress() // Reload achievements from storage
        
        guard let coins = coins else {
            throw NSError(domain: "CryptoClicker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve coins data."]) // Error handling
        }
        
        achievementsModel.refreshProgress(
            coins: coins,
            coinsPerSecond: store.coinsPerSecond,
            coinsPerClick: store.coinsPerClick
        )
        viewID = UUID() // Force a unique view reload
    }
}

struct AchievementsView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let mockCoins = CryptoCoin(value: Decimal(10000))
        let mockExchangeModel = CoinExchangeModel.shared // Use the shared instance
        let mockPowerUps = PowerUps.shared
        let mockStore = CryptoStore()
        
        // Use AchievementsModel.shared for the singleton pattern
        let mockAchievementsModel = AchievementsModel.shared
        mockAchievementsModel.configureDependencies(
            exchangeModel: mockExchangeModel,
            powerUps: mockPowerUps,
            store: mockStore
        ) // Configure dependencies
        
        return AchievementsView(
            coins: .constant(mockCoins),
            store: mockStore,
            powerUps: mockPowerUps,
            exchangeModel: mockExchangeModel
        )
        .environmentObject(mockAchievementsModel) // Add the environment object here
    }
}
