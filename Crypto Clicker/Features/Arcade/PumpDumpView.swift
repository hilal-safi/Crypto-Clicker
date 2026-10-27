import SwiftUI
import CryptoClickerKit

/// Pump and Dump: coins pop up in a 3×3 grid for 30 seconds; tap them before they drop back down.
/// Scam tokens cost points, rug pulls shake and then turn into scams, and golden coins are worth
/// five. Hits in a row build a combo. The rules live in `PumpDumpGame`; this view runs its clock,
/// takes taps the moment a finger lands, and pays the score when the round ends (or when the
/// player leaves).
struct PumpDumpView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = PumpDumpGame()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var result: GameResult?
    @State private var popups: [Popup] = []
    /// Where the current touch began, so one touch taps once.
    @State private var touchStart: CGPoint?
    @State private var hits = 0
    @State private var goldenHits = 0
    @State private var scamHits = 0
    @State private var rng = SeededGenerator(seed: .random(in: 0...UInt64.max))

    private var isRunning: Bool { isPlaying && !isPaused }

    /// A "+12" or "−30" floating up from a hole.
    struct Popup: Identifiable {
        let id = UUID()
        let hole: Int
        let text: String
        let color: Color
        let time: TimeInterval
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Combo", value: game.combo > 1 ? CoinFormat.multiplier(game.comboMultiplier) : "–")
                GameStat(title: "Time", value: "\(Int(game.timeLeft.rounded(.up)))s")
                Spacer(minLength: 0)
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying { isPaused.toggle() }
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            ProgressView(value: game.timeLeft, total: PumpDumpGame.roundLength)
                .tint(game.timeLeft < 5 ? Theme.loss : Theme.gold)
                .accessibilityLabel("Time left")
                .accessibilityValue("\(Int(game.timeLeft.rounded(.up))) seconds")
            grid
                .frame(maxHeight: .infinity)
                .overlay {
                    if isPaused {
                        Button("Resume", systemImage: "play.fill") { isPaused = false }
                            .buttonStyle(.glassProminent)
                            .font(.title3.bold())
                    }
                }
            Legend()
        }
        .padding(12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background { AppBackground(tint: MiniGame.pumpDump.color) }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle("Pump and Dump")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: hits) { _, _ in haptics }
        .sensoryFeedback(.success, trigger: goldenHits) { _, _ in haptics }
        .sensoryFeedback(.error, trigger: scamHits) { _, _ in haptics }
        .task(id: isRunning) { await run() }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                isPaused = true
                store.holdArcadeRun(ArcadeRun(game: .pumpDump, score: game.score, detail: game.coinsHit, extra: game.bestCombo))
            default:
                isPaused = true
            }
        }
        .onDisappear {
            if isPlaying { endGame() }
        }
        .gameScreen(blocksSwipeBack: true)
    }

    // MARK: Pieces

    private var grid: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let gap = side * 0.04
            let cell = (side - gap * 4) / 3
            ZStack(alignment: .topLeading) {
                ForEach(0..<PumpDumpGame.holes, id: \.self) { hole in
                    HoleView(target: game.target(inHole: hole), time: game.time, size: cell)
                        .frame(width: cell, height: cell)
                        .offset(x: gap + CGFloat(hole % 3) * (cell + gap), y: gap + CGFloat(hole / 3) * (cell + gap))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(label(for: hole))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { tap(hole) }
                }
                ForEach(popups) { popup in
                    let age = game.time - popup.time
                    Text(popup.text)
                        .font(.system(size: cell * 0.26, weight: .heavy, design: .rounded))
                        .foregroundStyle(popup.color)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .position(x: gap + CGFloat(popup.hole % 3) * (cell + gap) + cell / 2,
                                  y: gap + CGFloat(popup.hole / 3) * (cell + gap) + cell * 0.3 - CGFloat(age) * cell * 0.6)
                        .opacity(max(0, 1 - age / 0.7))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
            .background(Color(red: 0.10, green: 0.05, blue: 0.08).opacity(0.85), in: .rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(MiniGame.pumpDump.color.opacity(0.5), lineWidth: 1)
            }
            .contentShape(.rect)
            // A tap lands the moment the finger touches down, as whack-a-mole needs.
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard touchStart != value.startLocation else { return }
                    touchStart = value.startLocation
                    let column = Int(value.startLocation.x / (cell + gap))
                    let row = Int(value.startLocation.y / (cell + gap))
                    guard (0..<3).contains(column), (0..<3).contains(row) else { return }
                    tap(row * 3 + column)
                }
                .onEnded { _ in touchStart = nil })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func label(for hole: Int) -> String {
        guard let target = game.target(inHole: hole) else { return "Empty" }
        if target.isScam(at: game.time) { return "Scam token" }
        if target.isWarning(at: game.time) { return "Coin, shaking" }
        return target.kind == .golden ? "Golden coin" : "Coin"
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: "Time's Up", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest,
                                    best: store.game.stats.pumpDumpBestScore, reward: result.reward,
                                    details: ["\(CoinFormat.grouped(result.detail)) coins hit · best combo \(CoinFormat.grouped(game.bestCombo))"],
                                    challenge: result.challenge)
                }
            } else {
                GamePanel(title: "Pump and Dump", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.pumpDumpBestScore,
                              howTo: "Tap coins before they drop back down: hits in a row build a combo up to ×3, and golden coins are worth five. Don't tap scam tokens, and watch for coins that shake: they're rug pulls about to turn into scams.")
                }
            }
        }
    }

    // MARK: Game flow

    private func start() {
        game = PumpDumpGame()
        rng = SeededGenerator(seed: .random(in: 0...UInt64.max))
        popups = []
        result = nil
        isPaused = false
        isPlaying = true
    }

    private func run() async {
        guard isRunning else { return }
        var last = Date.now
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return
            }
            guard isRunning else { return }
            let now = Date.now
            game.advance(by: min(now.timeIntervalSince(last), 0.1), using: &rng)
            last = now
            popups.removeAll { game.time - $0.time > 0.7 }
            if game.isOver {
                endGame()
                return
            }
        }
    }

    private func tap(_ hole: Int) {
        guard isRunning else { return }
        let hit = game.tap(hole: hole)
        switch hit {
        case .coin(let points):
            hits += 1
            popups.append(Popup(hole: hole, text: "+\(points)", color: Theme.gold, time: game.time))
        case .golden(let points):
            goldenHits += 1
            popups.append(Popup(hole: hole, text: "+\(points)", color: .yellow, time: game.time))
        case .scam(let penalty):
            scamHits += 1
            popups.append(Popup(hole: hole, text: "−\(penalty)", color: Theme.loss, time: game.time))
        case .miss:
            break
        }
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        let payout = store.finishPumpDump(score: game.score, coinsHit: game.coinsHit, bestCombo: game.bestCombo,
                                          scamsHit: game.scamsHit)
        result = GameResult(score: game.score, payout: payout, detail: game.coinsHit)
    }
}

