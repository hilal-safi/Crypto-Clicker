import SwiftUI
import CryptoClickerKit

/// The screens inside 2048 (Merge Mining in the crypto edition), opened from its start screen.
enum Merge2048Route: Hashable {
    /// Goes on until the board locks up, with tile goals to climb and three undos.
    case classic
    /// The day's puzzle: the same start and tiles for everyone, in a fixed number of moves.
    case daily(day: String)
}

/// Where 2048 opens, like Brick Breaker and Scam Invaders: Classic, the Daily Puzzle and the
/// settings, each on a card.
struct Merge2048View: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.mergeSlideSpeedKey) private var slideSpeed = GameSpeed.normal
    @AppStorage(Preferences.mergeValuesKey) private var showsValues = true
    @State private var showingHelp = false

    var body: some View {
        let game = store.game
        let stats = game.stats
        let tint = MiniGame.merge2048.color
        let crypto = store.arcadeEdition == .crypto
        let today = store.today
        let stars = game.merge2048Daily.stars(on: today)
        let winner = Merge2048Game.winningValue
        ScrollView {
            VStack(spacing: 14) {
                ModeCard(tint: tint, icon: crypto ? "cpu" : "square.grid.3x3.fill", title: "Classic",
                         status: stats.merge2048Games == 0
                            ? (crypto ? "Start with a Chromebook or two" : "Start with two tiles")
                            : "Best \(CoinFormat.grouped(stats.merge2048BestScore)) · " + (crypto
                                ? "top miner: \(Merge2048Game.miner(for: stats.merge2048BestTile).name)"
                                : "top tile \(stats.merge2048BestTile)"),
                         detail: crypto
                            ? "Merge miners as far as you can, with goals to climb and \(Merge2048Game.undosPerGame) undos. Building the Lunar Base (\(CoinFormat.grouped(winner))) reaches the Moon: a bonus of \(CoinFormat.short(game.merge2048TileBonus)) coins."
                            : "Merge as far as you can, with tile goals to climb and \(Merge2048Game.undosPerGame) undos. A \(winner) tile pays a bonus of \(CoinFormat.short(game.merge2048TileBonus)) coins.",
                         note: nil) {
                    NavigationLink(value: Merge2048Route.classic) {
                        Label("Play Classic", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                ModeCard(tint: tint, icon: "calendar", title: "Daily Puzzle",
                         status: stars == 0 ? "No stars yet today" : "\(stars) of 3 stars today · best \(CoinFormat.grouped(game.merge2048Daily.bestScore(on: today)))",
                         detail: crypto
                            ? "The same start and miners for everyone today: \(Merge2048Game.dailyMoves) moves, stars at \(starScores). Each star pays \(CoinFormat.short(game.merge2048DailyStarReward)) coins the first time today."
                            : "The same start and tiles for everyone today: \(Merge2048Game.dailyMoves) moves, stars at \(starScores). Each star pays \(CoinFormat.short(game.merge2048DailyStarReward)) coins the first time today.",
                         note: nil) {
                    VStack(spacing: 12) {
                        StarRow(stars: stars, size: 22)
                        NavigationLink(value: Merge2048Route.daily(day: today)) {
                            Label("Play Today's Puzzle", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                ModeCard(tint: tint, icon: "slider.horizontal.3", title: "Settings", status: "\(slideSpeed.name) slides",
                         detail: crypto
                            ? "How quickly the miners slide, and whether each shows its number under its picture. Neither changes the score."
                            : "How quickly the tiles slide. It doesn't change the score.",
                         note: nil) {
                    VStack(spacing: 12) {
                        Picker("Slide speed", selection: $slideSpeed) {
                            ForEach(GameSpeed.allCases) { speed in
                                Text(speed.name).tag(speed)
                            }
                        }
                        .pickerStyle(.segmented)
                        if crypto {
                            Toggle("Show numbers on miners", isOn: $showsValues)
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background { AppBackground(tint: Theme.gold) }
        .navigationTitle(MiniGame.merge2048.name)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.merge2048, isPresented: $showingHelp)
    }

    private var starScores: String {
        Merge2048Game.dailyStarScores.map { CoinFormat.grouped($0) }.formatted(.list(type: .and))
    }
}

/// 2048's game: swipe anywhere in the play area to slide every tile one way. Two tiles with the
/// same number merge into their sum, which is added to the score (in Merge Mining the tiles are
/// miners, merging up the Shop's ladder). Points pay coins when the game ends, and making a 2048
/// tile pays a bonus on top. The player can end the game whenever they like to collect; leaving
/// the screen ends it too.
///
/// Two modes, from the start screen: Classic goes on until the board locks up, with tile goals to
/// climb and three undos; the Daily Puzzle gives everyone the same start and tiles for the day, in
/// a fixed number of moves, with stars for the score.
struct Merge2048PlayView: View {
    let route: Merge2048Route
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.mergeSlideSpeedKey) private var slideSpeed = GameSpeed.normal
    @State private var game: Merge2048Game
    @State private var isPlaying = false
    @State private var result: Merge2048Result?
    @State private var effects = Effects()
    /// Set once per game, when the first 2048 tile appears.
    @State private var hasWon = false
    @State private var showsWinBanner = false
    /// A tile goal just made, shown for a moment.
    @State private var goalBanner: GoalBanner?
    @State private var isConfirmingEnd = false
    @State private var showingHelp = false
    /// The drag that already slid the board; each swipe slides once.
    @State private var swipeStart: CGPoint?
    /// Points just scored, floating up from the score.
    @State private var gains: [ScoreGain] = []

    init(route: Merge2048Route) {
        self.route = route
        _game = State(initialValue: Self.newGame(for: route))
    }

    static func newGame(for route: Merge2048Route) -> Merge2048Game {
        switch route {
        case .classic:
            var rng = SystemRandomNumberGenerator()
            return Merge2048Game(using: &rng)
        case .daily(let day):
            return .daily(day: day)
        }
    }

    struct GoalBanner: Equatable {
        let id: Int
        let tile: Int
    }

    struct ScoreGain: Identifiable, Equatable {
        let id: Int
        let points: Int
    }

    private var crypto: Bool { store.arcadeEdition == .crypto }

    /// The slide's animation, at the speed picked on the start screen.
    private var slideAnimation: Animation {
        .easeOut(duration: Merge2048Board.slideDuration(slideSpeed))
    }

    var body: some View {
        withLifecycle(withFeedback(layout))
    }

    private var layout: some View {
        VStack(spacing: 12) {
            scoreBar
            Merge2048Board(game: game, slideSpeed: slideSpeed)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(MiniGame.merge2048.name) board")
                .accessibilityValue(boardDescription)
                .accessibilityAction(named: "Slide up") { slide(.up) }
                .accessibilityAction(named: "Slide down") { slide(.down) }
                .accessibilityAction(named: "Slide left") { slide(.left) }
                .accessibilityAction(named: "Slide right") { slide(.right) }
                .accessibilityAction(named: "Undo") { undo() }
                .overlay(alignment: .top) {
                    if showsWinBanner {
                        winBanner
                    } else if let goalBanner {
                        goalBannerView(goalBanner)
                    }
                }
                // The square board sits in all the space left, and swipes work anywhere in it.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .gesture(swipe)
            goalLine
            worth
        }
        .padding(12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background { AppBackground(tint: Theme.gold) }
        .overlay { EffectsLayer(effects: effects).ignoresSafeArea() }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle(game.isDaily ? "Daily Puzzle" : MiniGame.merge2048.name)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.merge2048, isPresented: $showingHelp)
        .confirmationDialog(game.isDaily ? "End this puzzle?" : "End this game?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            Button("End and Collect") { endGame(byPlayer: true) }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text(endMessage)
        }
    }

    private func withFeedback(_ view: some View) -> some View {
        view
        .sensoryFeedback(.impact(weight: .light), trigger: game.merges) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.success, trigger: hasWon) { _, new in haptics && new }
        .sensoryFeedback(.impact(weight: .medium), trigger: game.undosUsed) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(trigger: result) { _, new in
            guard haptics, let new else { return nil }
            return new.endedByPlayer || new.stars > 0 ? .success : .error
        }
    }

    /// Holding the game as the app goes to the background (it's paid if iOS closes the app), and
    /// ending it when the screen goes away.
    private func withLifecycle(_ view: some View) -> some View {
        view
        // Nothing runs between moves, so there's nothing to pause.
        .arcadeLifecycle(isPlaying: isPlaying, pause: {}, heldRun: { heldRun }) { endGame(byPlayer: true) }
    }

    /// The game so far, held while the app is in the background.
    private var heldRun: ArcadeRun {
        ArcadeRun(game: .merge2048, score: game.score, detail: game.bestTile, stage: game.isDaily ? ArcadeRun.dailyStage : 0)
    }

    // MARK: Pieces

    private var scoreBar: some View {
        HStack(spacing: 18) {
            GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        ForEach(gains) { gain in
                            FloatingGain(points: gain.points, reduceMotion: reduceMotion)
                        }
                    }
                    .offset(x: 20, y: -4)
                    .allowsHitTesting(false)
                }
            if let left = game.movesLeft {
                GameStat(title: "Moves left", value: "\(left)")
            } else {
                GameStat(title: crypto ? "Top miner" : "Top tile",
                         value: crypto ? Merge2048Game.miner(for: game.bestTile).emoji + " " + CoinFormat.grouped(game.bestTile)
                                       : String(game.bestTile))
            }
            Spacer(minLength: 0)
            ArcadeButton(title: "Undo, \(game.undosLeft) left", systemImage: "arrow.uturn.backward", size: 40) {
                undo()
            }
            .overlay(alignment: .topTrailing) {
                Text("\(game.undosLeft)")
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Theme.gold.mix(with: .black, by: 0.35), in: .circle)
                    .offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
            .disabled(!isPlaying || !game.canUndo)
            ArcadeButton(title: game.isDaily ? "End puzzle" : "End game", systemImage: "flag.checkered", size: 40) {
                isConfirmingEnd = true
            }
            .disabled(!isPlaying)
        }
        .scoreBar()
    }

    /// The next tile goal (Classic), or the stars the score has earned (Daily).
    @ViewBuilder
    private var goalLine: some View {
        HStack(spacing: 8) {
            if game.isDaily {
                let stars = Merge2048Game.dailyStars(score: game.score)
                StarRow(stars: stars, size: 15)
                Text(stars < 3 ? "Next star at \(CoinFormat.grouped(Merge2048Game.dailyStarScores[stars]))" : "All three stars!")
                    .font(.subheadline.weight(.semibold))
            } else if let goal = game.nextGoal {
                Image(systemName: "target")
                    .foregroundStyle(Theme.gold)
                Text(crypto ? "Goal: build the" : "Goal: make a")
                    .font(.subheadline.weight(.semibold))
                Merge2048TileView(value: goal, side: crypto ? 30 : 26, pops: false)
                Text(crypto ? Merge2048Game.miner(for: goal).name : "tile")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(.subtext)
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
        .opacity(isPlaying ? 1 : 0)
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: result.title, buttonTitle: "Play Again", action: start) {
                    VStack(spacing: 12) {
                        if result.isDaily {
                            StarRow(stars: result.stars, size: 30, animated: !reduceMotion)
                        }
                        GameOverSummary(score: result.score, isNewBest: result.payout.isNewBest,
                                        best: result.isDaily ? store.game.merge2048Daily.bestScore(on: store.today)
                                                             : store.game.stats.merge2048BestScore,
                                        reward: result.payout.coins, details: result.details, challenge: result.payout.challenge)
                    }
                }
            } else if case .daily(let day) = route {
                GamePanel(title: "Daily Puzzle", buttonTitle: "Start", action: start) {
                    VStack(spacing: 12) {
                        StarRow(stars: store.game.merge2048Daily.stars(on: day), size: 22)
                        GameIntro(best: store.game.merge2048Daily.bestScore(on: day),
                                  detail: "\(Merge2048Game.dailyMoves) moves, stars at \(starScores).")
                    }
                }
            } else {
                GamePanel(title: crypto ? MiniGame.merge2048.name : "Classic", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.merge2048BestScore,
                              detail: crypto
                                ? "Build the Lunar Base to reach the Moon: +\(CoinFormat.short(store.game.merge2048TileBonus)) coins."
                                : "A \(Merge2048Game.winningValue) tile pays a bonus of \(CoinFormat.short(store.game.merge2048TileBonus)) coins.")
                }
            }
        }
    }

    private var starScores: String {
        Merge2048Game.dailyStarScores.map { CoinFormat.grouped($0) }.formatted(.list(type: .and))
    }

    private var endMessage: String {
        if game.isDaily {
            let stars = Merge2048Game.dailyStars(score: game.score)
            return "Your \(CoinFormat.grouped(game.score)) points earn \(stars) \(stars == 1 ? "star" : "stars") and \(CoinFormat.short(currentWorth)) coins."
        }
        return "You'll collect \(CoinFormat.short(currentWorth)) coins for \(CoinFormat.grouped(game.score)) points."
    }

    /// What ending the game now would pay.
    private var currentWorth: Double {
        if let day = game.day {
            let stars = Merge2048Game.dailyStars(score: game.score)
            let newStars = max(0, stars - store.game.merge2048Daily.stars(on: day))
            return store.game.arcadeReward(.merge2048, score: game.score) + Double(newStars) * store.game.merge2048DailyStarReward
        }
        return store.game.merge2048Reward(score: game.score, bestTile: game.bestTile)
    }

    private var worth: some View {
        HStack(spacing: 6) {
            Text("Worth so far")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.subtext)
            CoinAmount(amount: currentWorth, font: .headline.monospacedDigit(), iconSize: 18)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .opacity(isPlaying ? 1 : 0)
    }

    private var winBanner: some View {
        VStack(spacing: 2) {
            Text(crypto ? "🌕 Lunar Base built!" : "2048!")
                .font(.title2.weight(.heavy))
            Text(crypto ? "You reached the Moon: +\(CoinFormat.short(store.game.merge2048TileBonus)) coins when the game ends. Keep going!"
                        : "+\(CoinFormat.short(store.game.merge2048TileBonus)) coins when the game ends. Keep going!")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(Theme.gold.opacity(0.5)), in: .rect(cornerRadius: 20))
        .padding(.top, 10)
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityAddTraits(.isStaticText)
    }

    private func goalBannerView(_ banner: GoalBanner) -> some View {
        VStack(spacing: 2) {
            Text(crypto ? "\(Merge2048Game.miner(for: banner.tile).name) built!" : "\(banner.tile) made!")
                .font(.title3.weight(.heavy))
            if let next = Merge2048Game.goalTiles.first(where: { $0 > banner.tile }) {
                Text(crypto ? "Next goal: the \(Merge2048Game.miner(for: next).name)" : "Next goal: \(next)")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(Merge2048TileView.style(for: banner.tile).background.opacity(0.5)), in: .rect(cornerRadius: 18))
        .padding(.top, 10)
        .id(banner.id)
        .transition(.move(edge: .top).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    /// The board read out row by row, for VoiceOver.
    private var boardDescription: String {
        let rows = game.rows.enumerated().map { index, row in
            "Row \(index + 1): " + row.map { value in
                value == 0 ? "empty" : crypto ? "\(Merge2048Game.miner(for: value).name) \(value)" : String(value)
            }.joined(separator: ", ")
        }
        var lines = ["Score \(game.score)"]
        if let left = game.movesLeft { lines.append("\(left) moves left") }
        return (lines + rows).joined(separator: ". ")
    }

    /// Each swipe slides the board once, as soon as it is long enough.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard swipeStart != value.startLocation else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard max(abs(dx), abs(dy)) >= 24 else { return }
                swipeStart = value.startLocation
                slide(abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up))
            }
            .onEnded { _ in swipeStart = nil }
    }

    // MARK: Game flow

    private func start() {
        withAnimation(.snappy(duration: 0.25)) {
            game = Self.newGame(for: route)
        }
        result = nil
        hasWon = false
        showsWinBanner = false
        goalBanner = nil
        gains = []
        isPlaying = true
    }

    /// Slides the board; nothing moves once the game is over or ending.
    private func slide(_ direction: SlideDirection) {
        guard isPlaying, !game.isOver else { return }
        var next = game
        let goal = next.nextGoal
        let scoreBefore = next.score
        guard next.slide(direction) else { return }
        withAnimation(slideAnimation) {
            game = next
        }
        showGain(game.score - scoreBefore)
        if game.hasWon && !hasWon {
            celebrate()
        } else if let goal, game.bestTile >= goal, goal != Merge2048Game.winningValue {
            showGoal(goal)
        }
        if game.isOver {
            // Let the final board show for a moment before the summary.
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                if game.isOver { endGame(byPlayer: false) }
            }
        }
    }

    private func undo() {
        guard isPlaying, game.canUndo else { return }
        withAnimation(slideAnimation) {
            _ = game.undo()
        }
    }

    private func showGain(_ points: Int) {
        guard points > 0 else { return }
        let gain = ScoreGain(id: (gains.last?.id ?? 0) + 1, points: points)
        gains.append(gain)
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            gains.removeAll { $0.id == gain.id }
        }
    }

    private func showGoal(_ tile: Int) {
        let banner = GoalBanner(id: (goalBanner?.id ?? 0) + 1, tile: tile)
        withAnimation(.snappy) { goalBanner = banner }
        effects.confetti(40, from: UnitPoint(x: 0.5, y: 0.4))
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if goalBanner?.id == banner.id { withAnimation(.snappy) { goalBanner = nil } }
        }
    }

    private func celebrate() {
        hasWon = true
        goalBanner = nil
        effects.confetti(120, from: UnitPoint(x: 0.5, y: 0.45))
        effects.coinFountain(20, from: UnitPoint(x: 0.5, y: 0.6))
        withAnimation(.snappy) { showsWinBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.snappy) { showsWinBanner = false }
        }
    }

    private func endGame(byPlayer: Bool) {
        guard isPlaying else { return }
        isPlaying = false
        showsWinBanner = false
        goalBanner = nil
        if let day = game.day {
            let daily = store.finishMerge2048Daily(day: day, score: game.score, bestTile: game.bestTile)
            result = Merge2048Result(game: game, payout: daily.payout, endedByPlayer: byPlayer, stars: daily.stars,
                                     newStars: daily.newStars, starCoins: daily.starCoins)
        } else {
            let payout = store.finishMerge2048(score: game.score, bestTile: game.bestTile)
            result = Merge2048Result(game: game, payout: payout, endedByPlayer: byPlayer)
        }
    }
}

