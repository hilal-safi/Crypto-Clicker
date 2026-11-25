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
    @AppStorage(Preferences.favoriteGamesKey) private var favoriteList = ""
    @AppStorage(Preferences.recentGamesKey) private var recentList = ""

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
                    gameSections(game)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 700)
                // Exactly the screen's width, so no card can make the page scroll sideways.
                .containerRelativeFrame(.horizontal)
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

    /// The games opened lately, the favorites, then the rest: the casino's and the arcade's.
    @ViewBuilder
    private func gameSections(_ game: GameState) -> some View {
        let favorites = ArcadeLists.games(in: favoriteList).filter(game.isUnlocked)
        let recent = ArcadeLists.games(in: recentList).filter(game.isUnlocked)
        let others = MiniGame.byPrice.filter { !favorites.contains($0) }
        let casino = others.filter(\.isCasino)
        let arcade = others.filter { !$0.isCasino }
        // Quick ways back once there are enough games to scroll past.
        if !recent.isEmpty && game.unlockedGames.count >= 4 {
            RecentGamesStrip(games: recent)
        }
        if !favorites.isEmpty {
            SectionHeader(title: "Favorites", detail: "Starred games")
            ForEach(favorites) { miniGame in
                row(miniGame, in: game)
            }
        }
        if !casino.isEmpty {
            SectionHeader(title: "Casino", detail: "Bet tokens from the Shop")
            ForEach(casino) { miniGame in
                row(miniGame, in: game)
            }
        }
        if !arcade.isEmpty {
            SectionHeader(title: "Arcade", detail: "Every point pays coins")
            ForEach(arcade) { miniGame in
                row(miniGame, in: game)
            }
        }
    }

    private func row(_ miniGame: MiniGame, in game: GameState) -> some View {
        let isUnlocked = game.isUnlocked(miniGame)
        let isFavorite = ArcadeLists.games(in: favoriteList).contains(miniGame)
        return MiniGameRow(miniGame: miniGame, isUnlocked: isUnlocked,
                           canAfford: miniGame.unlockCost <= game.coins, record: game.record(for: miniGame),
                           isNew: isUnlocked && !game.hasPlayed(miniGame), isFavorite: isFavorite,
                           toggleFavorite: { toggleFavorite(miniGame) }, showStats: { statsGame = miniGame })
    }

    private func toggleFavorite(_ miniGame: MiniGame) {
        withAnimation(.snappy) {
            favoriteList = ArcadeLists.toggling(miniGame, in: favoriteList)
        }
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
        } else if game == .bubbleBlaster {
            path.append(BubbleRoute.waves) // Pop Day counts bubbles in any game: straight into Waves.
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

/// Every screen the Arcade opens: the games, and the screens inside them. Opening one notes the
/// game for the Arcade's recent list.
private struct ArcadeDestinations: ViewModifier {
    @AppStorage(Preferences.recentGamesKey) private var recentList = ""

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: MiniGame.self) { miniGame in
                screen(for: miniGame)
                    .onAppear { opened(miniGame) }
            }
            .navigationDestination(for: TetrisRoute.self) { route in
                TetrisPlayView(route: route)
                    .onAppear { opened(.tetris) }
            }
            .navigationDestination(for: SnakeRoute.self) { route in
                switch route {
                case .play(let mode): SnakePlayView(mode: mode).onAppear { opened(.snake) }
                }
            }
            .navigationDestination(for: Merge2048Route.self) { route in
                Merge2048PlayView(route: route)
                    .onAppear { opened(.merge2048) }
            }
            .navigationDestination(for: TokenSwapRoute.self) { route in
                Group {
                    switch route {
                    case .levels: TokenSwapLevelsView()
                    case .level, .daily, .classic, .random: TokenSwapPlayView(route: route)
                    }
                }
                .onAppear { opened(.tokenSwap) }
            }
            .navigationDestination(for: BrickBreakerRoute.self) { route in
                switch route {
                case .play(let levels, let start):
                    BrickBreakerPlayView(levels: levels, startLevel: start).onAppear { opened(.brickBreaker) }
                }
            }
            .navigationDestination(for: InvadersRoute.self) { route in
                switch route {
                case .play(let waves, let start):
                    InvadersPlayView(waves: waves, startWave: start).onAppear { opened(.invaders) }
                }
            }
            .navigationDestination(for: BubbleRoute.self) { route in
                BubblePlayView(route: route)
                    .onAppear { opened(.bubbleBlaster) }
            }
            .navigationDestination(for: PumpDumpRoute.self) { route in
                switch route {
                case .play(let board): PumpDumpPlayView(board: board).onAppear { opened(.pumpDump) }
                }
            }
    }

    @ViewBuilder
    private func screen(for miniGame: MiniGame) -> some View {
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

    private func opened(_ miniGame: MiniGame) {
        let noted = ArcadeLists.noting(miniGame, in: recentList)
        if noted != recentList { recentList = noted }
    }
}

