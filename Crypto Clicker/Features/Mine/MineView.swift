import SwiftUI
import CryptoClickerKit

/// The home screen, in order of importance: the balance with coins per second and per tap, the coin
/// to tap, a tip for new players, what the player owns (miners and power-ups, and crypto), and steps
/// once they are unlocked. No title and no buttons along the top, so the coin gets the room;
/// Statistics and How to Play are in the Settings tab.
struct MineView: View {
    let openShop: () -> Void
    let openPowerUps: () -> Void
    /// Opens the Shop's tokens.
    let openTokens: () -> Void
    let openDaily: () -> Void
    /// Shows where the coins come from.
    let openIncome: () -> Void
    /// Opens How to Play in the Settings tab.
    let openHowToPlay: () -> Void
    @Environment(GameStore.self) private var store
    @State private var showingStepsIntro = false
    @State private var effects = Effects()
    /// Every digit or the short form, for the balance and tap values. Tapping the balance switches.
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false
    @AppStorage(Preferences.coinFinishKey) private var finish = CoinFinish.gold
    @AppStorage(Preferences.coinRimKey) private var rim = CoinRim.plain
    @AppStorage(Preferences.coinTapEffectKey) private var tapEffect = CoinTapEffect.none
    @AppStorage(Preferences.stepsInviteDismissedKey) private var stepsInviteDismissed = false