/// Points rising from the score and fading.
private struct FloatingGain: View {
    let points: Int
    let reduceMotion: Bool
    @State private var risen = false

    var body: some View {
        Text("+\(CoinFormat.grouped(points))")
            .font(.subheadline.weight(.heavy).monospacedDigit())
            .foregroundStyle(Theme.gold)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .fixedSize()
            .offset(y: risen && !reduceMotion ? -26 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.75)) { risen = true }
            }
            .accessibilityHidden(true)
    }
}

/// How a 2048 game ended and what it paid.
struct Merge2048Result: Equatable {
    let score: Int
    let bestTile: Int
    let moves: Int
    let undosUsed: Int
    let isDaily: Bool
    /// The game ran out of moves (Daily), rather than locking up.
    let ranOutOfMoves: Bool
    let payout: ArcadePayout
    /// The player ended it (or left), rather than running out of moves.
    let endedByPlayer: Bool
    /// Daily stars earned, the ones new today, and what those paid.
    var stars = 0
    var newStars = 0
    var starCoins = 0.0

    init(game: Merge2048Game, payout: ArcadePayout, endedByPlayer: Bool, stars: Int = 0, newStars: Int = 0, starCoins: Double = 0) {
        score = game.score
        bestTile = game.bestTile
        moves = game.moves
        undosUsed = game.undosUsed
        isDaily = game.isDaily
        ranOutOfMoves = game.movesLeft == 0
        self.payout = payout
        self.endedByPlayer = endedByPlayer
        self.stars = stars
        self.newStars = newStars
        self.starCoins = starCoins
    }

