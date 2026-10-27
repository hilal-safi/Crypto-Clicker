import SwiftUI
import CryptoClickerKit

/// Brick Breaker: drag anywhere on the field to move the paddle and lift your finger to launch.
/// The physics runs on the display's frame clock while the ball is in play.
struct BrickBreakerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = BrickBreakerGame()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var result: GameResult?
    @State private var lastFrame: Date?
    /// Where the current drag began, and whether a ball was waiting to be served then. Only a
    /// drag that began on a waiting ball launches it, so a new ball never flies off by surprise.
    @State private var dragStart: CGPoint?
    @State private var dragBeganServing = false
    @State private var effects = Effects()

    private var isRunning: Bool { isPlaying && !isPaused }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Level", value: "\(game.level)")
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    ForEach(0..<BrickBreakerGame.startingLives, id: \.self) { life in
                        Image(systemName: life < game.lives ? "heart.fill" : "heart")
                            .foregroundStyle(life < game.lives ? .red : .subtext)
                    }
                }
                .font(.subheadline)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(game.lives) lives left")
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying { isPaused.toggle() }
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            field
                .frame(maxHeight: .infinity)
            Text(game.phase == .serving ? "Drag to move, lift your finger to launch" : "Drag anywhere to move the paddle")
                .font(.footnote)
                .foregroundStyle(.subtext)
        }
        .padding(12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background { AppBackground(tint: .orange) }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle("Brick Breaker")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: game.bricksBroken) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.5), trigger: game.paddleHits) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.error, trigger: game.lives) { (old: Int, new: Int) in haptics && new < old }
        .onChange(of: game.level) { old, new in
            if new > old { effects.confetti(80, from: UnitPoint(x: 0.5, y: 0.35)) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                isPaused = true
                store.holdArcadeRun(ArcadeRun(game: .brickBreaker, score: game.score, detail: game.bricksBroken, extra: game.level))
            default:
                isPaused = true
            }
        }
        .onChange(of: isRunning) { _, _ in lastFrame = nil }
        .onChange(of: game.phase) { _, _ in lastFrame = nil }
        .onDisappear {
            if isPlaying { endGame() }
        }
        .gameScreen(blocksSwipeBack: true)
    }

    private var field: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isRunning || game.phase != .playing)) { timeline in
            BrickField(game: game)
                .onChange(of: timeline.date) { _, date in advance(to: date) }
        }
        .aspectRatio(BrickBreakerGame.width / BrickBreakerGame.height, contentMode: .fit)
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(.rect)
                    .gesture(paddleGesture(width: proxy.size.width))
            }
        }
        .overlay { EffectsLayer(effects: effects) }
        .overlay {
            if isPaused {
                Button("Resume", systemImage: "play.fill") { isPaused = false }
                    .buttonStyle(.glassProminent)
                    .font(.title3.bold())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Brick Breaker field")
        .accessibilityValue("\(game.bricks.count) bricks left, \(game.lives) lives")
    }

    private func paddleGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart != value.startLocation {
                    dragStart = value.startLocation
                    dragBeganServing = game.phase == .serving
                }
                guard isRunning, width > 0 else { return }
                game.movePaddle(to: Double(value.location.x / width) * BrickBreakerGame.width)
            }
            .onEnded { _ in
                defer { dragStart = nil }
                guard isRunning, dragBeganServing, game.phase == .serving else { return }
                game.launch()
            }
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: "Game Over", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest,
                                    best: store.game.stats.brickBreakerBestScore, reward: result.reward,
                                    details: ["\(CoinFormat.grouped(result.detail)) bricks broken", "Reached level \(game.level)"],
                                    challenge: result.challenge)
                }
            } else {
                GamePanel(title: "Brick Breaker", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.brickBreakerBestScore,
                              howTo: "Drag to move the paddle and lift your finger to launch. Clear every brick to reach a faster level with a new wall. You have three balls.")
                }
            }
        }
    }

    // MARK: Game flow

    private func advance(to date: Date) {
        guard isRunning else { return }
        let seconds = lastFrame.map { date.timeIntervalSince($0) } ?? 0
        lastFrame = date
        game.update(by: seconds)
        if game.phase == .over { endGame() }
    }

    private func start() {
        game = BrickBreakerGame()
        result = nil
        isPaused = false
        lastFrame = nil
        isPlaying = true
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        let payout = store.finishBrickBreaker(score: game.score, bricks: game.bricksBroken, level: game.level)
        result = GameResult(score: game.score, payout: payout, detail: game.bricksBroken)
    }
}

/// The bricks, the paddle and the coin ball.
private struct BrickField: View {
    let game: BrickBreakerGame
    static let rowColors: [Color] = [.red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple]

    var body: some View {
        Canvas { context, size in
            let scale = size.width / BrickBreakerGame.width
            func rect(_ box: Box) -> CGRect {
                CGRect(x: box.minX * scale, y: box.minY * scale, width: box.width * scale, height: box.height * scale)
            }
            for brick in game.bricks {
                let frame = rect(brick.frame)
                let color = Self.rowColors[brick.row % Self.rowColors.count]
                let shape = Path(roundedRect: frame, cornerRadius: frame.height * 0.3)
                context.fill(shape, with: .linearGradient(
                    Gradient(colors: [color.mix(with: .white, by: 0.25), color]),
                    startPoint: CGPoint(x: frame.midX, y: frame.minY), endPoint: CGPoint(x: frame.midX, y: frame.maxY)))
                if brick.maxHits > 1 {
                    // Tough bricks wear a silver rim until their first hit cracks it.
                    let rim = brick.hitsLeft > 1 ? Color.white.opacity(0.9) : Color.black.opacity(0.35)
                    context.stroke(Path(roundedRect: frame.insetBy(dx: 1, dy: 1), cornerRadius: frame.height * 0.3),
                                   with: .color(rim), lineWidth: 2)
                }
            }
            let paddle = rect(game.paddle)
            context.fill(Path(roundedRect: paddle, cornerRadius: paddle.height / 2),
                         with: .linearGradient(Gradient(colors: [Theme.gold, Theme.bitcoin]),
                                               startPoint: CGPoint(x: paddle.minX, y: paddle.minY),
                                               endPoint: CGPoint(x: paddle.minX, y: paddle.maxY)))
            if game.phase != .over {
                let radius = BrickBreakerGame.ballRadius * scale * 1.25
                let ball = CGRect(x: game.ball.x * scale - radius, y: game.ball.y * scale - radius,
                                  width: radius * 2, height: radius * 2)
                var glow = context
                glow.addFilter(.shadow(color: Theme.gold.opacity(0.8), radius: 6))
                glow.draw(context.resolve(Image("CoinSmall")), in: ball)
            }
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.12).opacity(0.9), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
    }
}
