import SwiftUI
import UIKit
import CryptoClickerKit

/// The screens inside Pump and Dump, opened from its start screen.
enum PumpDumpRoute: Hashable {
    /// A run on this board.
    case play(PumpDumpGame.Board)
}

/// Where Pump and Dump opens, like Hash Chain and Merge Mining: a run on the board picked (3×3,
/// 4×4 or 5×5, each in miniature with its best), and the speed setting, each on a card.
struct PumpDumpView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.pumpDumpBoardKey) private var board = PumpDumpGame.Board.three
    @AppStorage(Preferences.pumpDumpSpeedKey) private var speed = GameSpeed.normal
    @State private var showingHelp = false

    private let tint = MiniGame.pumpDump.color

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                roundsCard
                settingsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(MiniGame.pumpDump.name)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.pumpDump, isPresented: $showingHelp)
        .gameBackdrop(.pumpDump)
    }

    private var roundsCard: some View {
        let game = store.game
        let best = game.pumpDumpBest(on: board)
        return ModeCard(tint: tint, icon: "chart.line.uptrend.xyaxis", title: "Rounds",
                        status: best > 0
                            ? "Best on \(board.name): \(CoinFormat.grouped(best)) · furthest round \(game.stats.pumpDumpBestRound)"
                            : "Pick a board and play",
                        detail: "Tap coins as they list and reach each \(Int(PumpDumpGame.roundLength))-second round's goal. Bigger boards list coins faster and more at once, with bigger goals; their points pay a little less each, so every board pays about the same.",
                        note: nil) {
            VStack(spacing: 12) {
                BoardPicker(selection: $board, tint: tint) { game.pumpDumpBest(on: $0) }
                NavigationLink(value: PumpDumpRoute.play(board)) {
                    Label("Play \(board.name)", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private var settingsCard: some View {
        ModeCard(tint: tint, icon: "slider.horizontal.3", title: "Settings", status: "\(speed.name) speed",
                 detail: "How fast coins list and leave. Goals move with the speed, so Fast scores sooner but needs quicker fingers, and Slow is relaxed.",
                 note: nil) {
            Picker("Speed", selection: $speed) {
                ForEach(GameSpeed.allCases) { speed in
                    Text(speed.name).tag(speed)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// The three boards in miniature, side by side, each with its best: tap one to pick it.
private struct BoardPicker: View {
    @Binding var selection: PumpDumpGame.Board
    let tint: Color
    let best: (PumpDumpGame.Board) -> Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(PumpDumpGame.Board.allCases) { board in
                tile(board)
            }
        }
    }

    private func tile(_ board: PumpDumpGame.Board) -> some View {
        let isSelected = board == selection
        let record = best(board)
        return Button {
            selection = board
        } label: {
            VStack(spacing: 6) {
                BoardPreview(board: board, tint: tint)
                    .frame(width: 46, height: 46)
                Text(board.name)
                    .font(.headline)
                Text(record > 0 ? CoinFormat.grouped(record) : "–")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? tint.opacity(0.25) : Color.primary.opacity(0.06), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? tint.mix(with: .white, by: 0.3) : .clear, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(board.name) board")
        .accessibilityValue(record > 0 ? "Best \(CoinFormat.grouped(record))" : "Not played yet")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A board's slots in miniature, a few lit as if coins were listed.
private struct BoardPreview: View {
    let board: PumpDumpGame.Board
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let side = board.side
            let gap = size.width * 0.06
            let cell = (size.width - gap * CGFloat(side + 1)) / CGFloat(side)
            let lit: Set<Int> = [1, side + 2, side * side - 2]
            for hole in 0..<board.holes {
                let frame = CGRect(x: gap + CGFloat(hole % side) * (cell + gap), y: gap + CGFloat(hole / side) * (cell + gap),
                                   width: cell, height: cell)
                let slot = Path(roundedRect: frame, cornerRadius: cell * 0.22)
                context.fill(slot, with: .color(lit.contains(hole) ? Theme.gold : .white.opacity(0.18)))
            }
        }
        .background(Color(red: 0.05, green: 0.09, blue: 0.16), in: .rect(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

/// Pump and Dump's game on one board: coins list in a grid of slots; tap them before they're
/// delisted. A run is a series of 30-second rounds, each with a score goal and a bonus objective;
/// the run ends when a round falls short. The rules live in `PumpDumpGame`. This view runs its
/// clock, takes every finger the moment it lands, shows what each tap did, and pays the run when it
/// ends (or when the player leaves).
struct PumpDumpPlayView: View {
    let board: PumpDumpGame.Board
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.pumpDumpSpeedKey) private var speed = GameSpeed.normal
    @State private var game: PumpDumpGame
    /// A run is under way: a round, or the break between two.
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showingHelp = false
    @State private var result: GameResult?
    /// What the last taps did, shown at their holes for a moment.
    @State private var marks: [Mark] = []
    @State private var nextMarkID = 0
    /// The last combo that ended, for the "combo lost" banner.
    @State private var lostCombo: LostCombo?
    // Haptic triggers.
    @State private var hits = 0
    @State private var goldenHits = 0
    @State private var mistakes = 0
    @State private var roundsCleared = 0
    @State private var rng = SeededGenerator(seed: .random(in: 0...UInt64.max))

    private var isRunning: Bool { isPlaying && !isPaused && game.phase == .playing }

    init(board: PumpDumpGame.Board) {
        self.board = board
        let speed = GameSpeed(rawValue: UserDefaults.standard.string(forKey: Preferences.pumpDumpSpeedKey) ?? "") ?? .normal
        _game = State(initialValue: PumpDumpGame(board: board, speed: speed))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Combo", value: game.combo > 1 ? CoinFormat.multiplier(game.comboMultiplier) : "–")
                GameStat(title: "Time", value: "\(Int(game.timeLeft.rounded(.up)))s")
                    .foregroundStyle(isPlaying && game.timeLeft < 5 ? Theme.loss : .primary)
                Spacer(minLength: 0)
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying && game.phase == .playing { isPaused.toggle() }
                }
                .disabled(!isPlaying || game.phase != .playing)
            }
            .scoreBar()
            RoundStatus(game: game)
            field
                .frame(maxHeight: .infinity)
                .overlay {
                    if isPaused {
                        PausedCard(game: .pumpDump, resume: { isPaused = false }, showHelp: { showingHelp = true })
                    }
                }
            ComboLine(combo: game.combo, multiplier: game.comboMultiplier, lost: lostCombo, time: game.time)
            Legend()
        }
        .padding(12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .animation(.snappy, value: game.phase)
        .navigationTitle("\(MiniGame.pumpDump.name) \(board.name)")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.pumpDump, isPresented: $showingHelp) {
            if isPlaying && game.phase == .playing { isPaused = true }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hits) { _, _ in haptics }
        .sensoryFeedback(.success, trigger: goldenHits) { _, _ in haptics }
        .sensoryFeedback(.error, trigger: mistakes) { _, _ in haptics }
        .sensoryFeedback(.success, trigger: roundsCleared) { _, _ in haptics }
        .task(id: isRunning) { await run() }
        // Between rounds there's nothing running to pause.
        .arcadeLifecycle(isPlaying: isPlaying, pause: { if game.phase == .playing { isPaused = true } },
                         heldRun: { heldRun }) { endGame() }
        .gameBackdrop(.pumpDump)
    }

    /// The game so far, held while the app is in the background.
    private var heldRun: ArcadeRun {
        ArcadeRun(game: .pumpDump, score: game.score, detail: game.coinsHit, extra: game.bestCombo, stage: game.round,
                  records: .init(scamsHit: game.scamsHit, board: board.rawValue))
    }

    // MARK: Board

    private var field: some View {
        GeometryReader { proxy in
            let layout = BoardLayout(side: min(proxy.size.width, proxy.size.height), count: board.side)
            // Every piece is placed by its center inside one fixed square, and touches are judged
            // against the same square, so what's drawn and what's tapped always line up.
            ZStack(alignment: .topLeading) {
                TouchDownPad { point in
                    if let hole = layout.hole(at: point) { tap(hole) }
                }
                .accessibilityHidden(true)
                ForEach(0..<game.holes, id: \.self) { hole in
                    let target = game.target(inHole: hole)
                    HoleView(target: target, time: game.time,
                             sink: target.map(sinkProgress) ?? 0,
                             flash: flash(at: hole), size: layout.cell, reduceMotion: reduceMotion,
                             look: store.game.equipped(.pumpBoard))
                        .frame(width: layout.cell, height: layout.cell)
                        .allowsHitTesting(false)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(label(for: hole))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { tap(hole) }
                        .position(layout.center(of: hole))
                }
                ForEach(marks) { mark in
                    MarkView(mark: mark, age: game.time - mark.time, cell: layout.cell, reduceMotion: reduceMotion)
                        .position(layout.center(of: mark.hole))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: layout.side, height: layout.side, alignment: .topLeading)
            .background(Color(red: 0.10, green: 0.05, blue: 0.08).opacity(0.85), in: .rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(MiniGame.pumpDump.color.opacity(0.5), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// How far a target whose time is up has sunk, from 0 to 1.
    private func sinkProgress(_ target: PumpDumpGame.Target) -> Double {
        guard game.isSinking(target) else { return 0 }
        return min(1, (game.time - target.leavesAt) / PumpDumpGame.sinkTime)
    }

    /// A red flash at a hole where a scam was just tapped, from 1 down to 0.
    private func flash(at hole: Int) -> Double {
        guard let mark = marks.last(where: { $0.hole == hole && $0.style == .penalty }) else { return 0 }
        return max(0, 1 - (game.time - mark.time) / 0.45)
    }

    private func label(for hole: Int) -> String {
        let place = "Row \(hole / board.side + 1), column \(hole % board.side + 1)"
        guard let target = game.target(inHole: hole) else { return "\(place): empty" }
        if target.isScam(at: game.time) { return "\(place): scam token, don't tap" }
        if target.kind == .rug { return target.isWarning(at: game.time) ? "\(place): rug pull, shaking" : "\(place): coin with a red rim" }
        return "\(place): " + (target.kind == .golden ? "golden coin" : "coin")
    }

    // MARK: Panels

    @ViewBuilder
    private var panel: some View {
        if isPlaying && game.phase == .roundCleared {
            GamePanel(title: "Round \(game.round) Cleared!", buttonTitle: "Round \(game.round + 1)", action: nextRound) {
                RoundClearedSummary(game: game)
            }
        } else if !isPlaying {
            if let result {
                GamePanel(title: "Run Over", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest,
                                    best: store.game.pumpDumpBest(on: board), reward: result.reward,
                                    details: runDetails, challenge: result.challenge, xp: result.xp)
                }
            } else {
                GamePanel(title: "\(board.name) Board", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.pumpDumpBest(on: board),
                              note: store.game.stats.pumpDumpBestRound > 0 ? "Furthest: round \(store.game.stats.pumpDumpBestRound)" : nil,
                              detail: "\(board.holes) slots · \(speed.name) speed · first goal \(CoinFormat.grouped(game.goal(forRound: 1)))")
                }
            }
        }
    }

    private var runDetails: [String] {
        let accuracy = Int((game.accuracy * 100).rounded())
        return [
            "Round \(game.round): \(CoinFormat.grouped(game.roundScore)) of \(CoinFormat.grouped(game.goal)) needed",
            "\(CoinFormat.grouped(game.coinsHit)) coins · \(game.goldenHit) golden · \(game.scamsHit) scam\(game.scamsHit == 1 ? "" : "s")",
            "Best combo \(game.bestCombo) · \(accuracy)% accurate · \(game.escaped) got away",
        ]
    }

    // MARK: Game flow

    private func start() {
        game = PumpDumpGame(board: board, speed: speed)
        rng = SeededGenerator(seed: .random(in: 0...UInt64.max))
        marks = []
        lostCombo = nil
        result = nil
        isPaused = false
        isPlaying = true
    }

    private func nextRound() {
        game.startNextRound()
        marks = []
        lostCombo = nil
        isPaused = false
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
            let breaks = game.comboBreaks
            game.advance(by: min(now.timeIntervalSince(last), 0.1), using: &rng)
            last = now
            for hole in game.escapedHoles { addMark(.escaped, at: hole, text: "Delisted") }
            noteLostCombo(since: breaks)
            marks.removeAll { game.time - $0.time > 0.8 }
            switch game.phase {
            case .playing:
                continue
            case .roundCleared:
                roundsCleared += 1
                return
            case .over:
                endGame()
                return
            }
        }
    }

    private func tap(_ hole: Int) {
        guard isRunning else { return }
        let breaks = game.comboBreaks
        switch game.tap(hole: hole) {
        case .coin(let points):
            hits += 1
            addMark(.points, at: hole, text: "+\(points)")
        case .golden(let points):
            goldenHits += 1
            addMark(.golden, at: hole, text: "+\(points)")
        case .scam(let penalty):
            mistakes += 1
            addMark(.penalty, at: hole, text: "−\(penalty)")
        case .miss:
            addMark(.miss, at: hole, text: "✕")
        }
        noteLostCombo(since: breaks)
    }

    private func addMark(_ style: Mark.Style, at hole: Int, text: String) {
        marks.append(Mark(id: nextMarkID, hole: hole, text: text, style: style, time: game.time))
        nextMarkID += 1
    }

    private func noteLostCombo(since breaks: Int) {
        guard game.comboBreaks > breaks else { return }
        lostCombo = LostCombo(id: game.comboBreaks, length: game.lastLostCombo, time: game.time)
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        let payout = store.finishPumpDump(score: game.score, coinsHit: game.coinsHit, bestCombo: game.bestCombo,
                                          scamsHit: game.scamsHit, rounds: game.round, board: board)
        result = GameResult(score: game.score, payout: payout, detail: game.coinsHit, xp: store.lastArcadeAward)
    }
}

// MARK: - Layout and touch

/// Where the holes sit in a square board `side` points across, `count` to a side, and which hole a
/// point is in.
private struct BoardLayout {
    let side: CGFloat
    let count: Int
    /// The gap between slots: a little narrower on the bigger boards, so their slots stay big.
    var gap: CGFloat { side * (count > 3 ? 0.03 : 0.04) }
    var cell: CGFloat { max(0, (side - gap * CGFloat(count + 1)) / CGFloat(count)) }

    func center(of hole: Int) -> CGPoint {
        CGPoint(x: gap + CGFloat(hole % count) * (cell + gap) + cell / 2,
                y: gap + CGFloat(hole / count) * (cell + gap) + cell / 2)
    }

    /// The hole under `point`. Each hole owns its cell plus half the gap around it, so a touch
    /// between two holes goes to the nearer one and a touch at the edge to the outer row.
    func hole(at point: CGPoint) -> Int? {
        guard side > 0, (0...side).contains(point.x), (0...side).contains(point.y) else { return nil }
        let step = cell + gap
        let column = min(count - 1, max(0, Int((point.x - gap / 2) / step)))
        let row = min(count - 1, max(0, Int((point.y - gap / 2) / step)))
        return row * count + column
    }
}

/// Reports every finger the moment it touches down, several at once if need be: whack-a-mole needs
/// the touch, not the lift, and a second finger mustn't wait for the first.
private struct TouchDownPad: UIViewRepresentable {
    let onTouch: (CGPoint) -> Void

    func makeUIView(context: Context) -> PadView {
        let view = PadView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.onTouch = onTouch
        return view
    }

    func updateUIView(_ view: PadView, context: Context) {
        view.onTouch = onTouch
    }

    final class PadView: UIView {
        var onTouch: ((CGPoint) -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches { onTouch?(touch.location(in: self)) }
        }
    }
}

// MARK: - Pieces

/// A piece popping out of a hole. The help sheet draws the same pieces.
struct PumpPiece: View {
    enum Look: Equatable {
        case coin, golden, scam
        /// A rug pull while it's still a coin, red rim and all.
        case rug
        /// A rug pull that has turned into a scam.
        case rugPulled
    }

    let look: Look
    let size: CGFloat
    /// A rug pull about to turn: its rim goes solid and bright.
    var isWarning = false

    var body: some View {
        switch look {
        case .coin:
            coin(scale: 0.62)
        case .golden:
            coin(scale: 0.72)
                .shadow(color: .yellow.opacity(0.9), radius: size * 0.12)
                .overlay(alignment: .topTrailing) {
                    Text("×5")
                        .font(.system(size: size * 0.12, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, size * 0.04)
                        .background(.yellow, in: .capsule)
                }
                .overlay(alignment: .topLeading) {
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.14, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .yellow, radius: 3)
                }
        case .rug:
            coin(scale: 0.6)
                .padding(size * 0.03)
                .overlay {
                    Circle()
                        .strokeBorder(Color(red: 1, green: 0.2, blue: 0.2),
                                      style: StrokeStyle(lineWidth: size * (isWarning ? 0.06 : 0.04),
                                                         dash: isWarning ? [] : [size * 0.07, size * 0.045]))
                }
        case .scam, .rugPulled:
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 0.95, green: 0.25, blue: 0.25), Color(red: 0.45, green: 0.02, blue: 0.05)],
                                         center: .topLeading, startRadius: 2, endRadius: size * 0.5))
                Circle()
                    .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                VStack(spacing: 0) {
                    Text(look == .rugPulled ? "🪤" : "☠️")
                        .font(.system(size: size * 0.24))
                    Text(look == .rugPulled ? "RUG" : "SCAM")
                        .font(.system(size: size * 0.11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size * 0.66, height: size * 0.66)
        }
    }

    private func coin(scale: CGFloat) -> some View {
        Image("CoinSmall")
            .resizable()
            .scaledToFit()
            .frame(width: size * scale, height: size * scale)
    }
}

extension PumpPiece.Look {
    /// The look the help sheet draws for a guide item.
    init?(guideID: String) {
        switch guideID {
        case "pump.coin": self = .coin
        case "pump.golden": self = .golden
        case "pump.scam": self = .scam
        case "pump.rug": self = .rug
        default: return nil
        }
    }
}

/// One hole: empty, or a piece popping up out of it (and sinking back once its time is up).
private struct HoleView: View {
    let target: PumpDumpGame.Target?
    let time: TimeInterval
    /// How far the piece has sunk, from 0 to 1.
    let sink: Double
    /// A red flash after a scam was tapped here, from 1 down to 0.
    let flash: Double
    let size: CGFloat
    let reduceMotion: Bool
    /// The board picked in Style.
    var look = Cosmetic.pumpExchange

    var body: some View {
        ZStack {
            listingSlot
            if let target {
                let warning = target.isWarning(at: time)
                PumpPiece(look: look(of: target), size: size, isWarning: warning)
                    .rotationEffect(.degrees(warning && !reduceMotion ? sin(time * 60) * 14 : 0))
                    .scaleEffect(1 - 0.35 * sink, anchor: .bottom)
                    .opacity(1 - 0.5 * sink)
                    .offset(y: -size * 0.04 + size * 0.22 * sink)
                    .id(target.id)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.18), value: target?.id)
    }

    /// The hole: a listing slot on an exchange board, lit while a coin is listed, in the look
    /// picked in Style.
    @ViewBuilder
    private var listingSlot: some View {
        let isListed = target != nil
        let colors = look.pumpSlotColors
        RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
            .fill(colors.fill.opacity(0.85))
        RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
            .fill(Theme.loss.opacity(0.55 * flash))
        RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
            .strokeBorder(isListed ? colors.rim.opacity(0.6) : .white.opacity(0.12), lineWidth: 1.5)
            .shadow(color: isListed && look == .pumpNeon ? colors.rim.opacity(0.8) : .clear, radius: size * 0.06)
        RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
            .fill(.black.opacity(0.55))
            .frame(width: size * 0.74, height: size * 0.14)
            .offset(y: size * 0.32)
        Text(isListed ? "LISTED" : "— — —")
            .font(.system(size: max(8, size * 0.09), weight: .heavy, design: .monospaced))
            .foregroundStyle(isListed ? colors.listed : .white.opacity(0.3))
            .offset(y: -size * 0.41)
            .accessibilityHidden(true)
    }

    private func look(of target: PumpDumpGame.Target) -> PumpPiece.Look {
        switch target.kind {
        case .coin: .coin
        case .golden: .golden
        case .scam: .scam
        case .rug: target.isScam(at: time) ? .rugPulled : .rug
        }
    }
}

// MARK: - Feedback

/// Something a tap or an escape left at a hole for a moment.
private struct Mark: Identifiable {
    enum Style: Equatable { case points, golden, penalty, miss, escaped }

    let id: Int
    let hole: Int
    let text: String
    let style: Style
    /// Round time it appeared.
    let time: TimeInterval
}

private struct LostCombo: Equatable {
    let id: Int
    let length: Int
    let time: TimeInterval
}

private struct MarkView: View {
    let mark: Mark
    let age: TimeInterval
    let cell: CGFloat
    let reduceMotion: Bool

    var body: some View {
        Text(mark.text)
            .font(.system(size: cell * fontScale, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.6), radius: 3)
            .offset(y: offset)
            .opacity(max(0, 1 - age / 0.8))
    }

    /// Points float up (or just sit above the hole with reduced motion); misses sit low.
    private var offset: CGFloat {
        switch mark.style {
        case .points, .golden, .penalty: -cell * 0.2 - (reduceMotion ? 0 : CGFloat(age) * cell * 0.6)
        case .miss: 0
        case .escaped: cell * 0.3
        }
    }

    private var fontScale: CGFloat {
        switch mark.style {
        case .golden: 0.32
        case .points, .penalty: 0.26
        case .miss: 0.3
        case .escaped: 0.15
        }
    }

    private var color: Color {
        switch mark.style {
        case .points: Theme.gold
        case .golden: .yellow
        case .penalty: Color(red: 1, green: 0.35, blue: 0.35)
        case .miss: .white.opacity(0.7)
        case .escaped: Color(red: 1, green: 0.55, blue: 0.5)
        }
    }
}

/// The round, its goal and how close the score is, and the bonus objective.
private struct RoundStatus: View {
    let game: PumpDumpGame

    var body: some View {
        let reached = game.roundScore >= game.goal
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text("Round \(game.round)")
                    .font(.headline)
                ProgressView(value: Double(min(game.roundScore, game.goal)), total: Double(max(1, game.goal)))
                    .tint(reached ? Theme.gain : Theme.gold)
                Text(reached ? "Goal reached" : "\(CoinFormat.grouped(game.roundScore)) / \(CoinFormat.grouped(game.goal))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(reached ? Theme.gain : .primary)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Round \(game.round) goal")
            .accessibilityValue(reached ? "Reached" : "\(game.roundScore) of \(game.goal) points")
            ObjectiveLine(game: game)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

private struct ObjectiveLine: View {
    let game: PumpDumpGame

    var body: some View {
        let status = self.status
        let done = game.isObjectiveMet && game.objective != .noMistakes
        HStack(spacing: 8) {
            Image(systemName: game.isObjectiveFailed ? "xmark.circle.fill" : done ? "checkmark.circle.fill" : "target")
                .foregroundStyle(game.isObjectiveFailed ? Theme.loss : done ? Theme.gain : Theme.accent)
            Text(game.objective.description)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Text(status)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(game.isObjectiveFailed ? Theme.loss : done ? Theme.gain : .subtext)
            Text("+\(PumpDumpGame.objectiveBonus(round: game.round))")
                .font(.footnote.weight(.heavy).monospacedDigit())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.gold.opacity(0.25), in: .capsule)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bonus objective: \(game.objective.description), worth \(PumpDumpGame.objectiveBonus(round: game.round)) points")
        .accessibilityValue(status)
    }

    private var status: String {
        if game.isObjectiveFailed { return "Missed" }
        if game.objective == .noMistakes { return "Clean so far" }
        if game.isObjectiveMet { return "Done" }
        let progress = game.objectiveProgress
        return "\(progress.current)/\(progress.target)"
    }
}

/// The combo under the board, or a warning when one was just lost. Always the same height, so
/// nothing jumps.
private struct ComboLine: View {
    let combo: Int
    let multiplier: Double
    let lost: LostCombo?
    let time: TimeInterval

    var body: some View {
        ZStack {
            if let lost, time >= lost.time, time - lost.time < 1.2 {
                Label("Combo of \(lost.length) lost", systemImage: "bolt.slash.fill")
                    .foregroundStyle(Theme.loss)
                    .id(lost.id)
                    .transition(.opacity)
            } else if combo > 1 {
                Label("\(combo) in a row · \(CoinFormat.multiplier(multiplier)) points", systemImage: "bolt.fill")
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            } else {
                Text(" ")
                    .accessibilityHidden(true)
            }
        }
        .font(.subheadline.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(height: 22)
        .animation(.easeOut(duration: 0.2), value: lost?.id)
    }
}

/// What a cleared round scored and what comes next.
private struct RoundClearedSummary: View {
    let game: PumpDumpGame

    var body: some View {
        let next = game.round + 1
        VStack(spacing: 10) {
            Text("\(CoinFormat.grouped(game.roundScore)) of \(CoinFormat.grouped(game.goal)) needed")
                .font(.title3.weight(.semibold))
            if game.lastBonus > 0 {
                Label("\(game.objective.description): +\(game.lastBonus)", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.gain)
            } else {
                Label("Missed: \(game.objective.description)", systemImage: "xmark.circle")
                    .font(.headline)
                    .foregroundStyle(.subtext)
            }
            Text("Run total \(CoinFormat.grouped(game.score)) · best combo \(game.bestCombo)")
                .font(.subheadline)
                .foregroundStyle(.subtext)
            Divider()
            VStack(spacing: 4) {
                Text("Next goal: \(CoinFormat.grouped(game.goal(forRound: next)))")
                    .font(.headline)
                Text("Bonus: \(PumpDumpGame.objective(for: next).description)")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                Text("Coins come quicker, with more scams.")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
        }
    }
}

/// What each piece is, under the grid.
private struct Legend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { items }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 14) {
                    item("Tap coins", "bitcoinsign.circle.fill", Theme.gold)
                    item("Golden ×5", "star.fill", .yellow)
                }
                item("Avoid scams and red rims", "xmark.octagon.fill", Theme.loss)
            }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
    }

    @ViewBuilder private var items: some View {
        item("Tap coins", "bitcoinsign.circle.fill", Theme.gold)
        item("Golden ×5", "star.fill", .yellow)
        item("Avoid scams and red rims", "xmark.octagon.fill", Theme.loss)
    }

    private func item(_ title: String, _ symbol: String, _ color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
        }
    }
}
