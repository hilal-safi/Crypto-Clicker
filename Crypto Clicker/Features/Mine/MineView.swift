import SwiftUI
import CryptoClickerKit

struct MineView: View {
    @Environment(GameStore.self) private var store
    @State private var showingStats = false
    @State private var showingHelp = false

    var body: some View {
        let game = store.game
        NavigationStack {
            VStack(spacing: 16) {
                BalanceHeader(coins: game.coins, boost: game.activeBoost(at: .now))
                Spacer(minLength: 0)
                CoinButton(tapValue: game.tapValue(at: .now)) { store.tap() }
                Spacer(minLength: 0)
                StepsCard()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background { AppBackground() }
            .navigationTitle("Crypto Clicker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("How to Play", systemImage: "questionmark.circle") { showingHelp = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Statistics", systemImage: "chart.bar.xaxis") { showingStats = true }
                }
            }
            .sheet(isPresented: $showingStats) { StatsView() }
            .sheet(isPresented: $showingHelp) { HowToPlayView() }
        }
    }
}

/// The balance, large, with a Bull Run countdown while one is running.
struct BalanceHeader: View {
    let coins: Double
    let boost: Boost?

    var body: some View {
        VStack(spacing: 6) {
            Text(CoinFormat.short(coins))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: coins))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .animation(.snappy(duration: 0.25), value: coins)
            Text("coins")
                .font(.headline)
                .foregroundStyle(.secondary)
            if let boost {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    StatPill(systemImage: "flame.fill",
                             text: "Bull Run \(CoinFormat.multiplier(boost.multiplier)) · \(CoinFormat.duration(boost.endsAt.timeIntervalSince(context.date)))",
                             tint: .orange)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 12)
        .animation(.spring, value: boost)
        .accessibilityElement(children: .combine)
    }
}

/// The big tappable coin. Each tap pops a floating "+value" above it.
struct CoinButton: View {
    let tapValue: Double
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
                .padding(26)
                .glassEffect(.clear.interactive(), in: .circle)
                .frame(maxWidth: 262, maxHeight: 262)
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
        .accessibilityHint("Earns \(CoinFormat.short(tapValue)) coins per tap")
    }

    private func spawnFloater() {
        let floater = Floater(id: taps, text: "+\(CoinFormat.short(tapValue))", xOffset: .random(in: -60...60))
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
            .font(.title2.weight(.heavy))
            .fontDesign(.rounded)
            .foregroundStyle(Theme.bitcoin)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .offset(y: risen ? -90 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { risen = true }
            }
    }
}