/// One hole: empty, or a coin, golden coin, scam token or rug pull popping up out of it.
private struct HoleView: View {
    let target: PumpDumpGame.Target?
    let time: TimeInterval
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(.black.opacity(0.35))
            Ellipse()
                .fill(.black.opacity(0.45))
                .frame(width: size * 0.7, height: size * 0.22)
                .offset(y: size * 0.3)
            if let target {
                piece(target)
                    .id(target.id)
                    .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.18), value: target?.id)
    }

    @ViewBuilder
    private func piece(_ target: PumpDumpGame.Target) -> some View {
        let isScam = target.isScam(at: time)
        let shake = target.isWarning(at: time) ? sin(time * 60) * 14 : 0
        Group {
            if isScam {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color(red: 0.95, green: 0.25, blue: 0.25), Color(red: 0.45, green: 0.02, blue: 0.05)],
                                             center: .topLeading, startRadius: 2, endRadius: size * 0.5))
                    Circle()
                        .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                    VStack(spacing: 0) {
                        Text(target.kind == .rug ? "🪤" : "☠️")
                            .font(.system(size: size * 0.26))
                        Text(target.kind == .rug ? "RUG" : "SCAM")
                            .font(.system(size: size * 0.11, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: size * 0.66, height: size * 0.66)
            } else {
                Image("CoinSmall")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * (target.kind == .golden ? 0.72 : 0.62))
                    .overlay(alignment: .topTrailing) {
                        if target.kind == .golden {
                            Text("×5")
                                .font(.system(size: size * 0.12, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5)
                                .background(.yellow, in: .capsule)
                        }
                    }
                    .shadow(color: target.kind == .golden ? .yellow.opacity(0.9) : .clear, radius: size * 0.12)
            }
        }
        .rotationEffect(.degrees(shake))
        .offset(y: -size * 0.04)
    }
}

/// What each piece is, under the grid.
private struct Legend: View {
    var body: some View {
        HStack(spacing: 14) {
            Label("Tap coins", systemImage: "bitcoinsign.circle.fill")
            Label("Golden ×5", systemImage: "star.fill")
            Label("Avoid scams", systemImage: "xmark.octagon.fill")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.subtext)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}
