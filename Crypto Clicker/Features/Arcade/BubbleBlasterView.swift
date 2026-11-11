import SwiftUI
import CryptoClickerKit

/// The screens inside Bubble Market, opened from its start screen.
enum BubbleRoute: Hashable {
    /// Wave after wave until the market crashes.
    case waves
    /// Two minutes, with rows on the clock.
    case flash
    /// Waves from the day's market: everyone starts with the same bubbles all day.
    case todaysMarket(day: String)

    var mode: BubbleShooterGame.Mode { self == .flash ? .flash : .waves }

    var title: String {
        switch self {
        case .waves: MiniGame.bubbleBlaster.name
        case .flash: "Flash Market"
        case .todaysMarket: "Today's Market"
        }
    }
}

/// How much of a shot's path the aiming guide shows: all of it, bounces and landing ring, or only
/// up to the first bounce, for a harder game.
enum BubbleAimGuide: String, CaseIterable, Identifiable {
    case full, short

    var id: String { rawValue }

    var name: String {
        switch self {
        case .full: "Full path"
        case .short: "First bounce"
        }
    }
}

/// Where Bubble Market opens, like the other arcade games: Waves, Flash Market, Today's Market and
/// the settings (the shots' speed and the aiming guide), each on a card.
struct BubbleBlasterView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.bubbleSpeedKey) private var speed = GameSpeed.normal
    @AppStorage(Preferences.bubbleAimKey) private var aimGuide = BubbleAimGuide.full
    @State private var showingHelp = false

    private let tint = MiniGame.bubbleBlaster.color

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                wavesCard
                flashCard
                todayCard
                settingsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(MiniGame.bubbleBlaster.name)
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.bubbleBlaster, isPresented: $showingHelp)
        .gameBackdrop(.bubbleBlaster)
    }

    private var wavesCard: some View {
        let stats = store.game.stats
        return ModeCard(tint: tint, icon: "water.waves", title: "Waves",
                        status: stats.bubbleBestScore > 0
                            ? "Best \(CoinFormat.grouped(stats.bubbleBestScore)) · wave \(stats.bubbleBestWave)"
                            : "Start at wave 1",
                        detail: "Pop three of a kind and clear the market for the next wave, with another token each time. Every \(BubbleShooterGame.missesPerRow) shots that pop nothing push a new row down; the game ends at the crash line.",
                        note: nil) {
            playLink(.waves, title: "Play Waves")
        }
    }

    private var flashCard: some View {
        let best = store.game.stats.bubbleFlashBestScore
        return ModeCard(tint: tint, icon: "bolt.fill", title: "Flash Market",
                        status: best > 0 ? "Best \(CoinFormat.grouped(best))" : "\(Int(BubbleShooterGame.flashLength / 60)) minutes on the clock",
                        detail: "\(Int(BubbleShooterGame.flashLength / 60)) minutes to score all you can. A new row drops every \(Int(BubbleShooterGame.flashRowEvery)) seconds whatever you shoot, a second sooner each wave, and a miss only costs the streak.",
                        note: nil) {
            playLink(.flash, title: "Play Flash Market")
        }
    }

    private var todayCard: some View {
        let today = store.today
        let popDay = store.game.dailyChallenge(today: today).flatMap { $0.kind == .bubbleBlaster && !$0.isComplete ? $0.goal : nil }
        return ModeCard(tint: tint, icon: "calendar", title: "Today's Market",
                        status: popDay.map { "Pop Day: \($0)" } ?? "The same market for everyone today",
                        detail: "Waves from today's market: everyone starts with the same bubbles, all day. Scores count toward your Waves best.",
                        note: nil) {
            playLink(.todaysMarket(day: today), title: "Play Today's Market")
        }
    }

    private var settingsCard: some View {
        ModeCard(tint: tint, icon: "slider.horizontal.3", title: "Settings",
                 status: "\(speed.name) shots · \(aimGuide.name)",
                 detail: "How fast shots fly, and how much of their path the guide shows. Neither changes what a point pays.",
                 note: nil) {
            VStack(spacing: 12) {
                Picker("Shot speed", selection: $speed) {
                    ForEach(GameSpeed.allCases) { speed in
                        Text(speed.name).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Aiming guide", selection: $aimGuide) {
                    ForEach(BubbleAimGuide.allCases) { guide in
                        Text(guide.name).tag(guide)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func playLink(_ route: BubbleRoute, title: LocalizedStringKey) -> some View {
        NavigationLink(value: route) {
            Label(title, systemImage: "play.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
    }
}

/// Bubble Market's game, with token bubbles and a crash line: drag on the field to aim (a guide
/// shows the path and a ring marks where the bubble will stick, or only the first bounce with the
/// short guide), lift to fire. Tap the loaded bubble to swap it with the next one. Waves and
/// Today's Market bring rows with misses; Flash Market brings them on its two-minute clock. Shots
/// come from one generator, seeded by the day for Today's Market.
struct BubblePlayView: View {
    typealias Special = BubbleShooterGame.Special

    let route: BubbleRoute
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.bubbleSpeedKey) private var speed = GameSpeed.normal
    @AppStorage(Preferences.bubbleAimKey) private var aimGuide = BubbleAimGuide.full
    @State private var rng: SeededGenerator
    @State private var game: BubbleShooterGame
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

    init(route: BubbleRoute) {
        self.route = route
        var rng = Self.generator(for: route)
        let speed = GameSpeed(rawValue: UserDefaults.standard.string(forKey: Preferences.bubbleSpeedKey) ?? "") ?? .normal
        _game = State(initialValue: BubbleShooterGame(mode: route.mode, speed: speed, using: &rng))
        _rng = State(initialValue: rng)
    }

    /// Today's Market draws from the day's seed; the other games at random.
    static func generator(for route: BubbleRoute) -> SeededGenerator {
        if case .todaysMarket(let day) = route { return SeededGenerator(seed: GameState.dailyChallengeSeed(day: day)) }
        return SeededGenerator(seed: .random(in: 0...UInt64.max))
    }

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
        /// Flash Market's clock ran out, rather than the market crashing.
        let isTimeUp: Bool
    }

    var body: some View {
        withLifecycle(withFeedback(layout))
            .gameBackdrop(.bubbleBlaster)
    }

    private var layout: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                GameStat(title: "Score", value: CoinFormat.grouped(game.score))
                if game.mode == .flash {
                    GameStat(title: "Time", value: clock(game.timeLeft))
                        .foregroundStyle(isPlaying && game.timeLeft < 10 ? Theme.loss : .primary)
                    GameStat(title: "Row in", value: "\(Int(game.rowClock.rounded(.up)))s")
                } else {
                    GameStat(title: "Wave", value: "\(game.wave)")
                    GameStat(title: "New row in", value: "\(game.missesBeforeRow - game.misses)")
                }
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
        .overlay {
            if isPaused {
                PausedCard(game: .bubbleBlaster, resume: { isPaused = false }, showHelp: { showingHelp = true })
            }
        }
        .overlay { panel }
        .animation(.snappy, value: isPlaying)
        .navigationTitle(route.title)
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
            .onChange(of: isRunning) { _, _ in lastFrame = nil }
            .arcadeLifecycle(isPlaying: isPlaying, pause: { isPaused = true }, heldRun: { heldRun }) { endGame() }
    }

    /// The game so far, held while the app is in the background.
    private var heldRun: ArcadeRun {
        ArcadeRun(game: .bubbleBlaster, score: game.score, detail: game.popped, extra: game.bestClear, stage: game.wave,
                  records: .init(bestStreak: game.bestStreak, bonuses: game.bonusesCollected, mode: game.mode == .flash ? 1 : 0))
    }

    private var field: some View {
        // Waves only need frames while a shot flies; Flash Market's clock always runs.
        TimelineView(.animation(minimumInterval: nil, paused: !isRunning || (game.shot == nil && game.mode == .waves))) { timeline in
            BubbleField(game: game, guide: game.shot == nil ? aim.map(guide) : nil, finish: store.game.equipped(.bubbles))
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
                    BlastRing(diameter: (BubbleShooterGame.bombRadius * 2 + 1) * scale, reduceMotion: reduceMotion,
                              color: blastColor)
                        .position(x: blast.position.x * scale, y: blast.position.y * scale)
                        .id(blast.id)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay { EffectsLayer(effects: effects) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fieldLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var fieldLabel: String {
        "Bubble market"
    }

    /// A Bomb's shock wave is orange; a Flash Crash's red.
    private var blastColor: Color {
        Theme.loss
    }

    private var accessibilityValue: String {
        var parts = ["Score \(game.score)", "wave \(game.wave)"]
        if game.mode == .flash { parts.append("\(Int(game.timeLeft.rounded(.up))) seconds left") }
        if let special = game.currentSpecial { parts.append("\(special.name) loaded") }
        if let special = game.nextSpecial { parts.append("\(special.name) next") }
        return parts.joined(separator: ", ")
    }

    /// The aiming guide for `angle`: the path up to the third bounce, and where the bubble will
    /// stick; or, with the short guide, only up to the first bounce.
    private func guide(_ angle: Double) -> BubbleField.Guide {
        let path = game.trajectory(angle: angle, maxBounces: 60)
        if aimGuide == .short { return BubbleField.Guide(path: Array(path.prefix(2)), landing: nil) }
        return BubbleField.Guide(path: Array(path.prefix(4)), landing: path.last.flatMap { game.landingSpot(for: $0) })
    }

    /// Time left as "1:42".
    private func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.up))
        return "\(whole / 60):" + (whole % 60 < 10 ? "0" : "") + "\(whole % 60)"
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
                GamePanel(title: result.isTimeUp ? "Time's Up" : "Market Crashed", buttonTitle: "Play Again", action: start) {
                    GameOverSummary(score: result.game.score, isNewBest: result.game.isNewBest,
                                    best: best, reward: result.game.reward,
                                    details: summary(result), challenge: result.game.challenge, xp: result.game.xp)
                }
            } else {
                GamePanel(title: route.title, buttonTitle: "Start", action: start) {
                    GameIntro(best: best, detail: introDetail)
                }
            }
        }
    }

    /// The best this mode counts toward: Flash Market's own, or Waves' (Today's Market included).
    private var best: Int {
        game.mode == .flash ? store.game.stats.bubbleFlashBestScore : store.game.stats.bubbleBestScore
    }

    private var introDetail: String {
        let speedText = "\(speed.name) shots · \(aimGuide.name)"
        switch route {
        case .waves:
            return "A new row every \(BubbleShooterGame.missesPerRow) misses · \(speedText)"
        case .flash:
            return "\(Int(BubbleShooterGame.flashLength / 60)) minutes · a row every \(Int(BubbleShooterGame.flashRowEvery)) seconds · \(speedText)"
        case .todaysMarket(let day):
            let goal = store.game.dailyChallenge(today: day).flatMap { $0.kind == .bubbleBlaster ? $0.goal : nil }
            return "Everyone starts with the same market today." + (goal.map { " Daily challenge: \($0)." } ?? "") + " \(speedText)."
        }
    }

    private func summary(_ result: BubbleResult) -> [String] {
        var lines = ["\(CoinFormat.grouped(result.game.detail)) bubbles popped · wave \(result.wave)"]
        if result.bestStreak > 1 { lines.append("Best streak: \(result.bestStreak) pops in a row") }
        if result.bonuses > 0 {
            lines.append("\(result.bonuses) blue \(result.bonuses == 1 ? "chip" : "chips")")
        }
        return lines
    }

    // MARK: Game flow

    private func advance(to date: Date) {
        guard isRunning else { return }
        let seconds = lastFrame.map { date.timeIntervalSince($0) } ?? 0
        lastFrame = date
        game.tick(by: seconds, using: &rng)
        game.update(by: seconds, using: &rng)
        if game.shot == nil && game.mode == .waves { lastFrame = nil }
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
        rng = Self.generator(for: route)
        game = BubbleShooterGame(mode: route.mode, speed: speed, using: &rng)
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
                                               wave: game.wave, bestStreak: game.bestStreak, bonuses: game.bonusesCollected,
                                               mode: game.mode)
        result = BubbleResult(game: GameResult(score: game.score, payout: payout, detail: game.popped, xp: store.lastArcadeAward),
                              wave: game.wave, bestStreak: game.bestStreak, bonuses: game.bonusesCollected,
                              isTimeUp: game.isTimeUp)
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

/// A Bomb's shock wave (a Flash Crash's): a ring that grows to the blast's reach and fades.
private struct BlastRing: View {
    let diameter: CGFloat
    let reduceMotion: Bool
    var color = Color.orange
    @State private var isOpen = false

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 6)
            .background(Circle().fill(color.mix(with: .yellow, by: 0.5).opacity(0.25)))
            .frame(width: diameter, height: diameter)
            .scaleEffect(isOpen || reduceMotion ? 1 : 0.2)
            .opacity(isOpen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.55)) { isOpen = true }
            }
    }
}

