import SwiftUI
import CryptoClickerKit

/// Token Swap: a minute of match-three with crypto tokens. Drag a token onto a neighbor (or tap
/// one, then the other) to swap them; three or more in a row clear, the tokens above fall and new
/// ones drop in. The rules live in `TokenSwapGame`; this view runs the clock, animates each wave
/// and pays the score when the round ends (or when the player leaves).
struct TokenSwapView: View {
    typealias Position = TokenSwapGame.Position

    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = TokenSwapGame(seed: .random(in: 0...UInt64.max))
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var result: GameResult?
    /// The token tapped first, waiting for a neighbor to swap with.
    @State private var selected: Position?
    /// Where the current drag began, and whether it has already made its swap.
    @State private var dragStart: Position?
    @State private var dragSwapped = false
    /// Tokens that just refused a swap, outlined in red for a moment.
    @State private var refused: Set<Int> = []
    @State private var popups: [Popup] = []
    @State private var resolveTask: Task<Void, Never>?
    /// Seconds since the last swap, to point out a move when the player is stuck.
    @State private var idle: TimeInterval = 0
    /// The wave on screen, for the chain counter.
    @State private var chain = 0
    @State private var waves = 0
    @State private var blasts = 0
    @State private var refusals = 0

    private var isRunning: Bool { isPlaying && !isPaused }

