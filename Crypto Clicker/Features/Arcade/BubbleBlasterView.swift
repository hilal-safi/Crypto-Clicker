import SwiftUI
import CryptoClickerKit

/// Bubble Blaster: drag on the field to aim (a guide shows the bounce and a ring marks where the
/// bubble will stick), lift to fire. Tap the loaded bubble to swap it with the next one.
struct BubbleBlasterView: View {
    typealias Special = BubbleShooterGame.Special

    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = BubbleShooterGame.fresh()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showingHelp = false
    @State private var result: BubbleResult?
    @State private var aim: Double?
    /// Where the current touch began; a new start means a new gesture, even if the last was cut short.
    @State private var aimStart: CGPoint?
    @State private var lastFrame: Date?
    @State private var shots = 0
    @State private var effects = Effects()
    /// A banner for a special earned or a new wave.
    @State private var banner: Banner?
    /// The shock wave of the last Bomb.
    @State private var blast: Blast?

    private var isRunning: Bool { isPlaying && !isPaused }

    struct Banner: Equatable {
        let id: Int
        let text: String
    }

    struct Blast: Equatable {
        let id: Int
        let position: Vector2
    }

    struct BubbleResult: Equatable {
        let game: GameResult
        let wave: Int
        let bestStreak: Int
        let bonuses: Int
    }

    var body: some View {
        withLifecycle(withFeedback(layout))
    }

