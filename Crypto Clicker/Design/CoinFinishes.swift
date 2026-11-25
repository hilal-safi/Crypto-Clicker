import SwiftUI
import CryptoClickerKit

/// The coin artwork in a finish: the gold coin, recoloured (see `CoinFinishImage`, which the
/// widgets share). Holographic shimmers through every hue and Aurora drifts from green to violet;
/// both hold still with Reduce Motion on.
struct CoinArt: View {
    var finish = CoinFinish.gold
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if finish == .holographic && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let degrees = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) * 60
                Image("Coin").resizable().scaledToFit().hueRotation(.degrees(degrees))
            }
        } else if finish == .aurora && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                // Twelve seconds from green through teal to violet and back.
                let phase = sin(context.date.timeIntervalSinceReferenceDate * .pi / 6)
                CoinFinishImage.aurora(Image("Coin").resizable().scaledToFit(), degrees: 175 + 60 * phase)
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

    var body: some View {
        let game = store.game
        let stars = game.earnedAchievementTiers
        let prestiges = game.stats.prestiges
        CoinStyleGrid(intro: "Earn achievement stars to unlock new finishes for the coin, and prestige for the last five. You have \(stars) \(stars == 1 ? "star" : "stars") and \(prestiges) \(prestiges == 1 ? "prestige" : "prestiges").",
                      items: CoinFinish.allCases, selected: $selected, stars: stars, tint: selected.glow,
                      name: \.name, starsNeeded: \.starsNeeded,
                      isUnlocked: { game.isUnlocked($0) }, requirement: { $0.requirement }) { finish, size in
            CoinArt(finish: finish)
                .frame(width: size, height: size)
                .shadow(color: finish.glow.opacity(0.5), radius: size * 0.14)
        }
        .sensoryFeedback(.selection, trigger: selected) { _, _ in haptics }
        .navigationTitle("Coin Finish")
        .navigationBarTitleDisplayMode(.inline)
    }
}