    /// "+120" or "Chain ×3" floating up from where a wave cleared.
    struct Popup: Identifiable {
        let id = UUID()
        let text: String
        /// Board position in cells (column, row), fractional.
        let x: Double
        let y: Double
        let isBig: Bool
        let born: Date
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Chain", value: chain > 1 ? "×\(chain)" : "–")
                GameStat(title: "Time", value: "\(Int(game.timeLeft.rounded(.up)))s")
                Spacer(minLength: 0)
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying { isPaused.toggle() }
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            ProgressView(value: game.timeLeft, total: TokenSwapGame.roundLength)
                .tint(game.timeLeft < 10 ? Theme.loss : MiniGame.tokenSwap.color)
                .accessibilityLabel("Time left")
                .accessibilityValue("\(Int(game.timeLeft.rounded(.up))) seconds")
            board
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
        .background { AppBackground(tint: MiniGame.tokenSwap.color) }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle("Token Swap")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: waves) { _, _ in haptics }
        .sensoryFeedback(.impact(weight: .heavy), trigger: blasts) { _, _ in haptics }
        .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
        .task(id: isRunning) { await run() }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                isPaused = true
                store.holdArcadeRun(ArcadeRun(game: .tokenSwap, score: game.score, detail: game.tokensCleared,
                                              extra: game.bestChain))
            default:
                isPaused = true
            }
        }
        .onDisappear {
            if isPlaying { endGame() }
        }
        .gameScreen(blocksSwipeBack: true)
    }

    // MARK: Board

    private struct PlacedTile: Identifiable {
        let tile: TokenSwapGame.Tile
        let position: Position
        var id: Int { tile.id }
    }

    private var placedTiles: [PlacedTile] {
        game.board.enumerated().flatMap { row, tiles in
            tiles.enumerated().map { column, tile in PlacedTile(tile: tile, position: Position(row: row, column: column)) }
        }
    }

    /// The move to point out after a few seconds without one.
    private var hinted: Set<Position> {
        guard isRunning, idle >= 6, !game.isResolving, let (a, b) = game.hint else { return [] }
        return [a, b]
    }

    private var board: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(TokenSwapGame.size)
            let hintedCells = self.hinted
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    // A faint checkerboard under the tokens.
                    for row in 0..<TokenSwapGame.size {
                        for column in 0..<TokenSwapGame.size where (row + column) % 2 == 0 {
                            let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                            context.fill(Path(rect), with: .color(.white.opacity(0.05)))
                        }
                    }
                }
                ForEach(placedTiles) { placed in
                    TokenTile(kind: placed.tile.kind, isBlast: placed.tile.isBlast,
                              isSelected: placed.position == selected, isHinted: hintedCells.contains(placed.position),
                              isRefused: refused.contains(placed.tile.id), size: cell)
                        .position(x: (CGFloat(placed.position.column) + 0.5) * cell,
                                  y: (CGFloat(placed.position.row) + 0.5) * cell)
                        .transition(.asymmetric(insertion: .offset(y: -cell * 2).combined(with: .opacity),
                                                removal: .scale(scale: 0.2).combined(with: .opacity)))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(label(for: placed))
                        .accessibilityActions {
                            ForEach(SwapDirection.all) { direction in
                                Button("Swap \(direction.name)") {
                                    attemptSwap(placed.position, placed.position.moved(dRow: direction.dRow, dColumn: direction.dColumn))
                                }
                            }
                        }
                }
                TimelineView(.animation(paused: popups.isEmpty)) { context in
                    ZStack(alignment: .topLeading) {
                        ForEach(popups) { popup in
                            let age = context.date.timeIntervalSince(popup.born)
                            Text(popup.text)
                                .font(.system(size: cell * (popup.isBig ? 0.5 : 0.38), weight: .heavy, design: .rounded))
                                .foregroundStyle(popup.isBig ? AnyShapeStyle(Theme.gold.gradient) : AnyShapeStyle(.white))
                                .shadow(color: .black.opacity(0.6), radius: 3)
                                .fixedSize()
                                .position(x: popup.x * cell, y: popup.y * cell - CGFloat(age) * cell * 0.9)
                                .opacity(max(0, 1 - age / 0.9))
                        }
                    }
                    .frame(width: side, height: side, alignment: .topLeading)
                }
                .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .background(Color(red: 0.03, green: 0.12, blue: 0.11).opacity(0.85))
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(MiniGame.tokenSwap.color.opacity(0.6), lineWidth: 1)
            }
            .contentShape(.rect)
            .gesture(drag(cell: cell))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The four ways a token can be swapped, for VoiceOver's actions.
    private struct SwapDirection: Identifiable {
        let name: String
        let dRow: Int
        let dColumn: Int
        var id: String { name }

        static let all = [SwapDirection(name: "up", dRow: -1, dColumn: 0), SwapDirection(name: "down", dRow: 1, dColumn: 0),
                          SwapDirection(name: "left", dRow: 0, dColumn: -1), SwapDirection(name: "right", dRow: 0, dColumn: 1)]
    }

    private func label(for placed: PlacedTile) -> String {
        let name = TokenTile.tokens[placed.tile.kind].name
        let blast = placed.tile.isBlast ? " Blast" : ""
        return "\(name)\(blast), row \(placed.position.row + 1), column \(placed.position.column + 1)"
    }

    /// Drag a token toward a neighbor to swap them; a touch that barely moves is a tap.
    private func drag(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isRunning else { return }
                if dragStart == nil {
                    dragStart = cellPosition(value.startLocation, cell: cell)
                    dragSwapped = false
                }
                guard let from = dragStart, !dragSwapped else { return }
                let dx = value.translation.width, dy = value.translation.height
                guard max(abs(dx), abs(dy)) > cell * 0.35 else { return }
                dragSwapped = true
                let to = abs(dx) > abs(dy) ? from.moved(dRow: 0, dColumn: dx > 0 ? 1 : -1)
                                           : from.moved(dRow: dy > 0 ? 1 : -1, dColumn: 0)
                attemptSwap(from, to)
            }
            .onEnded { value in
                defer {
                    dragStart = nil
                    dragSwapped = false
                }
                guard isRunning, !dragSwapped, let position = dragStart else { return }
                tap(position)
            }
    }

    private func cellPosition(_ point: CGPoint, cell: CGFloat) -> Position? {
        let position = Position(row: Int(point.y / cell), column: Int(point.x / cell))
        return point.x >= 0 && point.y >= 0 && position.isOnBoard ? position : nil
    }

    private func tap(_ position: Position) {
        if let selected, selected.isNeighbor(of: position) {
            attemptSwap(selected, position)
        } else {
            withAnimation(.snappy(duration: 0.15)) { selected = selected == position ? nil : position }
        }
    }

    // MARK: Game flow

    private func attemptSwap(_ a: Position, _ b: Position) {
        guard isRunning, !game.isResolving, a.isOnBoard, b.isOnBoard else { return }
        selected = nil
        idle = 0
        if game.isValidSwap(a, b) {
            withAnimation(.snappy(duration: 0.18)) { _ = game.swap(a, b) }
            resolveTask = Task { await resolve() }
        } else {
            refusals += 1
            let ids: Set<Int> = [game.tile(at: a).id, game.tile(at: b).id]
            withAnimation(.snappy(duration: 0.12)) { refused = ids }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.snappy(duration: 0.2)) { refused.subtract(ids) }
            }
        }
    }

    /// Clears wave after wave, pausing between them so each can be seen.
    private func resolve() async {
        while game.isResolving {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 210))
            guard !Task.isCancelled else { return }
            let step = withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.24)) { game.resolveStep() }
            guard let step else { break }
            chain = step.chain
            waves += 1
            if step.blasts > 0 { blasts += 1 }
            showPopups(for: step)
        }
        withAnimation(.snappy) { chain = 0 }
        if game.isOver { endGame() }
    }

    private func showPopups(for step: TokenSwapGame.Step) {
        guard !step.cleared.isEmpty else { return }
        let x = step.cleared.reduce(0.0) { $0 + Double($1.column) } / Double(step.cleared.count) + 0.5
        let y = step.cleared.reduce(0.0) { $0 + Double($1.row) } / Double(step.cleared.count) + 0.5
        let now = Date.now
        popups.removeAll { now.timeIntervalSince($0.born) > 1 }
        popups.append(Popup(text: "+\(CoinFormat.grouped(step.points))", x: x, y: y, isBig: step.blasts > 0, born: now))
        if step.chain >= 2 {
            popups.append(Popup(text: "Chain ×\(step.chain)", x: x, y: y - 0.7, isBig: true, born: now))
        }
    }

    private func start() {
        resolveTask?.cancel()
        game = TokenSwapGame(seed: .random(in: 0...UInt64.max))
        popups = []
        result = nil
        selected = nil
        refused = []
        chain = 0
        idle = 0
        isPaused = false
        isPlaying = true
    }

    private func run() async {
        guard isRunning else { return }
        var last = Date.now
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }
            guard isRunning else { return }
            let now = Date.now
            let elapsed = min(now.timeIntervalSince(last), 0.2)
            game.advance(by: elapsed)
            idle += elapsed
            last = now
            if !popups.isEmpty { popups.removeAll { now.timeIntervalSince($0.born) > 1 } }
            if game.isOver {
                endGame()
                return
            }
        }
    }

    private func endGame() {
        guard isPlaying else { return }
        resolveTask?.cancel()
        game.resolveAll() // Waves still falling count.
        isPlaying = false
        isPaused = false
        selected = nil
        chain = 0
        let payout = store.finishTokenSwap(score: game.score, tokens: game.tokensCleared, bestChain: game.bestChain,
                                           blasts: game.blastsSetOff)
        result = GameResult(score: game.score, payout: payout, detail: game.tokensCleared)
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: "Time's Up", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest,
                                    best: store.game.stats.tokenSwapBestScore, reward: result.reward,
                                    details: ["\(CoinFormat.grouped(result.detail)) tokens matched · longest chain \(CoinFormat.grouped(game.bestChain))"],
                                    challenge: result.challenge)
                }
            } else {
                GamePanel(title: "Token Swap", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.tokenSwapBestScore,
                              howTo: "Drag a token onto its neighbor to swap them and line up three or more of a kind. Tokens that fall into new matches score more each time. Line up four, or match across and down at once, to make a Blast: match it to clear its whole row and column. You have a minute.")
                }
            }
        }
    }
}