    var title: String {
        if endedByPlayer { return isDaily ? "Puzzle Ended" : "Well Played" }
        if isDaily { return ranOutOfMoves ? "Out of Moves" : "Boxed In" }
        return "Game Over"
    }

    /// "top tile 512", or in Merge Mining "top miner: Quantum Computer".
    private var topTile: String {
        ArcadeEdition.current == .crypto ? "top miner: \(Merge2048Game.miner(for: bestTile).name)" : "top tile \(bestTile)"
    }

    var details: [String] {
        var lines: [String] = []
        if isDaily {
            lines.append("\(moves) of \(Merge2048Game.dailyMoves) moves · " + topTile)
            if newStars > 0 {
                lines.append("Includes \(CoinFormat.short(starCoins)) coins for \(newStars) new \(newStars == 1 ? "star" : "stars")")
            } else if stars > 0 {
                lines.append("Stars already earned today")
            }
        } else {
            lines.append(topTile.prefix(1).uppercased() + topTile.dropFirst()
                         + (undosUsed > 0 ? " · \(undosUsed) \(undosUsed == 1 ? "undo" : "undos")" : ""))
            if payout.tileBonus > 0 {
                lines.append(ArcadeEdition.current == .crypto
                             ? "Includes \(CoinFormat.short(payout.tileBonus)) coins for reaching the Moon"
                             : "Includes \(CoinFormat.short(payout.tileBonus)) coins for the 2048 tile")
            }
        }
        return lines
    }
}

