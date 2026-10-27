import SwiftUI
import CryptoClickerKit

/// Opens today's Tetris challenge: the same pieces for everyone, all day.
struct DailyChallenge: Hashable {
    let day: String
}

struct ArcadeView: View {
    /// Goes up by one each time the Daily page asks to open today's Tetris challenge.
    var challengeRequests = 0
    @Environment(GameStore.self) private var store
    @State private var path = NavigationPath()
    @State private var handledChallengeRequests = 0

    var body: some View {
        let game = store.game
        let today = store.today
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeader(title: "Casino", detail: "Bet tokens from the Exchange")
                    ForEach(MiniGame.allCases.filter(\.isCasino)) { miniGame in
                        MiniGameRow(miniGame: miniGame, isUnlocked: game.isUnlocked(miniGame),
                                    canAfford: miniGame.unlockCost <= game.coins, record: record(for: miniGame, in: game))
                    }

                    SectionHeader(title: "Arcade", detail: "Every point pays coins")
                    if game.isUnlocked(.tetris) {
                        DailyChallengeCard(day: today, isBonusAvailable: game.isDailyChallengeBonusAvailable(today: today),
                                           best: game.dailyChallengeBest(today: today))
                    }
                    ForEach(MiniGame.allCases.filter { !$0.isCasino }) { miniGame in
                        MiniGameRow(miniGame: miniGame, isUnlocked: game.isUnlocked(miniGame),
                                    canAfford: miniGame.unlockCost <= game.coins, record: record(for: miniGame, in: game))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .onAppear(perform: showChallengeIfAsked)
            .onChange(of: challengeRequests) { _, _ in showChallengeIfAsked() }
            .background { AppBackground(tint: Theme.arcade) }
            .navigationTitle("Arcade")
            .balanceToolbar()
            .navigationDestination(for: MiniGame.self) { miniGame in
                switch miniGame {
                case .blackjack: BlackjackView()
                case .slots: SlotsView()
                case .tetris: TetrisView()
                case .merge2048: Merge2048View()
                case .snake: SnakeView()
                case .brickBreaker: BrickBreakerView()
                case .bubbleBlaster: BubbleBlasterView()
                }
            }
            .navigationDestination(for: DailyChallenge.self) { challenge in
                TetrisView(challengeDay: challenge.day)
            }
        }
    }

    /// Opens today's challenge once for each request, closing an open game screen first.
    private func showChallengeIfAsked() {
        guard handledChallengeRequests != challengeRequests else { return }
        handledChallengeRequests = challengeRequests
        guard store.game.isUnlocked(.tetris) else { return }
        let wasInGame = !path.isEmpty
        path = NavigationPath()
        Task {
            try? await Task.sleep(for: .milliseconds(wasInGame ? 450 : 50))
            path.append(DailyChallenge(day: store.today))
        }
    }

    private func record(for miniGame: MiniGame, in game: GameState) -> String {
        let stats = game.stats
        return switch miniGame {
        case .blackjack: "\(CoinFormat.grouped(stats.blackjackWins)) hands won"
        case .slots: "\(CoinFormat.grouped(stats.slotsWins)) wins · \(CoinFormat.grouped(stats.slotsJackpots)) jackpots"
        case .tetris: "Best \(CoinFormat.grouped(stats.tetrisBestScore))"
        case .merge2048: stats.merge2048BestTile > 0
            ? "Best \(CoinFormat.grouped(stats.merge2048BestScore)) · top tile \(stats.merge2048BestTile)"
            : "Best 0"
        case .snake: "Best \(CoinFormat.grouped(stats.snakeBestScore))"
        case .brickBreaker: "Best \(CoinFormat.grouped(stats.brickBreakerBestScore))"
        case .bubbleBlaster: "Best \(CoinFormat.grouped(stats.bubbleBestScore))"
        }
    }
}

extension MiniGame {
    var icon: String {
        switch self {
        case .blackjack: "🃏"
        case .slots: "🎰"
        case .tetris: "🧱"
        case .merge2048: "🔢"
        case .snake: "🐍"
        case .brickBreaker: "💥"
        case .bubbleBlaster: "🫧"
        }
    }