/// One token on the board, tinted by its kind. Blasts glow and carry a bolt.
private struct TokenTile: View {
    let kind: Int
    let isBlast: Bool
    let isSelected: Bool
    let isHinted: Bool
    let isRefused: Bool
    let size: CGFloat

    static let tokens: [TokenID] = [.bitcoin, .ethereum, .solana, .dogecoin, .xrp, .cardano]
    static let tints: [Color] = [
        Color(red: 0.97, green: 0.58, blue: 0.10), Color(red: 0.45, green: 0.48, blue: 0.90),
        Color(red: 0.62, green: 0.30, blue: 0.95), Color(red: 0.86, green: 0.70, blue: 0.22),
        Color(red: 0.60, green: 0.66, blue: 0.72), Color(red: 0.15, green: 0.45, blue: 0.95),
    ]

    var body: some View {
        let tint = Self.tints[kind % Self.tints.count]
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(tint.opacity(isBlast ? 0.55 : 0.26))
            TokenImage(token: Self.tokens[kind % Self.tokens.count], size: size * 0.64)
            if isBlast {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(AngularGradient(colors: [.white, tint, Theme.gold, .white], center: .center), lineWidth: 2.5)
                Image(systemName: "bolt.fill")
                    .font(.system(size: size * 0.24, weight: .black))
                    .foregroundStyle(Theme.gold)
                    .shadow(color: .black.opacity(0.6), radius: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(size * 0.06)
            }
        }
        .padding(size * 0.05)
        .frame(width: size, height: size)
        .overlay {
            if isSelected || isRefused {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(isRefused ? Theme.loss : .white, lineWidth: 3)
                    .padding(size * 0.03)
            } else if isHinted {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(Theme.gold, lineWidth: 2.5)
                    .padding(size * 0.03)
                    .phaseAnimator([0.25, 1.0]) { content, opacity in
                        content.opacity(opacity)
                    } animation: { _ in .easeInOut(duration: 0.6) }
            }
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .shadow(color: isBlast ? tint.opacity(0.8) : .clear, radius: size * 0.15)
    }
}

/// What to do, under the board.
private struct Legend: View {
    var body: some View {
        HStack(spacing: 14) {
            Label("Match 3+", systemImage: "line.3.horizontal")
            Label("4 makes a Blast", systemImage: "bolt.fill")
            Label("Chains score more", systemImage: "arrow.down.circle.fill")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.subtext)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}