/// The 4×4 board: empty cells, then every tile at its cell. Tiles keep their identity as they
/// slide, a merged tile pops, and a tile that merged away slides into its partner before it goes.
struct Merge2048Board: View {
    let game: Merge2048Game
    var slideSpeed = GameSpeed.normal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long a slide takes at each speed.
    static func slideDuration(_ speed: GameSpeed) -> Double {
        switch speed {
        case .slow: 0.18
        case .normal: 0.12
        case .fast: 0.07
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = Merge2048Game.size
            let gap = proxy.size.width * 0.028
            let cell = (proxy.size.width - gap * CGFloat(size + 1)) / CGFloat(size)
            let mergedAway = Set(game.mergedAway.map(\.id))
            ZStack(alignment: .topLeading) {
                ForEach(0..<size * size, id: \.self) { index in
                    RoundedRectangle(cornerRadius: cell * 0.14, style: .continuous)
                        .fill(.white.opacity(0.07))
                        .frame(width: cell, height: cell)
                        .offset(x: gap + CGFloat(index % size) * (cell + gap), y: gap + CGFloat(index / size) * (cell + gap))
                }
                // One list, so a tile that merges away keeps its identity and slides into place.
                ForEach(game.mergedAway + game.tiles) { tile in
                    Merge2048TileView(value: tile.value, side: cell, pops: !reduceMotion)
                        .offset(x: gap + CGFloat(tile.column) * (cell + gap), y: gap + CGFloat(tile.row) * (cell + gap))
                        .zIndex(mergedAway.contains(tile.id) ? 0 : 1)
                        .transition(.asymmetric(
                            insertion: AnyTransition.scale(scale: 0.3).combined(with: .opacity)
                                .animation(.easeOut(duration: 0.14).delay(0.1)),
                            removal: .identity))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Color(red: 0.07, green: 0.08, blue: 0.16).opacity(0.88), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
        }
        .contentShape(.rect)
    }
}

/// One numbered tile. The number always shows; colors climb from cool to warm and end in
/// Bitcoin gold at 2048.
struct Merge2048TileView: View {
    let value: Int
    let side: CGFloat
    var pops = true
    /// Merge Mining shows each miner's number under its picture, unless turned off.
    @AppStorage(Preferences.mergeValuesKey) private var showsValues = true

    var body: some View {
        let style = Self.style(for: value)
        RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
            .fill(style.background.gradient)
            .overlay {
                RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
            .overlay {
                if ArcadeEdition.current == .crypto {
                    miner(style: style)
                } else {
                    Text(verbatim: String(value))
                        .font(.system(size: side * Self.fontScale(digits: String(value).count), weight: .heavy, design: .rounded))
                        .foregroundStyle(style.foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, side * 0.06)
                }
            }
            .shadow(color: value >= Merge2048Game.winningValue ? Theme.gold.opacity(0.75) : .clear, radius: side * 0.12)
            .frame(width: side, height: side)
            .keyframeAnimator(initialValue: 1.0, trigger: value) { content, scale in
                content.scaleEffect(pops ? scale : 1)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1.0, duration: 0.08)
                    SpringKeyframe(1.14, duration: 0.08)
                    SpringKeyframe(1.0, duration: 0.14)
                }
            }
    }

    /// Merge Mining's tile: the miner's picture, with its number underneath on tiles big enough.
    private func miner(style: (background: Color, foreground: Color)) -> some View {
        let showsNumber = showsValues && side >= 44
        return VStack(spacing: side * 0.01) {
            Text(verbatim: Merge2048Game.miner(for: value).emoji)
                .font(.system(size: side * (showsNumber ? 0.42 : 0.56)))
                .shadow(color: .black.opacity(0.25), radius: side * 0.02, y: side * 0.01)
            if showsNumber {
                Text(verbatim: CoinFormat.grouped(value))
                    .font(.system(size: side * 0.17, weight: .heavy, design: .rounded))
                    .foregroundStyle(style.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, side * 0.06)
            }
        }
    }

    static func fontScale(digits: Int) -> CGFloat {
        switch digits {
        case ...2: 0.46
        case 3: 0.38
        case 4: 0.30
        default: 0.24
        }
    }

    /// Background and number colors, with the number at least 4:1 against its tile.
    static func style(for value: Int) -> (background: Color, foreground: Color) {
        let white = Color.white
        return switch value {
        case ...2: (Color(red: 0.91, green: 0.93, blue: 0.97), Color(red: 0.15, green: 0.19, blue: 0.32))
        case 4: (Color(red: 0.80, green: 0.87, blue: 0.98), Color(red: 0.10, green: 0.17, blue: 0.38))
        case 8: (Color(red: 0.00, green: 0.47, blue: 0.52), white)
        case 16: (Color(red: 0.05, green: 0.47, blue: 0.27), white)
        case 32: (Color(red: 0.12, green: 0.38, blue: 0.84), white)
        case 64: (Color(red: 0.33, green: 0.27, blue: 0.84), white)
        case 128: (Color(red: 0.52, green: 0.20, blue: 0.78), white)
        case 256: (Color(red: 0.74, green: 0.13, blue: 0.49), white)
        case 512: (Color(red: 0.80, green: 0.20, blue: 0.12), white)
        case 1_024: (Color(red: 0.72, green: 0.35, blue: 0.00), white)
        case 2_048: (Theme.gold, Color(red: 0.33, green: 0.18, blue: 0.00))
        default: (Color(red: 0.13, green: 0.11, blue: 0.20), Theme.gold)
        }
    }
}
