import SwiftUI
import CryptoClickerKit

/// The home screen, in order of importance: the balance with coins per second and per tap, the coin
/// to tap, a tip for new players, what the player owns (miners and power-ups, and crypto), and steps
/// once they are unlocked. No title, so the game gets the room.
struct MineView: View {
    let openShop: () -> Void
    let openPowerUps: () -> Void
    let openExchange: () -> Void
    let openDaily: () -> Void
    /// Shows where the coins come from.
    let openIncome: () -> Void
    @Environment(GameStore.self) private var store
    @State private var showingStats = false
    @State private var showingHelp = false
    @State private var showingStepsIntro = false
    @State private var showingSettings = false
    @State private var effects = Effects()
    /// Every digit or the short form, for the balance and tap values. Tapping the balance switches.
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false
    @AppStorage(Preferences.coinFinishKey) private var finish = CoinFinish.gold

    var body: some View {
        NavigationStack {
            // The coin takes the room the other items leave, from 200 to 320 points. When even
            // 200 doesn't fit (a small iPhone with very large text), the page scrolls instead.
            ViewThatFits(in: .vertical) {
                content
                ScrollView {
                    content
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    MineBackground()
                    // Coins fall behind the content, so they never cover the balance or buttons.
                    EffectsLayer(effects: effects)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Crypto Clicker") // Kept for VoiceOver and the app switcher, but not shown.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("How to Play", systemImage: "questionmark.circle") { showingHelp = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Statistics", systemImage: "chart.bar.xaxis") { showingStats = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingStats) { StatsView() }
            .sheet(isPresented: $showingHelp) { HowToPlayView() }
            .sheet(isPresented: $showingStepsIntro) { StepsIntroView() }
        }
    }

    private var content: some View {
        let game = store.game
        let now = Date.now
        return VStack(spacing: 10) {
            BalanceHeader(coins: game.coins, boost: game.activeBoost(at: now), showsExact: exactNumbers,
                          income: game.idleIncome(at: now), tapValue: game.tapValue(at: now), openIncome: openIncome) {
                withAnimation(.snappy) { exactNumbers.toggle() }
            }
            CoinButton(tapValue: game.tapValue(at: now), exactNumbers: exactNumbers,
                       finish: finish.isUnlocked(stars: game.earnedAchievementTiers) ? finish : .gold) {
                effects.rainCoins()
                return store.tap()
            }
            .frame(minHeight: CoinButton.minimumSize, idealHeight: CoinButton.minimumSize, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                // Shown once a combo is clearly under way, so a few casual taps don't flicker it.
                if store.comboStreak >= 5 {
                    ComboPill(multiplier: store.comboMultiplier, isMax: store.comboMultiplier >= game.comboMaxMultiplier)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: store.comboStreak >= 5)
            GuideTipCard(openShop: openShop, openPowerUps: openPowerUps, openDaily: openDaily)
            InventoryStrip(game: game, market: store.market, openShop: openShop, openExchange: openExchange)
            StepsCard(learnMore: { showingStepsIntro = true })
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .animation(.smooth, value: game.areStepsUnlocked)
        .animation(.smooth, value: game.steps.isConnected)
    }
}

/// The balance, large: the short form from 10,000 up, or every digit when `showsExact` is on
/// (tap it to switch). Coins per second and per tap sit just under it, and during a Bull Run its
/// countdown below them.
struct BalanceHeader: View {
    let coins: Double
    let boost: Boost?
    let showsExact: Bool
    /// Coins per second, Bull Run included.
    let income: Double
    let tapValue: Double
    let openIncome: () -> Void
    let toggleExact: () -> Void

    var body: some View {
        let short = CoinFormat.short(coins)
        let exact = showsExact ? CoinFormat.exact(coins) : short
        VStack(spacing: 4) {
            Group {
                // Below 10,000 both forms are the same, so there is nothing to switch.
                if exact != short {
                    ExactBalance(text: exact, coins: coins)
                        .transition(.opacity)
                } else {
                    Self.number(short, size: 60, coins: coins)
                        .minimumScaleFactor(0.4)
                        .transition(.opacity)
                }
            }
            // A fixed height, so switching forms (or sizes) never moves the coin below.
            .frame(height: 76)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .onTapGesture(perform: toggleExact)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(exact) coins")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(showsExact ? "Shows the short form" : "Shows every digit")
            .accessibilityAction(.default, toggleExact)
            RatesLine(income: income, tapValue: tapValue, showsExact: showsExact, open: openIncome)
            if let boost {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = CoinFormat.duration(boost.endsAt.timeIntervalSince(context.date))
                    Label("Bull Run \(CoinFormat.multiplier(boost.multiplier)) · \(remaining)", systemImage: "flame.fill")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 8)
                        .background(Theme.accent.opacity(0.14), in: .capsule)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring, value: boost)
    }

    /// The balance in the large rounded style.
    static func number(_ text: String, size: CGFloat, coins: Double) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: coins))
            .lineLimit(1)
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            .animation(.snappy(duration: 0.25), value: coins)
    }
}

