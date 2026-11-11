import SwiftUI
import CryptoClickerKit

/// The screens inside Hash Smash, opened from its start screen.
enum BrickBreakerRoute: Hashable {
    /// A game with these walls, from `startLevel` (a level reached before).
    case play(BrickBreakerGame.LevelStyle, startLevel: Int = 1)
}

/// Where Brick Breaker opens, like Token Swap: the classic levels, random walls and the speed
/// setting, each on a card. Levels start at any level reached so far, picked on its track;
/// random walls start at level 1.
struct BrickBreakerView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.brickBreakerSpeedKey) private var speed = GameSpeed.normal
    @AppStorage(Preferences.brickBreakerStartKey) private var pickedStart = 1

    /// The picked level, kept within those reached.
    private var startLevel: Int {
        min(max(pickedStart, 1), store.game.brickBreakerStartLevels.upperBound)
    }
    @State private var showingHelp = false

    var body: some View {
        let stats = store.game.stats
        let tint = MiniGame.brickBreaker.color
        let bosses = stats.brickBreakerBosses
        ScrollView {
            VStack(spacing: 14) {
                ModeCard(tint: tint, icon: "square.grid.3x2.fill", title: "Levels",
                         status: stats.brickBreakerGames == 0
                            ? "Start at level 1"
                            : "Best: level \(CoinFormat.grouped(stats.brickBreakerBestLevel)) · \(CoinFormat.grouped(bosses)) "
                                + "whale\(bosses == 1 ? "" : "s")" + " beaten",
                         detail: "The classic walls: cold storage, liquidation and airdrop blocks, and the whale every fifth level. Start at level 1 or any level you've reached.",
                         note: nil) {
                    VStack(spacing: 12) {
                        LevelTrack(best: stats.brickBreakerBestLevel, bossEvery: BrickBreakerGame.bossEvery, tint: tint,
                                   bossSymbol: "fish.fill", noun: "level",
                                   bossNote: "The whale every fifth level.",
                                   selection: Binding(get: { startLevel }, set: { pickedStart = $0 }))
                        StartPay.label(start: startLevel, noun: "level", slope: Tuning.brickBreakerStartPaySlope)
                        NavigationLink(value: BrickBreakerRoute.play(.classic, startLevel: startLevel)) {
                            Label("Play Level \(startLevel)", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                ModeCard(tint: tint, icon: "dice.fill", title: "Random Walls", status: "A new wall every level",
                         detail: "Walls made up for every level, never the same twice. They take about as many hits and pay about the same, and the whale still comes every fifth level.",
                         note: nil) {
                    NavigationLink(value: BrickBreakerRoute.play(.generated)) {
                        Label("Play Random Walls", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                ModeCard(tint: tint, icon: "slider.horizontal.3", title: "Settings", status: "\(speed.name) speed",
                         detail: "How fast the ball moves. A point is worth the same at every speed: Fast scores sooner, Slow is relaxed.",
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
        .navigationTitle(MiniGame.brickBreaker.name)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.brickBreaker, isPresented: $showingHelp)
        .gameBackdrop(.brickBreaker)
    }
}

/// Brick Breaker's game: drag anywhere on the field to move the paddle and lift your finger to
/// launch. Bonus bricks drop power-ups to catch, explosive bricks break their neighbors, and every
/// fifth level is a boss. The walls come from the start screen, and the ball's speed from its
/// setting. The physics runs on the display's frame clock while the ball is in play.
struct BrickBreakerPlayView: View {
    /// Classic walls or random ones.
    let levels: BrickBreakerGame.LevelStyle
    /// The level every game here starts at.
    let startLevel: Int
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.brickBreakerSpeedKey) private var speed = GameSpeed.normal
    @State private var game: BrickBreakerGame
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

    init(levels: BrickBreakerGame.LevelStyle, startLevel: Int = 1) {
        self.levels = levels
        self.startLevel = startLevel
        _game = State(initialValue: BrickBreakerGame(levels: levels, startLevel: startLevel))
    }

    var body: some View {
        withLifecycle(withFeedback(layout))
            .gameBackdrop(.brickBreaker)
    }

    private var layout: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Level", value: game.isBossLevel ? "\(game.level) · Whale" : "\(game.level)")
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
            Label(game.phase == .serving ? "Drag to move, lift your finger to launch" : "Drag anywhere to move the paddle",
                  systemImage: "hand.draw.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.subtext)
        }
        .padding(12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .overlay {
            if isPaused {
                PausedCard(game: .brickBreaker, resume: { isPaused = false }, showHelp: { showingHelp = true })
            }
        }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle(levels == .generated ? "Random Walls" : MiniGame.brickBreaker.name)
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
        .onChange(of: isRunning) { _, _ in lastFrame = nil }
        .onChange(of: game.phase) { _, _ in lastFrame = nil }
        .arcadeLifecycle(isPlaying: isPlaying, pause: { isPaused = true }, heldRun: { heldRun }) { endGame() }
    }

    /// The game so far, held while the app is in the background.

    private var heldRun: ArcadeRun {
        ArcadeRun(game: .brickBreaker, score: game.score, detail: game.bricksBroken, extra: game.level,
                  records: .init(powerUps: game.powerUpsCaught, bosses: game.bossesDefeated, bestStreak: game.bestLevelStreak,
                                 start: startLevel))
    }

    private var field: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isRunning || game.phase != .playing)) { timeline in
            BrickField(game: game, time: timeline.date.timeIntervalSinceReferenceDate, reduceMotion: reduceMotion,
                       paddle: store.game.equipped(.paddle))
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
        .accessibilityLabel("\(MiniGame.brickBreaker.name) field")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var parts = ["\(game.bricks.count) blocks left", "\(game.lives) lives"]
        if let boss = game.boss { parts.append("whale \(boss.hitsLeft) of \(boss.maxHits)") }
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
                                    details: ["\(CoinFormat.grouped(result.detail)) blocks · reached level \(game.level)",
                                              "\(game.powerUpsCaught) power-up\(game.powerUpsCaught == 1 ? "" : "s")"
                                                + (game.bossesDefeated > 0
                                                   ? " · \(game.bossesDefeated) " + "whale\(game.bossesDefeated == 1 ? "" : "s")" + " beaten"
                                                   : "")
                                                + " · best streak \(game.bestLevelStreak)"],
                                    challenge: result.challenge, xp: result.xp)
                }
            } else {
                GamePanel(title: "Level \(startLevel)", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.brickBreakerBestScore,
                              detail: "\(levels == .generated ? "Random walls" : "Classic walls") · \(speed.name) speed"
                                + StartPay.note(start: startLevel, noun: "level", slope: Tuning.brickBreakerStartPaySlope, separator: " · "))
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
        game = BrickBreakerGame(speed: speed, levels: levels, startLevel: startLevel)
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
                                              bestStreak: game.bestLevelStreak, startLevel: startLevel)
        result = GameResult(score: game.score, payout: payout, detail: game.bricksBroken, xp: store.lastArcadeAward)
    }
}

extension BrickBreakerGame.PowerUp {
    /// In Hash Smash: a Fork, Deep Liquidity, a Gas Limit and Hash Rate.
    var symbol: String {
        return switch self {
        case .multiBall: "arrow.triangle.branch"
        case .widePaddle: "drop.fill"
        case .slowBall: "gauge.with.dots.needle.33percent"
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
                                .font(.footnote.weight(.heavy).monospacedDigit())
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
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(Theme.loss)
                    .accessibilityLabel("Paddle shrunk for \(Int(game.shrunkFor.rounded(.up))) seconds")
            }
        }
        .frame(height: 30)
    }
}

/// The bricks, the boss, falling power-ups and debris, laser bolts, the paddle and the coin balls.
/// Hash Smash draws hash blocks with their hashes, liquidation blocks, the whale and its dumps.
private struct BrickField: View {
    let game: BrickBreakerGame
    let time: TimeInterval
    let reduceMotion: Bool
    /// The paddle picked in Style.
    var paddle = Cosmetic.paddleGold
    static let rowColors: [Color] = [.red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple]

    var body: some View {
        Canvas { context, size in
            let scale = size.width / BrickBreakerGame.width
            func rect(_ box: Box) -> CGRect {
                CGRect(x: box.minX * scale, y: box.minY * scale, width: box.width * scale, height: box.height * scale)
            }
            let hashes = Self.hashLabels(height: 0.045 * scale, context: context)
            for brick in game.bricks {
                drawBrick(brick, frame: rect(brick.frame), in: &context)
                if !hashes.isEmpty && (brick.kind == .normal || brick.kind == .armored) {
                    let frame = rect(brick.frame)
                    context.draw(hashes[brick.id % hashes.count], at: CGPoint(x: frame.midX, y: frame.midY))
                }
            }
            if let boss = game.boss {
                drawWhale(boss, frame: rect(boss.frame), in: &context)
            }
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
                // A dump: a red candle falling, wick and all.
                var wick = Path()
                wick.move(to: CGPoint(x: center.x, y: center.y - radius * 1.5))
                wick.addLine(to: CGPoint(x: center.x, y: center.y + radius * 1.5))
                context.stroke(wick, with: .color(Theme.loss), lineWidth: max(1, radius * 0.25))
                context.fill(Path(roundedRect: CGRect(x: center.x - radius * 0.7, y: center.y - radius, width: radius * 1.4, height: radius * 2),
                                  cornerRadius: radius * 0.2), with: .color(Theme.loss))
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
                Gradient(colors: [Color(red: 0.95, green: 0.25, blue: 0.3), Color(red: 0.45, green: 0.02, blue: 0.08)]),
                startPoint: CGPoint(x: frame.midX, y: frame.minY), endPoint: CGPoint(x: frame.midX, y: frame.maxY)))
            var symbol = context.resolve(Image(systemName: "chart.line.downtrend.xyaxis"))
            symbol.shading = .color(.white)
            context.draw(symbol, in: frame.insetBy(dx: frame.width * 0.34, dy: frame.height * 0.12))
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

    /// Short hashes for the blocks to wear, sized to fit one: "#3fa9" and the like.
    static func hashLabels(height: CGFloat, context: GraphicsContext) -> [GraphicsContext.ResolvedText] {
        ["#3fa9", "#0c7e", "#b41d", "#9e02", "#d7c5", "#61af", "#e8b3", "#27d0"].map { hash in
            context.resolve(Text(hash).font(.system(size: max(6, height * 0.5), weight: .heavy, design: .monospaced))
                .foregroundStyle(.black.opacity(0.4)))
        }
    }

    /// Hash Smash's boss: a whale swimming along the top, spouting, with its health bar.
    private func drawWhale(_ boss: BrickBreakerGame.Boss, frame: CGRect, in context: inout GraphicsContext) {
        let body = CGRect(x: frame.minX, y: frame.minY + frame.height * 0.12, width: frame.width * 0.84, height: frame.height * 0.82)
        let blue = Gradient(colors: [Color(red: 0.3, green: 0.55, blue: 0.95), Color(red: 0.08, green: 0.2, blue: 0.55)])
        // The tail, at the back (the right).
        var tail = Path()
        tail.move(to: CGPoint(x: body.maxX - body.width * 0.06, y: body.midY))
        tail.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + frame.height * 0.08))
        tail.addLine(to: CGPoint(x: frame.maxX - frame.width * 0.05, y: body.midY))
        tail.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - frame.height * 0.08))
        tail.closeSubpath()
        context.fill(tail, with: .linearGradient(blue, startPoint: CGPoint(x: frame.midX, y: frame.minY),
                                                 endPoint: CGPoint(x: frame.midX, y: frame.maxY)))
        context.fill(Path(ellipseIn: body), with: .linearGradient(blue, startPoint: CGPoint(x: body.midX, y: body.minY),
                                                                   endPoint: CGPoint(x: body.midX, y: body.maxY)))
        // A paler belly, and an eye toward the front.
        let belly = CGRect(x: body.minX + body.width * 0.12, y: body.midY + body.height * 0.08,
                           width: body.width * 0.62, height: body.height * 0.36)
        context.fill(Path(ellipseIn: belly), with: .color(Color(red: 0.75, green: 0.86, blue: 1).opacity(0.7)))
        let eye = CGPoint(x: body.minX + body.width * 0.2, y: body.minY + body.height * 0.34)
        context.fill(Path(ellipseIn: CGRect(x: eye.x - 4, y: eye.y - 4, width: 8, height: 8)), with: .color(.white))
        context.fill(Path(ellipseIn: CGRect(x: eye.x - 2, y: eye.y - 1.5, width: 4, height: 4)), with: .color(.black))
        // The spout, swaying.
        let sway = reduceMotion ? 0 : sin(time * 4) * 3
        let spoutX = body.minX + body.width * 0.35
        for offset in [-6.0, 0, 6] {
            var jet = Path()
            jet.move(to: CGPoint(x: spoutX, y: body.minY + 2))
            jet.addQuadCurve(to: CGPoint(x: spoutX + offset * 1.6 + sway, y: frame.minY - 6),
                             control: CGPoint(x: spoutX + offset * 0.4, y: frame.minY))
            context.stroke(jet, with: .color(.cyan.opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        drawHealth(boss, over: frame, in: &context)
    }

    private func drawHealth(_ boss: BrickBreakerGame.Boss, over frame: CGRect, in context: inout GraphicsContext) {
        let bar = CGRect(x: frame.minX, y: frame.minY - 9, width: frame.width, height: 5)
        context.fill(Path(roundedRect: bar, cornerRadius: 2.5), with: .color(.white.opacity(0.25)))
        let share = CGFloat(boss.hitsLeft) / CGFloat(max(1, boss.maxHits))
        context.fill(Path(roundedRect: CGRect(x: bar.minX, y: bar.minY, width: bar.width * share, height: bar.height), cornerRadius: 2.5),
                     with: .color(share > 0.3 ? .green : .red))
    }

    private func drawPaddle(_ frame: CGRect, in context: inout GraphicsContext) {
        paddle.drawPaddle(frame, isShrunk: game.shrunkFor > 0, in: &context)
        if game.isActive(.laser) {
            // Two cannons where the bolts come from.
            for x in [frame.midX - frame.width * 0.4, frame.midX + frame.width * 0.4] {
                context.fill(Path(roundedRect: CGRect(x: x - 3, y: frame.minY - 6, width: 6, height: 8), cornerRadius: 2),
                             with: .color(.red))
            }
        }
    }
}
