//
//  AchievementsItemView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import SwiftUI

struct AchievementItemView: View {
    
    let achievement: Achievement
    @ObservedObject var achievementsModel: AchievementsModel
    @Environment(\.colorScheme) var colorScheme // Detect light or dark mode

    // Unique ID for debugging this view
    private let viewID = UUID()

    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            // Title and Image
            HStack {
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(textColor(for: achievement.currentProgress))
                
                Spacer() // Push image to the right
                
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
                .foregroundColor(textColor(for: achievement.currentProgress).opacity(0.8))
            
            // Stars and Progress Number
            HStack {
                ForEach(achievement.tiers, id: \.self) { tier in
                    Text(achievement.currentProgress >= tier ? "⭐" : "☆")
                        .font(.largeTitle) // Bigger stars
                        .foregroundColor(starColor(for: tier, progress: achievement.currentProgress)) // Adjust star color
                }
                Spacer()
                Text("\(achievement.currentProgress) / \(achievement.tiers.max() ?? 0)")
                    .font(.caption)
                    .foregroundColor(textColor(for: achievement.currentProgress))
            }
            
            // Progress Bar
            ProgressView(value: calculateProgressPercentage(for: achievement.currentProgress))
                .accentColor(.green)
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .frame(maxWidth: .infinity) // Make the progress bar span the full width
                .padding(.top, 8) // Add spacing between stars and progress bar
        }
        .padding()
        .background(background(for: achievement.currentProgress)) // Dynamic background
        .cornerRadius(10)
        .shadow(color: glowColor(for: achievement.currentProgress), radius: 10, x: 0, y: 0) // Glow effect
    }

    // Helper to determine if the string is an emoji
    private func isEmoji(_ text: String) -> Bool {
        return text.unicodeScalars.contains { $0.properties.isEmoji }
    }
    
    // Calculate progress as a percentage of the highest tier
    private func calculateProgressPercentage(for progress: Int) -> Double {
        guard let maxTier = achievement.tiers.max() else { return 0.0 }
        return min(Double(progress) / Double(maxTier), 1.0)
    }

    // Determine background color based on completed tiers with stronger shine
    private func background(for progress: Int) -> some View {
        
        let completedTiers = achievement.tiers.filter { progress >= $0 }.count

        switch completedTiers {
        case 3: // Gold shine with enhanced glow
            return AnyView(
                ZStack {
                    Color.yellow
                        .shadow(color: Color.yellow.opacity(1.0), radius: 40, x: 0, y: 0) // Strong gold glow
                        .shadow(color: Color.yellow.opacity(0.9), radius: 60, x: 0, y: 0) // Additional layered glow
                        .shadow(color: Color.yellow.opacity(0.8), radius: 80, x: 0, y: 0) // Further layered glow
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(1.0), Color.yellow.opacity(0.7), Color.clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .animation(
                        Animation.linear(duration: 0.4).repeatForever(autoreverses: true), // Faster shimmer
                        value: completedTiers
                    )
                    .blendMode(.overlay)
                }
                .cornerRadius(10)
            )
        case 2: // Silver shine with enhanced glow
            return AnyView(
                ZStack {
                    Color(red: 211 / 255, green: 211 / 255, blue: 211 / 255) // Silver base
                        .shadow(color: Color.gray.opacity(1.0), radius: 40, x: 0, y: 0) // Strong silver glow
                        .shadow(color: Color.gray.opacity(0.9), radius: 60, x: 0, y: 0) // Additional layered glow
                        .shadow(color: Color.gray.opacity(0.8), radius: 80, x: 0, y: 0) // Further layered glow
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.9), Color.gray.opacity(0.6), Color.clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .animation(
                        Animation.linear(duration: 0.4).repeatForever(autoreverses: true), // Faster shimmer
                        value: completedTiers
                    )
                    .blendMode(.overlay)
                }
                .cornerRadius(10)
            )
        case 1: // Bronze shine with enhanced glow
            return AnyView(
                ZStack {
                    Color(red: 205 / 255, green: 127 / 255, blue: 50 / 255) // Bronze base
                        .shadow(color: Color.orange.opacity(1.0), radius: 40, x: 0, y: 0) // Strong bronze glow
                        .shadow(color: Color.orange.opacity(0.9), radius: 60, x: 0, y: 0) // Additional layered glow
                        .shadow(color: Color.orange.opacity(0.8), radius: 80, x: 0, y: 0) // Further layered glow
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.9), Color.orange.opacity(0.6), Color.clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .animation(
                        Animation.linear(duration: 0.4).repeatForever(autoreverses: true), // Faster shimmer
                        value: completedTiers
                    )
                    .blendMode(.overlay)
                }
                .cornerRadius(10)
            )
        default: // Default blurred background
            return AnyView(
                BlurView(style: .systemMaterial, reduction: 0.8)
            )
        }
    }
    
    // Determine text color based on background and color scheme
    private func textColor(for progress: Int) -> Color {
        let completedTiers = achievement.tiers.filter { progress >= $0 }.count
        if completedTiers == 0 {
            return colorScheme == .dark ? .white : .black // Use white for dark mode, black for light mode
        } else {
            return .black
        }
    }
    
    // Determine star color dynamically based on progress and background
    private func starColor(for tier: Int, progress: Int) -> Color {
        if progress >= tier {
            return .yellow // Filled star
        } else {
            return colorScheme == .dark ? .white : .black // Blank star based on color scheme
        }
    }
    
    // Glow effect
    private func glowColor(for progress: Int) -> Color {
        let completedTiers = achievement.tiers.filter { progress >= $0 }.count

        switch completedTiers {
        case 3:
            return Color.yellow
        case 2:
            return Color.gray
        case 1:
            return Color.orange
        default:
            return .clear
        }
    }
}

struct AchievementItemView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let mockAchievementsModel = AchievementsModel.shared // Use the shared instance for simplicity

        VStack {
            AchievementItemView(
                achievement: Achievement(
                    name: "Mining Coins",
                    description: "Mine coins to achieve these milestones.",
                    tiers: [10, 5000, 100000],
                    currentProgress: 10000, // Example progress
                    image: "💰" // Example image
                ),
                achievementsModel: mockAchievementsModel // Pass the achievements model
            )
            AchievementItemView(
                achievement: Achievement(
                    name: "Coins Per Second",
                    description: "Earn coins per second to reach these levels.",
                    tiers: [5, 250, 10000],
                    currentProgress: 200000, // Example progress
                    image: "💵" // Example image
                ),
                achievementsModel: mockAchievementsModel // Pass the achievements model
            )
            AchievementItemView(
                achievement: Achievement(
                    name: "Coins Per Click",
                    description: "Increase coins earned per click to these values.",
                    tiers: [2, 100, 7500],
                    currentProgress: 1, // Example progress
                    image: "💸" // Example image
                ),
                achievementsModel: mockAchievementsModel // Pass the achievements model
            )
            AchievementItemView(
                achievement: Achievement(
                    name: "Exchanged Bitcoin",
                    description: "Exchange Bitcoin to achieve milestones.",
                    tiers: [1, 200, 5000],
                    currentProgress: 150, // Example progress
                    image: "bitcoin_image" // Example uploaded image
                ),
                achievementsModel: mockAchievementsModel // Pass the achievements model
            )
        }
        .padding()
    }
}
