import SwiftUI
import CryptoClickerKit

/// To the Moon: bet tokens, launch, and watch the multiplier climb up the chart until the market
/// crashes. Cash out before it does, or set an automatic cash-out. The bet is taken and the flight
/// saved at launch; leaving the screen or the app mid-flight cashes out at once, so a bet is never
/// left hanging. Where the flight crashes is decided at launch (see `MoonFlight`). Practice flies
/// the same flights for chips, without the wallet.
struct MoonView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var token = TokenID.shibaInu
    @State private var bet = 1
    /// Cash out by itself on reaching this, if it gets there.
    @State private var autoCashOut: Double? = 2
    @State private var launchDate: Date?
    /// The flight's end, for the frozen chart: seconds after launch.
    @State private var endedAfter: TimeInterval = 0
    @State private var result: MoonResult?
    @State private var flights = 0
    @State private var effects = Effects()
    @State private var showingHelp = false
    @State private var isPracticing = false
    @State private var chips = PracticeChips()
    @State private var practiceBet = 25
    /// A practice flight in the air (a real one is saved in the game).
    @State private var practiceRound: MoonRound?
    @State private var roundIsPractice = false

    /// The flight in the air: a practice one, or the saved one.
    private var activeRound: MoonRound? { roundIsPractice ? practiceRound : store.game.moonRound }

    private var isFlying: Bool { launchDate != nil && activeRound != nil }

    /// What the flight's bet is counted in.
    private func unit(_ token: TokenID) -> String { roundIsPractice ? "chips" : token.ticker }

    var body: some View {
        let game = store.game
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    Spacer(minLength: 0)
                    Text("TO THE MOON")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.gold.gradient)
                        .shadow(color: Theme.gold.opacity(0.5), radius: 12)
                    chart
                        .frame(height: min(320, max(220, proxy.size.height * 0.42)))
                    status(game: game)
                        .frame(minHeight: 56)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            controls(game: game)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: 560)
        }
        .background { SpaceBackground() }
        .overlay { EffectsLayer(effects: effects).ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .navigationTitle("To the Moon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .gameHelp(.moon, isPresented: $showingHelp, isEnabled: !isFlying)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CoinAmount(amount: game.coins, font: .subheadline.weight(.semibold), iconSize: 16)
                    .padding(.horizontal, 6)
            }
        }
        .sensoryFeedback(trigger: flights) { _, _ in
            guard haptics, let result else { return nil }
            return result.isWin ? .success : .error
        }
        .task(id: launchDate) { await waitForTheEnd() }
        .onAppear(perform: prepare)
        .onDisappear { cashOut(at: .now) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cashOut(at: .now) }
        }
        .gameScreen()
    }

    // MARK: Chart

    private var chart: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isFlying)) { timeline in
            let elapsed = launchDate.map { timeline.date.timeIntervalSince($0) } ?? endedAfter
            let crash = activeRound?.crashPoint ?? .infinity
            // While flying, the line never shows past the crash point, even for a frame.
            let shownTime = isFlying ? min(elapsed, MoonFlight.time(toReach: crash)) : endedAfter
            let multiplier = isFlying ? min(MoonFlight.multiplier(after: shownTime), crash) : endMultiplier
            ZStack {
                FlightChart(seconds: shownTime, isCrashed: result?.isWin == false, hasFlown: isFlying || result != nil)
                VStack(spacing: 4) {
                    Text(CoinFormat.flight(multiplier))
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(headlineColor)
                        .contentTransition(.numericText(value: multiplier))
                        .shadow(color: headlineColor.opacity(0.5), radius: 10)
                    Text(headline)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .accessibilityElement(children: .combine)
            }
            .accessibilityLabel(isFlying ? "Flying at \(CoinFormat.flight(multiplier))" : headline)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.10, green: 0.09, blue: 0.30), .black.opacity(0.7)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.6), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
    }

    private var endMultiplier: Double {
        guard let result else { return 1 }
        return result.cashedOutAt ?? result.crashPoint
    }

    private var headline: String {
        if isFlying { return "Cash out before the crash" }
        guard let result else { return "Ready for launch" }
        return result.isWin ? "Cashed out" : "Crashed"
    }

    private var headlineColor: Color {
        if isFlying || result == nil { return Theme.gold }
        return result?.isWin == true ? Theme.gain : Theme.loss
    }

    @ViewBuilder
    private func status(game: GameState) -> some View {
        if isFlying, let round = activeRound {
            TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                let elapsed = launchDate.map { timeline.date.timeIntervalSince($0) } ?? 0
                let multiplier = min(MoonFlight.multiplier(after: elapsed), round.crashPoint)
                Text("Cash out now for \(CoinFormat.grouped(round.tokensWon(at: multiplier))) \(unit(round.token))"
                     + (round.autoCashOut.map { " · auto at \(CoinFormat.flight($0))" } ?? ""))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
        } else if let result {
            VStack(spacing: 4) {
                if result.isWin {
                    Text("+\(CoinFormat.grouped(result.tokensWon - result.bet)) \(unit(result.token)) profit")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    if result.bonus > 0 {
                        CoinAmount(amount: result.bonus, font: .headline, iconSize: 18)
                            .foregroundStyle(Theme.gold)
                    }
                } else {
                    Text("Lost \(CoinFormat.grouped(result.bet)) \(unit(result.token))")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.loss)
                }
            }
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        } else {
            Text("The multiplier doubles every \(Int(MoonFlight.doublingTime)) seconds until the market crashes. Every target pays back 97% on average: it's luck, so bet what you can lose.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(game: GameState) -> some View {
        if isFlying {
            Button(action: { cashOut(at: .now) }) {
                Label("Cash Out", systemImage: "hand.raised.fill")
                    .font(.title3.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.gain)
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        } else {
            let counts = Dictionary(uniqueKeysWithValues: TokenID.allCases.map { ($0, game.tokenCount($0)) })
            VStack(spacing: 12) {
                CasinoModePicker(isPracticing: $isPracticing)
                if isPracticing {
                    PracticeBetControls(chips: chips, bet: $practiceBet)
                    if chips.isBroke {
                        Button("New Stack of \(CoinFormat.grouped(PracticeChips.starting)) Chips") { chips.refill() }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                            .tint(Theme.gold)
                    }
                } else {
                    if TokenID.allCases.allSatisfy({ counts[$0, default: 0] == 0 }) {
                        Label("Buy tokens on the Coin Exchange to play, or practice with chips.", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.subtext)
                    }
                    TokenBetControls(token: $token, bet: $bet, counts: counts)
                }
                HStack {
                    Menu {
                        Picker("Automatic cash-out", selection: $autoCashOut) {
                            Text("Off").tag(Double?.none)
                            ForEach(MoonFlight.autoCashOutChoices, id: \.self) { target in
                                Text(CoinFormat.flight(target)).tag(Double?.some(target))
                            }
                        }
                    } label: {
                        Label(autoCashOut.map { "Auto cash-out \(CoinFormat.flight($0))" } ?? "Auto cash-out off",
                              systemImage: "timer")
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    if !isPracticing {
                        Text("2× pays +\(CoinFormat.short(game.moonBonus(bet: bet, token: token, multiplier: 2))) coins")
                            .font(.footnote)
                            .foregroundStyle(.subtext)
                    }
                }
                Button(action: launch) {
                    Text(result == nil ? "LAUNCH" : "LAUNCH AGAIN")
                        .font(.title3.weight(.black))
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .disabled(isPracticing ? chips.balance < practiceBet : counts[token, default: 0] < bet)
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }

    // MARK: Flight

    private func prepare() {
        // A flight can't outlive its screen; if one is somehow left, its bet goes back.
        if launchDate == nil { store.refundMoonRound() }
        if store.game.tokenCount(token) == 0, let owned = TokenID.allCases.first(where: { store.game.tokenCount($0) > 0 }) {
            token = owned
        }
    }

    private func launch() {
        guard !isFlying else { return }
        if isPracticing {
            guard chips.take(practiceBet) else { return }
            practiceRound = MoonRound(token: token, bet: practiceBet,
                                      crashPoint: MoonFlight.crashPoint(roll: Double.random(in: 0..<1)), autoCashOut: autoCashOut)
        } else {
            guard store.launchMoon(token, bet: bet, autoCashOut: autoCashOut) else { return }
        }
        roundIsPractice = isPracticing
        withAnimation(.snappy) { result = nil }
        endedAfter = 0
        launchDate = .now
    }

    /// Sleeps until the flight ends by itself (the automatic cash-out or the crash), then settles it.
    private func waitForTheEnd() async {
        guard let launchDate, let round = activeRound else { return }
        let target = round.autoCashOut.flatMap { $0 <= round.crashPoint ? $0 : nil } ?? round.crashPoint
        let endsAfter = MoonFlight.time(toReach: target)
        do {
            try await Task.sleep(for: .seconds(max(0, endsAfter - Date.now.timeIntervalSince(launchDate))))
        } catch {
            return
        }
        settle(after: endsAfter)
    }

    /// The player's cash-out (or leaving): settles at the moment's multiplier.
    private func cashOut(at date: Date) {
        guard let launchDate, activeRound != nil else { return }
        settle(after: date.timeIntervalSince(launchDate))
    }

    /// Ends the flight once: a practice flight pays its chips here, a real one through the store.
    private func settle(after seconds: TimeInterval) {
        guard launchDate != nil else { return }
        let settled: MoonResult
        if roundIsPractice {
            guard let round = practiceRound else { return }
            practiceRound = nil
            settled = round.outcome(after: seconds)
            chips.pay(settled.tokensWon)
        } else {
            guard let paid = store.settleMoon(after: seconds) else { return }
            settled = paid
        }
        endedAfter = MoonFlight.time(toReach: settled.cashedOutAt ?? settled.crashPoint)
        launchDate = nil
        withAnimation(.snappy) { result = settled }
        flights += 1
        if let multiplier = settled.cashedOutAt, multiplier >= 2 {
            effects.confetti(multiplier >= 10 ? 150 : 80, from: UnitPoint(x: 0.5, y: 0.4))
            effects.coinFountain(multiplier >= 10 ? 28 : 14, from: UnitPoint(x: 0.5, y: 0.55))
        }
    }
}

/// The price line: an exponential climb drawn up to `seconds`, red after a crash.
private struct FlightChart: View {
    let seconds: TimeInterval
    let isCrashed: Bool
    let hasFlown: Bool

    var body: some View {
        Canvas { context, size in
            // Faint grid.
            var grid = Path()
            for step in 1..<4 {
                let y = size.height * CGFloat(step) / 4
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(.white.opacity(0.06)), lineWidth: 1)
            guard hasFlown, seconds > 0 else { return }
            // The window grows with the flight, so the line always fills the chart.
            let span = max(seconds, MoonFlight.doublingTime)
            let top = max(MoonFlight.multiplier(after: span), 2)
            func point(at time: TimeInterval) -> CGPoint {
                let multiplier = pow(2, time / MoonFlight.doublingTime)
                let x = CGFloat(time / span) * size.width
                let y = size.height - CGFloat((multiplier - 1) / (top - 1)) * size.height * 0.9
                return CGPoint(x: x, y: y)
            }
            var line = Path()
            line.move(to: CGPoint(x: 0, y: size.height))
            let steps = 60
            for index in 1...steps { line.addLine(to: point(at: seconds * Double(index) / Double(steps))) }
            var area = line
            area.addLine(to: CGPoint(x: point(at: seconds).x, y: size.height))
            area.closeSubpath()
            let color = isCrashed ? Theme.loss : Theme.gold
            context.fill(area, with: .linearGradient(Gradient(colors: [color.opacity(0.35), color.opacity(0)]),
                                                     startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            // The rocket (or the wreck) at the head of the line.
            let head = point(at: seconds)
            let rocket = context.resolve(Text(isCrashed ? "💥" : "🚀").font(.system(size: 30)))
            context.draw(rocket, at: CGPoint(x: min(max(head.x, 18), size.width - 18), y: max(head.y, 18)))
        }
        .accessibilityHidden(true)
    }
}

/// Deep space with a scatter of stars.
private struct SpaceBackground: View {
    var body: some View {
        RadialGradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.40), Color(red: 0.02, green: 0.02, blue: 0.08)],
                       center: .top, startRadius: 40, endRadius: 820)
            .overlay {
                Canvas { context, size in
                    var rng = SeededGenerator(seed: 42)
                    for _ in 0..<90 {
                        let x = Double.random(in: 0...1, using: &rng) * size.width
                        let y = Double.random(in: 0...1, using: &rng) * size.height
                        let radius = Double.random(in: 0.5...1.6, using: &rng)
                        let opacity = Double.random(in: 0.2...0.8, using: &rng)
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                                     with: .color(.white.opacity(opacity)))
                    }
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
