import SwiftUI
import CryptoClickerKit

/// The screens inside Hash Chain, opened from its start screen.
enum SnakeRoute: Hashable {
    /// A game in this mode: Classic in the arena picked on the start screen, or Coin Rush.
    case play(SnakeGame.Mode)
}

/// Where Hash Chain opens, like Hash Smash and Scam Invaders: Classic with its four arenas, Coin
/// Rush, and the speed setting, each on a card.
struct SnakeView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.snakeArenaKey) private var arena = SnakeGame.Arena.open
    @AppStorage(Preferences.snakeSpeedKey) private var speed = GameSpeed.normal
    @State private var showingHelp = false

    var body: some View {
        let stats = store.game.stats
        let tint = MiniGame.snake.color
        ScrollView {
            VStack(spacing: 14) {
                ModeCard(tint: tint, icon: "link",
                         title: "Classic",
                         status: stats.snakeGames == 0
                            ? "Pick an arena and play"
                            : "Best \(CoinFormat.grouped(stats.snakeBestScore)) · longest \(CoinFormat.grouped(stats.snakeLongest))",
                         detail: "Grow the chain until it crashes: every coin adds a block, and the chain speeds up as it grows. Every arena but Open adds walls to steer around.",
                         note: nil) {
                    VStack(spacing: 12) {
                        ArenaPicker(selection: $arena, tint: tint)
                        NavigationLink(value: SnakeRoute.play(.classic)) {
                            Label(arena == .open ? "Play Classic" : "Play \(arena.name)", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                ModeCard(tint: tint, icon: "timer", title: "Coin Rush",
                         status: stats.snakeRushes == 0
                            ? "One minute, three coins out"
                            : "Best \(CoinFormat.grouped(stats.snakeRushBestScore)) · \(CoinFormat.grouped(stats.snakeRushes)) played",
                         detail: "One minute in the open arena with three coins out at once: grab as many as you can before the clock runs out. It pays about what Classic does.",
                         note: nil) {
                    NavigationLink(value: SnakeRoute.play(.coinRush)) {
                        Label("Play Coin Rush", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                ModeCard(tint: tint, icon: "slider.horizontal.3", title: "Settings", status: "\(speed.name) speed",
                         detail: "How fast the chain moves. A coin is worth the same at every speed: Fast scores sooner, Slow is relaxed.",
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
        .navigationTitle(MiniGame.snake.name)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.snake, isPresented: $showingHelp)
        .gameBackdrop(.snake)
    }
}

/// The four arenas as small pictures of their walls, two by two: tap one to play it.
private struct ArenaPicker: View {
    @Binding var selection: SnakeGame.Arena
    let tint: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(SnakeGame.Arena.allCases) { arena in
                let isSelected = arena == selection
                Button {
                    selection = arena
                } label: {
                    HStack(spacing: 10) {
                        ArenaPreview(arena: arena)
                            .frame(width: 36, height: 48)
                        Text(arena.name)
                            .font(.subheadline.weight(.bold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(isSelected ? tint.opacity(0.22) : Color.primary.opacity(0.05), in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? tint : .clear, lineWidth: 2)
                    }
                    .contentShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(arena.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// An arena's walls in miniature.
private struct ArenaPreview: View {
    let arena: SnakeGame.Arena

    var body: some View {
        Canvas { context, size in
            let cell = min(size.width / CGFloat(SnakeGame.width), size.height / CGFloat(SnakeGame.height))
            for wall in arena.walls {
                let frame = CGRect(x: CGFloat(wall.x) * cell, y: CGFloat(wall.y) * cell, width: cell, height: cell)
                context.fill(Path(frame), with: .color(SnakeBoard.wallColor))
            }
        }
        .padding(2)
        .background(SnakeBoard.boardColor, in: .rect(cornerRadius: 5))
        .accessibilityHidden(true)
    }
}

/// Snake's game: swipe anywhere in the play area to steer toward the coins; there are no buttons to
/// reach for. A long swipe that bends (up, then left) turns twice. Classic is played in the arena
/// picked on the start screen until the snake crashes; Coin Rush is a minute with three coins out
/// at once. Power-ups appear every few coins. Points pay coins when the game ends, including when
/// the player leaves.
struct SnakePlayView: View {
    let mode: SnakeGame.Mode
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.snakeArenaKey) private var arena = SnakeGame.Arena.open
    @AppStorage(Preferences.snakeSpeedKey) private var speed = GameSpeed.normal
    @State private var game: SnakeGame
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

    init(mode: SnakeGame.Mode) {
        self.mode = mode
        var rng = SystemRandomNumberGenerator()
        let arena = SnakeGame.Arena(rawValue: UserDefaults.standard.string(forKey: Preferences.snakeArenaKey) ?? "") ?? .open
        _game = State(initialValue: SnakeGame(mode: mode, arena: arena, using: &rng))
    }

    var body: some View {
        withLifecycle(withFeedback(layout))
            .gameBackdrop(.snake)
    }

    private var layout: some View {
        return VStack(spacing: 10) {
            HStack(spacing: 16) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                if game.mode == .coinRush {
                    GameStat(title: "Time", value: "\(Int(game.timeLeft.rounded(.up)))s")
                } else {
                    GameStat(title: "Blocks", value: "\(game.body.count)")
                }
                Spacer(minLength: 0)
                GameStat(title: "Best", value: CoinFormat.grouped(best))
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying { isPaused.toggle() }
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            PowerUpStrip(game: game)
            SnakeBoard(game: game, reduceMotion: reduceMotion, skin: store.game.equipped(.snake),
                       board: store.game.equipped(.snakeBoard))
                .overlay(alignment: .top) { pickupBanner }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(MiniGame.snake.name) board")
                .accessibilityValue("Score \(game.score), blocks \(game.body.count)")
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
        .overlay {
            if isPaused {
                PausedCard(game: .snake, resume: { isPaused = false }, showHelp: { showingHelp = true })
            }
        }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.snake, isPresented: $showingHelp) {
            if isPlaying { isPaused = true }
        }
    }

    private func withFeedback(_ view: some View) -> some View {
        view
            .sensoryFeedback(.impact(weight: .light), trigger: game.eaten) { (old: Int, new: Int) in haptics && new > old }
            .sensoryFeedback(.success, trigger: pickups) { _, _ in haptics }
            .sensoryFeedback(.warning, trigger: game.graceTicks) { (old: Int, new: Int) in haptics && new > old }
            .sensoryFeedback(.error, trigger: result) { _, new in haptics && new != nil }
    }

    /// The clock while the game runs, pausing in the background, and paying out on the way out.
    private func withLifecycle(_ view: some View) -> some View {
        view
            .task(id: isRunning) { await run() }
            .arcadeLifecycle(isPlaying: isPlaying, pause: { isPaused = true }, heldRun: { heldRun }) { endGame() }
    }

    private var title: String {
        mode == .coinRush ? "Coin Rush" : arena == .open ? MiniGame.snake.name : arena.name
    }

    private var best: Int {
        mode == .coinRush ? store.game.stats.snakeRushBestScore : store.game.stats.snakeBestScore
    }

    /// The game so far, held while the app is in the background.
    private var heldRun: ArcadeRun {
        ArcadeRun(game: .snake, score: game.score, detail: game.body.count,
                  stage: game.mode == .coinRush ? ArcadeRun.coinRushStage : 0,
                  records: .init(coins: game.eaten, seconds: game.time, powerUps: game.powerUpsCollected))
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
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest, best: best, reward: result.reward,
                                    details: ["\(game.eaten) coins · \(game.body.count) blocks · \(CoinFormat.stopwatch(game.time))",
                                              "\(game.powerUpsCollected) power-up\(game.powerUpsCollected == 1 ? "" : "s")"
                                                + (game.mode == .classic ? " · \(game.arena.name)" : " · Coin Rush")],
                                    challenge: result.challenge, xp: result.xp)
                }
            } else {
                GamePanel(title: mode == .coinRush ? "Coin Rush" : arena.name, buttonTitle: "Start", action: start) {
                    GameIntro(best: best,
                              detail: (mode == .coinRush ? "One minute, three coins out at once" : "Classic") + " · \(speed.name) speed")
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
        game = SnakeGame(mode: mode, arena: arena, speed: speed, using: &rng)
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
        result = GameResult(score: game.score, payout: payout, detail: game.body.count, xp: store.lastArcadeAward)
    }
}

extension SnakeGame.PowerUp {
    /// In Hash Chain: Lightning, Cold Storage, a Hardware Wallet and the Airdrop Magnet.
    var symbol: String {
        return switch self {
        case .speedBoost: "bolt.fill"
        case .slowMotion: "snowflake"
        case .shield: "lock.shield.fill"
        case .magnet: "dot.radiowaves.left.and.right"
        }
    }

    var color: Color {
        return switch self {
        case .speedBoost: Color(red: 0.98, green: 0.72, blue: 0.0)
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
                                .font(.footnote.weight(.heavy))
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
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(Theme.loss)
            }
        }
        .frame(height: 30)
        .animation(.snappy, value: SnakeGame.PowerUp.allCases.map(game.isActive))
    }
}

/// The board, tail to head: a ledger grid, server walls, and a chain of blocks linked one to the
/// next, a hash mark on the head block.
struct SnakeBoard: View {
    let game: SnakeGame
    var reduceMotion = false
    /// The skin picked in Style.
    var skin: Cosmetic = .snakeGreen
    /// The board picked in Style.
    var board: Cosmetic = .snakeBoardLedger

    static let boardColor = Cosmetic.snakeBoardLedger.snakeBoardColors.fill
    static let wallColor = Color(red: 0.32, green: 0.36, blue: 0.44)

    var body: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(SnakeGame.width)
            func frame(_ point: GridPoint, inset: CGFloat = 0) -> CGRect {
                CGRect(x: CGFloat(point.x) * cell, y: CGFloat(point.y) * cell, width: cell, height: cell)
                    .insetBy(dx: inset, dy: inset)
            }
            drawLedger(in: &context, size: size, cell: cell)
            for wall in game.walls {
                drawServer(in: &context, frame: frame(wall, inset: 1), cell: cell, lit: (wall.x + wall.y) % 3 == 0)
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
            drawChain(in: &context, cell: cell, frame: { frame($0) })
            if game.hasShield || game.graceTicks > 0 {
                let bubble = frame(game.head, inset: -cell * 0.18)
                context.stroke(Path(ellipseIn: bubble), with: .color(Color(red: 0.5, green: 0.7, blue: 1).opacity(game.hasShield ? 0.9 : 0.5)),
                               lineWidth: 2.5)
            }
        }
        .aspectRatio(CGFloat(SnakeGame.width) / CGFloat(SnakeGame.height), contentMode: .fit)
        .padding(4)
        .background(board.snakeBoardColors.fill, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(board.snakeBoardColors.rim, lineWidth: 1)
        }
    }

    /// The segment's color: bright at the head, deeper toward the tail, in the skin's colors, and
    /// gold or orange while sped up.
    private func color(at index: Int, count: Int) -> Color {
        let shade = count > 1 ? Double(index) / Double(count - 1) : 0
        guard game.isActive(.speedBoost) else { return skin.snakeColor(shade: shade, index: index) }
        return Color(red: 1.0 - 0.2 * shade, green: 0.82 - 0.3 * shade, blue: 0.15)
    }

    /// Hash Chain: square blocks, each tied to the next by a short link, the head marked with a hash.
    private func drawChain(in context: inout GraphicsContext, cell: CGFloat, frame: (GridPoint) -> CGRect) {
        let count = game.body.count
        let body = game.body
        for index in body.indices.dropLast().reversed() {
            let a = frame(body[index]), b = frame(body[index + 1])
            var link = Path()
            link.move(to: CGPoint(x: a.midX, y: a.midY))
            link.addLine(to: CGPoint(x: b.midX, y: b.midY))
            context.stroke(link, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: max(1.5, cell * 0.16), lineCap: .round))
        }
        for (index, segment) in body.enumerated().reversed() {
            let block = frame(segment).insetBy(dx: cell * (index == 0 ? 0.06 : 0.15), dy: cell * (index == 0 ? 0.06 : 0.15))
            let shape = Path(roundedRect: block, cornerRadius: cell * 0.12)
            context.fill(shape, with: .color(color(at: index, count: count)))
            context.stroke(shape, with: .color(.black.opacity(0.35)), lineWidth: max(1, cell * 0.06))
            // A lighter top edge, so each block reads as a block.
            var shine = Path()
            shine.move(to: CGPoint(x: block.minX + cell * 0.12, y: block.minY + cell * 0.1))
            shine.addLine(to: CGPoint(x: block.maxX - cell * 0.12, y: block.minY + cell * 0.1))
            context.stroke(shine, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: max(1, cell * 0.07), lineCap: .round))
        }
        let head = frame(game.head)
        context.draw(Text("#").font(.system(size: cell * 0.62, weight: .black, design: .monospaced)).foregroundStyle(.black.opacity(0.65)),
                     at: CGPoint(x: head.midX, y: head.midY))
    }

    /// Faint ledger lines across the board.
    private func drawLedger(in context: inout GraphicsContext, size: CGSize, cell: CGFloat) {
        var grid = Path()
        for x in 1..<SnakeGame.width {
            grid.move(to: CGPoint(x: CGFloat(x) * cell, y: 0))
            grid.addLine(to: CGPoint(x: CGFloat(x) * cell, y: size.height))
        }
        for y in 1..<SnakeGame.height {
            grid.move(to: CGPoint(x: 0, y: CGFloat(y) * cell))
            grid.addLine(to: CGPoint(x: size.width, y: CGFloat(y) * cell))
        }
        context.stroke(grid, with: .color(board.snakeBoardColors.grid), lineWidth: 0.5)
    }

    /// A wall cell as a server: a dark unit with a vent line and a status light.
    private func drawServer(in context: inout GraphicsContext, frame: CGRect, cell: CGFloat, lit: Bool) {
        let unit = Path(roundedRect: frame, cornerRadius: cell * 0.1)
        context.fill(unit, with: .color(Self.wallColor))
        context.stroke(unit, with: .color(.black.opacity(0.4)), lineWidth: 1)
        var vent = Path()
        vent.move(to: CGPoint(x: frame.minX + cell * 0.15, y: frame.midY))
        vent.addLine(to: CGPoint(x: frame.maxX - cell * 0.4, y: frame.midY))
        context.stroke(vent, with: .color(.black.opacity(0.45)), lineWidth: max(1, cell * 0.08))
        let light = CGRect(x: frame.maxX - cell * 0.3, y: frame.midY - cell * 0.08, width: cell * 0.16, height: cell * 0.16)
        context.fill(Path(ellipseIn: light), with: .color(lit ? .green : .cyan.opacity(0.7)))
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
}