/// Coins per second and per tap, in the form the balance uses. Tapping them shows where the coins
/// come from.
private struct RatesLine: View {
    let income: Double
    let tapValue: Double
    let showsExact: Bool
    let open: () -> Void

    var body: some View {
        let rate = showsExact ? CoinFormat.exactRate(income) : CoinFormat.rate(income)
        let tap = showsExact ? CoinFormat.exact(tapValue) : CoinFormat.short(tapValue)
        Button(action: open) {
            HStack(spacing: 14) {
                Label("\(rate)/s", systemImage: "bolt.fill")
                Label("\(tap) per tap", systemImage: "hand.tap.fill")
                    .foregroundStyle(.subtext)
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rate) coins per second, \(tap) per tap")
        .accessibilityHint("Shows where your coins come from")
        .accessibilityAddTraits(.isButton)
    }
}

/// Every digit of the balance, as large as fits. When even the smallest size is too wide, the
/// number scrolls sideways.
private struct ExactBalance: View {
    let text: String
    let coins: Double

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach([60.0, 48, 38, 30], id: \.self) { size in
                BalanceHeader.number(text, size: size, coins: coins)
                    .fixedSize()
            }
            ScrollView(.horizontal) {
                BalanceHeader.number(text, size: 30, coins: coins)
                    .fixedSize()
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8) // Room for the shadow and the scroll indicator.
            }
            .scrollIndicators(.visible)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
    }
}

/// The big tappable coin, in the finish the player picked. Each tap pops a floating "+value" above
/// it (what that tap earned, combo included), in the same form as the balance: every digit, or the
/// short form.
struct CoinButton: View {
    /// The smallest the home screen lets the coin get; it grows to 320 points where there's room.
    static let minimumSize: CGFloat = 200

    /// Coins one tap earns without a combo: always a whole number.
    let tapValue: Double
    let exactNumbers: Bool
    var finish = CoinFinish.gold
    /// Taps the coin and returns what that tap earned.
    let onTap: () -> Double
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.tapHapticStrengthKey) private var hapticStrength = TapHapticStrength.strong
    @AppStorage(Preferences.soundsKey) private var sounds = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0
    @State private var floaters: [Floater] = []

    struct Floater: Identifiable {
        let id: Int
        let text: String
        let xOffset: CGFloat
    }

    var body: some View {
        Button {
            taps += 1
            let earned = onTap()
            if sounds { TapSound.play() }
            if !reduceMotion { spawnFloater(earned) }
        } label: {
            CoinArt(finish: finish)
                .frame(maxWidth: 320, maxHeight: 320)
                .shadow(color: finish.glow.opacity(0.45), radius: 28)
                .shadow(color: .black.opacity(0.3), radius: 14, y: 10)
                .contentShape(.circle)
        }
        .buttonStyle(CoinPressStyle())
        .overlay {
            ZStack {
                ForEach(floaters) { floater in
                    FloatingText(text: floater.text)
                        .offset(x: floater.xOffset, y: -70)
                }
            }
            .allowsHitTesting(false)
        }
        .sensoryFeedback(hapticStrength.feedback, trigger: taps) { _, _ in haptics }
        .accessibilityLabel("Mine coin")
        .accessibilityHint("Earns \(tapText) coins per tap")
    }

    private var tapText: String { text(tapValue) }

    private func text(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exact(value) : CoinFormat.short(value)
    }

    private func spawnFloater(_ earned: Double) {
        let floater = Floater(id: taps, text: "+\(text(earned))", xOffset: .random(in: -70...70))
        floaters.append(floater)
        if floaters.count > 12 { floaters.removeFirst(floaters.count - 12) }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            floaters.removeAll { $0.id == floater.id }
        }
    }
}

private struct CoinPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

private struct FloatingText: View {
    let text: String
    @State private var risen = false

    var body: some View {
        Text(text)
            .font(.title.weight(.heavy))
            .fontDesign(.rounded)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4) // Long values shrink instead of running off the screen.
            .frame(maxWidth: 300)
            .foregroundStyle(Theme.gold)
            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
            .offset(y: risen ? -100 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { risen = true }
            }
    }
}

/// The combo under the coin while quick taps keep it going.
struct ComboPill: View {
    let multiplier: Double
    let isMax: Bool

    var body: some View {
        Label("Combo ×\(String(format: "%.1f", multiplier))", systemImage: "flame.fill")
            .font(.headline.monospacedDigit())
            .foregroundStyle(.white)
            .contentTransition(.numericText(value: multiplier))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background((isMax ? Color.red : Theme.accent).gradient, in: .capsule)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            .allowsHitTesting(false)
            .accessibilityLabel("Combo, taps earn \(CoinFormat.multiplier(multiplier))")
    }
}