    private var layout: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Wave", value: "\(game.wave)")
                GameStat(title: "New row in", value: "\(game.missesBeforeRow - game.misses)")
                Spacer(minLength: 0)
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying { isPaused.toggle() }
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            StreakLine(game: game)
            field
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) { bannerView }
            ControlHint(game: .bubbleBlaster)
        }
        .padding(12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background { AppBackground(tint: .blue) }
        .overlay {
            if isPaused {
                PausedCard(game: .bubbleBlaster, resume: { isPaused = false }, showHelp: { showingHelp = true })
            }
        }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle("Bubble Blaster")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.bubbleBlaster, isPresented: $showingHelp) {
            if isPlaying { isPaused = true }
        }
    }

    /// Haptics, pops, banners and confetti for what the game just did.
    private func withFeedback(_ view: some View) -> some View {
        view
            .sensoryFeedback(.impact(weight: .light), trigger: shots) { _, _ in haptics }
            .sensoryFeedback(.success, trigger: game.clears) { (old: Int, new: Int) in haptics && new > old }
            .sensoryFeedback(.impact(weight: .heavy), trigger: blast) { _, new in haptics && new != nil }
            .onChange(of: game.clears) { _, _ in showPops() }
            .onChange(of: game.specialsEarned) { old, new in
                if new > old, let special = game.lastEarned { show("\(special.name) earned!") }
            }
            .onChange(of: game.wave) { old, new in
                if new > old {
                    effects.confetti(90, from: UnitPoint(x: 0.5, y: 0.3))
                    show("Wave \(new)!")
                }
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
                    store.holdArcadeRun(ArcadeRun(game: .bubbleBlaster, score: game.score, detail: game.popped,
                                                  extra: game.bestClear, stage: game.wave))
                default:
                    isPaused = true
                }
            }
            .onChange(of: isRunning) { _, _ in lastFrame = nil }
            .onDisappear {
                if isPlaying { endGame() }
            }
            .gameScreen(blocksSwipeBack: true)
    }

    private var field: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isRunning || game.shot == nil)) { timeline in
            BubbleField(game: game, guide: game.shot == nil ? aim.map(aimGuide) : nil)
                .onChange(of: timeline.date) { _, date in advance(to: date) }
        }
        .aspectRatio(BubbleShooterGame.width / BubbleShooterGame.height, contentMode: .fit)
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(.rect)
                    .gesture(aimGesture(width: proxy.size.width))
            }
        }
        .overlay {
            GeometryReader { proxy in
                if let blast {
                    let scale = proxy.size.width / BubbleShooterGame.width
                    BlastRing(diameter: (BubbleShooterGame.bombRadius * 2 + 1) * scale, reduceMotion: reduceMotion)
                        .position(x: blast.position.x * scale, y: blast.position.y * scale)
                        .id(blast.id)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay { EffectsLayer(effects: effects) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bubble field")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var parts = ["Score \(game.score)", "wave \(game.wave)"]
        if let special = game.currentSpecial { parts.append("\(special.name) loaded") }
        if let special = game.nextSpecial { parts.append("\(special.name) next") }
        return parts.joined(separator: ", ")
    }

    /// The aiming guide for `angle`: the path up to the third bounce, and where the bubble will stick.
    private func aimGuide(_ angle: Double) -> BubbleField.Guide {
        let path = game.trajectory(angle: angle, maxBounces: 60)
        return BubbleField.Guide(path: Array(path.prefix(4)), landing: path.last.flatMap { game.landingSpot(for: $0) })
    }

    /// Drag to aim (the guide follows your finger) and lift to fire. A tap on the loaded or the
    /// next bubble swaps them; any other tap does nothing, so a stray touch never wastes a shot.
    private func aimGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if aimStart != value.startLocation {
                    aimStart = value.startLocation
                    aim = nil
                }
                guard isRunning, game.shot == nil, width > 0,
                      hypot(value.translation.width, value.translation.height) > 10 else { return }
                let scale = width / BubbleShooterGame.width
                let point = Vector2(x: value.location.x / scale, y: value.location.y / scale)
                let launcher = BubbleShooterGame.launcher
                aim = BubbleShooterGame.clampAngle(atan2(launcher.y - point.y, point.x - launcher.x))
            }
            .onEnded { value in
                defer {
                    aim = nil
                    aimStart = nil
                }
                guard isRunning, game.shot == nil, width > 0 else { return }
                let moved = hypot(value.translation.width, value.translation.height) > 10
                if moved, let aim {
                    var rng = SystemRandomNumberGenerator()
                    game.fire(angle: aim, using: &rng)
                    shots += 1
                } else if !moved {
                    let scale = width / BubbleShooterGame.width
                    let tap = Vector2(x: value.location.x / scale, y: value.location.y / scale)
                    if tap.distance(to: BubbleShooterGame.launcher) < 1.3 || tap.distance(to: BubbleField.nextPosition) < 1.0 {
                        game.swapBubbles()
                    }
                }
            }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner {
            Text(banner.text)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.gold.gradient)
                .shadow(color: .black.opacity(0.7), radius: 3)
                .padding(.top, 24)
                .id(banner.id)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: "Game Over", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.game.score, isNewBest: result.game.isNewBest,
                                    best: store.game.stats.bubbleBestScore, reward: result.game.reward,
                                    details: summary(result), challenge: result.game.challenge)
                }
            } else {
                GamePanel(title: "Bubble Blaster", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.bubbleBestScore,
                              howTo: "Match three or more of a color to pop them; anything left hanging falls for double points. Pops in a row build a streak that scores more and earns Rainbow and Bomb bubbles. Clear the field for the next wave, and don't let the bubbles reach the line.",
                              showHelp: { showingHelp = true })
                }
            }
        }
    }

    private func summary(_ result: BubbleResult) -> [String] {
        var lines = ["\(CoinFormat.grouped(result.game.detail)) bubbles popped · wave \(result.wave)"]
        if result.bestStreak > 1 { lines.append("Best streak: \(result.bestStreak) pops in a row") }
        if result.bonuses > 0 { lines.append("\(result.bonuses) gold \(result.bonuses == 1 ? "bubble" : "bubbles")") }
        return lines
    }

    // MARK: Game flow

    private func advance(to date: Date) {
        guard isRunning else { return }
        let seconds = lastFrame.map { date.timeIntervalSince($0) } ?? 0
        lastFrame = date
        var rng = SystemRandomNumberGenerator()
        game.update(by: seconds, using: &rng)
        if game.shot == nil { lastFrame = nil }
        if game.isOver { endGame() }
    }

    private func showPops() {
        for bubble in game.lastCleared {
            let point = UnitPoint(x: bubble.position.x / BubbleShooterGame.width, y: bubble.position.y / BubbleShooterGame.height)
            effects.pop(Theme.bubble(bubble.color), at: point)
            if bubble.isBonus { effects.coinFountain(6, from: point) }
        }
        if let bomb = game.lastBomb { blast = Blast(id: game.clears, position: bomb) }
    }

    private func show(_ text: String) {
        let id = (banner?.id ?? 0) + 1
        withAnimation(.spring(duration: 0.3)) { banner = Banner(id: id, text: text) }
        Task {
            try? await Task.sleep(for: .milliseconds(1_100))
            if banner?.id == id { withAnimation(.easeOut(duration: 0.3)) { banner = nil } }
        }
    }

    private func start() {
        game = .fresh()
        result = nil
        isPaused = false
        aim = nil
        aimStart = nil
        lastFrame = nil
        banner = nil
        blast = nil
        isPlaying = true
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        aim = nil
        let payout = store.finishBubbleBlaster(score: game.score, popped: game.popped, bestShot: game.bestClear,
                                               wave: game.wave, bestStreak: game.bestStreak, bonuses: game.bonusesCollected)
        result = BubbleResult(game: GameResult(score: game.score, payout: payout, detail: game.popped),
                              wave: game.wave, bestStreak: game.bestStreak, bonuses: game.bonusesCollected)
    }
}