    var body: some View {
        NavigationStack {
            // The coin takes the room the other items leave, from 200 points up to 320 (and larger
            // still on a new game, with nothing under it yet). When even 200 doesn't fit (a small
            // iPhone with very large text), the page scrolls instead. The balance sits 1% of the
            // screen's height below the top.
            GeometryReader { proxy in
                let topPadding = (proxy.size.height * 0.01).rounded()
                ViewThatFits(in: .vertical) {
                    content(topPadding: topPadding)
                    ScrollView {
                        content(topPadding: topPadding)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
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
            .toolbarVisibility(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingStepsIntro) { StepsIntroView() }
        }
    }

    private func content(topPadding: CGFloat) -> some View {
        let game = store.game
        let now = Date.now
        // A new game has no cards under the coin yet, so the coin grows into the room and sits in
        // the middle of it.
        let hasCards = InventoryStrip.hasContent(game)
            || StepsCard.isShown(game, canTrackSteps: store.canTrackSteps, inviteDismissed: stepsInviteDismissed)
        return VStack(spacing: 10) {
            // The rates under the balance, and the coin, get less room around them than the other
            // items have (10% less, then 10% less again).
            VStack(spacing: 8) {
                LiveBalanceHeader(boost: game.activeBoost(at: now), showsExact: exactNumbers,
                                  income: game.idleIncome(at: now), tapValue: game.tapValue(at: now), openIncome: openIncome) {
                    withAnimation(.snappy) { exactNumbers.toggle() }
                }
                GeometryReader { proxy in
                    let cap = hasCards ? CoinButton.maximumSize : CoinButton.freshMaximumSize
                    // Looks locked again (after a reset) fall back to the plain coin.
                    let stars = game.earnedAchievementTiers
                    CoinButton(tapValue: game.tapValue(at: now), exactNumbers: exactNumbers,
                               finish: finish.isUnlocked(stars: stars) ? finish : .gold,
                               rim: rim.isUnlocked(stars: stars) ? rim : .plain,
                               tapEffect: tapEffect.isUnlocked(stars: stars) ? tapEffect : .none,
                               maxSize: CoinButton.size(in: proxy.size, cap: cap)) {
                        effects.rainCoins()
                        return store.tap()
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .frame(minHeight: CoinButton.minimumSize, idealHeight: CoinButton.minimumSize, maxHeight: .infinity)
                .animation(.smooth, value: hasCards)
                .overlay(alignment: .bottom) {
                    // Shown from the combo's first +0.1, so a few casual taps don't flicker it.
                    if store.comboMultiplier > 1 {
                        ComboPill(multiplier: store.comboMultiplier, isMax: store.comboMultiplier >= game.comboMaxMultiplier)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: store.comboMultiplier > 1)
            }
            GuideTipCard(openShop: openShop, openPowerUps: openPowerUps, openDaily: openDaily, openHowToPlay: openHowToPlay)
            InventoryStrip(game: game, market: store.market, openShop: openShop, openTokens: openTokens)
            StepsCard(learnMore: { showingStepsIntro = true })
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .animation(.smooth, value: game.areStepsUnlocked)
        .animation(.smooth, value: game.steps.isConnected)
    }
}

/// The balance header with the live balance: it reads the store's coins itself, so the balance
/// redraws on every tick without taking the rest of the Mine screen with it.
private struct LiveBalanceHeader: View {
    let boost: Boost?
    let showsExact: Bool
    let income: Double
    let tapValue: Double
    let openIncome: () -> Void
    let toggleExact: () -> Void
    @Environment(GameStore.self) private var store

    var body: some View {
        BalanceHeader(coins: store.coins, boost: boost, showsExact: showsExact, income: income, tapValue: tapValue,
                      openIncome: openIncome, toggleExact: toggleExact)
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
        VStack(spacing: 3.6) {
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
                BullRunBadge(boost: boost)
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
    /// The smallest the home screen lets the coin get...
    static let minimumSize: CGFloat = 200
    /// ...the largest once there are cards under it...
    static let maximumSize: CGFloat = 320
    /// ...and the largest on a new game, with nothing under it yet (width allowing).
    static let freshMaximumSize: CGFloat = 420
    /// Share of the room above and below the coin that the coin grows into, so it isn't lost in
    /// space: 15% less padding around it, then 10% less twice more (about 31% of the room in all).
    static let spareRoomTaken: CGFloat = 1 - 0.85 * 0.9 * 0.9

    /// The coin's size in an area: as big as `cap` allows, then grown into a share of the room
    /// left above and below it (`spareRoomTaken`), never wider than the area.
    static func size(in area: CGSize, cap: CGFloat) -> CGFloat {
        let fitted = min(cap, area.width, area.height)
        let spare = max(0, area.height - fitted)
        return max(0, min(area.width, fitted + spare * spareRoomTaken))
    }

    /// Coins one tap earns without a combo: always a whole number.
    let tapValue: Double
    let exactNumbers: Bool
    var finish = CoinFinish.gold
    var rim = CoinRim.plain
    var tapEffect = CoinTapEffect.none
    var maxSize = CoinButton.maximumSize
    /// Taps the coin and returns what that tap earned.
    let onTap: () -> Double
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.tapHapticStrengthKey) private var hapticStrength = TapHapticStrength.strong
    @AppStorage(Preferences.soundsKey) private var sounds = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0
    @State private var floaters: [Floater] = []
    /// Tap effects still playing.
    @State private var bursts: [TapBurst] = []

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
            if !reduceMotion {
                spawnFloater(earned)
                spawnBurst()
            }
        } label: {
            CoinArt(finish: finish)
                .overlay { CoinRimView(rim: rim, color: finish.glow) }
                .frame(maxWidth: maxSize, maxHeight: maxSize)
                .shadow(color: finish.glow.opacity(0.45), radius: 28)
                .shadow(color: .black.opacity(0.3), radius: 14, y: 10)
                .contentShape(.circle)
        }
        .buttonStyle(CoinPressStyle())
        .overlay {
            GeometryReader { proxy in
                let coin = min(proxy.size.width, proxy.size.height)
                TapEffectsLayer(bursts: bursts, coin: coin)
                    .frame(width: coin * 2.2, height: coin * 2.2)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .allowsHitTesting(false)
        }
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

    /// Sets off the tap effect picked in Settings; a few play at once at most.
    private func spawnBurst() {
        guard tapEffect != .none else { return }
        let burst = TapBurst(id: taps, effect: tapEffect, start: .now, seed: .random(in: 0...UInt64.max))
        bursts.append(burst)
        if bursts.count > 8 { bursts.removeFirst(bursts.count - 8) }
        Task {
            try? await Task.sleep(for: .seconds(burst.lifetime + 0.1))
            bursts.removeAll { $0.id == burst.id }
        }
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

/// The Bull Run under the rates: a burning badge with the multiplier and the time left, beating
/// like a heart while it lasts.
private struct BullRunBadge: View {
    let boost: Boost
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = CoinFormat.duration(max(0, boost.endsAt.timeIntervalSince(context.date)))
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .symbolEffect(.bounce, options: .repeating, isActive: !reduceMotion)
                Text("BULL RUN \(CoinFormat.multiplier(boost.multiplier))")
                    .fontWeight(.black)
                Text(remaining)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(.black.opacity(0.22), in: .capsule)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(LinearGradient(colors: [FireEdges.red, FireEdges.orange], startPoint: .leading, endPoint: .trailing),
                        in: .capsule)
            .shadow(color: FireEdges.red.opacity(0.6), radius: beat ? 14 : 6)
            .scaleEffect(beat ? 1.05 : 1)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { beat = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bull Run, production \(CoinFormat.multiplier(boost.multiplier))")
    }
}
