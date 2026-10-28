import SwiftUI
import CryptoClickerKit

/// Brick Breaker: drag anywhere on the field to move the paddle and lift your finger to launch.
/// Bonus bricks drop power-ups to catch, explosive bricks break their neighbors, and every fifth
/// level is a boss. The physics runs on the display's frame clock while the ball is in play.
struct BrickBreakerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = BrickBreakerGame()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showingHelp = false
    @State private var result: GameResult?
    @State private var lastFrame: Date?
    /// Where the current drag began, and whether a ball was waiting to be served then. Only a
    /// drag that began on a waiting ball launches it, so a new ball never flies off by surprise.
    @State private var dragStart: CGPoint?
    @State private var dragBeganServing = false
    @State private var effects = Effects()

    private var isRunning: Bool { isPlaying && !isPaused }

    var body: some View {
        withLifecycle(withFeedback(layout))
    }

    private var layout: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Level", value: game.isBossLevel ? "\(game.level) · Boss" : "\(game.level)")
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
            BrickPowerUpStrip(game: game)
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
        .overlay {
            if isPaused {
                PausedCard(game: .brickBreaker, resume: { isPaused = false }, showHelp: { showingHelp = true })
            }
        }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle("Brick Breaker")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.brickBreaker, isPresented: $showingHelp) {
            if isPlaying { isPaused = true }
        }
    }

    /// Haptics and confetti for what the game just did.
    private func withFeedback(_ view: some View) -> some View {
        view
        .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: game.bricksBroken) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.5), trigger: game.paddleHits) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.explosions) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.7), trigger: game.bossHits) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.success, trigger: game.powerUpsCaught) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.error, trigger: game.lives) { (old: Int, new: Int) in haptics && new < old }
        .onChange(of: game.level) { old, new in
            if new > old { effects.confetti(80, from: UnitPoint(x: 0.5, y: 0.35)) }
        }
        .onChange(of: game.bossesDefeated) { old, new in
            if new > old { effects.confetti(140, from: UnitPoint(x: 0.5, y: 0.2)) }
        }
    }

    /// Pausing in the background (holding the run so it's paid if iOS closes the app), and ending
    /// the game when the screen goes away.
    private func withLifecycle(_ view: some View) -> some View {
        view
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
            BrickField(game: game, time: timeline.date.timeIntervalSinceReferenceDate, reduceMotion: reduceMotion)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Brick Breaker field")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var parts = ["\(game.bricks.count) bricks left", "\(game.lives) lives"]
        if let boss = game.boss { parts.append("boss \(boss.hitsLeft) of \(boss.maxHits)") }
        if !game.capsules.isEmpty { parts.append("a power-up falling") }
        return parts.joined(separator: ", ")
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
                                    details: ["\(CoinFormat.grouped(result.detail)) bricks · reached level \(game.level)",
                                              "\(game.powerUpsCaught) power-up\(game.powerUpsCaught == 1 ? "" : "s")"
                                                + (game.bossesDefeated > 0 ? " · \(game.bossesDefeated) boss\(game.bossesDefeated == 1 ? "" : "es") beaten" : "")
                                                + " · best streak \(game.bestLevelStreak)"],
                                    challenge: result.challenge)
                }
            } else {
                GamePanel(title: "Brick Breaker", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.brickBreakerBestScore,
                              howTo: "Drag to move the paddle and lift your finger to launch. Clear every brick to reach a faster level. Catch the power-ups bonus bricks drop, and watch for a boss every fifth level. You have three balls.",
                              showHelp: { showingHelp = true })
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
        for frame in game.lastExplosions {
            effects.confetti(reduceMotion ? 6 : 18, from: UnitPoint(x: frame.midX / BrickBreakerGame.width, y: frame.midY / BrickBreakerGame.height))
        }
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
        let payout = store.finishBrickBreaker(score: game.score, bricks: game.bricksBroken, level: game.level,
                                              bosses: game.bossesDefeated, powerUps: game.powerUpsCaught,
                                              bestStreak: game.bestLevelStreak)
        result = GameResult(score: game.score, payout: payout, detail: game.bricksBroken)
    }
}

extension BrickBreakerGame.PowerUp {
    var symbol: String {
        switch self {
        case .multiBall: "circle.grid.2x1.fill"
        case .widePaddle: "arrow.left.and.right"
        case .slowBall: "tortoise.fill"
        case .laser: "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .multiBall: .pink
        case .widePaddle: .green
        case .slowBall: .cyan
        case .laser: .red
        }
    }
}

