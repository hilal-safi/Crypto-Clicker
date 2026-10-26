import SwiftUI
import CryptoClickerKit

/// The home screen, in order of importance: the balance, the coin to tap, what the player owns
/// (miners and tokens), and steps once they are unlocked.
struct MineView: View {
    let openShop: () -> Void
    let openExchange: () -> Void
    @Environment(GameStore.self) private var store
    @State private var showingStats = false
    @State private var showingHelp = false
    @State private var showingStepsIntro = false
    #if DEBUG
    @State private var showingTestingTools = false
    #endif
    @State private var effects = Effects()
    /// Every digit or the short form, for the balance and tap values. Tapping the balance switches.
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false

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
            .navigationTitle("Crypto Clicker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("How to Play", systemImage: "questionmark.circle") { showingHelp = true }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Testing Tools", systemImage: "ladybug") { showingTestingTools = true }
                }
                #endif
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Statistics", systemImage: "chart.bar.xaxis") { showingStats = true }
                }
            }
            .sheet(isPresented: $showingStats) { StatsView() }
            .sheet(isPresented: $showingHelp) { HowToPlayView() }
            .sheet(isPresented: $showingStepsIntro) { StepsIntroView() }
            #if DEBUG
            .sheet(isPresented: $showingTestingTools) { TestingToolsView() }
            #endif
        }
    }

    private var content: some View {
        let game = store.game
        let now = Date.now
        return VStack(spacing: 14) {
            BalanceHeader(coins: game.coins, boost: game.activeBoost(at: now), showsExact: exactNumbers) {
                withAnimation(.snappy) { exactNumbers.toggle() }
            }
            CoinButton(tapValue: game.tapValue(at: now), exactNumbers: exactNumbers) {
                store.tap()
                effects.rainCoins()
            }
            .frame(minHeight: CoinButton.minimumSize, idealHeight: CoinButton.minimumSize, maxHeight: .infinity)
            InventoryStrip(game: game, openShop: openShop, openExchange: openExchange)
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
/// (tap it to switch). During a Bull Run its countdown sits beside "coins", so the coin below
/// keeps its size.
struct BalanceHeader: View {
    let coins: Double
    let boost: Boost?
    let showsExact: Bool
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
            HStack(spacing: 8) {
                Text("coins")
                    .foregroundStyle(.subtext)
                    .accessibilityHidden(true) // The number above already says "coins".
                if let boost {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = CoinFormat.duration(boost.endsAt.timeIntervalSince(context.date))
                        Label("Bull Run \(CoinFormat.multiplier(boost.multiplier)) · \(remaining)", systemImage: "flame.fill")
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 8)
                            .background(Theme.accent.opacity(0.14), in: .capsule)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .font(.headline.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .accessibilityElement(children: .combine)
        }
        .padding(.top, 8)
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

/// The big tappable coin. Each tap pops a floating "+value" above it, in the same form as the
/// balance: every digit, or the short form.
struct CoinButton: View {
    /// The smallest the home screen lets the coin get; it grows to 320 points where there's room.
    static let minimumSize: CGFloat = 200

    /// Coins one tap earns: always a whole number.
    let tapValue: Double
    let exactNumbers: Bool
    let onTap: () -> Void
    @AppStorage(Preferences.hapticsKey) private var haptics = true
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
            onTap()
            if sounds { TapSound.play() }
            if !reduceMotion { spawnFloater() }
        } label: {
            Image("Coin")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 320)
                .shadow(color: Theme.bitcoin.opacity(0.45), radius: 28)
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
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: taps) { _, _ in haptics }
        .accessibilityLabel("Mine coin")
        .accessibilityHint("Earns \(tapText) coins per tap")
    }

    private var tapText: String {
        exactNumbers ? CoinFormat.exact(tapValue) : CoinFormat.short(tapValue)
    }

    private func spawnFloater() {
        let floater = Floater(id: taps, text: "+\(tapText)", xOffset: .random(in: -70...70))
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
