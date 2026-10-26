import SwiftUI
import CryptoClickerKit

extension CoinFinish {
    /// The glow around the coin.
    var glow: Color {
        switch self {
        case .gold: Theme.bitcoin
        case .silver: Color(white: 0.85)
        case .roseGold: Color(red: 0.95, green: 0.55, blue: 0.60)
        case .emerald: Color(red: 0.15, green: 0.80, blue: 0.45)
        case .sapphire: Color(red: 0.20, green: 0.45, blue: 1.00)
        case .amethyst: Color(red: 0.65, green: 0.35, blue: 0.95)
        case .obsidian: Color(red: 0.45, green: 0.30, blue: 0.60)
        case .holographic: Color(red: 0.40, green: 0.85, blue: 1.00)
        }
    }
}

/// The coin artwork in a finish: the gold coin, recoloured. Holographic shimmers through every
/// hue (and holds still with Reduce Motion on).
struct CoinArt: View {
    var finish = CoinFinish.gold
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let coin = Image("Coin").resizable().scaledToFit()
        switch finish {
        case .gold:
            coin
        case .silver:
            coin.saturation(0).brightness(0.06).contrast(1.15)
        case .roseGold:
            coin.hueRotation(.degrees(-30)).saturation(0.75).brightness(0.03)
        case .emerald:
            coin.hueRotation(.degrees(95)).saturation(1.1)
        case .sapphire:
            coin.hueRotation(.degrees(180)).saturation(1.1)
        case .amethyst:
            coin.hueRotation(.degrees(235)).saturation(0.95)
        case .obsidian:
            coin.saturation(0.15).brightness(-0.32).contrast(1.45)
        case .holographic:
            if reduceMotion {
                coin.hueRotation(.degrees(150))
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let degrees = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) * 60
                    coin.hueRotation(.degrees(degrees))
                }
            }
        }
    }
}

/// The finishes, unlocked by achievement stars, for picking one in Settings.
struct CoinFinishPicker: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.coinFinishKey) private var selected = CoinFinish.gold
    @AppStorage(Preferences.hapticsKey) private var haptics = true

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 14)]

    var body: some View {
        let stars = store.game.earnedAchievementTiers
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Earn achievement stars to unlock new finishes for the coin. You have \(stars) \(stars == 1 ? "star" : "stars").")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(CoinFinish.allCases) { finish in
                        let unlocked = finish.isUnlocked(stars: stars)
                        Button {
                            if unlocked { selected = finish }
                        } label: {
                            VStack(spacing: 8) {
                                CoinArt(finish: finish)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: finish.glow.opacity(unlocked ? 0.5 : 0), radius: 10)
                                    .opacity(unlocked ? 1 : 0.35)
                                    .overlay {
                                        if !unlocked {
                                            Image(systemName: "lock.fill")
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                Text(finish.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(unlocked ? (selected == finish ? "Selected" : "Unlocked") : "\(finish.starsNeeded) stars")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selected == finish ? Theme.accent : Theme.subtext)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                CardSurface(cornerRadius: 18)
                                    .overlay {
                                        if selected == finish {
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .strokeBorder(Theme.accent, lineWidth: 2.5)
                                        }
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: selected) { _, _ in haptics }
                        .accessibilityLabel(finish.name)
                        .accessibilityValue(unlocked ? (selected == finish ? "Selected" : "Unlocked")
                                                     : "Locked, needs \(finish.starsNeeded) stars")
                        .accessibilityAddTraits(selected == finish ? .isSelected : [])
                    }
                }
            }
            .padding(16)
        }
        .background { AppBackground(tint: selected.glow) }
        .navigationTitle("Coin Finish")
        .navigationBarTitleDisplayMode(.inline)
    }
}
