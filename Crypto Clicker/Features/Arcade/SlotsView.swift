import SwiftUI
import CryptoClickerKit

/// Crypto Slots: bet tokens and spin, on the classic three reels with one pay line or the video
/// machine's five reels of three rows with five pay lines. The spin is settled (and saved) the
/// moment the lever is pulled; the reels then animate to the result, stopping one at a time on a
/// fixed beat whatever the result (no slowed-down "almost" reels), and the balances on screen wait
/// for the last reel so the outcome isn't given away. On the classic machine a Cardano, a Solana
/// and an Ethereum win free spins, on the video machine three Bitcoins anywhere; every tenth
/// Bitcoin collected pays a collection prize.
struct SlotsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    /// The machine picked: remembered between visits.
    @AppStorage("slotsMachine") private var machine = SlotMachineKind.classic
    @State private var token = TokenID.shibaInu
    /// The bet per line.
    @State private var bet = 1
    /// Every reel's stop (the classic machine uses the first three).
    @State private var stops = [0, 8, 16, 4, 12]
    @State private var spinning: Set<Int> = []
    /// The spin being revealed, and the one last revealed.
    @State private var pending: SlotsSpin?
    @State private var revealed: SlotsSpin?
    /// What the spin earned toward Arcade Rank, shown with its result.
    @State private var pendingXP: ArcadeAward?
    @State private var revealedXP: ArcadeAward?
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

    /// The result on the reels now, for the machine on screen.
    private var shownResult: SlotsSpin? { revealed?.machine == machine ? revealed : nil }

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
                    reels
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
        .background { VelvetBackground(look: store.game.equipped(.slotsBackdrop)) }
        .overlay { EffectsLayer(effects: effects).ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .navigationTitle("Crypto Slots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .gameHelp(.slots, isPresented: $showingHelp)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Paytable", systemImage: "list.bullet.rectangle") { showingPaytable = true }
            }
        }
        .sheet(isPresented: $showingPaytable) { PaytableView(machine: machine) }
        .sensoryFeedback(.impact(weight: .medium), trigger: reelStops) { _, _ in haptics }
        .sensoryFeedback(trigger: revealed?.stops) { _, _ in
            guard haptics, let revealed else { return nil }
            return revealed.isWin ? .success : nil
        }
        .onAppear {
            // Waiting free spins are played on the machine that won them.
            if let free = store.game.slotsFreeSpins { machine = free.machine }
            pickOwnedToken()
        }
        .onDisappear(perform: finishRevealNow)
        .gameScreen()
    }

    // MARK: Pieces

    @ViewBuilder
    private var reels: some View {
        switch machine {
        case .classic: classicReels
        case .video: videoReels
        }
    }

    private var classicReels: some View {
        let winning = isSpinning ? [] : Set(shownResult?.winningReels ?? [])
        return HStack(spacing: 10) {
            ForEach(0..<SlotMachine.reelCount, id: \.self) { reel in
                ReelView(stop: stops[reel], isSpinning: spinning.contains(reel), isWinning: winning.contains(reel),
                         look: store.game.equipped(.reels))
            }
        }
        .padding(12)
        .machineFrame(look: store.game.equipped(.reels))
        .overlay {
            // The pay line.
            Capsule()
                .fill(Theme.gold.opacity(0.85))
                .frame(height: 3)
                .padding(.horizontal, 6)
                .shadow(color: Theme.gold, radius: 6)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isSpinning ? "Reels spinning" : "Reels: " + SlotMachine.line(stops: Array(stops.prefix(3))).map(\.name).joined(separator: ", "))
    }

    private var videoReels: some View {
        let result = isSpinning ? nil : shownResult
        let winning = result?.winningCells ?? []
        return HStack(spacing: VideoReelLayout.spacing) {
            ForEach(0..<VideoSlots.reelCount, id: \.self) { reel in
                VideoReelView(stop: stops[reel], isSpinning: spinning.contains(reel),
                              winningRows: Set(winning.filter { $0.reel == reel }.map(\.row)),
                              look: store.game.equipped(.reels))
            }
        }
        .overlay {
            if let result, !result.lineWins.isEmpty {
                WinningLines(wins: result.lineWins)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.25), value: result?.lineWins)
        .padding(10)
        .machineFrame(look: store.game.equipped(.reels))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isSpinning ? "Reels spinning" : videoAccessibilityLabel)
    }

    private var videoAccessibilityLabel: String {
        let rows = (0..<VideoSlots.rowCount).map { row in
            stops.prefix(VideoSlots.reelCount).map { VideoSlots.symbol(stop: $0, row: row).name }.joined(separator: ", ")
        }
        return "Top row: \(rows[0]). Middle row: \(rows[1]). Bottom row: \(rows[2])."
    }

    @ViewBuilder
    private var outcome: some View {
        if let revealed = shownResult, !isSpinning {
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
                    Text(revealed.isFree ? "Free spin" : "Bet \(CoinFormat.grouped(revealed.stake))")
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
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
            }
            .foregroundStyle(.white)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
            .id(revealed.stops)
            ArcadeXPEarned(award: revealedXP, compact: true)
        } else {
            Text(isSpinning ? "Good luck!" : machine == .classic
                 ? "Three of a kind wins. Bitcoin pays the most."
                 : "Three or more in a row from the left reel win, on any of five lines. Three Bitcoins anywhere win free spins.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private func title(for spin: SlotsSpin) -> String {
        if spin.isJackpot { return "BITCOIN JACKPOT!" }
        if spin.freeSpinsWon > 0 { return "\(spin.freeSpinsWon) FREE SPINS!" }
        if spin.stakeMultiple >= 25 { return "BIG WIN! \(CoinFormat.multiplier(spin.stakeMultiple))" }
        if spin.isWin {
            let lines = spin.lineWins.count
            return lines > 1 ? "\(lines) LINES WIN \(CoinFormat.multiplier(spin.stakeMultiple))" : "WIN \(CoinFormat.multiplier(spin.stakeMultiple))"
        }
        if spin.multiple > 0 { return "Bet back" }
        return "No win"
    }

    private func controls(counts: [TokenID: Int], game: GameState) -> some View {
        // Free spins keep the bet that won them; while the reels reveal the spin that won them,
        // they don't show yet.
        let free = pending == nil ? game.slotsFreeSpins : nil
        let lines = machine.lines
        return VStack(spacing: 12) {
            Picker("Machine", selection: $machine) {
                ForEach(SlotMachineKind.allCases) { kind in
                    Text(kind.name).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isSpinning || game.slotsFreeSpins != nil)
            .onChange(of: machine) { _, _ in
                withAnimation(.snappy) { revealed = nil }
            }
            if let free {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(Theme.gold)
                    Text("\(free.left) free \(free.left == 1 ? "spin" : "spins") at \(CoinFormat.grouped(free.bet)) \(free.token.ticker)\(free.machine == .video ? " a line" : "")")
                        .font(.headline.monospacedDigit())
                    Spacer(minLength: 0)
                    TokenImage(token: free.token, size: 26)
                }
            } else {
                if TokenID.allCases.allSatisfy({ counts[$0, default: 0] == 0 }) {
                    Label("Buy tokens in the Shop to play.", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                TokenBetControls(token: $token, bet: $bet, counts: counts, lines: lines)
                    .disabled(isSpinning)
            }
            HStack(alignment: .firstTextBaseline) {
                let jackpot = machine == .classic ? SlotMachine.jackpot : VideoSlots.jackpot
                Text("Wins pay tokens plus up to \(CoinFormat.short(game.slotsBonus(bet: free?.bet ?? bet, token: free?.token ?? token, multiple: jackpot, machine: machine))) coins")
                Spacer(minLength: 8)
                BitcoinCollection(count: heldBitcoins ?? game.slotsBitcoinsTowardPrize, prize: game.slotsCollectionPrize)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
            Button(action: spin) {
                Text(isSpinning ? "Spinning…" : free != nil ? "FREE SPIN" : "SPIN")
                    .font(.title3.weight(.black))
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(free != nil ? Theme.gold : Theme.accent)
            .disabled(isSpinning || (free == nil && counts[token, default: 0] < bet * lines))
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
        guard let result = store.spinSlots(token, bet: bet, machine: machine) else { return }
        pendingXP = store.lastArcadeAward
        heldBitcoins = bitcoins
        // Show the wallet as it was, minus the stake (none for a free spin), until the reels stop.
        var held = counts
        held[result.token, default: 0] -= result.isFree ? 0 : result.stake
        heldCounts = held
        store.heldCoins = coins
        pending = result
        withAnimation(.snappy) {
            revealed = nil
            spinning = Set(0..<result.machine.reelCount)
        }
        if reduceMotion {
            // No flickering reels: a short pause, then the result.
            spinTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                land(result)
                spinning = []
                reelStops += 1
                reveal(result)
            }
        } else {
            spinTask = Task { await animateReels(to: result) }
        }
    }

    /// Puts every reel on the result's stops.
    private func land(_ result: SlotsSpin) {
        for reel in result.stops.indices { stops[reel] = result.stops[reel] }
    }

    private func animateReels(to result: SlotsSpin) async {
        let stopTimes: [TimeInterval] = result.machine == .classic ? [0.9, 1.35, 1.8] : [0.8, 1.1, 1.4, 1.7, 2.0]
        let start = Date.now
        while !spinning.isEmpty {
            do {
                try await Task.sleep(for: .milliseconds(55))
            } catch {
                return
            }
            let elapsed = Date.now.timeIntervalSince(start)
            for reel in 0..<result.machine.reelCount where spinning.contains(reel) {
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
        revealedXP = pendingXP
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
            let big = result.stakeMultiple >= 25
            effects.confetti(big ? 130 : 70, from: UnitPoint(x: 0.5, y: 0.4))
            effects.coinFountain(big ? 24 : 12, from: UnitPoint(x: 0.5, y: 0.5))
        }
    }

    /// Leaving mid-spin skips the animation; the spin itself was already paid.
    private func finishRevealNow() {
        spinTask?.cancel()
        spinTask = nil
        if let pending {
            land(pending)
            spinning = []
            reveal(pending)
        }
    }
}

private extension View {
    /// The machine's cabinet around the reels.
    func machineFrame(look: Cosmetic) -> some View {
        background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.08, blue: 0.32), .black.opacity(0.6)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(LinearGradient(colors: look.reelFrame, startPoint: .top, endPoint: .bottom), lineWidth: 4)
        }
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
    }
}

/// One classic reel: the symbol on the pay line, with its neighbours above and below. A reel that's
/// part of the win glows.
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

/// The video reels' measurements, shared with the winning lines drawn over them.
private enum VideoReelLayout {
    static let rowHeight: CGFloat = 48
    static let rowSpacing: CGFloat = 4
    /// Between reels.
    static let spacing: CGFloat = 6
}

/// One video reel: three rows, every one in play. Winning positions glow.
private struct VideoReelView: View {
    let stop: Int
    let isSpinning: Bool
    var winningRows: Set<Int> = []
    var look: Cosmetic = .reelsClassic

    var body: some View {
        ZStack {
            VStack(spacing: VideoReelLayout.rowSpacing) {
                ForEach(0..<VideoSlots.rowCount, id: \.self) { row in
                    TokenImage(token: VideoSlots.symbol(stop: stop, row: row), size: 36)
                        .frame(height: VideoReelLayout.rowHeight)
                }
            }
            .id(stop)
            .transition(.push(from: .top))
            .blur(radius: isSpinning ? 1.2 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: VideoReelLayout.rowHeight * 3 + VideoReelLayout.rowSpacing * 2)
        .clipped()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: look.reelFace, startPoint: .top, endPoint: .bottom))
        }
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .overlay {
            VStack(spacing: VideoReelLayout.rowSpacing) {
                ForEach(0..<VideoSlots.rowCount, id: \.self) { row in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.gold, lineWidth: 3)
                        .shadow(color: Theme.gold, radius: 6)
                        .opacity(winningRows.contains(row) ? 1 : 0)
                        .frame(height: VideoReelLayout.rowHeight)
                }
            }
            .padding(.horizontal, 2)
        }
        .animation(.easeOut(duration: 0.25), value: winningRows)
    }
}