/// A Rainbow, Bomb or gold bubble, for the streak line and the help sheet: in Bubble Market a
/// Stablecoin, a Flash Crash or a blue chip.
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
                marketLook(size: size)
                // A highlight, so it reads as a bubble.
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.45), .clear], center: UnitPoint(x: 0.32, y: 0.3),
                                         startRadius: 0, endRadius: size * 0.35))
            }
            .frame(width: size, height: size)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @ViewBuilder
    private func marketLook(size: CGFloat) -> some View {
        switch look {
        case .rainbow:
            Circle().fill(RadialGradient(colors: [.white, Color(white: 0.72)], center: UnitPoint(x: 0.35, y: 0.35),
                                         startRadius: 0, endRadius: size * 0.7))
            Text("$")
                .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gain)
        case .bomb:
            Circle().fill(RadialGradient(colors: [Color(red: 0.75, green: 0.15, blue: 0.2), Color(red: 0.3, green: 0.02, blue: 0.06)],
                                         center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: size * 0.7))
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        case .gold:
            Circle().fill(RadialGradient(colors: [Theme.bubble(4).mix(with: .white, by: 0.55), Theme.bubble(4)],
                                         center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: size * 0.7))
            Circle().strokeBorder(.white, lineWidth: max(1.5, size * 0.08))
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.4, weight: .heavy))
                .foregroundStyle(.white)
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
    /// The bubbles picked in Style.
    var finish = Cosmetic.bubblesGlossy
    /// Where the next bubble waits, left of the launcher.
    static let nextPosition = Vector2(x: 1.1, y: BubbleShooterGame.launcher.y)

    /// Bubble Market's bubbles are tokens, each color with its sign.
    static let tokenSigns = ["✕", "Ð", "₮", "₳", "Ξ", "₿"]

    /// The signs are white, but dark on the pale pearl bubbles.
    private var signColor: Color { finish == .bubblesPearl ? .black.opacity(0.55) : .white.opacity(0.9) }

    var body: some View {
        Canvas { context, size in
            let scale = size.width / BubbleShooterGame.width
            drawChart(in: &context, size: size)
            drawLine(in: &context, size: size, scale: scale)
            // The signs, resolved once for all the bubbles in the field.
            let signs = Self.tokenSigns.map { sign(for: $0, radius: 0.48 * scale, color: signColor, context: context) }
            for row in 0...BubbleShooterGame.deadRow {
                for column in 0..<BubbleShooterGame.columns {
                    if let color = game.color(row: row, column: column) {
                        drawBubble(color, at: game.center(row: row, column: column), isBonus: game.isBonus(row: row, column: column),
                                   signs: signs, in: &context, scale: scale)
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

    /// The crash line bubbles must not cross: just below the last safe row.
    private func drawLine(in context: inout GraphicsContext, size: CGSize, scale: Double) {
        let lastSafeRow = Double(BubbleShooterGame.deadRow - 1)
        let lineY = (0.5 + lastSafeRow * BubbleShooterGame.rowHeight + 0.52) * scale
        var line = Path()
        line.move(to: CGPoint(x: 0, y: lineY))
        line.addLine(to: CGPoint(x: size.width, y: lineY))
        context.stroke(line, with: .color(.red.opacity(0.55)), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
        let label = context.resolve(Text("CRASH LINE").font(.system(size: max(8, scale * 0.26), weight: .heavy, design: .rounded))
            .foregroundStyle(.red.opacity(0.8)))
        context.draw(label, at: CGPoint(x: size.width - 6, y: lineY + 3), anchor: .topTrailing)
    }

    /// A faint price chart behind the market: a jagged line drifting down toward the crash line.
    private func drawChart(in context: inout GraphicsContext, size: CGSize) {
        let points: [Double] = [0.18, 0.26, 0.2, 0.34, 0.3, 0.42, 0.38, 0.5, 0.46, 0.58, 0.55, 0.66]
        var chart = Path()
        for (index, share) in points.enumerated() {
            let point = CGPoint(x: size.width * Double(index) / Double(points.count - 1), y: size.height * share)
            if index == 0 { chart.move(to: point) } else { chart.addLine(to: point) }
        }
        context.stroke(chart, with: .color(.cyan.opacity(0.08)), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
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
                            isBonus: Bool = false, signs: [GraphicsContext.ResolvedText] = [],
                            in context: inout GraphicsContext, scale: Double) {
        let radius = diameter / 2 * scale
        let middle = point(center, scale)
        let rect = CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2)
        let circle = Path(ellipseIn: rect)
        let highlight = CGPoint(x: middle.x - radius * 0.35, y: middle.y - radius * 0.35)
        switch special {
        case .rainbow:
            // A Stablecoin: silver, with a dollar sign.
            context.fill(circle, with: .radialGradient(Gradient(colors: [.white, Color(white: 0.75), Color(white: 0.5)]),
                                                       center: highlight, startRadius: 0, endRadius: radius * 1.5))
            context.draw(sign(for: "$", radius: radius, color: Theme.gain, context: context), at: CGPoint(x: middle.x, y: middle.y + radius * 0.04))
        case .bomb:
            // A Flash Crash: deep red, with a falling chart.
            context.fill(circle, with: .radialGradient(Gradient(colors: [Color(red: 0.8, green: 0.2, blue: 0.25), Color(red: 0.35, green: 0.02, blue: 0.06)]),
                                                       center: highlight, startRadius: 0, endRadius: radius * 1.5))
            drawSymbol("chart.line.downtrend.xyaxis", color: .white, in: rect.insetBy(dx: radius * 0.42, dy: radius * 0.45), context: &context)
        case nil:
            finish.drawBubble(Theme.bubble(color), at: middle, radius: radius, in: &context)
            if isBonus {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: 1.2, dy: 1.2)), with: .color(.white),
                               lineWidth: max(2, radius * 0.16))
                drawSymbol("star.fill", color: .white, in: rect.insetBy(dx: radius * 0.55, dy: radius * 0.5),
                           context: &context)
            } else {
                let index = (max(1, color) - 1) % Self.tokenSigns.count
                let text = signs.indices.contains(index) && diameter == 0.96
                    ? signs[index] : sign(for: Self.tokenSigns[index], radius: radius, color: signColor, context: context)
                context.draw(text, at: CGPoint(x: middle.x, y: middle.y + radius * 0.04))
            }
        }
    }

    /// A token's sign, sized for a bubble of `radius`.
    private func sign(for sign: String, radius: Double, color: Color = .white.opacity(0.9), context: GraphicsContext) -> GraphicsContext.ResolvedText {
        context.resolve(Text(sign).font(.system(size: radius * 0.95, weight: .heavy, design: .rounded)).foregroundStyle(color))
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
