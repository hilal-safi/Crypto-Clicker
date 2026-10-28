import SwiftUI
import CryptoClickerKit

/// Snake: swipe anywhere in the play area to steer toward the coins; there are no buttons to
/// reach for. A long swipe that bends (up, then left) turns twice. Classic is played in a choice
/// of arenas until the snake crashes; Coin Rush is a minute with three coins out at once. Power-ups
/// appear every few coins. Points pay coins when the game ends, including when the player leaves.
struct SnakeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage("snakeArena") private var arena = SnakeGame.Arena.open
    @State private var mode = SnakeGame.Mode.classic
    @State private var game = SnakeGame.fresh()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showingHelp = false
    @State private var result: GameResult?
    /// The last power-up picked up, for the banner.
    @State private var pickedUp: SnakeGame.PowerUp?
    @State private var pickups = 0
    /// Where the current swipe is measured from; it moves after each recognised swipe.
    @State private var swipeOrigin: CGPoint?
    /// Where the current drag began; a new start means a new gesture, even if the last was cut short.
    @State private var swipeStart: CGPoint?

    private var isRunning: Bool { isPlaying && !isPaused }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                if game.mode == .coinRush {
                    GameStat(title: "Time", value: "\(Int(game.timeLeft.rounded(.up)))s")
                } else {
                    GameStat(title: "Length", value: "\(game.body.count)")
                }
                Spacer(minLength: 0)
                GameStat(title: "Best", value: CoinFormat.grouped(game.mode == .coinRush ? store.game.stats.snakeRushBestScore
                                                                                         : store.game.stats.snakeBestScore))
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying { isPaused.toggle() }
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            PowerUpStrip(game: game)
            SnakeBoard(game: game, reduceMotion: reduceMotion)
                .overlay(alignment: .top) { pickupBanner }
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
        .navigationTitle(game.mode == .coinRush && isPlaying ? "Coin Rush" : "Snake")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.snake, isPresented: $showingHelp) {
            if isPlaying { isPaused = true }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: game.eaten) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.success, trigger: pickups) { _, _ in haptics }
        .sensoryFeedback(.warning, trigger: game.graceTicks) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.error, trigger: result) { _, new in haptics && new != nil }
        .task(id: isRunning) { await run() }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                isPaused = true
                store.holdArcadeRun(ArcadeRun(game: .snake, score: game.score, detail: game.body.count,
                                              stage: game.mode == .coinRush ? ArcadeRun.coinRushStage : 0))
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
    private var pickupBanner: some View {
        if let pickedUp {
            Label(pickedUp.name, systemImage: pickedUp.symbol)
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular.tint(pickedUp.color.opacity(0.4)), in: .capsule)
                .padding(.top, 12)
                .id(pickups)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: game.mode == .coinRush && game.timeLeft == 0 ? "Time's Up" : "Game Over",
                          buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest,
                                    best: game.mode == .coinRush ? store.game.stats.snakeRushBestScore : store.game.stats.snakeBestScore,
                                    reward: result.reward,
                                    details: ["\(game.eaten) coins · \(game.body.count) long · \(CoinFormat.stopwatch(game.time))",
                                              "\(game.powerUpsCollected) power-up\(game.powerUpsCollected == 1 ? "" : "s")"
                                                + (game.mode == .classic ? " · \(game.arena.name)" : " · Coin Rush")],
                                    challenge: result.challenge)
                }
            } else {
                GamePanel(title: "Snake", buttonTitle: "Start", action: start) {
                    VStack(spacing: 12) {
                        Picker("Mode", selection: $mode) {
                            Text("Classic").tag(SnakeGame.Mode.classic)
                            Text("Coin Rush").tag(SnakeGame.Mode.coinRush)
                        }
                        .pickerStyle(.segmented)
                        if mode == .classic {
                            Picker("Arena", selection: $arena) {
                                ForEach(SnakeGame.Arena.allCases) { arena in
                                    Text(arena.name).tag(arena)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        GameIntro(best: mode == .classic ? store.game.stats.snakeBestScore : store.game.stats.snakeRushBestScore,
                                  howTo: mode == .classic
                                    ? "Swipe anywhere to steer. Every coin is worth 10 points and makes you longer, and you speed up as you eat. Every few coins a power-up appears."
                                    : "One minute, three coins out at once. Eat as many as you can before time runs out, and don't crash.",
                                  showHelp: { showingHelp = true })
                    }
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
        var rng = SystemRandomNumberGenerator()
        game = SnakeGame(mode: mode, arena: arena, using: &rng)
        result = nil
        pickedUp = nil
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
            let collected = game.powerUpsCollected
            let item = game.item?.kind
            game.step(using: &rng)
            if game.powerUpsCollected > collected, let item { showPickup(item) }
            if game.isOver {
                endGame()
                return
            }
        }
    }

    private func showPickup(_ kind: SnakeGame.PowerUp) {
        pickups += 1
        let shown = pickups
        withAnimation(.spring(duration: 0.3)) { pickedUp = kind }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if pickups == shown { withAnimation(.easeOut(duration: 0.3)) { pickedUp = nil } }
        }
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        let payout = store.finishSnake(score: game.score, length: game.body.count, coins: game.eaten, time: game.time,
                                       powerUps: game.powerUpsCollected, mode: game.mode)
        result = GameResult(score: game.score, payout: payout, detail: game.body.count)
    }
}

extension SnakeGame {
    static func fresh() -> SnakeGame {
        var rng = SystemRandomNumberGenerator()
        return SnakeGame(using: &rng)
    }
}

extension SnakeGame.PowerUp {
    var symbol: String {
        switch self {
        case .speedBoost: "hare.fill"
        case .slowMotion: "tortoise.fill"
        case .shield: "shield.fill"
        case .magnet: "dot.radiowaves.left.and.right"
        }
    }

    var color: Color {
        switch self {
        case .speedBoost: .orange
        case .slowMotion: .cyan
        case .shield: Color(red: 0.4, green: 0.6, blue: 1)
        case .magnet: .pink
        }
    }
}

/// The power-ups running, each with the time it has left.
private struct PowerUpStrip: View {
    let game: SnakeGame

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SnakeGame.PowerUp.allCases, id: \.self) { kind in
                if game.isActive(kind) {
                    HStack(spacing: 5) {
                        Image(systemName: kind.symbol)
                            .foregroundStyle(kind.color)
                        if let left = game.effects[kind], let duration = kind.duration {
                            ProgressView(value: left, total: duration)
                                .tint(kind.color)
                                .frame(width: 44)
                        } else {
                            Text("Ready")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(kind.name)
                    .accessibilityValue(game.effects[kind].map { "\(Int($0.rounded(.up))) seconds left" } ?? "Ready")
                }
            }
            if game.graceTicks > 0 {
                Label("Turn!", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.loss)
            }
        }
        .frame(height: 30)
        .animation(.snappy, value: SnakeGame.PowerUp.allCases.map(game.isActive))
    }
}