    /// Deep enough for white "Play" text to read clearly (at least 4.5:1 contrast).
    var color: Color {
        switch self {
        case .blackjack: Color(red: 0.05, green: 0.47, blue: 0.25)
        case .slots: Color(red: 0.60, green: 0.20, blue: 0.75)
        case .tetris: Color(red: 0.00, green: 0.46, blue: 0.62)
        case .merge2048: Color(red: 0.75, green: 0.13, blue: 0.42)
        case .snake: Color(red: 0.22, green: 0.50, blue: 0.08)
        case .brickBreaker: Color(red: 0.75, green: 0.33, blue: 0.00)
        case .bubbleBlaster: Color(red: 0.00, green: 0.40, blue: 0.90)
        }
    }

    /// The game's color for text, lightened in dark mode so it stays readable on dark cards.
    func textColor(in scheme: ColorScheme) -> Color {
        scheme == .dark ? color.mix(with: .white, by: 0.45) : color
    }

    var pitch: String {
        switch self {
        case .blackjack: "Beat the dealer with tokens. Wins pay a coin bonus that grows with your bet."
        case .slots: "Spin three reels of crypto. Three Bitcoins pay 500 times your bet."
        case .tetris: "Clear lines for points. Every point pays coins."
        case .merge2048: "Slide numbered tiles and merge matching pairs. Make 2048 for a bonus."
        case .snake: "Eat coins and grow longer, but don't bite your own tail."
        case .brickBreaker: "Smash every brick with the coin ball. Each level is faster."
        case .bubbleBlaster: "Match three bubbles to pop them. Cut-off clusters fall for double points."
        }
    }
}

/// One mini-game: what it is, your record, and Play or Unlock.
struct MiniGameRow: View {
    let miniGame: MiniGame
    let isUnlocked: Bool
    let canAfford: Bool
    let record: String
    @Environment(GameStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var refusals = 0

    var body: some View {
        HStack(spacing: 14) {
            Text(miniGame.icon)
                .font(.system(size: 32))
                .frame(width: 58, height: 58)
                .background(miniGame.color.opacity(0.18), in: .rect(cornerRadius: 16))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(miniGame.name)
                    .font(.headline)
                Text(miniGame.pitch)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                if isUnlocked {
                    Text(record)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(miniGame.textColor(in: colorScheme))
                }
            }
            Spacer(minLength: 8)
            if isUnlocked {
                NavigationLink(value: miniGame) {
                    Text("Play")
                        .font(.subheadline.weight(.bold))
                        .frame(minWidth: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(miniGame.color)
                .accessibilityLabel("Play \(miniGame.name)")
            } else {
                Button {
                    if !store.unlock(miniGame) { refusals += 1 }
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: canAfford ? "lock.open.fill" : "lock.fill")
                            .font(.caption.weight(.bold))
                        Text(CoinFormat.cost(miniGame.unlockCost))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    .frame(minWidth: 72)
                }
                .priceButtonStyle(canAfford: canAfford, tint: Theme.arcadeButton)
                .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
                .accessibilityLabel("Unlock \(miniGame.name) for \(CoinFormat.cost(miniGame.unlockCost)) coins")
            }
        }
        .rowCard()
    }
}

/// Today's Tetris challenge, at the top of the arcade games.
struct DailyChallengeCard: View {
    let day: String
    let isBonusAvailable: Bool
    let best: Int

    var body: some View {
        NavigationLink(value: DailyChallenge(day: day)) {
            HStack(spacing: 14) {
                Text("🧩")
                    .font(.system(size: 32))
                    .frame(width: 58, height: 58)
                    .background(MiniGame.tetris.color.opacity(0.18), in: .rect(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Tetris Challenge")
                        .font(.headline)
                    Text(isBonusAvailable
                         ? "The same pieces for everyone today. Your first scoring game pays double."
                         : "Today's double reward is yours. Play again to beat your best.")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                    if best > 0 {
                        Text("Best today \(CoinFormat.grouped(best))")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 8)
                Text(isBonusAvailable ? "×2" : "Play")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 56)
                    .padding(.vertical, 7)
                    .background(MiniGame.tetris.color, in: .capsule)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .rowCard()
        .accessibilityLabel("Daily Tetris Challenge")
        .accessibilityHint(isBonusAvailable ? "Your first scoring game today pays double" : "Play today's pieces again")
    }
}
