import SwiftUI
import CryptoClickerKit

/// Tetris with guideline rules from `TetrisGame`. Points pay coins when the game ends,
/// including when the player leaves mid-game.
///
/// The controls sit in the space beside the well: on the left, force drop, pause and move left;
/// on the right, drop, rotate and move right. The board also takes taps, drags and swipes.
struct TetrisView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = TetrisGame.fresh()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var result: GameResult?
    @State private var boardWidth: CGFloat = 1
    @State private var dragColumns = 0
    /// Where the current drag began; a new start means a new gesture, even if the last one was cancelled.
    @State private var dragStart: CGPoint?
    @State private var hardDrops = 0

    private var isRunning: Bool { isPlaying && !isPaused }
    private static let columnWidth: CGFloat = 60

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
                TetrisBoard(game: game)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boardWidth = $0 }
                    .gesture(boardGesture)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Tetris board")
                    .accessibilityValue("Score \(game.score), \(game.lines) lines")
                    .overlay {
                        if isPaused {
                            Button("Resume", systemImage: "play.fill") { isPaused = false }
                                .buttonStyle(.glassProminent)
                                .font(.title3.bold())
                        }
                    }
                VStack(spacing: 12) {
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
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle("Tetris")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.lines) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.impact(weight: .medium), trigger: hardDrops) { _, _ in haptics }
        .sensoryFeedback(.error, trigger: result) { _, new in haptics && new != nil }
        .task(id: isRunning) { await runGravity() }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                isPaused = true
                store.holdArcadeRun(ArcadeRun(game: .tetris, score: game.score, detail: game.lines))
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
        HStack(alignment: .center, spacing: 14) {
            GameStat(title: "Score", value: CoinFormat.grouped(game.score))
            GameStat(title: "Lines", value: CoinFormat.grouped(game.lines))
            GameStat(title: "Level", value: "\(game.level)")
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text("Next")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.subtext)
                    .textCase(.uppercase)
                NextPieceView(kind: game.nextPiece)
            }
        }
        .scoreBar()
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: "Game Over", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest,
                                    best: store.game.stats.tetrisBestScore, reward: result.reward,
                                    details: ["\(CoinFormat.grouped(result.detail)) lines cleared"])
                }
            } else {
                GamePanel(title: "Tetris", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.tetrisBestScore,
                              howTo: "Use the buttons beside the board, or tap the board to rotate, drag to move and swipe down to drop.")
                }
            }
        }
    }

    /// Tap to rotate, drag sideways to move a column at a time, swipe down to hard drop.
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

    private func start() {
        game = .fresh()
        result = nil
        isPaused = false
        isPlaying = true
    }

    private func runGravity() async {
        guard isRunning else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(game.gravityInterval))
            } catch {
                return
            }
            step { $0.tick(using: &$1) }
        }
    }

    private func step(_ action: (inout TetrisGame, inout SystemRandomNumberGenerator) -> Void) {
        guard isRunning else { return }
        var rng = SystemRandomNumberGenerator()
        action(&game, &rng)
        if game.isOver { endGame() }
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        let previousBest = store.game.stats.tetrisBestScore
        let reward = store.finishTetris(score: game.score, lines: game.lines)
        result = GameResult(score: game.score, isNewBest: game.score > previousBest, reward: reward, detail: game.lines)
    }
}

/// A finished arcade game, for the game-over card.
struct GameResult: Equatable {
    let score: Int
    let isNewBest: Bool
    let reward: Double
    /// A game-specific number: lines, length, bricks or bubbles.
    let detail: Int
}

extension TetrisGame {
    static func fresh() -> TetrisGame {
        var rng = SystemRandomNumberGenerator()
        return TetrisGame(using: &rng)
    }
}

/// The well, drawn in one Canvas pass: settled blocks, the ghost, then the falling piece.
struct TetrisBoard: View {
    let game: TetrisGame

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
        }
        .aspectRatio(CGFloat(TetrisGame.width) / CGFloat(TetrisGame.height), contentMode: .fit)
        .padding(4)
        .background(.black.opacity(0.55), in: .rect(cornerRadius: 14))
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
        .accessibilityLabel(kind.map { "Next piece \($0.name)" } ?? "")
    }
}
