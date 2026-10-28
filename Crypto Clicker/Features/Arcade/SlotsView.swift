import SwiftUI
import CryptoClickerKit

/// Crypto Slots: bet tokens and spin three reels. The spin is settled (and saved) the moment the
/// lever is pulled; the reels then animate to the result, stopping one at a time on a fixed beat
/// whatever the result (no slowed-down "almost" reels), and the balances on screen wait for the
/// last reel so the outcome isn't given away. A Cardano, a Solana and an Ethereum win free spins;
/// every tenth Bitcoin on the line pays a collection prize.
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
    /// The Bitcoin collection as it was before the spin being revealed, so it doesn't give a
    /// Bitcoin away before the reels stop.
    @State private var heldBitcoins: Int?
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
        let winning = isSpinning ? [] : Set(revealed?.winningReels ?? [])
        return HStack(spacing: 10) {
            ForEach(0..<SlotMachine.reelCount, id: \.self) { reel in
                ReelView(stop: stops[reel], isSpinning: spinning.contains(reel), isWinning: winning.contains(reel),
                         look: store.game.equipped(.reels))
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
                .strokeBorder(LinearGradient(colors: store.game.equipped(.reels).reelFrame, startPoint: .top, endPoint: .bottom),
                              lineWidth: 4)
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
            let lit = revealed.isWin || revealed.freeSpinsWon > 0
            VStack(spacing: 4) {
                Text(title(for: revealed))
                    .font(.system(size: lit ? 30 : 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(lit ? AnyShapeStyle(Theme.gold.gradient) : AnyShapeStyle(.white.opacity(0.8)))
                    .shadow(color: lit ? Theme.gold.opacity(0.6) : .clear, radius: 10)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                // The whole spin in one line: what it cost, what it paid, and the difference.
                HStack(spacing: 10) {
                    Text(revealed.isFree ? "Free spin" : "Bet \(CoinFormat.grouped(revealed.bet))")
                    Text("Paid \(CoinFormat.grouped(revealed.payout))")
                    Text("Net \(revealed.net >= 0 ? "+" : "−")\(CoinFormat.grouped(abs(revealed.net))) \(revealed.token.ticker)")
                        .fontWeight(.bold)
                        .foregroundStyle(revealed.net > 0 ? Theme.gold : revealed.net < 0 ? .white.opacity(0.7) : .white)
                }
                .font(.subheadline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                if revealed.bonus + revealed.collectionPrize > 0 {
                    HStack(spacing: 6) {
                        CoinAmount(amount: revealed.bonus + revealed.collectionPrize, font: .headline, iconSize: 18)
                            .foregroundStyle(Theme.gold)
                        if revealed.collectionPrize > 0 {
                            Text("with the Bitcoin collection prize")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
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
        if spin.freeSpinsWon > 0 { return "\(spin.freeSpinsWon) FREE SPINS!" }
        if spin.multiple >= 25 { return "BIG WIN! ×\(spin.multiple)" }
        if spin.isWin { return "WIN ×\(spin.multiple)" }
        if spin.multiple == 1 { return "Bet back" }
        return "No win"
    }

    private func controls(counts: [TokenID: Int], game: GameState) -> some View {
        // Free spins keep the bet that won them; while the reels reveal the spin that won them,
        // they don't show yet.
        let free = pending == nil ? game.slotsFreeSpins : nil
        return VStack(spacing: 12) {
            if let free {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(Theme.gold)
                    Text("\(free.left) free \(free.left == 1 ? "spin" : "spins") at \(CoinFormat.grouped(free.bet)) \(free.token.ticker)")
                        .font(.headline.monospacedDigit())
                    Spacer(minLength: 0)
                    TokenImage(token: free.token, size: 26)
                }
            } else {
                if TokenID.allCases.allSatisfy({ counts[$0, default: 0] == 0 }) {
                    Label("Buy tokens on the Coin Exchange to play.", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                TokenBetControls(token: $token, bet: $bet, counts: counts)
                    .disabled(isSpinning)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Wins pay tokens plus up to \(CoinFormat.short(game.slotsBonus(bet: free?.bet ?? bet, token: free?.token ?? token, multiple: SlotMachine.jackpot))) coins")
                Spacer(minLength: 8)
                BitcoinCollection(count: heldBitcoins ?? game.slotsBitcoinsTowardPrize, prize: game.slotsCollectionPrize)
            }
            .font(.footnote)
            .foregroundStyle(.subtext)
            Button(action: spin) {
                Text(isSpinning ? "Spinning…" : free != nil ? "FREE SPIN" : "SPIN")
                    .font(.title3.weight(.black))
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(free != nil ? Theme.gold : Theme.accent)
            .disabled(isSpinning || (free == nil && counts[token, default: 0] < bet))
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
        let bitcoins = game.slotsBitcoinsTowardPrize
        guard let result = store.spinSlots(token, bet: bet) else { return }
        heldBitcoins = bitcoins
        // Show the wallet as it was, minus the bet (none for a free spin), until the reels stop.
        var held = counts
        held[result.token, default: 0] -= result.isFree ? 0 : result.bet
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
        heldBitcoins = nil
        store.heldCoins = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { revealed = result }
        var announcement = title(for: result)
        if result.isWin {
            announcement += ". Net \(result.net) \(result.token.name) and \(CoinFormat.short(result.bonus)) coins."
        }
        if result.collectionPrize > 0 { announcement += " Bitcoin collection prize: \(CoinFormat.short(result.collectionPrize)) coins." }
        AccessibilityNotification.Announcement(announcement).post()
        if result.freeSpinsWon > 0 {
            effects.confetti(90, from: UnitPoint(x: 0.5, y: 0.4))
        }
        if result.collectionPrize > 0 {
            effects.coinFountain(16, from: UnitPoint(x: 0.8, y: 0.85))
        }
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

/// One reel: the symbol on the pay line, with its neighbours above and below. A reel that's part of
/// the win glows.
private struct ReelView: View {
    let stop: Int
    let isSpinning: Bool
    var isWinning = false
    /// The reels picked in Style.
    var look: Cosmetic = .reelsClassic

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
                .fill(LinearGradient(colors: look.reelFace, startPoint: .top, endPoint: .bottom))
        }
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
        .overlay {
            if isWinning {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.gold, lineWidth: 4)
                    .shadow(color: Theme.gold, radius: 10)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: isWinning)
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
                }
                Section {
                    row([.cardano, .solana, .ethereum], "\(SlotMachine.freeSpinsAwarded) free", note: "Any order")
                } header: {
                    Text("Free spins")
                } footer: {
                    Text("A Cardano, a Solana and an Ethereum on the line, in any order, win \(SlotMachine.freeSpinsAwarded) free spins at the same bet, and they can win more. About 1 spin in \(Int((1 / SlotMachine.freeSpinChance).rounded())) wins them.")
                }
                Section {
                    row([.bitcoin], "\(SlotMachine.bitcoinsPerPrize) ₿", note: "Bitcoin collection")
                } footer: {
                    Text("Every Bitcoin on the line goes into your collection, and every \(SlotMachine.bitcoinsPerPrize) pay a coin prize. It never changes the odds of a spin.\n\nPayouts include your bet. Each spin pays its best line. Winning spins also pay coins, more for bigger wins. Over time the machine returns about \(CoinFormat.percent(SlotMachine.returnToPlayer)) of the tokens bet, free spins included. Every spin is independent: a near miss doesn't make the next win more likely.")
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

/// Bitcoins collected toward the next prize.
private struct BitcoinCollection: View {
    let count: Int
    let prize: Double

    var body: some View {
        HStack(spacing: 4) {
            TokenImage(token: .bitcoin, size: 16)
            Text("\(count)/\(SlotMachine.bitcoinsPerPrize)")
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bitcoin collection: \(count) of \(SlotMachine.bitcoinsPerPrize). The next prize pays \(CoinFormat.short(prize)) coins")
    }
}