/// The Arcade's lists kept on the device, as comma-separated raw values: the favorite games and
/// the ones opened most recently.
enum ArcadeLists {
    /// How many recent games the Arcade offers.
    static let recentCount = 3

    static func games(in list: String) -> [MiniGame] {
        list.split(separator: ",").compactMap { MiniGame(rawValue: String($0)) }
    }

    static func list(of games: [MiniGame]) -> String {
        games.map(\.rawValue).joined(separator: ",")
    }

    /// `list` with `game` added, or taken out if it's there.
    static func toggling(_ game: MiniGame, in list: String) -> String {
        let games = games(in: list)
        return self.list(of: games.contains(game) ? games.filter { $0 != game } : games + [game])
    }

    /// The recent `list` with `game` first.
    static func noting(_ game: MiniGame, in list: String) -> String {
        self.list(of: Array(([game] + games(in: list).filter { $0 != game }).prefix(recentCount)))
    }
}

/// The games opened most recently, a tap away from the top of the Arcade.
private struct RecentGamesStrip: View {
    let games: [MiniGame]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Jump back in")
                .font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) { chips }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var chips: some View {
        ForEach(games) { miniGame in
            NavigationLink(value: miniGame) {
                HStack(spacing: 6) {
                    Text(miniGame.icon)
                        .accessibilityHidden(true)
                    Text(miniGame.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(miniGame.color.opacity(0.18), in: .capsule)
                .fixedSize()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(miniGame.name)")
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
    /// Unlocked and never played.
    var isNew = false
    var isFavorite = false
    var toggleFavorite: (() -> Void)? = nil
    let showStats: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var refusals = 0

    /// The icon's width and the gap after it, which the records line up under the name with.
    private static let iconWidth: CGFloat = 58
    private static let gap: CGFloat = 14

    var body: some View {
        // The records run under the buttons too, to the card's edge, so a long one ("BEST HAND
        // Jacks or Better") keeps to one line.
        VStack(alignment: .leading, spacing: 6) {
            mainRow
            if isUnlocked && !record.isEmpty {
                RecordLine(facts: record, tint: miniGame.textColor(in: colorScheme))
                    .padding(.leading, Self.iconWidth + Self.gap)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .rowCard()
        .contextMenu {
            if isUnlocked, let toggleFavorite {
                Button(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                       systemImage: isFavorite ? "star.slash" : "star", action: toggleFavorite)
            }
        }
    }

    /// The name, with a New badge until the game is first played and the favorite star.
    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(miniGame.name)
                .font(.headline)
            if isNew {
                Text("New")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(miniGame.color, in: .capsule)
            }
            if isUnlocked, let toggleFavorite {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isFavorite ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(.subtext))
                        .padding(.horizontal, 4)
                        .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .sensoryFeedback(.selection, trigger: isFavorite) { _, _ in haptics }
                .accessibilityLabel(isFavorite ? "Remove \(miniGame.name) from Favorites" : "Add \(miniGame.name) to Favorites")
            }
        }
    }

    private var mainRow: some View {
        HStack(spacing: Self.gap) {
            Text(miniGame.icon)
                .font(.system(size: 32))
                .frame(width: Self.iconWidth, height: Self.iconWidth)
                .background(miniGame.color.opacity(0.18), in: .rect(cornerRadius: 16))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                title
                Text(miniGame.pitch)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 10 points between the text and the buttons (the row's gap of 14 less 4).
            .padding(.trailing, -4)
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
    }
}

/// A game's record as label and value pairs, the labels in small capitals in the game's color:
/// BEST 12,345  WAVE 5. On one line when it fits, one pair a line when it doesn't, and a long value
/// ("TOP MINER Space Mining Colony") wraps under its label rather than pushing the card wider than
/// the screen.
struct RecordLine: View {
    let facts: [RecordFact]
    let tint: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { pairs(fixed: true) }
            VStack(alignment: .leading, spacing: 2) { pairs(fixed: false) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(facts.map { "\($0.label) \($0.value)" }.joined(separator: ", "))
    }

    private func pairs(fixed: Bool) -> some View {
        ForEach(facts, id: \.label) { fact in
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(fact.label)
                    .font(.footnote.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize()
                Text(fact.value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(fixed ? 1 : 2)
                    .fixedSize(horizontal: fixed, vertical: !fixed)
            }
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
