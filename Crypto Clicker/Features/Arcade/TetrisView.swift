import SwiftUI
import CryptoClickerKit

/// The screens inside Tetris (Block Chain in the crypto edition), opened from its start screen.
enum TetrisRoute: Hashable {
    /// Until the stack tops out, faster every 10 lines.
    case endless
    /// Sprint (Block Rush): 40 lines against the clock.
    case sprint
    /// Endless with a day's pieces: the same for everyone, all day. The Daily page opens it on
    /// Block Day.
    case todaysPieces(day: String)
}

/// Where Tetris opens, like Brick Breaker and Scam Invaders: Endless, the Sprint (Block Rush),
/// today's pieces and the speed setting, each on a card.
struct TetrisView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.tetrisSpeedKey) private var speed = GameSpeed.normal
    @State private var showingHelp = false

    var body: some View {
        let stats = store.game.stats
        let tint = MiniGame.tetris.color
        let crypto = store.arcadeEdition == .crypto
        let today = store.today
        let blockDay = store.game.dailyChallenge(today: today).flatMap { $0.kind == .tetris && !$0.isComplete ? $0.goal : nil }
        ScrollView {
            VStack(spacing: 14) {
                ModeCard(tint: tint, icon: "infinity", title: "Endless",
                         status: stats.tetrisGames == 0
                            ? "Start at level 1"
                            : "Best \(CoinFormat.grouped(stats.tetrisBestScore)) · level \(CoinFormat.grouped(stats.tetrisBestLevel))",
                         detail: crypto
                            ? "Mine rows until the stack tops out, faster every 10 rows. Every \(TetrisGame.gasSpikeEvery) pieces a gas spike pushes the stack up a row from below: clear it to collect the fee."
                            : "Clear lines until the stack tops out, faster every 10 lines.",
                         note: nil) {
                    NavigationLink(value: TetrisRoute.endless) {
                        Label("Play Endless", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                ModeCard(tint: tint, icon: "stopwatch.fill", title: crypto ? "Block Rush" : "Sprint \(TetrisGame.sprintLines)",
                         status: stats.tetrisBestSprint > 0
                            ? "Fastest \(CoinFormat.stopwatch(stats.tetrisBestSprint)) · \(CoinFormat.grouped(stats.tetrisSprints)) finished"
                            : "No run finished yet",
                         detail: crypto
                            ? "Mine \(TetrisGame.sprintLines) rows as fast as you can, with no gas: the record is your time."
                            : "Clear \(TetrisGame.sprintLines) lines as fast as you can; the record is your time.",
                         note: nil) {
                    NavigationLink(value: TetrisRoute.sprint) {
                        Label(crypto ? "Play Block Rush" : "Play Sprint", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                ModeCard(tint: tint, icon: "calendar", title: "Today's Pieces",
                         status: blockDay.map { "Block Day: \($0)" } ?? "The same pieces for everyone today",
                         detail: "Endless with today's pieces, dealt the same to everyone all day. Scores count toward your Endless best.",
                         note: nil) {
                    NavigationLink(value: TetrisRoute.todaysPieces(day: today)) {
                        Label("Play Today's Pieces", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                ModeCard(tint: tint, icon: "slider.horizontal.3", title: "Settings", status: "\(speed.name) speed",
                         detail: "How fast pieces fall. Points are worth the same at every speed: Fast scores sooner but is harder to keep up with, and Slow is relaxed.",
                         note: nil) {
                    Picker("Speed", selection: $speed) {
                        ForEach(GameSpeed.allCases) { speed in
                            Text(speed.name).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background { AppBackground(tint: .cyan) }
        .navigationTitle(MiniGame.tetris.name)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.tetris, isPresented: $showingHelp)
    }
}

/// Tetris's game, with rules from `TetrisGame`: the classic well, or Block Chain's shorter one
/// with gas spikes. The mode comes from the start screen; a day's pieces are seeded by the day.
/// Points pay coins when the game ends, including when the player leaves mid-game.
///
/// The controls sit in the space beside the well: on the left, force drop, pause and move left;
/// on the right, hold, drop, rotate and move right. The board also takes taps (rotate), drags
/// (move), swipes down (drop) and swipes up (hold).
struct TetrisPlayView: View {
    let route: TetrisRoute
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.tetrisSpeedKey) private var speed = GameSpeed.normal
    /// Pieces come from this generator: seeded by the day for today's pieces, at random otherwise.
    @State private var rng = SeededGenerator(seed: .random(in: 0...UInt64.max))
    @State private var game: TetrisGame
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showingHelp = false
    @State private var result: TetrisResult?
    @State private var boardWidth: CGFloat = 1
    @State private var dragColumns = 0
    /// Where the current drag began; a new start means a new gesture, even if the last one was cancelled.
    @State private var dragStart: CGPoint?
    @State private var hardDrops = 0
    /// Playing time, without pauses: the Sprint clock.
    @State private var elapsed: TimeInterval = 0
    /// Time toward the next gravity step.
    @State private var gravityClock: TimeInterval = 0
    /// A banner for a combo, four lines, a gas spike or a new level.
    @State private var banner: Banner?
    /// Rows flashing after a clear.
    @State private var flashRows: [Int] = []

    private var isRunning: Bool { isPlaying && !isPaused }
    private static let columnWidth: CGFloat = 60

    init(route: TetrisRoute) {
        self.route = route
        var rng = SystemRandomNumberGenerator()
        _game = State(initialValue: TetrisGame(mode: Self.mode(for: route), rules: .edition(.current), using: &rng))
    }

    static func mode(for route: TetrisRoute) -> TetrisGame.Mode {
        route == .sprint ? .sprint(lines: TetrisGame.sprintLines) : .endless
    }

    /// What a finished game earned, for the game-over card.
    struct TetrisResult: Equatable {
        let base: GameResult
        let mode: TetrisGame.Mode
        let isComplete: Bool
        let time: TimeInterval
        let level: Int
        let bestCombo: Int
        let tetrises: Int
        let gasRows: Int
    }

    struct Banner: Equatable {
        let id: Int
        let text: String
    }

    var body: some View {
        VStack(spacing: 10) {
            scoreboard
            HStack(alignment: .bottom, spacing: 8) {
                VStack(spacing: 12) {
                    ArcadeButton(title: "Force drop", systemImage: "arrow.down.to.line") { forceDrop() }
                        .disabled(!isRunning)
                    ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill") {
                        if isPlaying { isPaused.toggle() }
                    }
                    .disabled(!isPlaying)
                    ArcadeButton(title: "Move left", systemImage: "arrow.left", repeats: true) {
                        step { game, _ in _ = game.moveLeft() }
                    }
                    .disabled(!isRunning)
                }
                .frame(width: Self.columnWidth)
                TetrisBoard(game: game, flashRows: flashRows, skin: store.game.equipped(.tetris), edition: store.arcadeEdition)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boardWidth = $0 }
                    .gesture(boardGesture)
                    .overlay(alignment: .top) { bannerView }
                    .overlay(alignment: .bottom) { gasGauge }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(MiniGame.tetris.name) well")
                    .accessibilityValue("Score \(game.score), \(game.lines) lines")
                VStack(spacing: 12) {
                    ArcadeButton(title: "Hold", systemImage: "tray.and.arrow.down") { hold() }
                        .disabled(!isRunning || !game.canHold)
                    ArcadeButton(title: "Drop", systemImage: "arrow.down", repeats: true) {
                        step { game, rng in game.softDrop(using: &rng) }
                    }
                    ArcadeButton(title: "Rotate", systemImage: "arrow.clockwise") {
                        step { game, _ in _ = game.rotate() }
                    }
                    ArcadeButton(title: "Move right", systemImage: "arrow.right", repeats: true) {
                        step { game, _ in _ = game.moveRight() }
                    }
                }
                .disabled(!isRunning)
                .frame(width: Self.columnWidth)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AppBackground(tint: .cyan) }
        .overlay {
            if isPaused {
                PausedCard(game: .tetris, resume: { isPaused = false }, showHelp: { showingHelp = true })
            }
        }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.tetris, isPresented: $showingHelp) {
            if isPlaying { isPaused = true }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.lines) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.impact(weight: .medium), trigger: hardDrops) { _, _ in haptics }
        .sensoryFeedback(.warning, trigger: game.gasSpikes) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(trigger: result) { _, new in
            guard haptics, let new else { return nil }
            return new.isComplete ? .success : .error
        }
        .task(id: isRunning) { await run() }
        .arcadeLifecycle(isPlaying: isPlaying, pause: { isPaused = true }, heldRun: { heldRun }) { endGame() }
    }

    private var crypto: Bool { store.arcadeEdition == .crypto }

    /// Block Chain's coin chips: its look for the Classic skin.
    private var showsChips: Bool { crypto && store.game.equipped(.tetris) == .tetrisClassic }

    private var title: String {
        switch route {
        case .endless: MiniGame.tetris.name
        case .sprint: crypto ? "Block Rush" : "Sprint \(TetrisGame.sprintLines)"
        case .todaysPieces: "Today's Pieces"
        }
    }

    /// The day whose pieces this game deals, if any.
    private var piecesDay: String? {
        if case .todaysPieces(let day) = route { return day }
        return nil
    }

    /// The game so far, held while the app is in the background.
    private var heldRun: ArcadeRun {
        ArcadeRun(game: .tetris, score: game.score, detail: game.lines, extra: game.rewardPoints,
                  records: .init(level: game.level, bestCombo: game.bestCombo, tetrises: game.tetrises))
    }

    // MARK: Pieces of the screen

    private var scoreboard: some View {
        HStack(alignment: .center, spacing: 12) {
            GameStat(title: "Score", value: CoinFormat.grouped(game.score))
            if game.mode == .endless {
                GameStat(title: crypto ? "Rows" : "Lines", value: CoinFormat.grouped(game.lines))
                GameStat(title: "Level", value: "\(game.level)")
            } else {
                GameStat(title: "Left", value: "\(game.linesLeft)")
                GameStat(title: "Time", value: CoinFormat.stopwatch(elapsed))
            }
            Spacer(minLength: 0)
            Button(action: hold) {
                PieceBox(title: "Hold", kind: game.held, isDimmed: !game.canHold, isChip: showsChips)
            }
            .buttonStyle(.plain)
            .disabled(!isRunning || !game.canHold)
            .accessibilityLabel(game.held.map { "Hold, holding \($0.name)" } ?? "Hold, empty")
            PieceBox(title: "Next", kind: game.nextPiece, isDimmed: false, isChip: showsChips)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(game.nextPiece.map { "Next piece \($0.name)" } ?? "")
        }
        .scoreBar()
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner {
            Text(banner.text)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.gold.gradient)
                .shadow(color: .black.opacity(0.7), radius: 3)
                .padding(.top, 40)
                .id(banner.id)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    /// Block Chain's gas gauge: how soon the next gas spike comes, once it's close.
    @ViewBuilder
    private var gasGauge: some View {
        if let left = game.piecesUntilGasSpike, isPlaying, left <= 5 {
            Label(left == 1 ? "Gas spike next piece" : "Gas spike in \(left) pieces", systemImage: "fuelpump.fill")
                .font(.footnote.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 0.55, green: 0.2, blue: 0.75).opacity(0.85), in: .capsule)
                .padding(.bottom, 8)
                .allowsHitTesting(false)
                .transition(.opacity)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: resultTitle(result), buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.base.score, isNewBest: result.base.isNewBest,
                                    best: store.game.stats.tetrisBestScore, reward: result.base.reward,
                                    details: resultDetails(result), challenge: result.base.challenge)
                }
            } else {
                GamePanel(title: title, buttonTitle: "Start", action: start) {
                    GameIntro(best: route == .sprint ? 0 : store.game.stats.tetrisBestScore,
                              note: route == .sprint ? sprintNote : nil,
                              detail: introDetail)
                }
            }
        }
    }

    private var introDetail: String {
        let speedText = "\(speed.name) speed"
        switch route {
        case .endless:
            return crypto ? "Gas spikes every \(TetrisGame.gasSpikeEvery) pieces · \(speedText)" : speedText
        case .sprint:
            return (crypto ? "Mine \(TetrisGame.sprintLines) rows" : "Clear \(TetrisGame.sprintLines) lines") + " · \(speedText)"
        case .todaysPieces(let day):
            let goal = store.game.dailyChallenge(today: day).flatMap { $0.kind == .tetris ? $0.goal : nil }
            return "Everyone gets the same pieces today." + (goal.map { " Daily challenge: \($0)." } ?? "") + " \(speedText)."
        }
    }

    private var sprintNote: String {
        let best = store.game.stats.tetrisBestSprint
        return best > 0 ? "Fastest \(CoinFormat.stopwatch(best))" : "No run finished yet"
    }

    private func resultTitle(_ result: TetrisResult) -> String {
        if case .sprint = result.mode { return result.isComplete ? (crypto ? "Rush Done" : "Sprint Done") : "Topped Out" }
        return "Game Over"
    }

    private func resultDetails(_ result: TetrisResult) -> [String] {
        var details: [String] = []
        let unit = crypto ? "rows" : "lines"
        if case .sprint(let lines) = result.mode {
            details.append(result.isComplete
                           ? "\(lines) \(unit) in \(CoinFormat.stopwatch(result.time))" + (result.base.isNewBest ? " · fastest yet" : "")
                           : "\(result.base.detail) of \(lines) \(unit) in \(CoinFormat.stopwatch(result.time))")
        } else {
            details.append("\(CoinFormat.grouped(result.base.detail)) \(unit) · level \(result.level)"
                           + (result.gasRows > 0 ? " · \(result.gasRows) gas row\(result.gasRows == 1 ? "" : "s")" : ""))
        }
        let fours = crypto ? "Full Block\(result.tetrises == 1 ? "" : "s")" : "Tetris\(result.tetrises == 1 ? "" : "es")"
        details.append("Best combo \(max(0, result.bestCombo)) · \(result.tetrises) \(fours)")
        return details
    }

    /// Tap to rotate, drag sideways to move a column at a time, swipe down to drop, swipe up to hold.
    private var boardGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart != value.startLocation {
                    dragStart = value.startLocation
                    dragColumns = 0
                }
                let column = boardWidth / CGFloat(TetrisGame.width)
                let target = Int((value.translation.width / column).rounded(.towardZero))
                while dragColumns < target {
                    dragColumns += 1
                    step { game, _ in _ = game.moveRight() }
                }
                while dragColumns > target {
                    dragColumns -= 1
                    step { game, _ in _ = game.moveLeft() }
                }
            }
            .onEnded { value in
                let distance = hypot(value.translation.width, value.translation.height)
                if distance < 10 {
                    step { game, _ in _ = game.rotate() }
                } else if value.translation.height > 80 && dragColumns == 0 {
                    forceDrop()
                } else if value.translation.height < -80 && dragColumns == 0 {
                    hold()
                }
                dragColumns = 0
                dragStart = nil
            }
    }

    // MARK: Game flow

    private func forceDrop() {
        guard isRunning else { return }
        step { game, rng in game.hardDrop(using: &rng) }
        hardDrops += 1
    }

    private func hold() {
        step { game, rng in _ = game.hold(using: &rng) }
    }

    private func start() {
        rng = SeededGenerator(seed: piecesDay.map(GameState.dailyChallengeSeed(day:)) ?? .random(in: 0...UInt64.max))
        game = TetrisGame(mode: Self.mode(for: route), speed: speed, rules: .edition(store.arcadeEdition), using: &rng)
        result = nil
        banner = nil
        flashRows = []
        elapsed = 0
        gravityClock = 0
        isPaused = false
        isPlaying = true
    }

    /// Runs the clock: gravity steps at the level's pace, and the Sprint timer.
    private func run() async {
        guard isRunning else { return }
        var last = Date.now
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(30))
            } catch {
                return
            }
            guard isRunning else { return }
            let now = Date.now
            let delta = min(now.timeIntervalSince(last), 0.25)
            last = now
            elapsed += delta
            gravityClock += delta
            if gravityClock >= game.gravityInterval {
                gravityClock = 0
                step { $0.tick(using: &$1) }
            }
        }
    }

    private func step(_ action: (inout TetrisGame, inout SeededGenerator) -> Void) {
        guard isRunning else { return }
        let before = (lines: game.lines, level: game.level, pieces: game.pieces, gas: game.gasSpikes)
        action(&game, &rng)
        if game.pieces != before.pieces {
            noteLock(linesBefore: before.lines, levelBefore: before.level, gasBefore: before.gas)
        }
        if game.isOver { endGame() }
    }

    /// Flashes cleared rows and calls out combos, four-line clears, gas spikes and new levels.
    private func noteLock(linesBefore: Int, levelBefore: Int, gasBefore: Int) {
        let cleared = game.lines - linesBefore
        var text: String?
        if cleared > 0 {
            flashRows = game.clearedRows
            if game.level > levelBefore && game.mode == .endless {
                text = "Level \(game.level)!"
            } else if cleared >= 4 {
                text = crypto ? "FULL BLOCK!" : "TETRIS!"
            } else if game.combo >= 1 {
                text = "Combo ×\(game.combo + 1)"
            }
        }
        if game.gasSpikes > gasBefore && !game.isOver {
            text = "Gas spike!"
        }
        guard text != nil || cleared > 0 else { return }
        let id = game.pieces
        if let text {
            withAnimation(.spring(duration: 0.3)) { banner = Banner(id: id, text: text) }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeOut(duration: 0.2)) { flashRows = [] }
            try? await Task.sleep(for: .milliseconds(700))
            if banner?.id == id { withAnimation(.easeOut(duration: 0.3)) { banner = nil } }
        }
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        let sprintTime: TimeInterval? = game.isComplete ? max(elapsed, 0.1) : nil
        let payout = store.finishTetris(score: game.score, lines: game.lines, rewardPoints: game.rewardPoints,
                                        level: game.level, bestCombo: game.bestCombo, tetrises: game.tetrises,
                                        sprintTime: sprintTime)
        result = TetrisResult(base: GameResult(score: game.score, payout: payout, detail: game.lines), mode: game.mode,
                              isComplete: game.isComplete, time: elapsed, level: game.level,
                              bestCombo: game.bestCombo, tetrises: game.tetrises, gasRows: game.gasRowsCleared)
    }
}