/// The board: a soft checkerboard, the walls, the coins, a power-up, and the snake from tail to head.
struct SnakeBoard: View {
    let game: SnakeGame
    var reduceMotion = false

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
            for wall in game.walls {
                context.fill(Path(roundedRect: frame(wall, inset: 1), cornerRadius: cell * 0.18),
                             with: .color(Color(red: 0.45, green: 0.38, blue: 0.3)))
            }
            for coin in game.coins {
                context.draw(context.resolve(Image("CoinSmall")), in: frame(coin, inset: cell * 0.08))
            }
            if let item = game.item {
                drawItem(item, in: &context, frame: frame(item.position), cell: cell)
            }
            if game.isActive(.magnet) {
                let reach = CGFloat(SnakeGame.magnetReach) + 0.5
                let center = CGPoint(x: frame(game.head).midX, y: frame(game.head).midY)
                let ring = CGRect(x: center.x - reach * cell, y: center.y - reach * cell, width: reach * cell * 2, height: reach * cell * 2)
                context.stroke(Path(ellipseIn: ring), with: .color(.pink.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
            let count = game.body.count
            let boosted = game.isActive(.speedBoost)
            for (index, segment) in game.body.enumerated().reversed() {
                // Bright at the head, deeper green toward the tail; orange while boosted.
                let shade = count > 1 ? Double(index) / Double(count - 1) : 0
                let color = boosted
                    ? Color(red: 1.0 - 0.3 * shade, green: 0.65 - 0.3 * shade, blue: 0.2)
                    : Color(red: 0.55 - 0.35 * shade, green: 0.95 - 0.35 * shade, blue: 0.30 - 0.15 * shade)
                let inset = index == 0 ? cell * 0.04 : cell * 0.1
                context.fill(Path(roundedRect: frame(segment, inset: inset), cornerRadius: cell * 0.32), with: .color(color))
            }
            if game.hasShield || game.graceTicks > 0 {
                let bubble = frame(game.head, inset: -cell * 0.18)
                context.stroke(Path(ellipseIn: bubble), with: .color(Color(red: 0.5, green: 0.7, blue: 1).opacity(game.hasShield ? 0.9 : 0.5)),
                               lineWidth: 2.5)
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

    /// A power-up: its symbol in a colored disc, with a ring that empties as its time runs out.
    private func drawItem(_ item: SnakeGame.Item, in context: inout GraphicsContext, frame: CGRect, cell: CGFloat) {
        let disc = frame.insetBy(dx: cell * 0.06, dy: cell * 0.06)
        context.fill(Path(ellipseIn: disc), with: .color(item.kind.color))
        let share = max(0, min(1, item.timeLeft / SnakeGame.powerUpLifetime))
        var ring = Path()
        ring.addArc(center: CGPoint(x: frame.midX, y: frame.midY), radius: cell * 0.5, startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * share), clockwise: false)
        context.stroke(ring, with: .color(.white), lineWidth: 2)
        var symbol = context.resolve(Image(systemName: item.kind.symbol))
        symbol.shading = .color(.white)
        context.draw(symbol, in: frame.insetBy(dx: cell * 0.24, dy: cell * 0.24))
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
