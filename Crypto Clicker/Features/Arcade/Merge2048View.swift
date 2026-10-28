import SwiftUI
import CryptoClickerKit

/// 2048: swipe anywhere in the play area to slide every tile one way. Two tiles with the
/// same number merge into their sum, which is added to the score. Points pay coins when the game
/// ends, and making a 2048 tile pays a bonus on top. The player can end the game whenever they
/// like to collect; leaving the screen ends it too.
///
/// Two modes: Classic goes on until the board locks up, with tile goals to climb and three undos;
/// the Daily Puzzle gives everyone the same start and tiles for the day, in a fixed number of
/// moves, with stars for the score.
struct Merge2048View: View {
    enum Kind: Hashable {
        case classic, daily
    }

    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var kind: Kind = .classic
    @State private var game = Merge2048Game.fresh()
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

    struct GoalBanner: Equatable {
        let id: Int
        let tile: Int
    }

    struct ScoreGain: Identifiable, Equatable {
        let id: Int
        let points: Int
    }

    var body: some View {
        withLifecycle(withFeedback(layout))
    }

    private var layout: some View {
        VStack(spacing: 12) {
            scoreBar
            Merge2048Board(game: game)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("2048 board")
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
        .navigationTitle(game.isDaily && isPlaying ? "Daily 2048" : "2048")
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
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                store.holdArcadeRun(ArcadeRun(game: .merge2048, score: game.score, detail: game.bestTile,
                                              stage: game.isDaily ? ArcadeRun.dailyStage : 0))
            default:
                break
            }
        }
        .onDisappear {
            if isPlaying { endGame(byPlayer: true) }
        }
        .gameScreen(blocksSwipeBack: true)
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
                GameStat(title: "Top tile", value: String(game.bestTile))
            }
            Spacer(minLength: 0)
            ArcadeButton(title: "Undo, \(game.undosLeft) left", systemImage: "arrow.uturn.backward", size: 40) {
                undo()
            }
            .overlay(alignment: .topTrailing) {
                Text("\(game.undosLeft)")
                    .font(.caption2.weight(.heavy).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(minWidth: 16, minHeight: 16)
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
                Text("Goal: make a")
                    .font(.subheadline.weight(.semibold))
                Merge2048TileView(value: goal, side: 26, pops: false)
                Text("tile")
                    .font(.subheadline.weight(.semibold))
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
            } else {
                GamePanel(title: kind == .daily ? "Daily 2048" : "2048", buttonTitle: "Start", action: start) {
                    VStack(spacing: 12) {
                        Picker("Mode", selection: $kind) {
                            Text("Classic").tag(Kind.classic)
                            Text("Daily Puzzle").tag(Kind.daily)
                        }
                        .pickerStyle(.segmented)
                        if kind == .daily {
                            let today = store.today
                            StarRow(stars: store.game.merge2048Daily.stars(on: today), size: 22)
                            GameIntro(best: store.game.merge2048Daily.bestScore(on: today),
                                      howTo: "Everyone gets the same start and the same new tiles today. Score as much as you can in \(Merge2048Game.dailyMoves) moves: stars at \(starScores). Each star pays \(CoinFormat.short(store.game.merge2048DailyStarReward)) coins the first time you earn it today.",
                                      showHelp: { showingHelp = true })
                        } else {
                            GameIntro(best: store.game.stats.merge2048BestScore,
                                      howTo: "Swipe to slide every tile. Two tiles with the same number merge into one, and the new number is added to your score. Climb the tile goals; make a 2048 tile for a bonus of \(CoinFormat.short(store.game.merge2048TileBonus)) coins. You have \(Merge2048Game.undosPerGame) undos a game, and you can end whenever you like to collect.",
                                      showHelp: { showingHelp = true })
                        }
                    }
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
            Text("2048!")
                .font(.title2.weight(.heavy))
            Text("+\(CoinFormat.short(store.game.merge2048TileBonus)) coins when the game ends. Keep going!")
                .font(.footnote.weight(.semibold))
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
            Text("\(banner.tile) made!")
                .font(.title3.weight(.heavy))
            if let next = Merge2048Game.goalTiles.first(where: { $0 > banner.tile }) {
                Text("Next goal: \(next)")
                    .font(.footnote.weight(.semibold))
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
            "Row \(index + 1): " + row.map { $0 == 0 ? "empty" : String($0) }.joined(separator: ", ")
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
            game = kind == .daily ? .daily(day: store.today) : .fresh()
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
        withAnimation(Merge2048Board.slideAnimation) {
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
        withAnimation(Merge2048Board.slideAnimation) {
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

    var details: [String] {
        var lines: [String] = []
        if isDaily {
            lines.append("\(moves) of \(Merge2048Game.dailyMoves) moves · top tile \(bestTile)")
            if newStars > 0 {
                lines.append("Includes \(CoinFormat.short(starCoins)) coins for \(newStars) new \(newStars == 1 ? "star" : "stars")")
            } else if stars > 0 {
                lines.append("Stars already earned today")
            }
        } else {
            lines.append("Top tile \(bestTile)" + (undosUsed > 0 ? " · \(undosUsed) \(undosUsed == 1 ? "undo" : "undos")" : ""))
            if payout.tileBonus > 0 { lines.append("Includes \(CoinFormat.short(payout.tileBonus)) coins for the 2048 tile") }
        }
        return lines
    }
}

extension Merge2048Game {
    static func fresh() -> Merge2048Game {
        var rng = SystemRandomNumberGenerator()
        return Merge2048Game(using: &rng)
    }
}

/// The 4×4 board: empty cells, then every tile at its cell. Tiles keep their identity as they
/// slide, a merged tile pops, and a tile that merged away slides into its partner before it goes.
struct Merge2048Board: View {
    let game: Merge2048Game
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let slideAnimation = Animation.easeOut(duration: 0.12)

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

    var body: some View {
        let style = Self.style(for: value)
        RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
            .fill(style.background.gradient)
            .overlay {
                RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
            .overlay {
                Text(verbatim: String(value))
                    .font(.system(size: side * Self.fontScale(digits: String(value).count), weight: .heavy, design: .rounded))
                    .foregroundStyle(style.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, side * 0.06)
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