extension BubbleShooterGame {
    static func fresh() -> BubbleShooterGame {
        var rng = SystemRandomNumberGenerator()
        return BubbleShooterGame(using: &rng)
    }
}

/// The streak, what the next pop is worth, and the special it's working toward.
private struct StreakLine: View {
    let game: BubbleShooterGame

    var body: some View {
        HStack(spacing: 10) {
            Label {
                if game.streak > 0 {
                    Text("Streak \(game.streak) · next ×\(multiplier)")
                } else {
                    Text("Pop in a row for a streak")
                }
            } icon: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(game.streak > 0 ? .orange : .secondary)
            }
            .contentTransition(.numericText())
            Spacer(minLength: 4)
            HStack(spacing: 5) {
                BubbleSpecialBadge(special: game.nextSpecialEarned)
                    .frame(width: 18, height: 18)
                Text("\(game.nextSpecialEarned.name) in \(game.shotsToSpecial)")
                    .contentTransition(.numericText())
            }
        }
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 6)
        .animation(.snappy, value: game.streak)
        .accessibilityElement(children: .combine)
    }

    /// The next pop's multiplier, as "1.3".
    private var multiplier: String {
        let tenths = game.nextMultiplierTenths
        return tenths % 10 == 0 ? "\(tenths / 10)" : "\(tenths / 10).\(tenths % 10)"
    }
}

/// A Bomb's shock wave: a ring that grows to the blast's reach and fades.
private struct BlastRing: View {
    let diameter: CGFloat
    let reduceMotion: Bool
    @State private var isOpen = false

    var body: some View {
        Circle()
            .strokeBorder(Color.orange, lineWidth: 6)
            .background(Circle().fill(Color.yellow.opacity(0.25)))
            .frame(width: diameter, height: diameter)
            .scaleEffect(isOpen || reduceMotion ? 1 : 0.2)
            .opacity(isOpen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.55)) { isOpen = true }
            }
    }
}

/// A Rainbow, Bomb or gold bubble, for the streak line and the help sheet.
struct BubbleSpecialBadge: View {
    enum Look {
        case rainbow, bomb, gold
    }

    let look: Look

    init(special: BubbleShooterGame.Special) {
        look = special == .rainbow ? .rainbow : .bomb
    }

    init(look: Look) {
        self.look = look
    }

    /// The help sheet's pictures, by guide item id.
    init?(guideID: String) {
        switch guideID {
        case "bubble.rainbow": look = .rainbow
        case "bubble.bomb": look = .bomb
        case "bubble.bonus": look = .gold
        default: return nil
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch look {
                case .rainbow:
                    Circle().fill(AngularGradient(colors: BubbleField.rainbowColors, center: .center))
                case .bomb:
                    Circle().fill(RadialGradient(colors: [Color(white: 0.45), Color(white: 0.08)],
                                                 center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: size * 0.7))
                    Image(systemName: "flame.fill")
                        .font(.system(size: size * 0.48, weight: .bold))
                        .foregroundStyle(.orange)
                case .gold:
                    Circle().fill(RadialGradient(colors: [Theme.bubble(4).mix(with: .white, by: 0.55), Theme.bubble(4)],
                                                 center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: size * 0.7))
                    Circle().strokeBorder(Theme.gold, lineWidth: max(1.5, size * 0.08))
                    Image(systemName: "bitcoinsign")
                        .font(.system(size: size * 0.42, weight: .heavy))
                        .foregroundStyle(.white)
                }
                // A highlight, so it reads as a bubble.
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.45), .clear], center: UnitPoint(x: 0.32, y: 0.3),
                                         startRadius: 0, endRadius: size * 0.35))
            }
            .frame(width: size, height: size)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// The bubbles, the danger line, the aiming guide and the launcher.
private struct BubbleField: View {
    typealias Special = BubbleShooterGame.Special

    /// The aiming guide: the path to show, and where the bubble will stick.
    struct Guide {
        let path: [Vector2]
        let landing: Vector2?
    }

    let game: BubbleShooterGame
    let guide: Guide?
    /// Where the next bubble waits, left of the launcher.
    static let nextPosition = Vector2(x: 1.1, y: BubbleShooterGame.launcher.y)
    static let rainbowColors: [Color] = (1...6).map { Theme.bubble($0) } + [Theme.bubble(1)]

