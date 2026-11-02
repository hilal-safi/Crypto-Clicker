import SwiftUI
import CryptoClickerKit

/// A game of Token Swap in one of its modes: Classic (a minute on the clock, paid per point), a
/// level (goals in a limited number of moves, up to three stars), the daily puzzle, or a random
/// level (made up from a seed, paid per point with a bonus for a win). The rules live in
/// `TokenSwapGame`; this view runs the clock, animates each wave and pays the result.
struct TokenSwapPlayView: View {
    typealias Position = TokenSwapGame.Position

    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var route: TokenSwapRoute
    @State private var game: TokenSwapGame
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showingHelp = false
    @State private var classicResult: GameResult?
    @State private var outcome: Outcome?
    /// The token tapped first, waiting for a neighbor to swap with.
    @State private var selected: Position?
    @State private var refused: Set<Int> = []
    @State private var nudge: TokenSwapBoardView.Nudge?
    @State private var effects: [BoardEffect] = []
    @State private var popups: [BoardPopup] = []
    @State private var nextEffectID = 0
    @State private var resolveTask: Task<Void, Never>?
    /// Seconds since the last swap, to point out a move when the player is stuck.
    @State private var idle: TimeInterval = 0
    /// The move pointed out, worked out once the player has been idle a while.
    @State private var hintMove: [Position] = []
    /// The wave on screen, for the chain counter.
    @State private var chain = 0
    // Haptic triggers.
    @State private var waves = 0
    @State private var blasts = 0
    @State private var refusals = 0
    @State private var finishes = 0

    /// How a level or the daily puzzle ended, and what it paid.
    struct Outcome: Equatable {
        let won: Bool
        let score: Int
        let stars: Int
        let newStars: Int
        let coins: Double
        let isNewBest: Bool
        let bonusPoints: Int
        let progress: [(goal: TokenSwapGame.Goal, done: Int)]

        static func == (lhs: Outcome, rhs: Outcome) -> Bool {
            lhs.won == rhs.won && lhs.score == rhs.score && lhs.stars == rhs.stars && lhs.coins == rhs.coins
        }
    }

    init(route: TokenSwapRoute) {
        _route = State(initialValue: route)
        _game = State(initialValue: Self.newGame(for: route))
    }

    private var isRunning: Bool { isPlaying && !isPaused }

    private var level: TokenSwapLevel? {
        switch route {
        case .level(let id): TokenSwapLevel.number(id)
        case .daily(let day): TokenSwapLevel.daily(day: day)
        case .random(let seed, let difficulty): TokenSwapLevel.generated(seed: seed, difficulty: difficulty)
        case .classic, .levels: nil
        }
    }

    private var isRandom: Bool {
        if case .random = route { true } else { false }
    }

    private var isDaily: Bool {
        if case .daily = route { true } else { false }
    }

    var body: some View {
        VStack(spacing: 10) {
            if game.isClassic { classicHUD } else { levelHUD }
            TokenSwapBoardView(game: game, selected: selected, hinted: hinted, refused: refused, nudge: nudge,
                               effects: effects, popups: popups, reduceMotion: reduceMotion,
                               isInteractive: isRunning && !game.isResolving,
                               onSwap: attemptSwap, onTap: tap)
                .frame(maxHeight: .infinity)
            SpecialsLegend()
        }
        .padding(12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background { AppBackground(tint: MiniGame.tokenSwap.color) }
        .overlay {
            if isPaused {
                PausedCard(game: .tokenSwap, resume: { isPaused = false }, showHelp: { showingHelp = true })
            }
        }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.tokenSwap, isPresented: $showingHelp) {
            if isPlaying { isPaused = true }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: waves) { _, _ in haptics }
        .sensoryFeedback(.impact(weight: .heavy), trigger: blasts) { _, _ in haptics }
        .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
        .sensoryFeedback(trigger: finishes) { _, _ in
            guard haptics, let outcome else { return nil }
            return outcome.won ? .success : .error
        }
        .task(id: isRunning) { await run() }
        .onChange(of: scenePhase) { _, phase in
            guard isPlaying else { return }
            switch phase {
            case .active:
                if game.isClassic { store.releaseArcadeRun() }
            case .background:
                isPaused = true
                if game.isClassic {
                    store.holdArcadeRun(ArcadeRun(game: .tokenSwap, score: game.score, detail: game.tokensCleared,
                                                  extra: game.bestChain))
                }
            default:
                isPaused = true
            }
        }
        .onDisappear {
            resolveTask?.cancel()
            guard isPlaying else { return }
            if game.isClassic {
                endClassic() // A Classic round pays what it scored.
            } else {
                // Waves still falling finish; a level that's won (or lost) by them is settled, and one
                // left halfway just ends.
                game.resolveAll()
                if game.phase != .playing { finishLevel() }
            }
        }
        .gameScreen(blocksSwipeBack: true)
    }

