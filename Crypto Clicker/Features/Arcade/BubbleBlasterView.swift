import SwiftUI
import CryptoClickerKit

/// Bubble Blaster: drag on the field to aim (a guide shows the bounce), lift to fire.
/// Tap the loaded bubble to swap it with the next one.
struct BubbleBlasterView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = BubbleShooterGame.fresh()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showingHelp = false
    @State private var result: GameResult?
    @State private var aim: Double?
    /// Where the current touch began; a new start means a new gesture, even if the last was cut short.
    @State private var aimStart: CGPoint?
    @State private var lastFrame: Date?
    @State private var shots = 0
    @State private var effects = Effects()

    private var isRunning: Bool { isPlaying && !isPaused }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Level", value: "\(game.level)")
                GameStat(title: "New row in", value: "\(BubbleShooterGame.missesPerRow - game.misses)")
                Spacer(minLength: 0)
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying { isPaused.toggle() }
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            field
                .frame(maxHeight: .infinity)
            Text("Drag to aim, lift to fire. Tap a waiting bubble to swap.")
                .font(.footnote)
                .foregroundStyle(.subtext)
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
        .sensoryFeedback(.impact(weight: .light), trigger: shots) { _, _ in haptics }
        .sensoryFeedback(.success, trigger: game.clears) { (old: Int, new: Int) in haptics && new > old }
        .onChange(of: game.clears) { _, _ in showPops() }
        .onChange(of: game.level) { old, new in
            if new > old { effects.confetti(90, from: UnitPoint(x: 0.5, y: 0.3)) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                isPaused = true
                store.holdArcadeRun(ArcadeRun(game: .bubbleBlaster, score: game.score, detail: game.popped, extra: game.bestClear))
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
            BubbleField(game: game, aimPath: game.shot == nil ? aim.map { game.trajectory(angle: $0) } : nil)
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
        .overlay { EffectsLayer(effects: effects) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bubble field")
        .accessibilityValue("Score \(game.score), level \(game.level)")
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
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: "Game Over", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest,
                                    best: store.game.stats.bubbleBestScore, reward: result.reward,
                                    details: ["\(CoinFormat.grouped(result.detail)) bubbles popped"],
                                    challenge: result.challenge)
                }
            } else {
                GamePanel(title: "Bubble Blaster", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.bubbleBestScore,
                              howTo: "Match three or more of a color to pop them; anything left hanging falls for double points. Every six shots that pop nothing, a new row drops. Don't let the bubbles reach the line.",
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
        var rng = SystemRandomNumberGenerator()
        game.update(by: seconds, using: &rng)
        if game.shot == nil { lastFrame = nil }
        if game.isOver { endGame() }
    }

    private func showPops() {
        for bubble in game.lastCleared {
            effects.pop(Theme.bubble(bubble.color),
                        at: UnitPoint(x: bubble.position.x / BubbleShooterGame.width,
                                      y: bubble.position.y / BubbleShooterGame.height))
        }
    }

    private func start() {
        game = .fresh()
        result = nil
        isPaused = false
        aim = nil
        aimStart = nil
        lastFrame = nil
        isPlaying = true
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        aim = nil
        let payout = store.finishBubbleBlaster(score: game.score, popped: game.popped, bestShot: game.bestClear)
        result = GameResult(score: game.score, payout: payout, detail: game.popped)
    }
}

extension BubbleShooterGame {
    static func fresh() -> BubbleShooterGame {
        var rng = SystemRandomNumberGenerator()
        return BubbleShooterGame(using: &rng)
    }
}

/// The bubbles, the danger line, the aiming guide and the launcher.
private struct BubbleField: View {
    let game: BubbleShooterGame
    let aimPath: [Vector2]?
    /// Where the next bubble waits, left of the launcher.
    static let nextPosition = Vector2(x: 1.1, y: BubbleShooterGame.launcher.y)

    var body: some View {
        Canvas { context, size in
            let scale = size.width / BubbleShooterGame.width
            func point(_ vector: Vector2) -> CGPoint { CGPoint(x: vector.x * scale, y: vector.y * scale) }
            func bubble(_ color: Int, at center: Vector2, diameter: Double = 0.96) {
                let radius = diameter / 2 * scale
                let middle = point(center)
                let rect = CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2)
                let base = Theme.bubble(color)
                context.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [base.mix(with: .white, by: 0.55), base, base.mix(with: .black, by: 0.25)]),
                    center: CGPoint(x: middle.x - radius * 0.35, y: middle.y - radius * 0.35),
                    startRadius: 0, endRadius: radius * 1.5))
            }

            // The line bubbles must not cross: just below the last safe row.
            let lastSafeRow = Double(BubbleShooterGame.deadRow - 1)
            let lineY = (0.5 + lastSafeRow * BubbleShooterGame.rowHeight + 0.52) * scale
            var line = Path()
            line.move(to: CGPoint(x: 0, y: lineY))
            line.addLine(to: CGPoint(x: size.width, y: lineY))
            context.stroke(line, with: .color(.red.opacity(0.55)), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))

            for row in 0...BubbleShooterGame.deadRow {
                for column in 0..<BubbleShooterGame.columns {
                    if let color = game.color(row: row, column: column) {
                        bubble(color, at: game.center(row: row, column: column))
                    }
                }
            }

            if let aimPath, aimPath.count > 1 {
                var guide = Path()
                guide.move(to: point(aimPath[0]))
                for next in aimPath.dropFirst() { guide.addLine(to: point(next)) }
                context.stroke(guide, with: .color(.white.opacity(0.75)),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 9]))
            }

            if let shot = game.shot {
                bubble(shot.color, at: shot.position)
            } else if !game.isOver {
                bubble(game.current, at: BubbleShooterGame.launcher)
            }
            // The next bubble waits to the left of the launcher.
            bubble(game.next, at: Self.nextPosition, diameter: 0.7)
            context.draw(Text("NEXT").font(.system(size: max(8, scale * 0.28), weight: .bold)).foregroundStyle(.white.opacity(0.7)),
                         at: CGPoint(x: Self.nextPosition.x * scale, y: (Self.nextPosition.y - 0.62) * scale))
        }
        .background(Color(red: 0.05, green: 0.07, blue: 0.18).opacity(0.92), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
    }
}
