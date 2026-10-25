import SwiftUI
import CryptoClickerKit

/// Tetris with guideline rules from `TetrisGame`. Points pay coins when the game ends,
/// including when the player leaves mid-game.
struct TetrisView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = TetrisGame.fresh()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var reward: Double?
    @State private var boardWidth: CGFloat = 1
    @State private var dragColumns = 0
    /// Where the current drag began; a new start means a new gesture, even if the last one was cancelled.
    @State private var dragStart: CGPoint?
    @State private var hardDrops = 0

    private var isRunning: Bool { isPlaying && !isPaused }

    var body: some View {
        VStack(spacing: 12) {
            scoreboard
            TetrisBoard(game: game)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boardWidth = $0 }
                .gesture(boardGesture)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tetris board")
                .accessibilityValue("Score \(game.score), \(game.lines) lines")
                .overlay { overlay }
            controls
        }
        .padding(16)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background { AppBackground(tint: .cyan) }
        .navigationTitle("Tetris")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPlaying {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill") {
                        isPaused.toggle()
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.lines) { _, _ in haptics }
        .sensoryFeedback(.impact(weight: .medium), trigger: hardDrops) { _, _ in haptics }
        .sensoryFeedback(.error, trigger: reward) { _, new in haptics && new != nil }
        .task(id: isRunning) { await runGravity() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && isPlaying { isPaused = true }
        }
        .onDisappear {
            if isPlaying { endGame() }
        }
    }

    // MARK: Pieces of the screen

    private var scoreboard: some View {
        HStack(alignment: .center, spacing: 16) {
            stat("Score", CoinFormat.grouped(game.score))
            stat("Lines", CoinFormat.grouped(game.lines))
            stat("Level", "\(game.level)")
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text("Next")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                NextPieceView(kind: game.nextPiece)
            }
        }
        .glassCard(cornerRadius: 20)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .contentTransition(.numericText())
        }
    }

    @ViewBuilder
    private var overlay: some View {
        if !isPlaying {
            VStack(spacing: 12) {
                if let reward {
                    Text("Game Over")
                        .font(.title.bold())
                    Text("\(CoinFormat.grouped(game.score)) points · \(CoinFormat.grouped(game.lines)) lines")
                        .font(.headline)
                    CoinAmount(amount: reward, font: .title3.bold(), iconSize: 22)
                } else {
                    Text("Tetris")
                        .font(.title.bold())
                    Text("Best: \(CoinFormat.grouped(store.game.stats.tetrisBestScore))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tap to rotate, drag to move, swipe down to drop.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button(reward == nil ? "Start" : "Play Again", systemImage: "play.fill", action: start)
                    .buttonStyle(.glassProminent)
                    .font(.headline)
            }
            .padding(24)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(24)
        } else if isPaused {
            Button("Resume", systemImage: "play.fill") { isPaused = false }
                .buttonStyle(.glassProminent)
                .font(.title3.bold())
        }
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                controlButton("Move left", systemImage: "arrow.left", repeats: true) { game, _ in _ = game.moveLeft() }
                controlButton("Rotate", systemImage: "arrow.clockwise", repeats: false) { game, _ in _ = game.rotate() }
                controlButton("Move right", systemImage: "arrow.right", repeats: true) { game, _ in _ = game.moveRight() }
                controlButton("Soft drop", systemImage: "arrow.down", repeats: true) { game, rng in
                    game.softDrop(using: &rng)
                }
                controlButton("Hard drop", systemImage: "arrow.down.to.line", repeats: false) { game, rng in
                    game.hardDrop(using: &rng)
                    hardDrops += 1
                }
            }
        }
        .disabled(!isRunning)
    }

    private func controlButton(_ title: String, systemImage: String, repeats: Bool,
                               action: @escaping (inout TetrisGame, inout SystemRandomNumberGenerator) -> Void) -> some View {
        Button {
            step(action)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glass)
        .buttonRepeatBehavior(repeats ? .enabled : .disabled)
        .accessibilityLabel(title)
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
                    step { game, rng in game.hardDrop(using: &rng) }
                    hardDrops += 1
                }
                dragColumns = 0
                dragStart = nil
            }
    }

    // MARK: Game flow

    private func start() {
        game = .fresh()
        reward = nil
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
        reward = store.finishTetris(score: game.score, lines: game.lines)
    }
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
        .background(.black.opacity(0.45), in: .rect(cornerRadius: 14))
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
        .frame(width: 56, height: 28)
        .accessibilityLabel(kind.map { "Next piece \($0.name)" } ?? "")
    }
}
