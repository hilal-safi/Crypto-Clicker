import SwiftUI
import CryptoClickerKit

/// The screens inside Scam Invaders, opened from its start screen.
enum InvadersRoute: Hashable {
    /// A game with these formations, from `startWave` (a wave reached before).
    case play(InvadersGame.WaveStyle, startWave: Int = 1)
}

/// Where Scam Invaders opens, like Brick Breaker: the classic waves, random formations and the
/// difficulty, each on a card. Waves start at any classic wave reached so far, picked on its
/// track; random formations start at wave 1 and don't unlock waves.
struct InvadersView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.invadersDifficultyKey) private var difficulty = InvadersGame.Difficulty.regular
    @AppStorage(Preferences.invadersStartKey) private var pickedStart = 1

    /// The picked wave, kept within those reached.
    private var startWave: Int {
        min(max(pickedStart, 1), store.game.invadersStartWaves.upperBound)
    }
    @State private var showingHelp = false

    var body: some View {
        let stats = store.game.stats
        let tint = MiniGame.invaders.color
        ScrollView {
            VStack(spacing: 14) {
                ModeCard(tint: tint, icon: "square.grid.3x3.fill", title: "Waves",
                         status: stats.invadersClassicBestWave == 0
                            ? "Start at wave 1"
                            : "Best: wave \(CoinFormat.grouped(stats.invadersClassicBestWave)) · \(CoinFormat.grouped(stats.invadersBosses)) Bear\(stats.invadersBosses == 1 ? "" : "s") beaten",
                         detail: "The classic formation, the same every time you play a wave: rug pullers on top, then pump bots and meme coins, marching a little faster and lower every wave. The Bear comes every fifth wave. Start at wave 1 or any wave you've reached here.",
                         note: nil) {
                    VStack(spacing: 12) {
                        LevelTrack(best: stats.invadersClassicBestWave, bossEvery: InvadersGame.bossEvery, tint: tint,
                                   bossSymbol: "pawprint.fill", noun: "wave", bossNote: "The Bear every fifth wave.",
                                   selection: Binding(get: { startWave }, set: { pickedStart = $0 }))
                        StartPay.label(start: startWave, noun: "wave", slope: Tuning.invadersStartPaySlope)
                        NavigationLink(value: InvadersRoute.play(.classic, startWave: startWave)) {
                            Label("Play Wave \(startWave)", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                ModeCard(tint: tint, icon: "dice.fill", title: "Random Waves", status: "A new formation every wave",
                         detail: "Formations made up for every wave, never the same twice: diamonds, arrows, frames, skylines and more, with the three kinds mixed up, and server racks of their own sizes in their own places. They pay about the same, one to three golden invaders show up from the first wave, and the Bear still comes every fifth wave. Waves reached here don't unlock Waves.",
                         note: nil) {
                    NavigationLink(value: InvadersRoute.play(.generated)) {
                        Label("Play Random Waves", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                ModeCard(tint: tint, icon: "slider.horizontal.3", title: "Difficulty",
                         status: "\(difficulty.name) · \(difficulty.hitsPerShip) hit\(difficulty.hitsPerShip == 1 ? "" : "s") a ship",
                         detail: "How many hits your ship takes before it's lost, and how fast the invaders march and everyone fires. A point is worth the same on every difficulty.",
                         note: nil) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(InvadersGame.Difficulty.allCases) { level in
                                Text(level.name).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        Label(difficulty.summary, systemImage: difficulty.speed.icon)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Scam Invaders")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.invaders, isPresented: $showingHelp)
        .gameBackdrop(.invaders)
    }
}

/// Scam Invaders' game: drag anywhere on the field to move the ship, which fires while your finger
/// is down. Scam tokens march down; shoot them all to bring the next, faster wave, and every fifth
/// wave the Bear. The whale and golden invaders drop power-ups to catch. The formations come from
/// the start screen, and the difficulty (hits a ship takes, and the speed) from its setting. The
/// game runs on the display's frame clock while it's on screen.
struct InvadersPlayView: View {
    /// Classic formations or random ones.
    let waves: InvadersGame.WaveStyle
    /// The wave every game here starts at.
    let startWave: Int
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.invadersDifficultyKey) private var difficulty = InvadersGame.Difficulty.regular
    /// The next game's seed: the field behind the start card shows that game's first wave.
    @State private var seed: UInt64
    @State private var game: InvadersGame
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showingHelp = false
    @State private var result: GameResult?
    @State private var lastFrame: Date?
    @State private var effects = Effects()
    /// Points floating up from what was just shot.
    @State private var popups: [InvadersPopup] = []
    /// When the Bear was last hit, for its flash.
    @State private var bossHitAt: Date?
    /// When the ship last took a hit it survived, for its flash.
    @State private var shipHitAt: Date?
    /// The last power-up caught, for the banner.
    @State private var caught: InvadersGame.PowerUp?
    @State private var catches = 0
    /// Counters for haptics.
    @State private var whaleHits = 0
    @State private var bossHits = 0

    private var isRunning: Bool { isPlaying && !isPaused }

    init(waves: InvadersGame.WaveStyle, startWave: Int = 1) {
        self.waves = waves
        self.startWave = startWave
        let seed = UInt64.random(in: 0...UInt64.max)
        _seed = State(initialValue: seed)
        let saved = UserDefaults.standard.string(forKey: Preferences.invadersDifficultyKey)
        let difficulty = saved.flatMap(InvadersGame.Difficulty.init(rawValue:)) ?? .regular
        _game = State(initialValue: InvadersGame(seed: seed, difficulty: difficulty, waves: waves, startWave: startWave))
    }

    var body: some View {
        withLifecycle(withFeedback(layout))
            .gameBackdrop(.invaders)
    }

    /// The score bar (with the streak's combo beside the enemies left), then the field just under it
    /// with the ship's health over the ships left down its left, and the power-ups running down its
    /// right.
    private var layout: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                GameStat(title: "Wave", value: game.isBossWave ? "\(game.wave) · Boss" : "\(game.wave)")
                GameStat(title: "Enemies", value: CoinFormat.grouped(enemiesLeft))
                    .accessibilityLabel("\(enemiesLeft) enemies left")
                InvadersComboStat(game: game)
                Spacer(minLength: 0)
                ArcadeButton(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", size: 40) {
                    if isPlaying { isPaused.toggle() }
                }
                .disabled(!isPlaying)
            }
            .scoreBar()
            .padding(.horizontal, SideColumn.barInset)
            field
                .sideColumns {
                    VStack(spacing: 8) {
                        InvadersHealthColumn(health: game.health, maxHealth: game.maxHealth)
                        LivesColumn(lives: game.lives, total: InvadersGame.startingLives, symbol: "arrowtriangle.up.fill",
                                    emptySymbol: "arrowtriangle.up", color: Theme.gold, label: "\(game.lives) ships left")
                    }
                } trailing: {
                    InvadersPowerUpColumn(game: game)
                }
            ControlHint(game: .invaders)
        }
        .padding(.horizontal, SideColumn.edge)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            if isPaused {
                PausedCard(game: .invaders, resume: { isPaused = false }, showHelp: { showingHelp = true })
            }
        }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle(waves == .generated ? "Random Waves" : "Scam Invaders")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.invaders, isPresented: $showingHelp) {
            if isPlaying { isPaused = true }
        }
    }

    /// Invaders still flying this wave, and the boss while it's there.
    private var enemiesLeft: Int { game.invaders.count + (game.boss == nil ? 0 : 1) }

    /// Haptics for hits, catches and lost ships, and confetti for cleared waves and beaten bosses.
    private func withFeedback(_ view: some View) -> some View {
        view
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: game.invadersDestroyed) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.6), trigger: bossHits) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.impact(weight: .medium), trigger: whaleHits) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.success, trigger: catches) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.warning, trigger: game.hitsTaken) { (old: Int, new: Int) in haptics && new > old }
        .sensoryFeedback(.error, trigger: game.shipsLost) { (old: Int, new: Int) in haptics && new > old }
        .onChange(of: game.phase) { _, new in
            if new == .waveCleared { effects.confetti(80, from: UnitPoint(x: 0.5, y: 0.35)) }
        }
        .onChange(of: game.bossesDefeated) { old, new in
            if new > old { effects.confetti(150, from: UnitPoint(x: 0.5, y: 0.2)) }
        }
    }

    /// Pausing in the background (holding the run so it's paid if iOS closes the app), and ending
    /// the game when the screen goes away.
    private func withLifecycle(_ view: some View) -> some View {
        view
        .onChange(of: isRunning) { _, running in
            lastFrame = nil
            if !running { game.isFiring = false }
        }
        .arcadeLifecycle(isPlaying: isPlaying, pause: {
            isPaused = true
            game.isFiring = false
        }, heldRun: { heldRun }) { endGame() }
    }

    /// The game so far, held while the app is in the background.
    private var heldRun: ArcadeRun {
        ArcadeRun(game: .invaders, score: game.score, detail: game.invadersDestroyed, extra: game.wave,
                  records: .init(powerUps: game.powerUpsCaught, bosses: game.bossesDefeated, bestStreak: game.bestStreak,
                                 bonuses: game.whalesHit, volleys: game.volleysFired, volleysHit: game.volleysHit,
                                 mode: waves == .generated ? 1 : 0, start: startWave))
    }

    private var field: some View {
        withFieldAccessibility(fieldLayers)
    }

    /// The sky, with the banners, the touch area and the bursts over it.
    private var fieldLayers: some View {
        fieldClock
            .aspectRatio(InvadersGame.width / InvadersGame.height, contentMode: .fit)
            .overlay { banner }
            .overlay(alignment: .top) { catchBanner }
            .overlay { touchArea }
            .overlay { EffectsLayer(effects: effects) }
    }

    private var fieldClock: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isRunning && popups.isEmpty)) { timeline in
            InvadersField(game: game, time: timeline.date, reduceMotion: reduceMotion, look: store.game.equipped(.ship),
                          shots: store.game.equipped(.shots), popups: popups, bossHitAt: bossHitAt, shipHitAt: shipHitAt)
                .onChange(of: timeline.date) { _, date in advance(to: date) }
        }
    }

    private var touchArea: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(.rect)
                .gesture(shipGesture(width: proxy.size.width))
        }
    }

    /// VoiceOver reads the field as one element, with actions to move and fire.
    private func withFieldAccessibility(_ view: some View) -> some View {
        let fireName: String = game.isFiring ? "Hold fire" : "Fire"
        return view
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Scam Invaders field"))
            .accessibilityValue(Text(accessibilityValue))
            .accessibilityAction(named: Text("Move left")) { nudge(-0.12) }
            .accessibilityAction(named: Text("Move right")) { nudge(0.12) }
            .accessibilityAction(named: Text(fireName)) {
                if isRunning { game.isFiring.toggle() }
            }
    }

    private var accessibilityValue: String {
        var parts = ["Wave \(game.wave)", "\(game.invaders.count) invaders left", "\(game.lives) ships",
                     "\(game.health) hit\(game.health == 1 ? "" : "s") left on this one"]
        if let boss = game.boss { parts.append("the Bear, \(boss.hitsLeft) of \(boss.maxHits) hits left") }
        if game.whale != nil { parts.append("a whale overhead") }
        if !game.capsules.isEmpty { parts.append("a power-up falling") }
        if !game.enemyShots.isEmpty { parts.append("\(game.enemyShots.count) shots incoming") }
        return parts.joined(separator: ", ")
    }

    private func nudge(_ dx: Double) {
        guard isRunning else { return }
        game.moveShip(to: game.shipX + dx)
    }

    /// The ship follows the finger, and fires while it's down.
    private func shipGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isRunning, width > 0 else { return }
                game.moveShip(to: Double(value.location.x / width) * InvadersGame.width)
                game.isFiring = true
            }
            .onEnded { _ in
                game.isFiring = false
            }
    }

    /// The wave's banner, the cleared wave's bonus, or the lost ship.
    @ViewBuilder
    private var banner: some View {
        if isPlaying {
            Group {
                switch game.phase {
                case .incoming:
                    InvadersBanner(title: game.isBossWave ? "Boss Wave" : "Wave \(game.wave)",
                                   detail: game.isBossWave ? "The Bear is coming" : game.wave == 1 ? "Hold to fire" : nil,
                                   tint: game.isBossWave ? .red : MiniGame.invaders.color)
                case .waveCleared:
                    InvadersBanner(title: "Wave Cleared", detail: "+\(CoinFormat.grouped(game.lastWaveBonus)) bonus", tint: Theme.gain)
                case .shipLost:
                    InvadersBanner(title: "Ship Lost", detail: game.lives == 1 ? "Last ship" : "\(game.lives) ships left", tint: Theme.loss)
                case .playing, .over:
                    EmptyView()
                }
            }
            .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
            .animation(.snappy, value: game.phase)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var catchBanner: some View {
        if let caught, isPlaying {
            Label(caught.name, systemImage: caught.symbol)
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular.tint(caught.color.opacity(0.4)), in: .capsule)
                .padding(.top, 10)
                .id(catches)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var panel: some View {
        if !isPlaying {
            if let result {
                GamePanel(title: "Game Over", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.score, isNewBest: result.isNewBest,
                                    best: store.game.stats.invadersBestScore, reward: result.reward,
                                    details: summaryDetails, challenge: result.challenge, xp: result.xp)
                }
            } else {
                GamePanel(title: "Wave \(startWave)", buttonTitle: "Start", action: start) {
                    GameIntro(best: store.game.stats.invadersBestScore,
                              detail: "\(waves == .generated ? "Random formations" : "Classic formation") · \(difficulty.name)"
                                + StartPay.note(start: startWave, noun: "wave", slope: Tuning.invadersStartPaySlope, separator: " · "))
                }
            }
        }
    }

    private var summaryDetails: [String] {
        let accuracy = Int((game.accuracy * 100).rounded())
        var second = "\(game.whalesHit) whale\(game.whalesHit == 1 ? "" : "s") · best streak \(game.bestStreak) · \(accuracy)% accuracy"
        if game.bossesDefeated > 0 { second = "\(game.bossesDefeated) boss\(game.bossesDefeated == 1 ? "" : "es") beaten · " + second }
        return ["\(CoinFormat.grouped(game.invadersDestroyed)) invaders · reached wave \(game.wave)", second]
    }

    // MARK: Game flow

    private func advance(to date: Date) {
        let isOld = { (popup: InvadersPopup) in date.timeIntervalSince(popup.start) > InvadersPopup.lifetime }
        if popups.contains(where: isOld) { popups.removeAll(where: isOld) }
        guard isRunning else { return }
        let seconds = lastFrame.map { date.timeIntervalSince($0) } ?? 0
        lastFrame = date
        game.update(by: seconds)
        for event in game.events { show(event, at: date) }
        if game.phase == .over { endGame() }
    }

    /// Bursts, floating points and banners for what just happened.
    private func show(_ event: InvadersGame.Event, at date: Date) {
        func point(_ position: Vector2) -> UnitPoint {
            UnitPoint(x: position.x / InvadersGame.width, y: position.y / InvadersGame.height)
        }
        switch event {
        case .invaderDestroyed(let position, let kind, let golden, let points):
            effects.pop(InvadersArt.burst(for: kind, golden: golden), at: point(position))
            popups.append(InvadersPopup(text: "+\(points)", position: position, start: date, color: golden ? Theme.gold : .white))
        case .whaleHit(let position, let points):
            whaleHits += 1
            effects.coinFountain(14, from: point(position))
            popups.append(InvadersPopup(text: "+\(points)", position: position, start: date, color: Theme.gold))
        case .bossHit(let position):
            bossHits += 1
            bossHitAt = date
            effects.pop(.red, at: point(position))
        case .bossDefeated(let position, let points):
            bossHits += 1
            popups.append(InvadersPopup(text: "+\(CoinFormat.grouped(points))", position: position, start: date, color: Theme.gold))
        case .firewallHit(let position):
            if !reduceMotion { effects.pop(.orange, at: point(position)) }
        case .shieldHit(let position):
            effects.pop(.cyan, at: point(position))
            shipHitAt = date
        case .shipDamaged(let position, _):
            effects.pop(.orange, at: point(position))
            effects.pop(.red, at: point(position))
            shipHitAt = date
        case .shipHit(let position):
            effects.pop(.red, at: point(position))
            effects.pop(Theme.gold, at: point(position))
        case .caught(let kind):
            showCatch(kind)
        }
        if popups.count > 24 { popups.removeFirst(popups.count - 24) }
    }

    /// Names the power-up just caught for a moment, then gets out of the way of the whale's lane.
    private func showCatch(_ kind: InvadersGame.PowerUp) {
        catches += 1
        let shown = catches
        withAnimation(.spring(duration: 0.3)) { caught = kind }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if catches == shown { withAnimation(.easeOut(duration: 0.3)) { caught = nil } }
        }
    }

    private func start() {
        game = InvadersGame(seed: seed, difficulty: difficulty, waves: waves, startWave: startWave)
        seed = .random(in: 0...UInt64.max)
        result = nil
        isPaused = false
        lastFrame = nil
        popups = []
        caught = nil
        bossHitAt = nil
        shipHitAt = nil
        isPlaying = true
    }

    private func endGame() {
        guard isPlaying else { return }
        isPlaying = false
        isPaused = false
        game.isFiring = false
        let payout = store.finishInvaders(score: game.score, destroyed: game.invadersDestroyed, wave: game.wave,
                                          whales: game.whalesHit, bosses: game.bossesDefeated, powerUps: game.powerUpsCaught,
                                          bestStreak: game.bestStreak, volleys: game.volleysFired, volleysHit: game.volleysHit,
                                          startWave: startWave, waves: waves)
        result = GameResult(score: game.score, payout: payout, detail: game.invadersDestroyed, xp: store.lastArcadeAward)
    }
}

