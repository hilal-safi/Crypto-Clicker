import SwiftUI
import CryptoClickerKit

/// The screens inside Block Chain, opened from its start screen.
enum TetrisRoute: Hashable {
    /// Until the stack tops out, faster every 10 lines.
    case endless
    /// Sprint (Block Rush): 40 lines against the clock.
    case sprint
    /// Endless with a day's pieces: the same for everyone, all day. The Daily page opens it on
    /// Block Day.
    case todaysPieces(day: String)
}

/// Where Block Chain opens, like Hash Smash and Scam Invaders: Endless, Block Rush, today's pieces
/// and the speed setting, each on a card.
struct TetrisView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.tetrisSpeedKey) private var speed = GameSpeed.normal
    @State private var showingHelp = false

    var body: some View {
        let stats = store.game.stats
        let tint = MiniGame.tetris.color
        let today = store.today
        let blockDay = store.game.dailyChallenge(today: today).flatMap { $0.kind == .tetris && !$0.isComplete ? $0.goal : nil }
        ScrollView {
            VStack(spacing: 14) {
                ModeCard(tint: tint, icon: "infinity", title: "Endless",
                         status: stats.tetrisGames == 0
                            ? "Start at level 1"
                            : "Best \(CoinFormat.grouped(stats.tetrisBestScore)) · level \(CoinFormat.grouped(stats.tetrisBestLevel))",
                         detail: "Mine rows until the stack tops out, faster every 10 rows. Every \(TetrisGame.gasSpikeEvery) pieces a gas spike pushes the stack up a row from below: clear it to collect the fee.",
                         note: nil) {
                    NavigationLink(value: TetrisRoute.endless) {
                        Label("Play Endless", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                ModeCard(tint: tint, icon: "stopwatch.fill", title: "Block Rush",
                         status: stats.tetrisBestSprint > 0
                            ? "Fastest \(CoinFormat.stopwatch(stats.tetrisBestSprint)) · \(CoinFormat.grouped(stats.tetrisSprints)) finished"
                            : "No run finished yet",
                         detail: "Mine \(TetrisGame.sprintLines) rows as fast as you can, with no gas: the record is your time.",
                         note: nil) {
                    NavigationLink(value: TetrisRoute.sprint) {
                        Label("Play Block Rush", systemImage: "play.fill")
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
        .navigationTitle(MiniGame.tetris.name)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.tetris, isPresented: $showingHelp)
        .gameBackdrop(.tetris)
    }
}

/// Block Chain's game, with rules from `TetrisGame`: a 10x18 well with gas spikes in Endless. The
/// mode comes from the start screen; a day's pieces are seeded by the day.
/// Points pay coins when the game ends, including when the player leaves mid-game.
///
/// The score sits at the top and the well at the bottom, with the mempool between them: the next
/// three pieces, the held one, and gauges for the next gas spike and the next level (or, in Block
/// Rush, the rows to go and the clock). The controls sit in the space beside the well: on the left,
/// force drop, pause and move left; on the right, hold, drop, rotate and move right. The board also
/// takes taps (rotate), drags (move), swipes down (drop) and swipes up (hold).
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
        _game = State(initialValue: TetrisGame(mode: Self.mode(for: route), using: &rng))
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
            // The room the well leaves over: the mempool fills it, between the score and the well.
            Mempool(game: game, elapsed: elapsed, bestRush: store.game.stats.tetrisBestSprint, isChip: showsChips,
                    canHold: isRunning && game.canHold, hold: hold)
                .frame(maxHeight: .infinity)
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
                TetrisBoard(game: game, flashRows: flashRows, skin: store.game.equipped(.tetris),
                            board: store.game.equipped(.tetrisBoard))
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boardWidth = $0 }
                    .gesture(boardGesture)
                    .overlay(alignment: .top) { bannerView }
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
            // The well takes all the height its width allows before the mempool gets any.
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .gameBackdrop(.tetris)
    }

    /// Block Chain's coin chips, its first skin.
    private var showsChips: Bool { store.game.equipped(.tetris) == .tetrisClassic }

    private var title: String {
        switch route {
        case .endless: MiniGame.tetris.name
        case .sprint: "Block Rush"
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
        HStack(alignment: .center, spacing: 16) {
            GameStat(title: "Score", value: CoinFormat.grouped(game.score))
            if game.mode == .endless {
                GameStat(title: "Rows", value: CoinFormat.grouped(game.lines))
                GameStat(title: "Level", value: "\(game.level)")
            } else {
                GameStat(title: "Left", value: "\(game.linesLeft)")
                GameStat(title: "Time", value: CoinFormat.stopwatch(elapsed))
            }
            Spacer(minLength: 0)
            if game.mode == .endless {
                GameStat(title: "Best", value: CoinFormat.grouped(store.game.stats.tetrisBestScore))
            } else if store.game.stats.tetrisBestSprint > 0 {
                GameStat(title: "Best", value: CoinFormat.stopwatch(store.game.stats.tetrisBestSprint))
            }
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

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: resultTitle(result), buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.base.score, isNewBest: result.base.isNewBest,
                                    best: store.game.stats.tetrisBestScore, reward: result.base.reward,
                                    details: resultDetails(result), challenge: result.base.challenge, xp: result.base.xp)
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
            return "Gas spikes every \(TetrisGame.gasSpikeEvery) pieces · \(speedText)"
        case .sprint:
            return ("Mine \(TetrisGame.sprintLines) rows") + " · \(speedText)"
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
        if case .sprint = result.mode { return result.isComplete ? ("Rush Done") : "Topped Out" }
        return "Game Over"
    }

    private func resultDetails(_ result: TetrisResult) -> [String] {
        var details: [String] = []
        let unit = "rows"
        if case .sprint(let lines) = result.mode {
            details.append(result.isComplete
                           ? "\(lines) \(unit) in \(CoinFormat.stopwatch(result.time))" + (result.base.isNewBest ? " · fastest yet" : "")
                           : "\(result.base.detail) of \(lines) \(unit) in \(CoinFormat.stopwatch(result.time))")
        } else {
            details.append("\(CoinFormat.grouped(result.base.detail)) \(unit) · level \(result.level)"
                           + (result.gasRows > 0 ? " · \(result.gasRows) gas row\(result.gasRows == 1 ? "" : "s")" : ""))
        }
        let fours = "Full Block\(result.tetrises == 1 ? "" : "s")"
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
                let column = max(1, boardWidth / CGFloat(TetrisGame.width)) // Never 0: a drag can't divide by it.
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
        game = TetrisGame(mode: Self.mode(for: route), speed: speed, using: &rng)
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
                text = "FULL BLOCK!"
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
        result = TetrisResult(base: GameResult(score: game.score, payout: payout, detail: game.lines, xp: store.lastArcadeAward), mode: game.mode,
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
    /// What the game earned toward Arcade Rank.
    let xp: ArcadeAward?

    init(score: Int, payout: ArcadePayout, detail: Int, xp: ArcadeAward?) {
        self.score = score
        isNewBest = payout.isNewBest
        reward = payout.coins
        self.detail = detail
        challenge = payout.challenge
        self.xp = xp
    }
}

/// The well, drawn in one Canvas pass: settled blocks and gas rows, a dotted pending marker where
/// the piece will land, then the falling piece, and a flash over rows just cleared. The Coin Chips
/// skin draws coins with their token's sign.
struct TetrisBoard: View {
    let game: TetrisGame
    var flashRows: [Int] = []
    /// The blocks picked in Style.
    var skin: Cosmetic = .tetrisClassic
    /// The board picked in Style.
    var board: Cosmetic = .tetrisBoardNight

    var body: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(TetrisGame.width)
            let chips = skin == .tetrisClassic
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
                    // A pending transaction: a ring of dots where the piece will land.
                    let spot = frame(block.x, block.y)
                    let dot = cell * 0.2
                    context.fill(Path(ellipseIn: CGRect(x: spot.midX - dot / 2, y: spot.midY - dot / 2, width: dot, height: dot)),
                                 with: .color(ghost.kind.color.opacity(0.9)))
                    context.stroke(Path(ellipseIn: spot.insetBy(dx: cell * 0.14, dy: cell * 0.14)),
                                   with: .color(ghost.kind.color.opacity(0.55)),
                                   style: StrokeStyle(lineWidth: max(1, cell * 0.06), dash: [max(1.5, cell * 0.08), max(2, cell * 0.1)]))
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
        .background { BoardBackdrop(look: board.boardLook, cornerRadius: 14) }
        .overlay {
            if board.boardLook.rimWidth > 0 {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(board.boardLook.rim, lineWidth: board.boardLook.rimWidth)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// The room between the score and the well: the mempool (the next three pieces, waiting to be
/// mined), the held piece (tap it to hold), and two gauges: the next gas spike and the next level
/// in Endless, the rows to go and the clock against the best in Block Rush. With room to spare
/// the gauges get a line each; with less they share one line, then go, then the pieces shrink.
private struct Mempool: View {
    let game: TetrisGame
    let elapsed: TimeInterval
    let bestRush: TimeInterval
    let isChip: Bool
    let canHold: Bool
    let hold: () -> Void

    private enum Gauges { case lines, shared, none }

    var body: some View {
        ViewThatFits(in: .vertical) {
            panel(pieceHeight: 48, gauges: .lines)
            panel(pieceHeight: 40, gauges: .shared)
            panel(pieceHeight: 34, gauges: .shared)
            panel(pieceHeight: 34, gauges: .none)
            panel(pieceHeight: 24, gauges: .none)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func panel(pieceHeight: CGFloat, gauges: Gauges) -> some View {
        VStack(spacing: 8) {
            pieces(height: pieceHeight)
            gaugeLines(gauges)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .background(.background.opacity(0.35), in: .rect(cornerRadius: 18))
    }

    /// The next three pieces, and the held one.
    private func pieces(height pieceHeight: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            upcoming(height: pieceHeight)
            Spacer(minLength: 0)
            holdSlot(height: pieceHeight)
        }
    }

    private func upcoming(height pieceHeight: CGFloat) -> some View {
        let next = Array(game.queue.prefix(3))
        return VStack(alignment: .leading, spacing: 4) {
            caption("Mempool")
            HStack(spacing: 8) {
                ForEach(next.indices, id: \.self) { index in
                    PieceSlot(kind: next[index], height: pieceHeight, isChip: isChip, isNext: index == 0)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Next pieces: " + next.map(\.name).joined(separator: ", "))
        }
    }

    private func holdSlot(height pieceHeight: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            caption("Hold")
            Button(action: hold) {
                PieceSlot(kind: game.held, height: pieceHeight, isChip: isChip, isNext: false)
                    .opacity(game.canHold ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!canHold)
            .accessibilityLabel(game.held.map { "Hold, holding \($0.name)" } ?? "Hold, empty")
        }
    }

    @ViewBuilder
    private func gaugeLines(_ gauges: Gauges) -> some View {
        switch gauges {
        case .lines:
            VStack(spacing: 6) {
                ForEach(readings, id: \.symbol) { reading in
                    GaugeRow(reading: reading, isShort: false)
                }
            }
        case .shared:
            HStack(spacing: 14) {
                ForEach(readings, id: \.symbol) { reading in
                    GaugeRow(reading: reading, isShort: true)
                }
            }
        case .none:
            EmptyView()
        }
    }

    private func caption(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.heavy))
            .foregroundStyle(Theme.accent)
            .textCase(.uppercase)
    }

    /// What the gauges show: the next gas spike and the next level in Endless (no gas in Block
    /// Rush's), the rows to go and the clock against the best Rush in Block Rush.
    private var readings: [GaugeReading] {
        var readings: [GaugeReading] = []
        if game.mode == .endless {
            if let left = game.piecesUntilGasSpike {
                readings.append(GaugeReading(
                    symbol: "fuelpump.fill",
                    text: left == 1 ? "Gas spike next piece" : "Gas spike in \(left) pieces", short: "\(left)",
                    progress: Double(TetrisGame.gasSpikeEvery - left) / Double(TetrisGame.gasSpikeEvery),
                    tint: left <= 3 ? Theme.loss : Color(red: 0.7, green: 0.45, blue: 1)))
            }
            let rows = 10 - game.lines % 10
            readings.append(GaugeReading(
                symbol: "arrow.up.circle.fill",
                text: rows == 1 ? "1 row to level \(game.level + 1)" : "\(rows) rows to level \(game.level + 1)",
                short: "Lv \(game.level + 1)", progress: Double(game.lines % 10) / 10, tint: .cyan))
        } else {
            let total = game.lines + game.linesLeft
            readings.append(GaugeReading(
                symbol: "flag.checkered", text: "\(game.linesLeft) of \(total) rows to go", short: "\(game.linesLeft)",
                progress: total > 0 ? Double(game.lines) / Double(total) : 0, tint: .cyan))
            readings.append(GaugeReading(
                symbol: "stopwatch.fill",
                text: bestRush > 0 ? "Best Rush \(CoinFormat.stopwatch(bestRush))" : "No Rush finished yet",
                short: bestRush > 0 ? CoinFormat.stopwatch(bestRush) : "–",
                progress: bestRush > 0 ? min(1, elapsed / bestRush) : 0,
                tint: bestRush > 0 && elapsed > bestRush ? Theme.loss : Theme.gold))
        }
        return readings
    }
}

/// One of the mempool's gauges.
private struct GaugeReading {
    let symbol: String
    /// What it counts, in full, and in a word or number for a shared line.
    let text: String
    let short: String
    let progress: Double
    let tint: Color
}

/// One of the mempool's gauges: a symbol, what it counts, and a bar filling up. A short one shares
/// its line with the other, the bar in the middle.
private struct GaugeRow: View {
    let reading: GaugeReading
    let isShort: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: reading.symbol)
                .foregroundStyle(reading.tint)
                .frame(width: 22)
            if isShort {
                ProgressView(value: min(max(reading.progress, 0), 1))
                    .tint(reading.tint)
                Text(reading.short)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Text(reading.text)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                ProgressView(value: min(max(reading.progress, 0), 1))
                    .tint(reading.tint)
                    .frame(width: 84)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.text)
    }
}

/// A piece waiting in the mempool or the hold slot, in a box; the next one is outlined.
private struct PieceSlot: View {
    let kind: Tetromino?
    let height: CGFloat
    let isChip: Bool
    let isNext: Bool

    var body: some View {
        PiecePreview(kind: kind, isChip: isChip)
            .padding(height * 0.16)
            .frame(width: height * 1.5, height: height)
            .background(Color(red: 0.02, green: 0.05, blue: 0.1).opacity(0.6), in: .rect(cornerRadius: height * 0.22))
            .overlay {
                RoundedRectangle(cornerRadius: height * 0.22)
                    .strokeBorder(isNext ? Theme.accent.opacity(0.8) : .white.opacity(0.15), lineWidth: isNext ? 1.5 : 1)
            }
    }
}

/// One piece, centered in whatever room it's given: coins in Coin Chips, or blocks.
struct PiecePreview: View {
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
                    context.stroke(Path(ellipseIn: frame.insetBy(dx: unit * 0.18, dy: unit * 0.18)),
                                   with: .color(.white.opacity(0.45)), lineWidth: max(0.8, unit * 0.06))
                } else {
                    context.fill(Path(roundedRect: frame.insetBy(dx: 1, dy: 1), cornerRadius: unit * 0.2),
                                 with: .color(kind.color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
