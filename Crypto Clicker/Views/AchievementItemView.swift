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
                    .accessibilityLabel("Achievement: \(achievement.name)") // VoiceOver description

                Spacer() // Push image to the right
                
                if isEmoji(achievement.image) {
                    Text(achievement.image)
                        .font(.largeTitle) // Emoji size
                        .accessibilityLabel("Achievement icon: \(achievement.image)") // VoiceOver
                } else {
                    Image(achievement.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40) // Adjust the size of the image
                        .accessibilityLabel("Achievement icon") // VoiceOver
                }
            }

            // Description
            Text(achievement.description)
                .font(.subheadline)
                .foregroundColor(textColor(for: achievement.currentProgress).opacity(0.8))
                .accessibilityLabel("Description: \(achievement.description)") // VoiceOver
            
            // Stars and Progress Number
            HStack {
                
                ForEach(achievement.tiers, id: \.self) { tier in
                    Text(achievement.currentProgress >= tier ? "⭐" : "☆")
                        .font(.largeTitle) // Bigger stars
                        .foregroundColor(starColor(for: tier, progress: achievement.currentProgress)) // Adjust star color
                        .accessibilityLabel(achievement.currentProgress >= tier ? "Achieved tier \(tier)" : "Pending tier \(tier)") // VoiceOver
                }
                
                Spacer()
                
                Text("\(achievement.currentProgress) / \(achievement.tiers.max() ?? 0)")
                    .font(.caption)
                    .foregroundColor(textColor(for: achievement.currentProgress))
                    .accessibilityLabel("Progress: \(achievement.currentProgress) out of \(achievement.tiers.max() ?? 0)") // VoiceOver
            }
            
            // Progress Bar
            ProgressView(value: calculateProgressPercentage(for: achievement.currentProgress))
                .accentColor(.green)
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .frame(maxWidth: .infinity) // Make the progress bar span the full width
                .padding(.top, 8) // Add spacing between stars and progress bar
                .accessibilityLabel("Progress bar showing \(Int(calculateProgressPercentage(for: achievement.currentProgress) * 100)) percent completed") // VoiceOver
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

    // Determine text color based on progress and color scheme
    private func textColor(for progress: Int) -> Color {
        
        let completedTiers = achievement.tiers.filter { progress >= $0 }.count

        if completedTiers == 1 { // Bronze tier
            return .white // Make text color white
            
        } else if completedTiers == 0 {
            return colorScheme == .dark ? .white : .black // Use white for dark mode, black for light mode
            
        } else {
            return .black // Default for other tiers
        }
    }

    // Determine star color dynamically based on progress
    private func starColor(for tier: Int, progress: Int) -> Color {
        return progress >= tier ? .yellow : (colorScheme == .dark ? .white : .black)
    }

    // Glow effect based on progress
    private func glowColor(for progress: Int) -> Color {
        
        let completedTiers = achievement.tiers.filter { progress >= $0 }.count
        
        switch completedTiers {
            
            case 3: return Color.yellow
            case 2: return Color.white
            case 1: return Color.orange
                
            default: return .clear
        }
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
                    Color(red: 150 / 255, green: 75 / 255, blue: 0 / 255) // A slightly brighter bronze base
                        .shadow(color: Color(red: 165 / 255, green: 90 / 255, blue: 30 / 255).opacity(0.9), radius: 30, x: 0, y: 0) // Moderate bronze glow
                        .shadow(color: Color(red: 165 / 255, green: 90 / 255, blue: 30 / 255).opacity(0.8), radius: 50, x: 0, y: 0) // Layered glow
                        .shadow(color: Color(red: 165 / 255, green: 90 / 255, blue: 30 / 255).opacity(0.7), radius: 70, x: 0, y: 0) // Further layered glow
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.8), Color(red: 165 / 255, green: 90 / 255, blue: 30 / 255).opacity(0.6), Color.clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .animation(
                        Animation.linear(duration: 0.5).repeatForever(autoreverses: true), // Moderate shimmer speed
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
