import SwiftUI
import CryptoClickerKit

/// 2048: swipe anywhere in the play area to slide every tile one way. Two tiles with the
/// same number merge into their sum, which is added to the score. Points pay coins when the game
/// ends, and making a 2048 tile pays a bonus on top. The player can end the game whenever they
/// like to collect; leaving the screen ends it too.
struct Merge2048View: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var game = Merge2048Game.fresh()
    @State private var isPlaying = false
    @State private var result: Merge2048Result?
    @State private var effects = Effects()
    /// Set once per game, when the first 2048 tile appears.
    @State private var hasWon = false
    @State private var showsWinBanner = false
    @State private var isConfirmingEnd = false
    @State private var showingHelp = false
    /// The drag that already slid the board; each swipe slides once.
    @State private var swipeStart: CGPoint?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Top tile", value: String(game.bestTile))
                Spacer(minLength: 0)
                GameStat(title: "Best", value: CoinFormat.grouped(store.game.stats.merge2048BestScore))
                ArcadeButton(title: "End game", systemImage: "flag.checkered", size: 40) {
                    isConfirmingEnd = true
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            Merge2048Board(game: game)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("2048 board")
                .accessibilityValue(boardDescription)
                .accessibilityAction(named: "Slide up") { slide(.up) }
                .accessibilityAction(named: "Slide down") { slide(.down) }
                .accessibilityAction(named: "Slide left") { slide(.left) }
                .accessibilityAction(named: "Slide right") { slide(.right) }
                .overlay(alignment: .top) {
                    if showsWinBanner { winBanner }
                }
                // The square board sits in all the space left, and swipes work anywhere in it.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .gesture(swipe)
            worth
        }
        .padding(12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background { AppBackground(tint: Theme.gold) }
        .overlay { EffectsLayer(effects: effects).ignoresSafeArea() }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle("2048")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.merge2048, isPresented: $showingHelp)
        .confirmationDialog("End this game?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            Button("End and Collect") { endGame(byPlayer: true) }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("You'll collect \(CoinFormat.short(currentWorth)) coins for \(CoinFormat.grouped(game.score)) points.")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: game.merges) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.success, trigger: hasWon) { _, new in haptics && new }
        .sensoryFeedback(trigger: result) { _, new in
            guard haptics, let new else { return nil }
            return new.endedByPlayer ? .success : .error
        }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                store.releaseArcadeRun()
            case .background:
                store.holdArcadeRun(ArcadeRun(game: .merge2048, score: game.score, detail: game.bestTile))
            default:
                break
            }
        }
        .onDisappear {
            if isPlaying { endGame(byPlayer: true) }
        }
        .gameScreen(blocksSwipeBack: true)
    }

    // MARK: Pieces

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: result.endedByPlayer ? "Well Played" : "Game Over", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.payout.isNewBest,
                                    best: store.game.stats.merge2048BestScore, reward: result.payout.coins,
                                    details: result.details, challenge: result.payout.challenge)
                }
            } else {
                GamePanel(title: "2048", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.merge2048BestScore,
                              howTo: "Swipe to slide every tile. Two tiles with the same number merge into one, and the new number is added to your score. Make a 2048 tile for a bonus of \(CoinFormat.short(store.game.merge2048TileBonus)) coins. End the game whenever you like to collect.",
                              showHelp: { showingHelp = true })
                }
            }
        }
    }

    /// What ending the game now would pay.
    private var currentWorth: Double {
        store.game.merge2048Reward(score: game.score, bestTile: game.bestTile)
    }

    private var worth: some View {
        HStack(spacing: 6) {
            Text("Worth so far")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.subtext)
            CoinAmount(amount: currentWorth, font: .headline.monospacedDigit(), iconSize: 18)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .opacity(isPlaying ? 1 : 0)
    }

    private var winBanner: some View {
        VStack(spacing: 2) {
            Text("2048!")
                .font(.title2.weight(.heavy))
            Text("+\(CoinFormat.short(store.game.merge2048TileBonus)) coins when the game ends. Keep going!")
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(Theme.gold.opacity(0.5)), in: .rect(cornerRadius: 20))
        .padding(.top, 10)
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityAddTraits(.isStaticText)
    }

    /// The board read out row by row, for VoiceOver.
    private var boardDescription: String {
        let rows = game.rows.enumerated().map { index, row in
            "Row \(index + 1): " + row.map { $0 == 0 ? "empty" : String($0) }.joined(separator: ", ")
        }
        return (["Score \(game.score)"] + rows).joined(separator: ". ")
    }

    /// Each swipe slides the board once, as soon as it is long enough.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard swipeStart != value.startLocation else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard max(abs(dx), abs(dy)) >= 24 else { return }
                swipeStart = value.startLocation
                slide(abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up))
            }
            .onEnded { _ in swipeStart = nil }
    }

    // MARK: Game flow

    private func start() {
        withAnimation(.snappy(duration: 0.25)) {
            game = .fresh()
        }
        result = nil
        hasWon = false
        showsWinBanner = false
        isPlaying = true
    }

    private func slide(_ direction: SlideDirection) {
        guard isPlaying, !game.isOver else { return }
        var rng = SystemRandomNumberGenerator()
        var next = game
        guard next.slide(direction, using: &rng) else { return }
        withAnimation(Merge2048Board.slideAnimation) {
            game = next
        }
        if game.hasWon && !hasWon { celebrate() }
        if game.isOver {
            // Let the final board show for a moment before the summary.
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                if game.isOver { endGame(byPlayer: false) }
            }
        }
    }

    private func celebrate() {
        hasWon = true
        effects.confetti(120, from: UnitPoint(x: 0.5, y: 0.45))
        effects.coinFountain(20, from: UnitPoint(x: 0.5, y: 0.6))
        withAnimation(.snappy) { showsWinBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.snappy) { showsWinBanner = false }
        }
    }

    private func endGame(byPlayer: Bool) {
        guard isPlaying else { return }
        isPlaying = false
        showsWinBanner = false
        let payout = store.finishMerge2048(score: game.score, bestTile: game.bestTile)
        result = Merge2048Result(score: game.score, bestTile: game.bestTile, payout: payout, endedByPlayer: byPlayer)
    }
}