/// The video machine's winning lines, drawn through the positions that won.
private struct WinningLines: View {
    let wins: [SlotLineWin]

    var body: some View {
        Canvas { context, size in
            let reels = CGFloat(VideoSlots.reelCount)
            let reelWidth = (size.width - VideoReelLayout.spacing * (reels - 1)) / reels
            func center(_ cell: SlotCell) -> CGPoint {
                CGPoint(x: CGFloat(cell.reel) * (reelWidth + VideoReelLayout.spacing) + reelWidth / 2,
                        y: CGFloat(cell.row) * (VideoReelLayout.rowHeight + VideoReelLayout.rowSpacing) + VideoReelLayout.rowHeight / 2)
            }
            for win in wins {
                var path = Path()
                let cells = win.cells
                path.move(to: center(cells[0]))
                for cell in cells.dropFirst() { path.addLine(to: center(cell)) }
                context.stroke(path, with: .color(Theme.gold.opacity(0.85)),
                               style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
        .shadow(color: Theme.gold, radius: 6)
    }
}

/// What every line pays, on the machine picked.
private struct PaytableView: View {
    let machine: SlotMachineKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                switch machine {
                case .classic: classic
                case .video: video
                }
            }
            .navigationTitle(machine == .classic ? "Classic Paytable" : "Video Paytable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var classic: some View {
        Section {
            ForEach(TokenID.allCases.filter(SlotMachine.strip.contains).reversed()) { token in
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
            SettingsNote("A Cardano, a Solana and an Ethereum on the line, in any order, win \(SlotMachine.freeSpinsAwarded) free spins at the same bet, and they can win more. About 1 spin in \(Int((1 / SlotMachine.freeSpinChance).rounded())) wins them.")
        }
        Section {
            row([.bitcoin], "\(SlotMachine.bitcoinsPerPrize) ₿", note: "Bitcoin collection")
        } footer: {
            SettingsNote("Every Bitcoin on the line goes into your collection, and every \(SlotMachine.bitcoinsPerPrize) pay a coin prize. It never changes the odds of a spin.\n\nPayouts include your bet. Each spin pays its best line. Winning spins also pay coins, more for bigger wins. Over time the machine returns about \(CoinFormat.percent(SlotMachine.returnToPlayer)) of the tokens bet, free spins included. Every spin is independent: a near miss doesn't make the next win more likely.")
        }
    }

    @ViewBuilder
    private var video: some View {
        Section {
            ForEach(TokenID.allCases.filter(VideoSlots.strip.contains).reversed()) { token in
                runRow(token)
            }
        } header: {
            Text("Three, four or five in a row")
        } footer: {
            SettingsNote("Pays are times the bet per line, from the left reel along a line. Every winning line pays.")
        }
        Section {
            LinesDiagram()
                .frame(height: 64)
                .listRowBackground(Color.clear)
        } header: {
            Text("Five lines")
        } footer: {
            SettingsNote("The middle, top and bottom rows, a V and an upside-down V. A spin bets on all five, so it stakes five times the bet.")
        }
        Section {
            row([.bitcoin, .bitcoin, .bitcoin], "\(VideoSlots.freeSpins(scatters: 3)) free", note: "Anywhere")
            row([.bitcoin, .bitcoin, .bitcoin, .bitcoin], "\(VideoSlots.freeSpins(scatters: 4)) free")
            row([.bitcoin, .bitcoin, .bitcoin, .bitcoin, .bitcoin], "\(VideoSlots.freeSpins(scatters: 5)) free")
        } header: {
            Text("Free spins")
        } footer: {
            SettingsNote("Three or more Bitcoins anywhere on the reels win free spins at the same bet, and they can win more. About 1 spin in \(Int((1 / VideoSlots.freeSpinChance).rounded())) wins them.\n\nBitcoins on the middle row go into your collection. Over time the machine returns about \(CoinFormat.percent(VideoSlots.returnToPlayer)) of the tokens bet, free spins included. Wins are rarer and bigger than on the classic machine. Every spin is independent.")
        }
    }

    /// What three, four and five of `token` in a row pay.
    private func runRow(_ token: TokenID) -> some View {
        let counts = Array(3...VideoSlots.reelCount)
        let spoken = counts.map { "\($0) pay \(VideoSlots.pays(token, count: $0)) times the line bet" }
        return HStack(spacing: 8) {
            TokenImage(token: token, size: 30)
            Spacer()
            ForEach(counts, id: \.self) { count in
                Text("\(count): ×\(VideoSlots.pays(token, count: count))")
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 72, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(token.name): " + spoken.joined(separator: ", "))
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

/// The five pay lines, side by side on little 5×3 grids.
private struct LinesDiagram: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(VideoSlots.paylines.indices, id: \.self) { line in
                Canvas { context, size in
                    let cellWidth = size.width / CGFloat(VideoSlots.reelCount)
                    let cellHeight = size.height / CGFloat(VideoSlots.rowCount)
                    for reel in 0..<VideoSlots.reelCount {
                        for row in 0..<VideoSlots.rowCount {
                            let rect = CGRect(x: CGFloat(reel) * cellWidth + 1, y: CGFloat(row) * cellHeight + 1,
                                              width: cellWidth - 2, height: cellHeight - 2)
                            let isOnLine = VideoSlots.paylines[line][reel] == row
                            context.fill(Path(roundedRect: rect, cornerRadius: 2),
                                         with: .color(isOnLine ? Theme.gold : .secondary.opacity(0.25)))
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lines: the middle row, the top row, the bottom row, a V and an upside-down V")
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
