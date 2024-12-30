//
//  AchievementsItemView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import SwiftUI

struct AchievementItemView: View {
    
    let achievement: Achievement
    let progress: Int

    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            HStack {
                // Title and Image
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(textColor())
                
                Spacer() // Push image to the right
                
                // Achievement Image (handles emojis and uploaded images)
                if isEmoji(achievement.image) {
                    Text(achievement.image)
                        .font(.largeTitle) // Emoji size
                } else {
                    Image(achievement.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40) // Adjust the size of the image
                }
            }

            // Description
            Text(achievement.description)
                .font(.subheadline)
                .foregroundColor(textColor().opacity(0.8))
            
            // Stars for Tiers
            HStack {
                
                ForEach(achievement.tiers, id: \.self) { tier in
                    
                    Text(progress >= tier ? "⭐" : "☆")
                        .font(.largeTitle) // Bigger stars
                        .foregroundColor(starColor(for: tier)) // Adjust star color
                }
            }
            
            // Progress Bar with Numerical Progress
            let progressPercentage = calculateProgressPercentage()
            
            HStack {
                
                ProgressView(value: progressPercentage)
                    .accentColor(.green)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                Text("\(progress) / \(achievement.tiers.max() ?? 0)")
                    .font(.caption)
                    .foregroundColor(textColor())
            }
        }
        .padding()
        .background(backgroundColor()) // Dynamic background
        .cornerRadius(10)
    }

    
    // Helper to determine if the string is an emoji
    private func isEmoji(_ text: String) -> Bool {
        return text.unicodeScalars.contains { $0.properties.isEmoji }
    }
    
    // Calculate progress as a percentage of the highest tier
    private func calculateProgressPercentage() -> Double {
        guard let maxTier = achievement.tiers.max() else { return 0.0 }
        return min(Double(progress) / Double(maxTier), 1.0)
    }

    // Determine background color based on completed tiers
    private func backgroundColor() -> Color {
        
        let completedTiers = achievement.tiers.filter { progress >= $0 }.count
    
        switch completedTiers {
            
        case 3:
            return Color.yellow // Gold for all tiers completed
        case 2:
            return Color(red: 211 / 255, green: 211 / 255, blue: 211 / 255) // Light grey for 2 tiers completed
        case 1:
            return Color(red: 205 / 255, green: 127 / 255, blue: 50 / 255) // Bronze for 1 tier completed
        default:
            return Color.black.opacity(0.8) // Dark grey for no tiers completed
        }
    }

    // Determine text color based on background
    private func textColor() -> Color {
        let completedTiers = achievement.tiers.filter { progress >= $0 }.count
        return completedTiers == 0 ? .white : .black
    }

    // Determine star color dynamically based on progress and background
    private func starColor(for tier: Int) -> Color {
        
        if progress >= tier {
            return .yellow // Filled star
            
        } else if backgroundColor() == Color.black.opacity(0.8) {
            return .white // Blank star on dark background
            
        } else {
            return .black // Blank star on other backgrounds
        }
    }
}

struct AchievementItemView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        VStack {
            
            AchievementItemView(
                achievement: Achievement(
                    name: "Mining Coins",
                    description: "Mine coins to achieve these milestones.",
                    tiers: [10, 5000, 100000],
                    currentProgress: 10000, // Example progress
                    image: "💰" // Example image
                ),
                progress: 10000 // Example progress
            )
            AchievementItemView(
                achievement: Achievement(
                    name: "Coins Per Second",
                    description: "Earn coins per second to reach these levels.",
                    tiers: [5, 250, 10000],
                    currentProgress: 200, // Example progress
                    image: "💵" // Example image

                ),
                progress: 200 // Example progress
            )
            AchievementItemView(
                achievement: Achievement(
                    name: "Coins Per Click",
                    description: "Increase coins earned per click to these values.",
                    tiers: [2, 100, 7500],
                    currentProgress: 1, // Example progress
                    image: "💸" // Example image
                ),
                progress: 1 // Example progress
            )
            AchievementItemView(
                achievement: Achievement(
                    name: "Exchanged Bitcoin",
                    description: "Exchange Bitcoin to achieve milestones.",
                    tiers: [1, 200, 5000],
                    currentProgress: 150,
                    image: "bitcoin_image" // Example uploaded image
                ),
                progress: 150
            )

        }
        .padding()
    }
}