    private var title: String {
        switch route {
        case .level(let id): "Level \(id)"
        case .daily: "Daily Puzzle"
        case .random: "Random Level"
        case .classic, .levels: "Token Swap"
        }
    }

    // MARK: Heads-up display

    private var classicHUD: some View {
        VStack(spacing: 8) {
            HStack(spacing: 18) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Chain", value: chain > 1 ? "×\(chain)" : "–")
                GameStat(title: "Time", value: "\(Int(game.timeLeft.rounded(.up)))s")
                Spacer(minLength: 0)
                pauseButton
            }
            .scoreBar()
            ProgressView(value: game.timeLeft, total: TokenSwapGame.roundLength)
                .tint(game.timeLeft < 10 ? Theme.loss : MiniGame.tokenSwap.color)
                .accessibilityLabel("Time left")
                .accessibilityValue("\(Int(game.timeLeft.rounded(.up))) seconds")
        }
    }

    private var levelHUD: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text("\(game.movesLeft ?? 0)")
                        .font(.title.bold().monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle((game.movesLeft ?? 0) <= 3 ? Theme.loss : .primary)
                    Text("moves")
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(Theme.accent)
                        .textCase(.uppercase)
                }
                .frame(minWidth: 54)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Moves left")
                .accessibilityValue("\(game.movesLeft ?? 0)")
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                        if chain > 1 {
                            Text("Chain ×\(chain)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    if let level { StarMeter(score: game.score, thresholds: level.starScores) }
                }
                Spacer(minLength: 0)
                pauseButton
            }
            .scoreBar()
            GoalStrip(goals: game.goals.map { ($0, game.progress($0)) })
        }
    }

    private var pauseButton: some View {
        ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
            if isPlaying { isPaused.toggle() }
        }
        .disabled(!isPlaying)
    }

    /// The move to point out after a few seconds without one.
    private var hinted: Set<Position> {
        guard isRunning, !game.isResolving else { return [] }
        return Set(hintMove)
    }

    // MARK: Panels

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let outcome, let level {
                outcomePanel(outcome, level: level)
            } else if let classicResult {
                GamePanel(title: "Time's Up", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: classicResult.score, isNewBest: classicResult.isNewBest,
                                    best: store.game.stats.tokenSwapBestScore, reward: classicResult.reward,
                                    details: ["\(CoinFormat.grouped(classicResult.detail)) tokens · \(game.specialsSetOff) specials · longest chain \(game.bestChain)"],
                                    challenge: classicResult.challenge)
                }
            } else if let level {
                startPanel(level)
            } else {
                GamePanel(title: "Classic", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.tokenSwapBestScore,
                              detail: "A minute on the clock. Every point pays coins.")
                }
            }
        }
    }

    private func startPanel(_ level: TokenSwapLevel) -> some View {
        let isLevel = !isDaily && !isRandom
        let best = isLevel ? store.game.tokenSwap.stars(for: level.id) : 0
        return GamePanel(title: isDaily ? "Daily Puzzle" : isRandom ? "Random Level" : "Level \(level.id)", buttonTitle: "Play", action: start) {
            VStack(spacing: 14) {
                Text(level.name)
                    .font(.title2.bold())
                if isLevel && best > 0 { StarRow(stars: best, size: 22) }
                GoalList(goals: level.goals.map { ($0, 0) }, showsProgress: false)
                HStack(spacing: 8) {
                    LevelFact(text: "\(level.moves) moves", systemImage: "hand.draw.fill", color: .blue)
                    LevelFact(text: level.difficulty.name, systemImage: level.difficulty.symbol, color: level.difficulty.color)
                }
                Label {
                    Text(level.tip)
                } icon: {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Theme.gold)
                }
                .font(.body.weight(.medium))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(MiniGame.tokenSwap.color.opacity(0.18), in: .rect(cornerRadius: 14))
                Label(rewardLine(for: level, isDaily: isDaily), systemImage: "bitcoinsign.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                if isRandom {
                    Button("Another Level", systemImage: "dice.fill", action: newRandomLevel)
                        .buttonStyle(.glass)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private func rewardLine(for level: TokenSwapLevel, isDaily: Bool) -> String {
        if isRandom {
            return "Every point pays coins, and a win pays \(CoinFormat.short(store.game.tokenSwapRandomWinBonus(level.difficulty))) more."
        }
        if isDaily, case .daily(let day) = route {
            return store.game.tokenSwap.hasWonDaily(day: day)
                ? "Solved today: this one's for fun."
                : "Win for \(CoinFormat.short(store.game.tokenSwapDailyReward)) coins, once today."
        }
        let earned = store.game.tokenSwap.stars(for: level.id)
        guard earned < 3 else { return "All three stars earned." }
        let left = ((earned + 1)...3).reduce(0.0) { $0 + store.game.tokenSwapStarReward(level, star: $1) }
        return "\(3 - earned) star\(3 - earned == 1 ? "" : "s") left to earn: \(CoinFormat.short(left)) coins."
    }

    @ViewBuilder
    private func outcomePanel(_ outcome: Outcome, level: TokenSwapLevel) -> some View {
        if isRandom {
            randomOutcomePanel(outcome)
        } else if outcome.won {
            let next = TokenSwapLevel.number(level.id + 1)
            GamePanel(title: isDaily ? "Puzzle Solved!" : "Level Complete!",
                      buttonTitle: !isDaily && next != nil ? "Next Level" : "Play Again",
                      action: !isDaily && next != nil ? { goToNextLevel() } : { start() }) {
                VStack(spacing: 10) {
                    StarRow(stars: outcome.stars, size: 34, animated: !reduceMotion)
                    Text(CoinFormat.grouped(outcome.score))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                    if outcome.bonusPoints > 0 {
                        Text("Includes \(CoinFormat.grouped(outcome.bonusPoints)) for moves left")
                            .font(.subheadline)
                            .foregroundStyle(.subtext)
                    }
                    if outcome.isNewBest {
                        Label("New best score!", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                    }
                    if outcome.coins > 0 {
                        HStack(spacing: 8) {
                            Text(isDaily ? "Today's reward" : (outcome.newStars == 1 ? "New star" : "New stars"))
                                .font(.title3.weight(.semibold))
                            CoinAmount(amount: outcome.coins, font: .title2.bold(), iconSize: 26)
                        }
                    } else {
                        Text(isDaily ? "Today's reward was already paid." : (outcome.stars < 3 ? "Score more for another star." : "Every star earned."))
                            .font(.subheadline)
                            .foregroundStyle(.subtext)
                    }
                    secondaryButtons(replay: !isDaily && next != nil)
                }
            }
        } else {
            GamePanel(title: "Out of Moves", buttonTitle: "Try Again", action: start) {
                VStack(spacing: 12) {
                    Text("So close. Here's how far you got:")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                    GoalList(goals: outcome.progress, showsProgress: true)
                    Text("Score \(CoinFormat.grouped(outcome.score))")
                        .font(.headline)
                    secondaryButtons(replay: false)
                }
            }
        }
    }

    /// A finished random level: what it scored and paid, with a new level one tap away.
    private func randomOutcomePanel(_ outcome: Outcome) -> some View {
        GamePanel(title: outcome.won ? "Level Complete!" : "Out of Moves", buttonTitle: "New Level", action: newRandomLevel) {
            VStack(spacing: 10) {
                if outcome.won { StarRow(stars: outcome.stars, size: 30, animated: !reduceMotion) }
                Text(CoinFormat.grouped(outcome.score))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                if !outcome.won {
                    GoalList(goals: outcome.progress, showsProgress: true)
                }
                HStack(spacing: 8) {
                    Text("You earned")
                        .font(.title3.weight(.semibold))
                    CoinAmount(amount: outcome.coins, font: .title2.bold(), iconSize: 26)
                }
                HStack(spacing: 10) {
                    Button("Retry", systemImage: "arrow.counterclockwise", action: start)
                        .buttonStyle(.glass)
                    Button("Done", systemImage: "checkmark") { dismiss() }
                        .buttonStyle(.glass)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func secondaryButtons(replay: Bool) -> some View {
        let isLevel = if case .level = route { true } else { false }
        return HStack(spacing: 10) {
            if replay {
                Button("Replay", systemImage: "arrow.counterclockwise", action: start)
                    .buttonStyle(.glass)
            }
            Button(isLevel ? "Levels" : "Done", systemImage: isLevel ? "square.grid.2x2" : "checkmark") { dismiss() }
                .buttonStyle(.glass)
        }
        .font(.subheadline.weight(.semibold))
    }

    // MARK: Moves

    private func tap(_ position: Position) {
        guard isRunning else { return }
        if let selected, selected.isNeighbor(of: position) {
            attemptSwap(selected, position)
        } else {
            withAnimation(.snappy(duration: 0.15)) { selected = selected == position ? nil : position }
        }
    }

    private func attemptSwap(_ a: Position, _ b: Position) {
        guard isRunning, !game.isResolving, a.isOnBoard, b.isOnBoard else { return }
        selected = nil
        idle = 0
        hintMove = []
        if game.isValidSwap(a, b) {
            withAnimation(.snappy(duration: reduceMotion ? 0.1 : 0.2)) { _ = game.swap(a, b) }
            resolveTask = Task { await resolve() }
        } else {
            refuse(a, b)
        }
    }

    /// A swap that isn't a move: the two tiles lean toward each other and back, outlined in red.
    private func refuse(_ a: Position, _ b: Position) {
        refusals += 1
        let ids = Set([game.cell(at: a).tile?.id, game.cell(at: b).tile?.id].compactMap { $0 })
        if let first = game.cell(at: a).tile?.id, let second = game.cell(at: b).tile?.id, a.isNeighbor(of: b) {
            withAnimation(.snappy(duration: 0.12)) {
                nudge = TokenSwapBoardView.Nudge(first: first, second: second, dRow: b.row - a.row, dColumn: b.column - a.column)
            }
        }
        withAnimation(.snappy(duration: 0.12)) { refused = ids }
        Task {
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(.snappy(duration: 0.2)) { nudge = nil }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.snappy(duration: 0.2)) { refused.subtract(ids) }
        }
    }

    /// Clears wave after wave, pausing between them so each can be seen; then decides the game.
    private func resolve() async {
        while game.isResolving {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 220))
            guard !Task.isCancelled else { return }
            let wave = withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.26)) { game.resolveStep() }
            guard let step = wave else { break }
            chain = step.chain
            waves += 1
            if step.blasts > 0 || !step.made.isEmpty { blasts += 1 }
            show(step)
        }
        withAnimation(.snappy) { chain = 0 }
        if game.isClassic {
            if game.isOver { endClassic() }
        } else if game.phase != .playing {
            finishLevel()
        }
    }

    private func show(_ step: TokenSwapGame.Step) {
        let now = Date.now
        effects.removeAll { now.timeIntervalSince($0.born) > $0.duration }
        let fresh = BoardEffect.effects(for: step, startingAt: nextEffectID, at: now)
        nextEffectID += fresh.count
        effects += fresh
        guard !step.cleared.isEmpty else { return }
        let x = step.cleared.reduce(0.0) { $0 + Double($1.column) } / Double(step.cleared.count) + 0.5
        let y = step.cleared.reduce(0.0) { $0 + Double($1.row) } / Double(step.cleared.count) + 0.5
        popups.removeAll { now.timeIntervalSince($0.born) > 1 }
        popups.append(BoardPopup(id: nextEffectID, text: "+\(CoinFormat.grouped(step.points))", x: x, y: y,
                                 isBig: step.blasts > 0, born: now))
        nextEffectID += 1
        if step.chain >= 2 {
            popups.append(BoardPopup(id: nextEffectID, text: "Chain ×\(step.chain)", x: x, y: y - 0.7, isBig: true, born: now))
            nextEffectID += 1
        }
    }

    // MARK: Game flow

    static func newGame(for route: TokenSwapRoute) -> TokenSwapGame {
        switch route {
        case .level(let id):
            TokenSwapGame(level: TokenSwapLevel.number(id) ?? TokenSwapLevel.all[0], refillSeed: .random(in: 0...UInt64.max))
        case .daily(let day):
            TokenSwapGame(level: TokenSwapLevel.daily(day: day), mode: .daily(day), refillSeed: TokenSwapLevel.dailyRefillSeed(day: day))
        case .random(let seed, let difficulty):
            TokenSwapGame(level: TokenSwapLevel.generated(seed: seed, difficulty: difficulty), refillSeed: .random(in: 0...UInt64.max))
        case .classic, .levels:
            TokenSwapGame(seed: .random(in: 0...UInt64.max))
        }
    }

    private func start() {
        resolveTask?.cancel()
        game = Self.newGame(for: route)
        effects = []
        popups = []
        classicResult = nil
        outcome = nil
        selected = nil
        refused = []
        nudge = nil
        chain = 0
        idle = 0
        hintMove = []
        isPaused = false
        isPlaying = true
    }

    /// A fresh random level at the same difficulty, waiting on its start card.
    private func newRandomLevel() {
        guard case .random(_, let difficulty) = route else { return }
        resolveTask?.cancel()
        route = .random(seed: .random(in: 0...UInt64.max), difficulty: difficulty)
        game = Self.newGame(for: route)
        outcome = nil
        effects = []
        popups = []
        isPlaying = false
    }

    private func goToNextLevel() {
        guard case .level(let id) = route, TokenSwapLevel.number(id + 1) != nil else { return }
        route = .level(id + 1)
        game = Self.newGame(for: route)
        outcome = nil
        effects = []
        popups = []
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
            if idle >= 6, hintMove.isEmpty, !game.isResolving, let (a, b) = game.hint { hintMove = [a, b] }
            last = now
            if !popups.isEmpty { popups.removeAll { now.timeIntervalSince($0.born) > 1 } }
            if !effects.isEmpty { effects.removeAll { now.timeIntervalSince($0.born) > $0.duration } }
            if game.isClassic && game.isOver {
                endClassic()
                return
            }
        }
    }

    private func endClassic() {
        guard isPlaying else { return }
        resolveTask?.cancel()
        game.resolveAll() // Waves still falling count.
        isPlaying = false
        isPaused = false
        selected = nil
        chain = 0
        let payout = store.finishTokenSwap(score: game.score, tokens: game.tokensCleared, bestChain: game.bestChain,
                                           blasts: game.specialsSetOff)
        classicResult = GameResult(score: game.score, payout: payout, detail: game.tokensCleared)
    }

    /// Pays a finished level or daily puzzle, once.
    private func finishLevel() {
        guard isPlaying, let level else { return }
        isPlaying = false
        isPaused = false
        selected = nil
        let won = game.phase == .won
        let progress = game.goals.map { (goal: $0, done: game.progress($0)) }
        switch route {
        case .daily(let day):
            let coins = store.finishTokenSwapDaily(day: day, game: game)
            outcome = Outcome(won: won, score: game.score, stars: level.stars(won: won, score: game.score), newStars: 0,
                              coins: coins, isNewBest: false, bonusPoints: game.bonusPoints, progress: progress)
        case .random:
            let coins = store.finishTokenSwapRandom(level, game: game)
            outcome = Outcome(won: won, score: game.score, stars: level.stars(won: won, score: game.score), newStars: 0,
                              coins: coins, isNewBest: false, bonusPoints: game.bonusPoints, progress: progress)
        default:
            let payout = store.finishTokenSwapLevel(level, game: game)
            outcome = Outcome(won: won, score: game.score, stars: payout.stars, newStars: payout.newStars, coins: payout.coins,
                              isNewBest: payout.isNewBest, bonusPoints: game.bonusPoints, progress: progress)
        }
        finishes += 1
    }
}

// MARK: - Pieces

/// How close the score is to the second and third stars (winning earns the first).
private struct StarMeter: View {
    let score: Int
    let thresholds: [Int]

    var body: some View {
        let top = Double(thresholds.last ?? 1)
        HStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(Theme.gold.gradient)
                        .frame(width: width * min(1, Double(score) / max(1, top)))
                    ForEach(thresholds, id: \.self) { mark in
                        Rectangle()
                            .fill(.white.opacity(0.8))
                            .frame(width: 2)
                            .offset(x: width * Double(mark) / max(1, top) - 1)
                    }
                }
            }
            .frame(height: 6)
            HStack(spacing: 1) {
                ForEach(thresholds.indices, id: \.self) { index in
                    Image(systemName: score >= thresholds[index] ? "star.fill" : "star")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(score >= thresholds[index] ? Theme.gold : .secondary)
                }
            }
        }
        .animation(.snappy, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Star score")
        .accessibilityValue(thresholds.map { score >= $0 ? "\($0) reached" : "\($0) to go" }.joined(separator: ", "))
    }
}

