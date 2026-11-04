import SwiftUI
import CryptoClickerKit

struct ArcadeView: View {
    /// Goes up by one each time the Daily page asks to open today's challenge.
    var challengeRequests = 0
    @Environment(GameStore.self) private var store
    @State private var path = NavigationPath()
    @State private var handledChallengeRequests = 0
    /// The game whose records are showing in a sheet.
    @State private var statsGame: MiniGame?
    /// A game to open once the records sheet has closed (its Play button).
    @State private var gameAfterStats: MiniGame?

    var body: some View {
        let game = store.game
        let today = store.today
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    if game.unlockedGames.isEmpty == false {
                        ArcadeRankCard(game: game, today: today)
                    }
                    if let challenge = game.dailyChallenge(today: today) {
                        ChallengeCard(challenge: challenge, weekCount: game.challengesCompleted(inWeekOf: today),
                                      reward: game.challengeReward, weeklyBonus: game.weeklyChallengeBonus,
                                      play: canOpen(challenge) ? { open(challenge) } : nil)
                    }
                    SectionHeader(title: "Casino", detail: "Bet tokens from the Shop")
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
            .modifier(ArcadeDestinations())
            .sheet(item: $statsGame, onDismiss: openGameAfterStats) { miniGame in
                GameStatsSheet(miniGame: miniGame) {
                    gameAfterStats = miniGame
                    statsGame = nil
                }
            }
        }
    }

    private func row(_ miniGame: MiniGame, in game: GameState) -> some View {
        MiniGameRow(miniGame: miniGame, isUnlocked: game.isUnlocked(miniGame),
                    canAfford: miniGame.unlockCost <= game.coins, record: game.record(for: miniGame),
                    showStats: { statsGame = miniGame })
    }

    /// Opens the game picked on the records sheet, once the sheet is out of the way.
    private func openGameAfterStats() {
        guard let miniGame = gameAfterStats else { return }
        gameAfterStats = nil
        path.append(miniGame)
    }

    /// The challenge's game is unlocked (the arcade mix has no single game to open).
    private func canOpen(_ challenge: DailyChallenge) -> Bool {
        guard let game = challenge.kind.game else { return false }
        return store.game.isUnlocked(game) && !challenge.isComplete
    }

    /// Opens the challenge's game, straight into a game where it has a start screen; on Block Day,
    /// Tetris deals today's pieces.
    private func open(_ challenge: DailyChallenge) {
        guard let game = challenge.kind.game, store.game.isUnlocked(game) else { return }
        if game == .tetris {
            path.append(TetrisRoute.todaysPieces(day: challenge.day))
        } else if game == .snake {
            path.append(SnakeRoute.play(.classic))
        } else if game == .merge2048 {
            path.append(Merge2048Route.classic) // Puzzle Day asks for a tile in Classic.
        } else if game == .tokenSwap {
            path.append(TokenSwapRoute.classic) // Match Day asks for a Classic score.
        } else if game == .brickBreaker {
            path.append(BrickBreakerRoute.play(.classic)) // Straight into a game, from level 1.
        } else if game == .invaders {
            path.append(InvadersRoute.play(.classic)) // Straight into a game, from wave 1.
        } else if game == .pumpDump {
            // Reflex Day counts a run on any board: the one last picked.
            let side = UserDefaults.standard.integer(forKey: Preferences.pumpDumpBoardKey)
            path.append(PumpDumpRoute.play(PumpDumpGame.Board(rawValue: side) ?? .three))
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

/// Every screen the Arcade opens: the games, and the screens inside them.
private struct ArcadeDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: MiniGame.self) { miniGame in
                switch miniGame {
                case .blackjack: BlackjackView()
                case .slots: SlotsView()
                case .moon: MoonView()
                case .videoPoker: VideoPokerView()
                case .tetris: TetrisView()
                case .merge2048: Merge2048View()
                case .snake: SnakeView()
                case .brickBreaker: BrickBreakerView()
                case .bubbleBlaster: BubbleBlasterView()
                case .pumpDump: PumpDumpView()
                case .tokenSwap: TokenSwapView()
                case .invaders: InvadersView()
                }
            }
            .navigationDestination(for: TetrisRoute.self) { route in
                TetrisPlayView(route: route)
            }
            .navigationDestination(for: SnakeRoute.self) { route in
                switch route {
                case .play(let mode): SnakePlayView(mode: mode)
                }
            }
            .navigationDestination(for: Merge2048Route.self) { route in
                Merge2048PlayView(route: route)
            }
            .navigationDestination(for: TokenSwapRoute.self) { route in
                switch route {
                case .levels: TokenSwapLevelsView()
                case .level, .daily, .classic, .random: TokenSwapPlayView(route: route)
                }
            }
            .navigationDestination(for: BrickBreakerRoute.self) { route in
                switch route {
                case .play(let levels): BrickBreakerPlayView(levels: levels)
                }
            }
            .navigationDestination(for: InvadersRoute.self) { route in
                switch route {
                case .play(let waves): InvadersPlayView(waves: waves)
                }
            }
            .navigationDestination(for: PumpDumpRoute.self) { route in
                switch route {
                case .play(let board): PumpDumpPlayView(board: board)
                }
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

/// One mini-game: what it is, your record, and Play (with its records under it) or Unlock.
struct MiniGameRow: View {
    let miniGame: MiniGame
    let isUnlocked: Bool
    let canAfford: Bool
    let record: [RecordFact]
    let showStats: () -> Void
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
            VStack(alignment: .leading, spacing: 4) {
                Text(miniGame.name)
                    .font(.headline)
                Text(miniGame.pitch)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                if isUnlocked {
                    RecordLine(facts: record, tint: miniGame.textColor(in: colorScheme))
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 18 points between the text and the buttons (the row's gap and this), half what it was.
            .padding(.trailing, 4)
            if isUnlocked {
                VStack(spacing: 8) {
                    NavigationLink(value: miniGame) {
                        Text("Play")
                            .font(.subheadline.weight(.bold))
                            .frame(minWidth: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(miniGame.color)
                    .accessibilityLabel("Play \(miniGame.name)")
                    Button(action: showStats) {
                        Label("Stats", systemImage: "chart.bar.fill")
                            .font(.footnote.weight(.semibold))
                            .frame(minWidth: 56)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(miniGame.textColor(in: colorScheme))
                    .accessibilityLabel("\(miniGame.name) stats")
                }
                .fixedSize()
            } else {
                Button {
                    if !store.unlock(miniGame) { refusals += 1 }
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: canAfford ? "lock.open.fill" : "lock.fill")
                            .font(.footnote.weight(.bold))
                        Text(CoinFormat.cost(miniGame.unlockCost))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    .frame(minWidth: 72)
                }
                .priceButtonStyle(canAfford: canAfford, tint: Theme.arcadeButton)
                .fixedSize()
                .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
                .accessibilityLabel("Unlock \(miniGame.name) for \(CoinFormat.cost(miniGame.unlockCost)) coins")
            }
        }
        .rowCard()
    }
}

/// A game's record as label and value pairs, the labels in small capitals in the game's color:
/// BEST 12,345  WAVE 5. On one line when it fits, one pair a line when it doesn't.
private struct RecordLine: View {
    let facts: [RecordFact]
    let tint: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { pairs }
            VStack(alignment: .leading, spacing: 2) { pairs }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(facts.map { "\($0.label) \($0.value)" }.joined(separator: ", "))
    }

    private var pairs: some View {
        ForEach(facts, id: \.label) { fact in
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(fact.label)
                    .font(.footnote.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(tint)
                Text(fact.value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .lineLimit(1)
            .fixedSize()
        }
    }
}

/// One game's records, the card Statistics shows for it, opened from the game's row in the Arcade
/// to look before playing. Its Play button opens the game.
private struct GameStatsSheet: View {
    let miniGame: MiniGame
    let play: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false

    var body: some View {
        let game = store.game
        NavigationStack {
            List {
                Section {
                    GameStatsCard(miniGame, in: game, exactNumbers: exactNumbers)
                } footer: {
                    if game.timesPlayed(miniGame) == 0 {
                        SettingsNote("Nothing played yet: your records fill in as you play.")
                    }
                }
            }
            .monospacedDigit()
            .navigationTitle("Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: play) {
                    Label("Play \(miniGame.name)", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(miniGame.color)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .presentationDetents([.medium, .large])
    }
}