    var body: some View {
        Canvas { context, size in
            let scale = size.width / BubbleShooterGame.width
            drawLine(in: &context, size: size, scale: scale)
            for row in 0...BubbleShooterGame.deadRow {
                for column in 0..<BubbleShooterGame.columns {
                    if let color = game.color(row: row, column: column) {
                        drawBubble(color, at: game.center(row: row, column: column), isBonus: game.isBonus(row: row, column: column),
                                   in: &context, scale: scale)
                    }
                }
            }
            if let guide { drawGuide(guide, in: &context, scale: scale) }
            if let shot = game.shot {
                drawBubble(shot.color, at: shot.position, special: shot.special, in: &context, scale: scale)
            } else if !game.isOver {
                drawBubble(game.current, at: BubbleShooterGame.launcher, special: game.currentSpecial, in: &context, scale: scale)
            }
            // The next bubble waits to the left of the launcher.
            drawBubble(game.next, at: Self.nextPosition, diameter: 0.7, special: game.nextSpecial, in: &context, scale: scale)
            context.draw(Text("NEXT").font(.system(size: max(8, scale * 0.28), weight: .bold)).foregroundStyle(.white.opacity(0.7)),
                         at: CGPoint(x: Self.nextPosition.x * scale, y: (Self.nextPosition.y - 0.62) * scale))
        }
        .background(Color(red: 0.05, green: 0.07, blue: 0.18).opacity(0.92), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
    }

    /// The line bubbles must not cross: just below the last safe row.
    private func drawLine(in context: inout GraphicsContext, size: CGSize, scale: Double) {
        let lastSafeRow = Double(BubbleShooterGame.deadRow - 1)
        let lineY = (0.5 + lastSafeRow * BubbleShooterGame.rowHeight + 0.52) * scale
        var line = Path()
        line.move(to: CGPoint(x: 0, y: lineY))
        line.addLine(to: CGPoint(x: size.width, y: lineY))
        context.stroke(line, with: .color(.red.opacity(0.55)), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
    }

    private func drawGuide(_ guide: Guide, in context: inout GraphicsContext, scale: Double) {
        if guide.path.count > 1 {
            var line = Path()
            line.move(to: point(guide.path[0], scale))
            for next in guide.path.dropFirst() { line.addLine(to: point(next, scale)) }
            context.stroke(line, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 9]))
        }
        if let landing = guide.landing {
            let middle = point(landing, scale)
            let radius = 0.46 * scale
            let ring = Path(ellipseIn: CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2))
            context.fill(ring, with: .color(.white.opacity(0.12)))
            context.stroke(ring, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
        }
    }

    private func point(_ vector: Vector2, _ scale: Double) -> CGPoint {
        CGPoint(x: vector.x * scale, y: vector.y * scale)
    }

    private func drawBubble(_ color: Int, at center: Vector2, diameter: Double = 0.96, special: Special? = nil,
                            isBonus: Bool = false, in context: inout GraphicsContext, scale: Double) {
        let radius = diameter / 2 * scale
        let middle = point(center, scale)
        let rect = CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2)
        let circle = Path(ellipseIn: rect)
        let highlight = CGPoint(x: middle.x - radius * 0.35, y: middle.y - radius * 0.35)
        switch special {
        case .rainbow:
            context.fill(circle, with: .conicGradient(Gradient(colors: Self.rainbowColors), center: middle))
            context.fill(circle, with: .radialGradient(Gradient(colors: [.white.opacity(0.55), .clear]),
                                                       center: highlight, startRadius: 0, endRadius: radius))
        case .bomb:
            context.fill(circle, with: .radialGradient(Gradient(colors: [Color(white: 0.5), Color(white: 0.12), .black]),
                                                       center: highlight, startRadius: 0, endRadius: radius * 1.5))
            drawSymbol("flame.fill", color: .orange, in: rect.insetBy(dx: radius * 0.45, dy: radius * 0.4), context: &context)
        case nil:
            let base = Theme.bubble(color)
            context.fill(circle, with: .radialGradient(
                Gradient(colors: [base.mix(with: .white, by: 0.55), base, base.mix(with: .black, by: 0.25)]),
                center: highlight, startRadius: 0, endRadius: radius * 1.5))
            if isBonus {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: 1.2, dy: 1.2)), with: .color(Theme.gold), lineWidth: max(2, radius * 0.16))
                drawSymbol("bitcoinsign", color: .white, in: rect.insetBy(dx: radius * 0.55, dy: radius * 0.5), context: &context)
            }
        }
    }

    private func drawSymbol(_ name: String, color: Color, in rect: CGRect, context: inout GraphicsContext) {
        var symbol = context.resolve(Image(systemName: name))
        symbol.shading = .color(color)
        // Keep the symbol's own shape: fit it in the middle of `rect`.
        let size = symbol.size
        guard size.width > 0, size.height > 0 else { return }
        let fit = min(rect.width / size.width, rect.height / size.height)
        let width = size.width * fit, height = size.height * fit
        context.draw(symbol, in: CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height))
    }
}
