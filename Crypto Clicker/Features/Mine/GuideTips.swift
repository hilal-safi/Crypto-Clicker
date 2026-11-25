import SwiftUI
import CryptoClickerKit

/// Tips for a new player, one at a time, each shown when the game reaches the moment it's about.
/// A tip goes away once it no longer applies, or for good when the player closes it.
enum GuideTip: String, CaseIterable {
    case tapCoin, buyMiner, combo, offlineMining, nextTier, howToPlay, daily, tokens, firstPoint, prestige

    var icon: String {
        switch self {
        case .tapCoin: "👆"
        case .buyMiner: "💻"
        case .combo: "🔥"
        case .offlineMining: "🌙"
        case .nextTier: "🚀"
        case .howToPlay: "📖"
        case .daily: "🎁"
        case .tokens: "🪙"
        case .firstPoint: "✨"
        case .prestige: "🌟"
        }
    }

    func text(in game: GameState) -> String {
        switch self {
        case .nextTier:
            let miner = Self.nextTier(in: game) ?? .desktop
            return "You can afford \(miner.article) \(miner.name). Each new tier earns far more a second than the one before."
        case .firstPoint:
            let points = CoinFormat.grouped(game.prestigePointsToRecommend)
            return "Your first prestige point is earned, but prestiging now would barely speed you up. Keep mining: the Shop suggests it at \(points) points."
        default:
            return text
        }
    }

    private var text: String {
        switch self {
        case .nextTier: ""
        case .tapCoin: "Tap the coin to mine your first coins."
        case .buyMiner: "You can afford a Chromebook. Miners earn coins for you every second."
        case .combo: "Tap quickly to build a combo: up to twice the coins per tap."
        case .offlineMining: "Miners keep earning for six minutes after you leave, at a share of your income that Offline Efficiency raises. Offline Mining lengthens the time."
        case .howToPlay: "How to Play is in the Settings tab, with the full rules for every game."
        case .daily: "A daily reward is waiting. Claim one every day to build a streak, and check the day's quests."
        case .tokens: "Casino games are played with tokens from the Shop. Their prices move every five minutes, but they're the game's own, not real crypto."
        case .firstPoint: ""
        case .prestige: "Prestiging now would speed you up a lot. Your points also buy permanent perks."
        }
    }

    /// The button that takes the player there, if the tip has one.
    var actionTitle: String? {
        switch self {
        case .tapCoin, .combo: nil
        case .buyMiner, .nextTier: "Shop"
        case .offlineMining: "Get It"
        case .howToPlay: "Open"
        case .daily: "Daily"
        case .tokens: "Tokens"
        case .firstPoint: "Details"
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
        case .nextTier:
            game.stats.prestiges == 0 && Self.nextTier(in: game).map { game.coins >= game.price(of: $0, quantity: 1) } == true
        case .howToPlay:
            // Once the first miners are working, for the rest of the first run's opening.
            (2...15).contains(game.totalMiners) && game.stats.prestiges == 0
        case .daily:
            dailyRewardReady && game.stats.longestStreak == 0 && game.totalMiners > 0
        case .tokens:
            // Once a casino game is open, until the first token is bought.
            game.unlockedGames.contains { $0.isCasino } && game.stats.totalTokensBought == 0
        case .firstPoint:
            game.stats.prestiges == 0 && game.claimablePrestigePoints > 0 && !game.isPrestigeRecommended
        case .prestige:
            game.stats.prestiges == 0 && game.isPrestigeRecommended
        }
    }
}

extension GuideTip {
    /// The first of the early tiers (Desktop to Data Center) not owned yet, once it shows in the Shop.
    static func nextTier(in game: GameState) -> MinerID? {
        MinerID.allCases.prefix(5).dropFirst().first { game.isRevealed($0) && game.owned($0) == 0 }
    }
}

/// The first tip that applies and hasn't been closed, in a small card on the Mine tab; when there's
/// none, the next goal (unless the player turned it off in Settings).
struct GuideTipCard: View {
    let openShop: () -> Void
    let openPowerUps: () -> Void
    let openTokens: () -> Void
    let openDaily: () -> Void
    let openHowToPlay: () -> Void
    let openGoal: (Goal.Kind) -> Void
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.dismissedTipsKey) private var dismissed = ""
    @AppStorage(Preferences.howToPlaySeenKey) private var seenHowToPlay = false
    @AppStorage(Preferences.showsNextGoalKey) private var showsNextGoal = true

    var body: some View {
        let game = store.game
        let closed = Set(dismissed.split(separator: ",").map(String.init) + (seenHowToPlay ? [GuideTip.howToPlay.rawValue] : []))
        let tip = GuideTip.allCases.first {
            !closed.contains($0.rawValue) && $0.applies(to: game, dailyRewardReady: store.isDailyRewardReady)
        }
        // The goal waits for the first miner: until then the tips say what to do.
        let goal = tip == nil && showsNextGoal && game.totalMiners > 0 ? game.featuredGoal : nil
        Group {
            if let goal {
                NextGoalCard(goal: goal) { openGoal(goal.kind) }
                    .id(goal.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let tip {
                HStack(spacing: 12) {
                    Text(tip.icon)
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text(tip.text(in: store.game))
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
        .animation(.smooth, value: goal?.id)
    }

    private func act(on tip: GuideTip) {
        switch tip {
        case .buyMiner, .nextTier: openShop()
        case .prestige, .firstPoint: openGoal(.prestige)
        case .offlineMining: openPowerUps()
        case .tokens: openTokens()
        case .daily: openDaily()
        case .howToPlay: openHowToPlay()
        case .tapCoin, .combo: break
        }
    }

    private func close(_ tip: GuideTip) {
        var closed = dismissed.split(separator: ",").map(String.init)
        closed.append(tip.rawValue)
        withAnimation(.smooth) { dismissed = closed.joined(separator: ",") }
    }
}

/// The next goal, in the tip's place: what to do, what it brings, how close it is, and a tap to
/// go where it's done (the Shop, the Arcade, the achievements).
struct NextGoalCard: View {
    let goal: Goal
    let open: () -> Void

    var body: some View {
        let isReady = goal.progress >= 1
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: goal.kind.symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(goal.kind.color.gradient, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(goal.title)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Text(isReady ? String(localized: "Ready") : CoinFormat.percent((goal.progress * 100).rounded(.down) / 100))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(isReady ? Theme.gain : goal.kind.color)
                    }
                    Text(goal.detail)
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    ProgressView(value: goal.progress)
                        .tint(isReady ? Theme.gain : goal.kind.color)
                        .padding(.top, 2)
                }
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.subtext)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next goal: \(goal.title). \(goal.detail). \(isReady ? String(localized: "Ready") : CoinFormat.percent((goal.progress * 100).rounded(.down) / 100))")
        .accessibilityHint(goal.kind.destination)
    }
}