/// The power-ups running, each with the time it has left, and the shrunk paddle's countdown.
private struct BrickPowerUpStrip: View {
    let game: BrickBreakerGame

    var body: some View {
        HStack(spacing: 8) {
            ForEach(BrickBreakerGame.PowerUp.allCases, id: \.self) { kind in
                if game.isActive(kind) {
                    HStack(spacing: 5) {
                        Image(systemName: kind.symbol)
                            .foregroundStyle(kind.color)
                        if let left = game.effects[kind], let duration = kind.duration {
                            ProgressView(value: left, total: duration)
                                .tint(kind.color)
                                .frame(width: 40)
                        } else {
                            Text("×\(game.balls.count)")
                                .font(.caption.weight(.bold).monospacedDigit())
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(kind.name)
                    .accessibilityValue(game.effects[kind].map { "\(Int($0.rounded(.up))) seconds left" } ?? "\(game.balls.count) balls")
                }
            }
            if game.shrunkFor > 0 {
                Label("\(Int(game.shrunkFor.rounded(.up)))s", systemImage: "arrow.right.and.line.vertical.and.arrow.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.loss)
                    .accessibilityLabel("Paddle shrunk for \(Int(game.shrunkFor.rounded(.up))) seconds")
            }
        }
        .frame(height: 30)
    }
}

/// The bricks, the boss, falling power-ups and debris, laser bolts, the paddle and the coin balls.
private struct BrickField: View {
    let game: BrickBreakerGame
    let time: TimeInterval
    let reduceMotion: Bool
    static let rowColors: [Color] = [.red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple]

    var body: some View {
        Canvas { context, size in
            let scale = size.width / BrickBreakerGame.width
            func rect(_ box: Box) -> CGRect {
                CGRect(x: box.minX * scale, y: box.minY * scale, width: box.width * scale, height: box.height * scale)
            }
            for brick in game.bricks { drawBrick(brick, frame: rect(brick.frame), in: &context) }
            if let boss = game.boss { drawBoss(boss, frame: rect(boss.frame), in: &context) }
            for capsule in game.capsules {
                let size = BrickBreakerGame.capsuleSize
                let frame = rect(Box(minX: capsule.position.x - size.width / 2, minY: capsule.position.y - size.height / 2,
                                     width: size.width, height: size.height))
                context.fill(Path(roundedRect: frame, cornerRadius: frame.height / 2), with: .color(capsule.kind.color))
                context.stroke(Path(roundedRect: frame, cornerRadius: frame.height / 2), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                var symbol = context.resolve(Image(systemName: capsule.kind.symbol))
                symbol.shading = .color(.white)
                context.draw(symbol, in: frame.insetBy(dx: frame.width * 0.3, dy: frame.height * 0.12))
            }
            for bolt in game.bolts {
                let start = CGPoint(x: bolt.position.x * scale, y: bolt.position.y * scale)
                var path = Path()
                path.move(to: start)
                path.addLine(to: CGPoint(x: start.x, y: start.y + 14))
                context.stroke(path, with: .color(.red), lineWidth: 3)
            }
            for piece in game.debris {
                let center = CGPoint(x: piece.position.x * scale, y: piece.position.y * scale)
                let radius = 0.02 * scale
                context.fill(Path(roundedRect: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
                                  cornerRadius: radius * 0.4), with: .color(Color(white: 0.55)))
            }
            drawPaddle(rect(game.paddle), in: &context)
            if game.phase != .over {
                let radius = BrickBreakerGame.ballRadius * scale * 1.25
                var glow = context
                glow.addFilter(.shadow(color: Theme.gold.opacity(0.8), radius: 6))
                let coin = context.resolve(Image("CoinSmall"))
                for ball in game.balls {
                    glow.draw(coin, in: CGRect(x: ball.position.x * scale - radius, y: ball.position.y * scale - radius,
                                               width: radius * 2, height: radius * 2))
                }
            }
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.12).opacity(0.9), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
    }

    private func drawBrick(_ brick: BrickBreakerGame.Brick, frame: CGRect, in context: inout GraphicsContext) {
        let shape = Path(roundedRect: frame, cornerRadius: frame.height * 0.3)
        switch brick.kind {
        case .normal, .armored:
            let color = Self.rowColors[brick.row % Self.rowColors.count]
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [color.mix(with: .white, by: 0.25), color]),
                startPoint: CGPoint(x: frame.midX, y: frame.minY), endPoint: CGPoint(x: frame.midX, y: frame.maxY)))
            if brick.kind == .armored {
                // Steel plating: one band per hit left.
                let rim = Color(white: 0.9)
                context.stroke(Path(roundedRect: frame.insetBy(dx: 1, dy: 1), cornerRadius: frame.height * 0.3),
                               with: .color(rim), lineWidth: 2.5)
                for band in 1..<max(1, brick.hitsLeft) {
                    let x = frame.minX + frame.width * CGFloat(band) / CGFloat(brick.hitsLeft)
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: frame.minY + 2))
                    line.addLine(to: CGPoint(x: x, y: frame.maxY - 2))
                    context.stroke(line, with: .color(rim.opacity(0.8)), lineWidth: 2)
                }
            }
        case .explosive:
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [Color(red: 1, green: 0.55, blue: 0.1), Color(red: 0.75, green: 0.1, blue: 0.05)]),
                startPoint: CGPoint(x: frame.midX, y: frame.minY), endPoint: CGPoint(x: frame.midX, y: frame.maxY)))
            var symbol = context.resolve(Image(systemName: "flame.fill"))
            symbol.shading = .color(.yellow)
            context.draw(symbol, in: frame.insetBy(dx: frame.width * 0.36, dy: frame.height * 0.12))
        case .bonus:
            let pulse = reduceMotion ? 0.8 : 0.65 + 0.35 * (sin(time * 5) + 1) / 2
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [Color(red: 0.6, green: 0.9, blue: 1).opacity(pulse), Color(red: 0.2, green: 0.4, blue: 0.95)]),
                startPoint: CGPoint(x: frame.midX, y: frame.minY), endPoint: CGPoint(x: frame.midX, y: frame.maxY)))
            var symbol = context.resolve(Image(systemName: "gift.fill"))
            symbol.shading = .color(.white)
            context.draw(symbol, in: frame.insetBy(dx: frame.width * 0.36, dy: frame.height * 0.12))
        }
    }

    private func drawBoss(_ boss: BrickBreakerGame.Boss, frame: CGRect, in context: inout GraphicsContext) {
        context.fill(Path(roundedRect: frame, cornerRadius: frame.height * 0.25), with: .linearGradient(
            Gradient(colors: [Color(red: 0.55, green: 0.15, blue: 0.6), Color(red: 0.25, green: 0.05, blue: 0.3)]),
            startPoint: CGPoint(x: frame.midX, y: frame.minY), endPoint: CGPoint(x: frame.midX, y: frame.maxY)))
        context.stroke(Path(roundedRect: frame, cornerRadius: frame.height * 0.25), with: .color(.white.opacity(0.7)), lineWidth: 2)
        // Eyes, so it reads as a foe.
        for side in [-1.0, 1.0] {
            let eye = CGRect(x: frame.midX + side * frame.width * 0.18 - 5, y: frame.minY + frame.height * 0.3, width: 10, height: 8)
            context.fill(Path(ellipseIn: eye), with: .color(.yellow))
        }
        // Health bar above it.
        let bar = CGRect(x: frame.minX, y: frame.minY - 9, width: frame.width, height: 5)
        context.fill(Path(roundedRect: bar, cornerRadius: 2.5), with: .color(.white.opacity(0.25)))
        let share = CGFloat(boss.hitsLeft) / CGFloat(max(1, boss.maxHits))
        context.fill(Path(roundedRect: CGRect(x: bar.minX, y: bar.minY, width: bar.width * share, height: bar.height), cornerRadius: 2.5),
                     with: .color(share > 0.3 ? .green : .red))
    }

    private func drawPaddle(_ paddle: CGRect, in context: inout GraphicsContext) {
        let colors: [Color] = game.shrunkFor > 0 ? [Color(white: 0.7), Color(white: 0.45)] : [Theme.gold, Theme.bitcoin]
        context.fill(Path(roundedRect: paddle, cornerRadius: paddle.height / 2),
                     with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: paddle.minX, y: paddle.minY),
                                           endPoint: CGPoint(x: paddle.minX, y: paddle.maxY)))
        if game.isActive(.laser) {
            // Two cannons where the bolts come from.
            for x in [paddle.midX - paddle.width * 0.4, paddle.midX + paddle.width * 0.4] {
                context.fill(Path(roundedRect: CGRect(x: x - 3, y: paddle.minY - 6, width: 6, height: 8), cornerRadius: 2),
                             with: .color(.red))
            }
        }
    }
}
