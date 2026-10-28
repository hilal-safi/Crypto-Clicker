import SwiftUI
import CryptoClickerKit

/// Crypto Slots: bet tokens and spin three reels. The spin is settled (and saved) the moment the
/// lever is pulled; the reels then animate to the result, stopping one at a time, and the
/// balances on screen wait for the last reel so the outcome isn't given away.
struct SlotsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var token = TokenID.shibaInu
    @State private var bet = 1
    @State private var stops = [0, 8, 16]
    @State private var spinning: Set<Int> = []
    /// The spin being revealed, and the one last revealed.
    @State private var pending: SlotsSpin?
    @State private var revealed: SlotsSpin?
    /// The wallet as it was before the spin being revealed (the balance is held by the store).
    @State private var heldCounts: [TokenID: Int]?
    @State private var reelStops = 0
    @State private var spinTask: Task<Void, Never>?
    @State private var showingPaytable = false
    @State private var effects = Effects()
    @State private var showingHelp = false

    private var isSpinning: Bool { !spinning.isEmpty }

    var body: some View {
        let game = store.game
        let counts = heldCounts ?? Dictionary(uniqueKeysWithValues: TokenID.allCases.map { ($0, game.tokenCount($0)) })
        GeometryReader { proxy in
            // Centered when it fits; scrolls on small phones rather than squeezing the reels.
            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    Text("CRYPTO SLOTS")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.gold.gradient)
                        .shadow(color: Theme.gold.opacity(0.5), radius: 12)
                    machine
                    outcome
                        .frame(minHeight: 56)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            controls(counts: counts, game: game)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: 520)
        }
        .background { VelvetBackground() }
        .overlay { EffectsLayer(effects: effects).ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .navigationTitle("Crypto Slots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .gameHelp(.slots, isPresented: $showingHelp)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CoinAmount(amount: store.heldCoins ?? game.coins, font: .subheadline.weight(.semibold), iconSize: 16)
                    .padding(.horizontal, 6)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Paytable", systemImage: "list.bullet.rectangle") { showingPaytable = true }
            }
        }
        .sheet(isPresented: $showingPaytable) { PaytableView() }
        .sensoryFeedback(.impact(weight: .medium), trigger: reelStops) { _, _ in haptics }
        .sensoryFeedback(trigger: revealed?.stops) { _, _ in
            guard haptics, let revealed else { return nil }
            return revealed.isWin ? .success : nil
        }
        .onAppear(perform: pickOwnedToken)
        .onDisappear(perform: finishRevealNow)
        .gameScreen()
    }

    // MARK: Pieces

    private var machine: some View {
        HStack(spacing: 10) {
            ForEach(0..<SlotMachine.reelCount, id: \.self) { reel in
                ReelView(stop: stops[reel], isSpinning: spinning.contains(reel))
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.08, blue: 0.32), .black.opacity(0.6)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.gold.gradient, lineWidth: 4)
        }
        .overlay {
            // The pay line.
            Capsule()
                .fill(Theme.gold.opacity(0.85))
                .frame(height: 3)
                .padding(.horizontal, 6)
                .shadow(color: Theme.gold, radius: 6)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isSpinning ? "Reels spinning" : "Reels: " + SlotMachine.line(stops: stops).map(\.name).joined(separator: ", "))
    }

    @ViewBuilder
    private var outcome: some View {
        if let revealed, !isSpinning {
            VStack(spacing: 4) {
                Text(title(for: revealed))
                    .font(.system(size: revealed.isWin ? 30 : 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(revealed.isWin ? AnyShapeStyle(Theme.gold.gradient) : AnyShapeStyle(.white.opacity(0.8)))
                    .shadow(color: revealed.isWin ? Theme.gold.opacity(0.6) : .clear, radius: 10)
                if revealed.isWin {
                    HStack(spacing: 10) {
                        Text("+\(CoinFormat.grouped(revealed.payout - revealed.bet)) \(revealed.token.ticker)")
                            .font(.headline)
                        CoinAmount(amount: revealed.bonus, font: .headline, iconSize: 18)
                            .foregroundStyle(Theme.gold)
                    }
                }
            }
            .foregroundStyle(.white)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
            .id(revealed.stops)
        } else {
            Text(isSpinning ? "Good luck!" : "Three of a kind wins. Bitcoin pays the most.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private func title(for spin: SlotsSpin) -> String {
        if spin.isJackpot { return "BITCOIN JACKPOT!" }
        if spin.multiple >= 25 { return "BIG WIN! ×\(spin.multiple)" }
        if spin.isWin { return "WIN ×\(spin.multiple)" }
        if spin.multiple == 1 { return "Bet back" }
        return "No win"
    }

    private func controls(counts: [TokenID: Int], game: GameState) -> some View {
        VStack(spacing: 12) {
            if TokenID.allCases.allSatisfy({ counts[$0, default: 0] == 0 }) {
                Label("Buy tokens on the Coin Exchange to play.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            TokenBetControls(token: $token, bet: $bet, counts: counts)
                .disabled(isSpinning)
            Text("Wins pay tokens plus up to \(CoinFormat.short(game.slotsBonus(bet: bet, token: token, multiple: SlotMachine.jackpot))) coins")
                .font(.footnote)
                .foregroundStyle(.subtext)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: spin) {
                Text(isSpinning ? "Spinning…" : "SPIN")
                    .font(.title3.weight(.black))
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            .disabled(isSpinning || counts[token, default: 0] < bet)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    // MARK: Spinning

    private func pickOwnedToken() {
        if store.game.tokenCount(token) == 0, let owned = TokenID.allCases.first(where: { store.game.tokenCount($0) > 0 }) {
            token = owned
        }
    }

    private func spin() {
        guard !isSpinning else { return }
        let game = store.game
        let counts = Dictionary(uniqueKeysWithValues: TokenID.allCases.map { ($0, game.tokenCount($0)) })
        let coins = game.coins
        guard let result = store.spinSlots(token, bet: bet) else { return }
        // Show the wallet as it was, minus the bet, until the reels stop.
        var held = counts
        held[result.token, default: 0] -= result.bet
        heldCounts = held
        store.heldCoins = coins
        pending = result
        withAnimation(.snappy) {
            revealed = nil
            spinning = Set(0..<SlotMachine.reelCount)
        }
        if reduceMotion {
            // No flickering reels: a short pause, then the result.
            spinTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                stops = result.stops
                spinning = []
                reelStops += 1
                reveal(result)
            }
        } else {
            spinTask = Task { await animateReels(to: result) }
        }
    }

    private func animateReels(to result: SlotsSpin) async {
        let stopTimes: [TimeInterval] = [0.9, 1.35, 1.8]
        let start = Date.now
        while !spinning.isEmpty {
            do {
                try await Task.sleep(for: .milliseconds(55))
            } catch {
                return
            }
            let elapsed = Date.now.timeIntervalSince(start)
            for reel in 0..<SlotMachine.reelCount where spinning.contains(reel) {
                if elapsed >= stopTimes[reel] {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        stops[reel] = result.stops[reel]
                        _ = spinning.remove(reel)
                    }
                    reelStops += 1
                } else {
                    // Symbols roll down the window, as on a real reel.
                    withAnimation(.linear(duration: 0.05)) {
                        stops[reel] = (stops[reel] - 1 + SlotMachine.strip.count) % SlotMachine.strip.count
                    }
                }
            }
        }
        reveal(result)
    }

    /// Shows the result: the real balance, the banner and, for wins, the celebration.
    private func reveal(_ result: SlotsSpin) {
        pending = nil
        heldCounts = nil
        store.heldCoins = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { revealed = result }
        var announcement = title(for: result)
        if result.isWin {
            announcement += ". \(result.payout - result.bet) \(result.token.name) and \(CoinFormat.short(result.bonus)) coins."
        }
        AccessibilityNotification.Announcement(announcement).post()
        guard result.isWin else { return }
        if result.isJackpot {
            effects.confetti(180, from: UnitPoint(x: 0.5, y: 0.4))
            effects.rainCoins(40)
            effects.coinFountain(30, from: UnitPoint(x: 0.5, y: 0.5))
        } else {
            effects.confetti(result.multiple >= 25 ? 130 : 70, from: UnitPoint(x: 0.5, y: 0.4))
            effects.coinFountain(result.multiple >= 25 ? 24 : 12, from: UnitPoint(x: 0.5, y: 0.5))
        }
    }

    /// Leaving mid-spin skips the animation; the spin itself was already paid.
    private func finishRevealNow() {
        spinTask?.cancel()
        spinTask = nil
        if let pending {
            stops = pending.stops
            spinning = []
            reveal(pending)
        }
    }
}

/// One reel: the symbol on the pay line, with its neighbours above and below.
private struct ReelView: View {
    let stop: Int
    let isSpinning: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 6) {
                symbol(at: stop - 1)
                    .opacity(0.4)
                    .scaleEffect(0.75)
                symbol(at: stop)
                symbol(at: stop + 1)
                    .opacity(0.4)
                    .scaleEffect(0.75)
            }
            .id(stop)
            .transition(.push(from: .top))
            .blur(radius: isSpinning ? 1.2 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipped()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.82), .white, Color(white: 0.82)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
    }

    private func symbol(at index: Int) -> some View {
        let token = SlotMachine.line(stops: [index])[0]
        return TokenImage(token: token, size: 44)
            .frame(height: 44)
    }
}

/// What every line pays.
private struct PaytableView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TokenID.allCases.reversed()) { token in
                        row(Array(repeating: token, count: 3), "×\(SlotMachine.threeOfAKind(token))")
                    }
                } header: {
                    Text("Three of a kind")
                }
                Section {
                    row([.bitcoin, .bitcoin], "×\(SlotMachine.twoBitcoins)", note: "Any two Bitcoins")
                    row([.dogecoin, .dogecoin], "×\(SlotMachine.pairOnFirstTwo)", note: "First two reels match")
                    row([.bitcoin], "×\(SlotMachine.oneBitcoin)", note: "Any Bitcoin returns your bet")
                } header: {
                    Text("More ways to win")
                } footer: {
                    Text("Payouts include your bet. Each spin pays its best line. Winning spins also pay coins, more for bigger wins. Over time the machine returns about \(CoinFormat.percent(SlotMachine.returnToPlayer)) of the tokens bet.")
                }
            }
            .navigationTitle("Paytable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ tokens: [TokenID], _ pays: String, note: String? = nil) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                TokenImage(token: token, size: 30)
            }
            if let note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            Spacer()
            Text(pays)
                .font(.headline.monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(note ?? tokens.map(\.name).joined(separator: ", ")) pays \(pays)")
    }
}