/// The goals and how far each has come, in a row under the score.
private struct GoalStrip: View {
    let goals: [(goal: TokenSwapGame.Goal, done: Int)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(goals.indices, id: \.self) { index in
                let (goal, done) = goals[index]
                let finished = done >= goal.target
                HStack(spacing: 6) {
                    GoalIcon(goal: goal, size: 22)
                    if finished {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.gain)
                    } else {
                        Text(isScore(goal) ? CoinFormat.grouped(goal.target - done) : "\(goal.target - done)")
                            .font(.headline.monospacedDigit())
                            .contentTransition(.numericText())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.tint(finished ? Theme.gain.opacity(0.25) : .clear), in: .capsule)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(goal.description)
                .accessibilityValue(finished ? "Done" : "\(goal.target - done) to go")
            }
        }
        .animation(.snappy, value: goals.map(\.done))
    }

    private func isScore(_ goal: TokenSwapGame.Goal) -> Bool {
        if case .score = goal { return true }
        return false
    }
}

/// Goals written out, for the start and end of a level.
private struct GoalList: View {
    let goals: [(goal: TokenSwapGame.Goal, done: Int)]
    let showsProgress: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(goals.indices, id: \.self) { index in
                let (goal, done) = goals[index]
                HStack(spacing: 10) {
                    GoalIcon(goal: goal, size: 24)
                    Text(goal.description)
                        .font(.headline)
                    Spacer(minLength: 8)
                    if showsProgress {
                        Text(done >= goal.target ? "Done" : "\(CoinFormat.grouped(done)) / \(CoinFormat.grouped(goal.target))")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(done >= goal.target ? Theme.gain : .subtext)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: 320)
    }
}

/// What makes each special, under the board: one line when it fits, two when it doesn't.
private struct SpecialsLegend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { items }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    item("Square", "fanblades.fill", .teal)
                    item("4 in a row", "arrow.left.and.right", .orange)
                }
                GridRow {
                    item("L or T", "flame.fill", .red)
                    item("5 in a row", "sparkles", .purple)
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A square makes a Propeller, four in a row a Rocket, an L or T a Bomb, and five in a row a Color Clear.")
    }

    @ViewBuilder private var items: some View {
        item("Square", "fanblades.fill", .teal)
        item("4 in a row", "arrow.left.and.right", .orange)
        item("L or T", "flame.fill", .red)
        item("5 in a row", "sparkles", .purple)
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

/// A fact about a level on its start card: the moves, or the difficulty.
private struct LevelFact: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
        }
        .font(.headline)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.18), in: .capsule)
    }
}

extension TokenSwapLevel.Difficulty {
    /// A gauge for the difficulty, fuller as it gets harder.
    var symbol: String {
        switch self {
        case .easy: "gauge.with.dots.needle.0percent"
        case .medium: "gauge.with.dots.needle.50percent"
        case .hard: "gauge.with.dots.needle.100percent"
        }
    }

    var color: Color {
        switch self {
        case .easy: Theme.gain
        case .medium: .orange
        case .hard: Theme.loss
        }
    }
}
