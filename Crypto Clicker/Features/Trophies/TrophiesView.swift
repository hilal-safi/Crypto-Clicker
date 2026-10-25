import SwiftUI
import CryptoClickerKit

struct TrophiesView: View {
    @Environment(GameStore.self) private var store

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        let game = store.game
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    TrophySummary(earned: game.earnedAchievementTiers, total: AchievementCatalog.tierCount,
                                  bonus: game.achievementBonus - 1)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AchievementCatalog.all) { achievement in
                            AchievementCard(achievement: achievement,
                                            tiers: game.tiersEarned(achievement),
                                            value: game.value(of: achievement.metric),
                                            next: game.nextThreshold(achievement))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background { AppBackground(tint: Theme.trophies) }
            .navigationTitle("Trophies")
            .balanceToolbar()
        }
    }
}

private struct TrophySummary: View {
    let earned: Int
    let total: Int
    let bonus: Double

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.trophies)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(earned) of \(total) stars")
                    .font(.title3.bold())
                Text("+\(CoinFormat.percent(bonus)) production from achievements")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(earned), total: Double(max(1, total)))
                    .tint(Theme.trophies)
            }
        }
        .glassCard(tint: Theme.trophies.opacity(0.12))
        .accessibilityElement(children: .combine)
    }
}

/// One achievement: its stars, and progress toward the next tier.
private struct AchievementCard: View {
    let achievement: Achievement
    let tiers: Int
    let value: Double
    let next: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let emoji = achievement.emoji {
                    Text(emoji)
                        .font(.system(size: 28))
                } else if let imageName = achievement.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
                Spacer()
                TierStars(earned: tiers)
            }
            Text(achievement.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(achievement.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
            if let next {
                ProgressView(value: min(value, next), total: next)
                    .tint(Theme.tierColor(tiers))
                Text("\(CoinFormat.short(value)) / \(CoinFormat.short(next))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Label("Complete", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tierColor(2))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowCard()
        .opacity(tiers == 0 ? 0.75 : 1)
        .accessibilityElement(children: .combine)
    }
}
