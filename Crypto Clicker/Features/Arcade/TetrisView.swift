import SwiftUI
import CryptoClickerKit

/// Tetris with guideline rules from `TetrisGame`, in two modes: Endless (until the stack tops
/// out, faster every 10 lines) and Sprint (40 lines against the clock). With a `challengeDay` it
/// deals that day's pieces: the same for everyone, all day (the Daily page opens it on Block Day).
/// Points pay coins when the game ends, including when the player leaves mid-game.
///
/// The controls sit in the space beside the well: on the left, force drop, pause and move left;
/// on the right, hold, drop, rotate and move right. The board also takes taps (rotate), drags
/// (move), swipes down (drop) and swipes up (hold).
struct TetrisView: View {
    var challengeDay: String? = nil
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    /// Pieces come from this generator: seeded by the day for a challenge, at random otherwise.
    @State private var rng = SeededGenerator(seed: .random(in: 0...UInt64.max))
    @State private var game = TetrisGame.fresh()
    @State private var mode = TetrisGame.Mode.endless
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
    /// A banner for a combo, a Tetris or a new level.
    @State private var banner: Banner?
    /// Rows flashing after a clear.
    @State private var flashRows: [Int] = []

    private var isRunning: Bool { isPlaying && !isPaused }
    private static let columnWidth: CGFloat = 60

    /// What a finished game earned, for the game-over card.
    struct TetrisResult: Equatable {
        let base: GameResult
        let mode: TetrisGame.Mode
        let isComplete: Bool
        let time: TimeInterval
        let level: Int
        let bestCombo: Int
        let tetrises: Int
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
                TetrisBoard(game: game, flashRows: flashRows)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boardWidth = $0 }
                    .gesture(boardGesture)
                    .overlay(alignment: .top) { bannerView }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Tetris board")
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
        .navigationTitle(challengeDay == nil ? "Tetris" : "Today's Pieces")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.tetris, isPresented: $showingHelp) {
            if isPlaying { isPaused = true }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.lines) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.impact(weight: .medium), trigger: hardDrops) { _, _ in haptics }
        .sensoryFeedback(trigger: result) { _, new in
            guard haptics, let new else { return nil }
            return new.isComplete ? .success : .error
        }
        .task(id: isRunning) { await run() }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                isPaused = true
                store.holdArcadeRun(ArcadeRun(game: .tetris, score: game.score, detail: game.lines, extra: game.rewardPoints))
            default:
                isPaused = true
            }
        }
        .onDisappear {
            if isPlaying { endGame() }
        }
        .gameScreen(blocksSwipeBack: true)
    }

    // MARK: Pieces of the screen

    private var scoreboard: some View {
        HStack(alignment: .center, spacing: 12) {
            GameStat(title: "Score", value: CoinFormat.grouped(game.score))
            if game.mode == .endless {
                GameStat(title: "Lines", value: CoinFormat.grouped(game.lines))
                GameStat(title: "Level", value: "\(game.level)")
            } else {
                GameStat(title: "Left", value: "\(game.linesLeft)")
                GameStat(title: "Time", value: CoinFormat.stopwatch(elapsed))
            }
            Spacer(minLength: 0)
            Button(action: hold) {
                PieceBox(title: "Hold", kind: game.held, isDimmed: !game.canHold)
            }
            .buttonStyle(.plain)
            .disabled(!isRunning || !game.canHold)
            .accessibilityLabel(game.held.map { "Hold, holding \($0.name)" } ?? "Hold, empty")
            PieceBox(title: "Next", kind: game.nextPiece, isDimmed: false)
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

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: resultTitle(result), buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.base.score, isNewBest: result.base.isNewBest,
                                    best: store.game.stats.tetrisBestScore, reward: result.base.reward,
                                    details: resultDetails(result), challenge: result.base.challenge)
                }
            } else if let challengeDay {
                let goal = store.game.dailyChallenge(today: challengeDay).flatMap { $0.kind == .tetris ? $0.goal : nil }
                GamePanel(title: "Today's Pieces", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.tetrisBestScore,
                              howTo: "Everyone gets the same pieces today, every game." + (goal.map { " Daily challenge: \($0)." } ?? ""),
                              showHelp: { showingHelp = true })
                }
            } else {
                GamePanel(title: "Tetris", buttonTitle: "Start", action: start) {
                    VStack(spacing: 12) {
                        Picker("Mode", selection: $mode) {
                            Text("Endless").tag(TetrisGame.Mode.endless)
                            Text("Sprint \(TetrisGame.sprintLines)").tag(TetrisGame.Mode.sprint(lines: TetrisGame.sprintLines))
                        }
                        .pickerStyle(.segmented)
                        GameIntro(best: mode == .endless ? store.game.stats.tetrisBestScore : 0,
                                  howTo: mode == .endless
                                    ? "Play until the stack reaches the top. Every 10 lines the pieces fall faster, and clears in a row build a combo."
                                    : "Clear \(TetrisGame.sprintLines) lines as fast as you can. Points pay as usual; the record is your time.",
                                  note: mode == .endless ? nil : sprintNote,
                                  showHelp: { showingHelp = true })
                    }
                }
            }
        }
    }

    private var sprintNote: String {
        let best = store.game.stats.tetrisBestSprint
        return best > 0 ? "Fastest Sprint \(CoinFormat.stopwatch(best))" : "No Sprint finished yet"
    }

    private func resultTitle(_ result: TetrisResult) -> String {
        if case .sprint = result.mode { return result.isComplete ? "Sprint Done" : "Topped Out" }
        return "Game Over"
    }

    private func resultDetails(_ result: TetrisResult) -> [String] {
        var details: [String] = []
        if case .sprint(let lines) = result.mode {
            details.append(result.isComplete
                           ? "\(lines) lines in \(CoinFormat.stopwatch(result.time))" + (result.base.isNewBest ? " · fastest yet" : "")
                           : "\(result.base.detail) of \(lines) lines in \(CoinFormat.stopwatch(result.time))")
        } else {
            details.append("\(CoinFormat.grouped(result.base.detail)) lines · level \(result.level)")
        }
        details.append("Best combo \(max(0, result.bestCombo)) · \(result.tetrises) Tetris\(result.tetrises == 1 ? "" : "es")")
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
        let playMode = challengeDay == nil ? mode : .endless
        rng = SeededGenerator(seed: challengeDay.map(GameState.dailyChallengeSeed(day:)) ?? .random(in: 0...UInt64.max))
        game = TetrisGame(mode: playMode, using: &rng)
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
        let before = (lines: game.lines, level: game.level, pieces: game.pieces)
        action(&game, &rng)
        if game.pieces != before.pieces { noteLock(linesBefore: before.lines, levelBefore: before.level) }
        if game.isOver { endGame() }
    }

    /// Flashes cleared rows and calls out combos, Tetrises and new levels.
    private func noteLock(linesBefore: Int, levelBefore: Int) {
        let cleared = game.lines - linesBefore
        guard cleared > 0 else { return }
        flashRows = game.clearedRows
        var text: String?
        if game.level > levelBefore && game.mode == .endless {
            text = "Level \(game.level)!"
        } else if cleared >= 4 {
            text = "TETRIS!"
        } else if game.combo >= 1 {
            text = "Combo ×\(game.combo + 1)"
        }
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
                              bestCombo: game.bestCombo, tetrises: game.tetrises)
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