extension InvadersGame.PowerUp {
    var symbol: String {
        switch self {
        case .rapidFire: "bolt.fill"
        case .spreadShot: "arrow.up.left.and.arrow.down.right"
        case .laser: "line.diagonal"
        case .shield: "shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .rapidFire: .orange
        case .spreadShot: .green
        case .laser: .pink
        case .shield: .cyan
        }
    }
}

/// Points floating up from something shot.
struct InvadersPopup: Identifiable {
    let id = UUID()
    let text: String
    let position: Vector2
    let start: Date
    let color: Color

    static let lifetime: TimeInterval = 0.8
}

/// A banner in the middle of the field: the next wave, a cleared wave or a lost ship.
private struct InvadersBanner: View {
    let title: String
    let detail: String?
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title2.weight(.heavy))
            if let detail {
                Text(detail)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(tint.opacity(0.55)), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

/// The timed power-ups running, as bars side by side, so two at once show which runs out first.
/// (The shield is an extra hit, shown with the ship's health.)
private struct InvadersPowerUpColumn: View {
    let game: InvadersGame

    var body: some View {
        let active = InvadersGame.PowerUp.allCases.filter { $0.duration != nil && game.isActive($0) }
        let timed: [EffectBars.Effect] = active.compactMap { kind in
            guard let duration = kind.duration, let left = game.effects[kind] else { return nil }
            return EffectBars.Effect(id: kind.name, symbol: kind.symbol, color: kind.color, name: kind.name,
                                     secondsLeft: left, duration: duration)
        }
        VStack(spacing: 8) {
            if !timed.isEmpty {
                EffectBars(effects: timed)
            }
        }
        .animation(.snappy, value: active)
    }
}

/// The hits the ship can still take, above the ships left: a heart for each, emptying from the
/// top as it's hit, and the shield's extra hit on top in cyan.
private struct InvadersHealthColumn: View {
    let health: Int
    let maxHealth: Int

    var body: some View {
        let whole = min(health, maxHealth)
        VStack(spacing: 7) {
            if health > maxHealth {
                Image(systemName: "shield.fill")
                    .foregroundStyle(.cyan)
                    .transition(.scale.combined(with: .opacity))
            }
            ForEach(0..<maxHealth, id: \.self) { slot in
                let isFull = maxHealth - slot <= whole
                Image(systemName: isFull ? "heart.fill" : "heart.slash")
                    .foregroundStyle(isFull ? AnyShapeStyle(Color(red: 1, green: 0.32, blue: 0.36)) : AnyShapeStyle(.subtext))
                    .symbolEffect(.bounce, value: isFull)
            }
        }
        .font(.subheadline.weight(.bold))
        .padding(.vertical, 10)
        .frame(width: SideColumn.width)
        .glassEffect(.regular, in: .capsule)
        .animation(.snappy, value: health)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ship health")
        .accessibilityValue("\(whole) of \(maxHealth) hits left" + (health > maxHealth ? ", and a shield" : ""))
    }
}

/// The hit streak's point multiplier in the score bar: ×1 until two hits run together, gold from
/// double. Always there, so the bar doesn't shift as streaks start and end.
private struct InvadersComboStat: View {
    let game: InvadersGame

    var body: some View {
        let multiplier = game.streak >= 2 ? game.streakMultiplier : 1
        VStack(alignment: .leading, spacing: 1) {
            Text("Combo")
                .font(.footnote.weight(.heavy))
                .foregroundStyle(Theme.accent)
                .textCase(.uppercase)
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .opacity(game.streak >= 2 ? 1 : 0.35)
                Text("×\(CoinFormat.compact(multiplier))")
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
            }
            .foregroundStyle(multiplier >= 2 ? AnyShapeStyle(Theme.gold) : game.streak >= 2 ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .animation(.snappy, value: multiplier)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.streak >= 2 ? "Streak \(game.streak), points times \(CoinFormat.compact(multiplier))" : "No streak")
    }
}

/// The night sky, the invaders, the whale, the Bear, the firewalls, every shot, falling power-ups,
/// the ship (blinking just after it arrives, in a bubble with a shield) and the floating points.
private struct InvadersField: View {
    let game: InvadersGame
    let time: Date
    let reduceMotion: Bool
    let look: Cosmetic
    /// The shots picked in Style.
    var shots = Cosmetic.shotsGold
    let popups: [InvadersPopup]
    let bossHitAt: Date?
    let shipHitAt: Date?

    var body: some View {
        Canvas { context, size in
            let scale = size.width / InvadersGame.width
            let seconds = reduceMotion ? 0 : time.timeIntervalSinceReferenceDate
            func rect(_ box: Box) -> CGRect {
                CGRect(x: box.minX * scale, y: box.minY * scale, width: box.width * scale, height: box.height * scale)
            }
            func point(_ vector: Vector2) -> CGPoint { CGPoint(x: vector.x * scale, y: vector.y * scale) }

            drawStars(in: &context, size: size, time: seconds)
            // The line the invaders must not reach.
            var ground = Path()
            let groundY = (InvadersGame.shipTop + InvadersGame.shipSize.height + 0.02) * scale
            ground.move(to: CGPoint(x: 8, y: groundY))
            ground.addLine(to: CGPoint(x: size.width - 8, y: groundY))
            context.stroke(ground, with: .color(Color(red: 1, green: 0.3, blue: 0.3).opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))

            for wall in game.firewalls {
                for row in 0..<wall.rows {
                    for column in 0..<wall.columns where wall.isStanding(row: row, column: column) {
                        InvadersArt.drawServerBlock(in: rect(wall.blockFrame(row: row, column: column)), row: row, column: column,
                                                    columns: wall.columns, context: &context, time: seconds)
                    }
                }
            }
            for invader in game.invaders {
                InvadersArt.drawInvader(invader.kind, golden: invader.isGolden, pose: game.marchPose,
                                        in: rect(game.frame(of: invader)), context: &context, time: seconds)
            }
            if let whale = game.whale {
                InvadersArt.drawWhale(in: rect(whale.frame), facingRight: whale.speedX > 0, context: &context, time: seconds)
            }
            if let boss = game.boss {
                let flash = bossHitAt.map { max(0, 1 - time.timeIntervalSince($0) / 0.15) } ?? 0
                let frame = rect(boss.frame)
                InvadersArt.drawBear(in: frame, flash: reduceMotion ? 0 : flash, context: &context)
                // Health bar above it.
                let bar = CGRect(x: frame.minX, y: frame.minY - 16, width: frame.width, height: 5)
                context.fill(Path(roundedRect: bar, cornerRadius: 2.5), with: .color(.white.opacity(0.25)))
                let share = CGFloat(boss.hitsLeft) / CGFloat(max(1, boss.maxHits))
                context.fill(Path(roundedRect: CGRect(x: bar.minX, y: bar.minY, width: bar.width * share, height: bar.height), cornerRadius: 2.5),
                             with: .color(share > 0.3 ? .green : .red))
            }
            drawShots(in: &context, scale: scale, point: point)
            for capsule in game.capsules {
                let size = InvadersGame.capsuleSize
                let frame = rect(Box(minX: capsule.position.x - size.width / 2, minY: capsule.position.y - size.height / 2,
                                     width: size.width, height: size.height))
                context.fill(Path(roundedRect: frame, cornerRadius: frame.height / 2), with: .color(capsule.kind.color))
                context.stroke(Path(roundedRect: frame, cornerRadius: frame.height / 2), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                var symbol = context.resolve(Image(systemName: capsule.kind.symbol))
                symbol.shading = .color(.white)
                context.draw(symbol, in: frame.insetBy(dx: frame.width * 0.3, dy: frame.height * 0.12))
            }
            drawShip(in: &context, rect: rect(game.ship), time: seconds)
            for popup in popups {
                let age = time.timeIntervalSince(popup.start)
                guard age >= 0, age < InvadersPopup.lifetime else { continue }
                var text = context
                text.opacity = 1 - age / InvadersPopup.lifetime
                let at = point(popup.position)
                text.draw(Text(popup.text).font(.caption.weight(.heavy)).foregroundStyle(popup.color),
                          at: CGPoint(x: at.x, y: at.y - CGFloat(age) * 40))
            }
        }
        .background(Color(red: 0.03, green: 0.02, blue: 0.09), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 16))
    }

    /// Stars at fixed spots, twinkling.
    private func drawStars(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        var rng = SeededGenerator(seed: 77)
        for index in 0..<70 {
            let x = Double.random(in: 0...1, using: &rng) * size.width
            let y = Double.random(in: 0...1, using: &rng) * size.height
            let radius = Double.random(in: 0.4...1.4, using: &rng)
            let speed = Double.random(in: 1...3, using: &rng)
            let twinkle = time == 0 ? 0.7 : 0.35 + 0.65 * (sin(time * speed + Double(index)) + 1) / 2
            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(.white.opacity(0.75 * twinkle)))
        }
    }

    private func drawShots(in context: inout GraphicsContext, scale: CGFloat, point: (Vector2) -> CGPoint) {
        let colors = shots.shotColors
        var glow = context
        glow.addFilter(.shadow(color: colors.glow.opacity(0.9), radius: 4))
        for shot in game.shots {
            let center = point(shot.position)
            if shot.isLaser {
                var beam = Path()
                beam.move(to: CGPoint(x: center.x, y: center.y - 12))
                beam.addLine(to: CGPoint(x: center.x, y: center.y + 12))
                var laser = context
                laser.addFilter(.shadow(color: .pink, radius: 6))
                laser.stroke(beam, with: .color(Color(red: 1, green: 0.55, blue: 0.85)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            } else {
                let width = InvadersGame.shotSize.width * scale, height = InvadersGame.shotSize.height * scale
                glow.fill(Path(roundedRect: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height),
                               cornerRadius: width / 2), with: .color(colors.fill))
            }
        }
        // The invaders' shots: drawn a little bigger than what they hit with, outlined and glowing,
        // so they stand out against everything.
        for shot in game.enemyShots {
            let center = point(shot.position)
            let height = InvadersGame.enemyShotSize.height * scale * 1.3
            switch shot.shooter {
            case .memeCoin:
                let radius = height * 0.34
                let orb = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                var lit = context
                lit.addFilter(.shadow(color: .orange, radius: 5))
                lit.fill(orb, with: .radialGradient(Gradient(colors: [.yellow, .orange]), center: center, startRadius: 0, endRadius: radius))
                context.stroke(orb, with: .color(.black.opacity(0.6)), lineWidth: 1)
            case .pumpBot, .rugPuller:
                // A crackling zigzag bolt over a dark core.
                var bolt = Path()
                let steps = 4
                for step in 0...steps {
                    let y = center.y - height / 2 + height * CGFloat(step) / CGFloat(steps)
                    let x = center.x + (step % 2 == 0 ? -1 : 1) * height * 0.2
                    if step == 0 { bolt.move(to: CGPoint(x: x, y: y)) } else { bolt.addLine(to: CGPoint(x: x, y: y)) }
                }
                let color = shot.shooter == .pumpBot ? Color(red: 0.5, green: 1, blue: 0.5) : Color(red: 1, green: 0.5, blue: 0.95)
                context.stroke(bolt, with: .color(.black.opacity(0.55)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                var lit = context
                lit.addFilter(.shadow(color: color, radius: 5))
                lit.stroke(bolt, with: .color(color), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
            case nil:
                var orb = context
                orb.addFilter(.shadow(color: .red, radius: 7))
                let radius = height * 0.42
                let ball = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                orb.fill(ball, with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.6), Color(red: 1, green: 0.3, blue: 0.25)]),
                                                     center: center, startRadius: 0, endRadius: radius))
                context.stroke(ball, with: .color(.black.opacity(0.5)), lineWidth: 1)
            }
        }
    }

    private func drawShip(in context: inout GraphicsContext, rect: CGRect, time: TimeInterval) {
        guard game.phase != .over else { return }
        if game.phase == .shipLost { return }
        // Blinking while new.
        if game.invulnerableFor > 0 && Int(game.invulnerableFor * 10) % 2 == 0 && !reduceMotion { return }
        var ship = context
        if game.invulnerableFor > 0 && reduceMotion { ship.opacity = 0.5 }
        InvadersArt.drawShip(look, in: rect, context: &ship, time: time)
        let lost = game.maxHealth - min(game.health, game.maxHealth)
        if lost > 0 {
            InvadersArt.drawDamage(Double(lost) / Double(game.maxHealth), cracks: lost, in: rect, context: &ship,
                                   time: reduceMotion ? 0 : time)
        }
        // A red flash as a hit lands.
        if let shipHitAt, !reduceMotion {
            let flash = max(0, 1 - self.time.timeIntervalSince(shipHitAt) / 0.3)
            if flash > 0 {
                context.fill(Path(ellipseIn: rect.insetBy(dx: -rect.width * 0.1, dy: -rect.height * 0.3)),
                             with: .color(.red.opacity(0.45 * flash)))
            }
        }
        if game.hasShield {
            let bubble = rect.insetBy(dx: -rect.width * 0.18, dy: -rect.height * 0.5)
            var shield = context
            shield.addFilter(.shadow(color: .cyan, radius: 6))
            shield.stroke(Path(ellipseIn: bubble), with: .color(.cyan.opacity(0.85)), lineWidth: 2)
            context.fill(Path(ellipseIn: bubble), with: .color(.cyan.opacity(0.12)))
        }
    }
}
