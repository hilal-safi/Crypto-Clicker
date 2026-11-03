import SwiftUI
import CryptoClickerKit

/// The coin artwork in a finish: the gold coin, recoloured (see `CoinFinishImage`, which the
/// widgets share). Holographic shimmers through every hue, and holds still with Reduce Motion on.
struct CoinArt: View {
    var finish = CoinFinish.gold
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if finish == .holographic && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let degrees = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) * 60
                Image("Coin").resizable().scaledToFit().hueRotation(.degrees(degrees))
            }
        } else {
            CoinFinishImage(finish: finish)
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
                                    .font(.subheadline.weight(.semibold))
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