extension TetrisGame {
    static func fresh() -> TetrisGame {
        var rng = SystemRandomNumberGenerator()
        return TetrisGame(using: &rng)
    }
}

/// The well, drawn in one Canvas pass: settled blocks, the ghost, then the falling piece, and a
/// flash over rows just cleared.
struct TetrisBoard: View {
    let game: TetrisGame
    var flashRows: [Int] = []

    var body: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(TetrisGame.width)
            func rect(_ x: Int, _ y: Int) -> Path {
                let frame = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                return Path(roundedRect: frame.insetBy(dx: 1, dy: 1), cornerRadius: cell * 0.2)
            }
            for y in 0..<TetrisGame.height {
                for x in 0..<TetrisGame.width {
                    if let kind = game.block(x: x, y: y) {
                        context.fill(rect(x, y), with: .color(kind.color))
                    } else {
                        context.fill(rect(x, y), with: .color(.white.opacity(0.05)))
                    }
                }
            }
            if let ghost = game.ghost {
                for cell in ghost.cells where cell.y >= 0 {
                    context.stroke(rect(cell.x, cell.y), with: .color(ghost.kind.color.opacity(0.7)), lineWidth: 2)
                }
            }
            if let piece = game.piece {
                for cell in piece.cells where cell.y >= 0 {
                    context.fill(rect(cell.x, cell.y), with: .color(piece.kind.color))
                }
            }
            for row in flashRows {
                let band = CGRect(x: 0, y: CGFloat(row) * cell, width: size.width, height: cell)
                context.fill(Path(roundedRect: band, cornerRadius: cell * 0.2), with: .color(.white.opacity(0.75)))
            }
        }
        .aspectRatio(CGFloat(TetrisGame.width) / CGFloat(TetrisGame.height), contentMode: .fit)
        .padding(4)
        .background(.black.opacity(0.55), in: .rect(cornerRadius: 14))
    }
}

/// A small labelled box showing one piece: the next, or the one held.
struct PieceBox: View {
    let title: String
    let kind: Tetromino?
    let isDimmed: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.subtext)
                .textCase(.uppercase)
            NextPieceView(kind: kind)
                .opacity(isDimmed ? 0.4 : 1)
        }
    }
}

struct NextPieceView: View {
    let kind: Tetromino?

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
                context.fill(Path(roundedRect: frame.insetBy(dx: 1, dy: 1), cornerRadius: unit * 0.2),
                             with: .color(kind.color))
            }
        }
        .frame(width: 48, height: 24)
        .accessibilityHidden(true)
    }
}
