import SwiftUI
import CryptoClickerKit

/// Snake: swipe anywhere in the play area to steer toward the coins; there are no buttons to
/// reach for. A long swipe that bends (up, then left) turns twice.
/// Points pay coins when the game ends, including when the player leaves mid-game.
struct SnakeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = SnakeGame.fresh()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showingHelp = false
    @State private var result: GameResult?
    /// Where the current swipe is measured from; it moves after each recognised swipe.
    @State private var swipeOrigin: CGPoint?
    /// Where the current drag began; a new start means a new gesture, even if the last was cut short.
    @State private var swipeStart: CGPoint?

    private var isRunning: Bool { isPlaying && !isPaused }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Length", value: "\(game.body.count)")
                Spacer(minLength: 0)
                GameStat(title: "Best", value: CoinFormat.grouped(store.game.stats.snakeBestScore))
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying { isPaused.toggle() }
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            SnakeBoard(game: game)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Snake board")
                .accessibilityValue("Score \(game.score), length \(game.body.count)")
                .accessibilityAction(named: "Turn up") { turn(.up) }
                .accessibilityAction(named: "Turn down") { turn(.down) }
                .accessibilityAction(named: "Turn left") { turn(.left) }
                .accessibilityAction(named: "Turn right") { turn(.right) }
                // The whole play area under the score takes swipes, not just the board.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .gesture(swipe)
            ControlHint(game: .snake)
        }
        .padding(12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background { AppBackground(tint: .green) }
        .overlay {
            if isPaused {
                PausedCard(game: .snake, resume: { isPaused = false }, showHelp: { showingHelp = true })
            }
        }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle("Snake")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.snake, isPresented: $showingHelp) {
            if isPlaying { isPaused = true }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: game.eaten) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.error, trigger: result) { _, new in haptics && new != nil }
        .task(id: isRunning) { await run() }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                isPaused = true
                store.holdArcadeRun(ArcadeRun(game: .snake, score: game.score, detail: game.body.count))
            default:
                isPaused = true
            }
        }
        .onDisappear {
            if isPlaying { endGame() }
        }
        .gameScreen(blocksSwipeBack: true)
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: "Game Over", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest,
                                    best: store.game.stats.snakeBestScore, reward: result.reward,
                                    details: ["Grew to \(result.detail) long"],
                                    challenge: result.challenge)
                }
            } else {
                GamePanel(title: "Snake", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.snakeBestScore,
                              howTo: "Swipe anywhere to steer: up, down, left or right. Every coin you eat is worth 10 points and makes you longer.",
                              showHelp: { showingHelp = true })
                }
            }
        }
    }

    /// Swipes turn the snake as soon as the finger has moved far enough, without waiting for it to
    /// lift. A long drag can turn more than once: each recognised swipe starts measuring again
    /// from where the finger is.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if swipeStart != value.startLocation {
                    swipeStart = value.startLocation
                    swipeOrigin = value.startLocation
                }
                let origin = swipeOrigin ?? value.startLocation
                let dx = value.location.x - origin.x
                let dy = value.location.y - origin.y
                guard max(abs(dx), abs(dy)) >= 18 else {
                    if swipeOrigin == nil { swipeOrigin = origin }
                    return
                }
                turn(abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up))
                swipeOrigin = value.location
            }
            .onEnded { _ in
                swipeOrigin = nil
                swipeStart = nil
            }
    }

    private func turn(_ direction: SnakeDirection) {
        guard isRunning else { return }
        game.turn(direction)
    }

    // MARK: Game flow

    private func start() {
        game = .fresh()
        result = nil
        isPaused = false
        isPlaying = true
    }

    private func run() async {
        guard isRunning else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(game.tickInterval))
            } catch {
                return
            }
            guard isRunning else { return }
            var rng = SystemRandomNumberGenerator()
            game.step(using: &rng)
            if game.isOver {
                endGame()
                return
            }
        }
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        let payout = store.finishSnake(score: game.score, length: game.body.count)
        result = GameResult(score: game.score, payout: payout, detail: game.body.count)
    }
}

extension SnakeGame {
    static func fresh() -> SnakeGame {
        var rng = SystemRandomNumberGenerator()
        return SnakeGame(using: &rng)
    }
}

/// The board: a soft checkerboard, the coin, and the snake from tail to head.
struct SnakeBoard: View {
    let game: SnakeGame

    var body: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(SnakeGame.width)
            func frame(_ point: GridPoint, inset: CGFloat = 0) -> CGRect {
                CGRect(x: CGFloat(point.x) * cell, y: CGFloat(point.y) * cell, width: cell, height: cell)
                    .insetBy(dx: inset, dy: inset)
            }
            for y in 0..<SnakeGame.height {
                for x in 0..<SnakeGame.width where (x + y) % 2 == 0 {
                    context.fill(Path(frame(GridPoint(x: x, y: y))), with: .color(.white.opacity(0.04)))
                }
            }
            if let food = game.food {
                context.draw(context.resolve(Image("CoinSmall")), in: frame(food, inset: cell * 0.08))
            }
            let count = game.body.count
            for (index, segment) in game.body.enumerated().reversed() {
                // Bright at the head, deeper green toward the tail.
                let shade = count > 1 ? Double(index) / Double(count - 1) : 0
                let color = Color(red: 0.55 - 0.35 * shade, green: 0.95 - 0.35 * shade, blue: 0.30 - 0.15 * shade)
                let inset = index == 0 ? cell * 0.04 : cell * 0.1
                context.fill(Path(roundedRect: frame(segment, inset: inset), cornerRadius: cell * 0.32), with: .color(color))
            }
            drawEyes(in: &context, cell: cell, frame: frame(game.head))
        }
        .aspectRatio(CGFloat(SnakeGame.width) / CGFloat(SnakeGame.height), contentMode: .fit)
        .padding(4)
        .background(Color(red: 0.03, green: 0.16, blue: 0.08).opacity(0.85), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.green.opacity(0.35), lineWidth: 1)
        }
    }

    private func drawEyes(in context: inout GraphicsContext, cell: CGFloat, frame: CGRect) {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let forward: CGVector = switch game.heading {
        case .up: CGVector(dx: 0, dy: -1)
        case .down: CGVector(dx: 0, dy: 1)
        case .left: CGVector(dx: -1, dy: 0)
        case .right: CGVector(dx: 1, dy: 0)
        }
        let side = CGVector(dx: -forward.dy, dy: forward.dx)
        for direction in [-1.0, 1.0] {
            let eye = CGPoint(x: center.x + forward.dx * cell * 0.15 + side.dx * cell * 0.2 * direction,
                              y: center.y + forward.dy * cell * 0.15 + side.dy * cell * 0.2 * direction)
            let radius = cell * 0.12
            context.fill(Path(ellipseIn: CGRect(x: eye.x - radius, y: eye.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(.white))
            let pupil = radius * 0.55
            context.fill(Path(ellipseIn: CGRect(x: eye.x - pupil + forward.dx * radius * 0.3, y: eye.y - pupil + forward.dy * radius * 0.3,
                                                width: pupil * 2, height: pupil * 2)), with: .color(.black))
        }
    }
}