/// A finished arcade game, for the game-over card.
struct GameResult: Equatable {
    let score: Int
    let isNewBest: Bool
    let reward: Double
    /// A game-specific number: lines, length, bricks or bubbles.
    let detail: Int
    /// Set when the game completed the daily challenge.
    let challenge: ChallengeReward?

    init(score: Int, payout: ArcadePayout, detail: Int) {
        self.score = score
        isNewBest = payout.isNewBest
        reward = payout.coins
        self.detail = detail
        challenge = payout.challenge
    }
}

/// The well, drawn in one Canvas pass: settled blocks, where the piece will land, then the falling
/// piece, and a flash over rows just cleared. Block Chain draws coin chips (with its Classic skin),
/// gas rows, and a dotted pending marker where the classic game draws a ghost outline.
struct TetrisBoard: View {
    let game: TetrisGame
    var flashRows: [Int] = []
    /// The blocks picked in Style.
    var skin: Cosmetic = .tetrisClassic
    var edition = ArcadeEdition.crypto

    var body: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(TetrisGame.width)
            let chips = edition == .crypto && skin == .tetrisClassic
            var glyphs: [Tetromino: GraphicsContext.ResolvedText] = [:]
            if chips {
                for kind in Tetromino.allCases { glyphs[kind] = Cosmetic.coinGlyph(kind, cell: cell, context: context) }
            }
            var flame = context.resolve(Image(systemName: "flame.fill"))
            flame.shading = .color(Color.orange.opacity(0.75))
            func frame(_ x: Int, _ y: Int) -> CGRect {
                CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
            }
            func rect(_ x: Int, _ y: Int) -> Path {
                Path(roundedRect: frame(x, y).insetBy(dx: 1, dy: 1), cornerRadius: cell * 0.2)
            }
            func draw(_ kind: Tetromino, at frame: CGRect, in context: inout GraphicsContext) {
                if chips {
                    Cosmetic.drawCoinChip(kind.color, in: frame, cell: cell, glyph: glyphs[kind], context: &context)
                } else {
                    skin.drawBlock(kind.color, in: frame, cell: cell, context: &context)
                }
            }
            for y in 0..<game.height {
                for x in 0..<TetrisGame.width {
                    if let kind = game.block(x: x, y: y) {
                        draw(kind, at: frame(x, y), in: &context)
                    } else if game.isGas(x: x, y: y) {
                        let block = Path(roundedRect: frame(x, y).insetBy(dx: 0.5, dy: 0.5), cornerRadius: cell * 0.12)
                        context.fill(block, with: .color(Color(red: 0.24, green: 0.2, blue: 0.32)))
                        context.stroke(block, with: .color(.black.opacity(0.4)), lineWidth: 1)
                        context.draw(flame, in: frame(x, y).insetBy(dx: cell * 0.28, dy: cell * 0.26))
                    } else {
                        context.fill(rect(x, y), with: .color(.white.opacity(0.05)))
                    }
                }
            }
            if let ghost = game.ghost {
                for block in ghost.cells where block.y >= 0 {
                    if edition == .crypto {
                        // A pending transaction: a ring of dots where the piece will land.
                        let spot = frame(block.x, block.y)
                        let dot = cell * 0.2
                        context.fill(Path(ellipseIn: CGRect(x: spot.midX - dot / 2, y: spot.midY - dot / 2, width: dot, height: dot)),
                                     with: .color(ghost.kind.color.opacity(0.9)))
                        context.stroke(Path(ellipseIn: spot.insetBy(dx: cell * 0.14, dy: cell * 0.14)),
                                       with: .color(ghost.kind.color.opacity(0.55)),
                                       style: StrokeStyle(lineWidth: max(1, cell * 0.06), dash: [max(1.5, cell * 0.08), max(2, cell * 0.1)]))
                    } else {
                        context.stroke(rect(block.x, block.y), with: .color(ghost.kind.color.opacity(0.7)), lineWidth: 2)
                    }
                }
            }
            if let piece = game.piece {
                for block in piece.cells where block.y >= 0 {
                    draw(piece.kind, at: frame(block.x, block.y), in: &context)
                }
            }
            for row in flashRows {
                let band = CGRect(x: 0, y: CGFloat(row) * cell, width: size.width, height: cell)
                context.fill(Path(roundedRect: band, cornerRadius: cell * 0.2), with: .color(.white.opacity(0.75)))
            }
        }
        .aspectRatio(CGFloat(TetrisGame.width) / CGFloat(game.height), contentMode: .fit)
        .padding(4)
        .background(edition == .crypto ? Color(red: 0.02, green: 0.05, blue: 0.1).opacity(0.7) : .black.opacity(0.55),
                    in: .rect(cornerRadius: 14))
    }
}

