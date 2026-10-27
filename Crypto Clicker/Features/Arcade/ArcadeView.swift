import SwiftUI
import CryptoClickerKit

/// Opens Tetris with today's pieces: the same for everyone, all day.
struct TodaysPieces: Hashable {
    let day: String
}

struct ArcadeView: View {
    /// Goes up by one each time the Daily page asks to open today's challenge.
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
                    if let challenge = game.dailyChallenge(today: today) {
                        ChallengeCard(challenge: challenge, weekCount: game.challengesCompleted(inWeekOf: today),
                                      reward: game.challengeReward, weeklyBonus: game.weeklyChallengeBonus,
                                      play: canOpen(challenge) ? { open(challenge) } : nil)
                    }
                    SectionHeader(title: "Casino", detail: "Bet tokens from the Exchange")
                    ForEach(MiniGame.byPrice.filter(\.isCasino)) { miniGame in
                        row(miniGame, in: game)
                    }
                    SectionHeader(title: "Arcade", detail: "Every point pays coins")
                    ForEach(MiniGame.byPrice.filter { !$0.isCasino }) { miniGame in
                        row(miniGame, in: game)
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
                case .moon: MoonView()
                case .tetris: TetrisView()
                case .merge2048: Merge2048View()
                case .snake: SnakeView()
                case .brickBreaker: BrickBreakerView()
                case .bubbleBlaster: BubbleBlasterView()
                case .pumpDump: PumpDumpView()
                }
            }
            .navigationDestination(for: TodaysPieces.self) { pieces in
                TetrisView(challengeDay: pieces.day)
            }
        }
    }

    private func row(_ miniGame: MiniGame, in game: GameState) -> some View {
        MiniGameRow(miniGame: miniGame, isUnlocked: game.isUnlocked(miniGame),
                    canAfford: miniGame.unlockCost <= game.coins, record: game.record(for: miniGame))
    }

    /// The challenge's game is unlocked (the arcade mix has no single game to open).
    private func canOpen(_ challenge: DailyChallenge) -> Bool {
        guard let game = challenge.kind.game else { return false }
        return store.game.isUnlocked(game) && !challenge.isComplete
    }

    /// Opens the challenge's game; on Block Day, Tetris deals today's pieces.
    private func open(_ challenge: DailyChallenge) {
        guard let game = challenge.kind.game, store.game.isUnlocked(game) else { return }
        if game == .tetris {
            path.append(TodaysPieces(day: challenge.day))
        } else {
            path.append(game)
        }
    }

    /// Opens today's challenge once for each request, closing an open game screen first.
    private func showChallengeIfAsked() {
        guard handledChallengeRequests != challengeRequests else { return }
        handledChallengeRequests = challengeRequests
        let wasInGame = !path.isEmpty
        path = NavigationPath()
        guard let challenge = store.game.dailyChallenge(today: store.today), canOpen(challenge) else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(wasInGame ? 450 : 50))
            open(challenge)
        }
    }
}

extension MiniGame {
    var icon: String { info.icon }

    /// Deep enough for white "Play" text to read clearly (at least 4.5:1 contrast).
    var color: Color { Color(red: info.color.red, green: info.color.green, blue: info.color.blue) }

    /// The game's color for text, lightened in dark mode so it stays readable on dark cards.
    func textColor(in scheme: ColorScheme) -> Color {
        scheme == .dark ? color.mix(with: .white, by: 0.45) : color
    }

    var pitch: String { info.pitch }
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
