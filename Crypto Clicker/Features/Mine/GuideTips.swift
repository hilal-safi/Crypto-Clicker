import SwiftUI
import CryptoClickerKit

/// Tips for a new player, one at a time, each shown when the game reaches the moment it's about.
/// A tip goes away once it no longer applies, or for good when the player closes it.
enum GuideTip: String, CaseIterable {
    case tapCoin, buyMiner, combo, offlineMining, daily, prestige

    var icon: String {
        switch self {
        case .tapCoin: "👆"
        case .buyMiner: "💻"
        case .combo: "🔥"
        case .offlineMining: "🌙"
        case .daily: "🎁"
        case .prestige: "🌟"
        }
    }

    var text: String {
        switch self {
        case .tapCoin: "Tap the coin to mine your first coins."
        case .buyMiner: "You can afford a Chromebook. Miners earn coins for you every second."
        case .combo: "Tap quickly to build a combo: up to twice the coins per tap."
        case .offlineMining: "Miners stop a minute after you leave. Offline Mining keeps them earning while the app is closed."
        case .daily: "A daily reward is waiting. Claim one every day to build a streak, and check the day's quests."
        case .prestige: "Prestiging now would speed you up a lot. Your points also buy permanent perks."
        }
    }

    /// The button that takes the player there, if the tip has one.
    var actionTitle: String? {
        switch self {
        case .tapCoin, .combo: nil
        case .buyMiner: "Shop"
        case .offlineMining: "Get It"
        case .daily: "Daily"
        case .prestige: "Prestige"
        }
    }

    /// Whether the tip is about what's happening in the game right now.
    func applies(to game: GameState, dailyRewardReady: Bool) -> Bool {
        switch self {
        case .tapCoin:
            game.stats.taps < 15 && game.totalMiners == 0 && game.stats.prestiges == 0
        case .buyMiner:
            game.totalMiners == 0 && game.stats.prestiges == 0 && game.coins >= game.price(of: .chromebook, quantity: 1)
        case .combo:
            game.stats.bestCombo < 10 && game.stats.taps >= 60
        case .offlineMining:
            game.offlineMiningLevel == 0 && game.totalMiners >= 3 && game.offlineMiningPrice.map { game.coins >= $0 } == true
        case .daily:
            dailyRewardReady && game.stats.longestStreak == 0 && game.totalMiners > 0
        case .prestige:
            game.stats.prestiges == 0 && game.isPrestigeRecommended
        }
    }
}

/// The first tip that applies and hasn't been closed, in a small card on the Mine tab.
struct GuideTipCard: View {
    let openShop: () -> Void
    let openPowerUps: () -> Void
    let openDaily: () -> Void
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.dismissedTipsKey) private var dismissed = ""

    var body: some View {
        let closed = Set(dismissed.split(separator: ",").map(String.init))
        let tip = GuideTip.allCases.first {
            !closed.contains($0.rawValue) && $0.applies(to: store.game, dailyRewardReady: store.isDailyRewardReady)
        }
        Group {
            if let tip {
                HStack(spacing: 12) {
                    Text(tip.icon)
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text(tip.text)
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let title = tip.actionTitle {
                        Button(title) { act(on: tip) }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .font(.subheadline.weight(.bold))
                    }
                    Button("Close tip", systemImage: "xmark") { close(tip) }
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.subtext)
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .id(tip)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: tip)
    }

    private func act(on tip: GuideTip) {
        switch tip {
        case .buyMiner, .prestige: openShop()
        case .offlineMining: openPowerUps()
        case .daily: openDaily()
        case .tapCoin, .combo: break
        }
    }

    private func close(_ tip: GuideTip) {
        var closed = dismissed.split(separator: ",").map(String.init)
        closed.append(tip.rawValue)
        withAnimation(.smooth) { dismissed = closed.joined(separator: ",") }
    }
}