/// A small labelled box showing one piece: the next, or the one held.
struct PieceBox: View {
    let title: LocalizedStringKey
    let kind: Tetromino?
    let isDimmed: Bool
    /// Drawn as coin chips, like Block Chain's pieces.
    var isChip = false

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.accent)
                .textCase(.uppercase)
            NextPieceView(kind: kind, isChip: isChip)
                .opacity(isDimmed ? 0.4 : 1)
        }
    }
}

struct NextPieceView: View {
    let kind: Tetromino?
    var isChip = false

    var body: some View {
        Canvas { context, size in
            guard let kind else { return }
            let cells = kind.cells(rotation: 0)
            let minX = cells.map(\.x).min() ?? 0, maxX = cells.map(\.x).max() ?? 0
            let minY = cells.map(\.y).min() ?? 0, maxY = cells.map(\.y).max() ?? 0
            let unit = min(size.width / 4, size.height / 2)
            let offsetX = (size.width - CGFloat(maxX - minX + 1) * unit) / 2
            let offsetY = (size.height - CGFloat(maxY - minY + 1) * unit) / 2
            for cell in cells {
                let frame = CGRect(x: offsetX + CGFloat(cell.x - minX) * unit, y: offsetY + CGFloat(cell.y - minY) * unit,
                                   width: unit, height: unit)
                if isChip {
                    context.fill(Path(ellipseIn: frame.insetBy(dx: 0.5, dy: 0.5)), with: .color(kind.color))
                } else {
                    context.fill(Path(roundedRect: frame.insetBy(dx: 1, dy: 1), cornerRadius: unit * 0.2),
                                 with: .color(kind.color))
                }
            }
        }
        .frame(width: 48, height: 24)
        .accessibilityHidden(true)
    }
}