/// How a 2048 game ended and what it paid.
struct Merge2048Result: Equatable {
    let score: Int
    let bestTile: Int
    let payout: ArcadePayout
    /// The player ended it (or left), rather than running out of moves.
    let endedByPlayer: Bool

    var details: [String] {
        var lines = ["Top tile \(bestTile)"]
        if payout.tileBonus > 0 { lines.append("Includes \(CoinFormat.short(payout.tileBonus)) coins for the 2048 tile") }
        return lines
    }
}

extension Merge2048Game {
    static func fresh() -> Merge2048Game {
        var rng = SystemRandomNumberGenerator()
        return Merge2048Game(using: &rng)
    }
}

/// The 4×4 board: empty cells, then every tile at its cell. Tiles keep their identity as they
/// slide, a merged tile pops, and a tile that merged away slides into its partner before it goes.
struct Merge2048Board: View {
    let game: Merge2048Game
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let slideAnimation = Animation.easeOut(duration: 0.12)

    var body: some View {
        GeometryReader { proxy in
            let size = Merge2048Game.size
            let gap = proxy.size.width * 0.028
            let cell = (proxy.size.width - gap * CGFloat(size + 1)) / CGFloat(size)
            let mergedAway = Set(game.mergedAway.map(\.id))
            ZStack(alignment: .topLeading) {
                ForEach(0..<size * size, id: \.self) { index in
                    RoundedRectangle(cornerRadius: cell * 0.14, style: .continuous)
                        .fill(.white.opacity(0.07))
                        .frame(width: cell, height: cell)
                        .offset(x: gap + CGFloat(index % size) * (cell + gap), y: gap + CGFloat(index / size) * (cell + gap))
                }
                // One list, so a tile that merges away keeps its identity and slides into place.
                ForEach(game.mergedAway + game.tiles) { tile in
                    Merge2048TileView(value: tile.value, side: cell, pops: !reduceMotion)
                        .offset(x: gap + CGFloat(tile.column) * (cell + gap), y: gap + CGFloat(tile.row) * (cell + gap))
                        .zIndex(mergedAway.contains(tile.id) ? 0 : 1)
                        .transition(.asymmetric(
                            insertion: AnyTransition.scale(scale: 0.3).combined(with: .opacity)
                                .animation(.easeOut(duration: 0.14).delay(0.1)),
                            removal: .identity))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Color(red: 0.07, green: 0.08, blue: 0.16).opacity(0.88), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
        }
        .contentShape(.rect)
    }
}

/// One numbered tile. The number always shows; colors climb from cool to warm and end in
/// Bitcoin gold at 2048.
struct Merge2048TileView: View {
    let value: Int
    let side: CGFloat
    var pops = true

    var body: some View {
        let style = Self.style(for: value)
        RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
            .fill(style.background.gradient)
            .overlay {
                RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
            .overlay {
                Text(verbatim: String(value))
                    .font(.system(size: side * Self.fontScale(digits: String(value).count), weight: .heavy, design: .rounded))
                    .foregroundStyle(style.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, side * 0.06)
            }
            .shadow(color: value >= Merge2048Game.winningValue ? Theme.gold.opacity(0.75) : .clear, radius: side * 0.12)
            .frame(width: side, height: side)
            .keyframeAnimator(initialValue: 1.0, trigger: value) { content, scale in
                content.scaleEffect(pops ? scale : 1)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1.0, duration: 0.08)
                    SpringKeyframe(1.14, duration: 0.08)
                    SpringKeyframe(1.0, duration: 0.14)
                }
            }
    }

    static func fontScale(digits: Int) -> CGFloat {
        switch digits {
        case ...2: 0.46
        case 3: 0.38
        case 4: 0.30
        default: 0.24
        }
    }

    /// Background and number colors, with the number at least 4:1 against its tile.
    static func style(for value: Int) -> (background: Color, foreground: Color) {
        let white = Color.white
        return switch value {
        case ...2: (Color(red: 0.91, green: 0.93, blue: 0.97), Color(red: 0.15, green: 0.19, blue: 0.32))
        case 4: (Color(red: 0.80, green: 0.87, blue: 0.98), Color(red: 0.10, green: 0.17, blue: 0.38))
        case 8: (Color(red: 0.00, green: 0.47, blue: 0.52), white)
        case 16: (Color(red: 0.05, green: 0.47, blue: 0.27), white)
        case 32: (Color(red: 0.12, green: 0.38, blue: 0.84), white)
        case 64: (Color(red: 0.33, green: 0.27, blue: 0.84), white)
        case 128: (Color(red: 0.52, green: 0.20, blue: 0.78), white)
        case 256: (Color(red: 0.74, green: 0.13, blue: 0.49), white)
        case 512: (Color(red: 0.80, green: 0.20, blue: 0.12), white)
        case 1_024: (Color(red: 0.72, green: 0.35, blue: 0.00), white)
        case 2_048: (Theme.gold, Color(red: 0.33, green: 0.18, blue: 0.00))
        default: (Color(red: 0.13, green: 0.11, blue: 0.20), Theme.gold)
        }
    }
}
