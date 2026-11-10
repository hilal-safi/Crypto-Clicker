import SwiftUI
import CryptoClickerKit

/// Blackjack against the dealer on a felt table, betting crypto tokens or practice chips. The rules
/// live in `BlackjackTable`; this view moves tokens in and out of the wallet, offers insurance when
/// the dealer shows an ace, paces the cards (a short beat for the player's, a longer one for each of
/// the dealer's, so a dealer's blackjack is seen before the round ends), and celebrates wins with
/// confetti and a shower of coins. Two tables (the dealer stands on or hits a soft 17) and an
/// optional coach that suggests the basic-strategy move.
struct BlackjackView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage("blackjackTable") private var tableRules = BlackjackRules.standsOnSoft17
    @AppStorage("blackjackCoach") private var showsCoach = false
    @State private var table = BlackjackTable()
    @State private var isPracticing = false
    @State private var chips = PracticeChips()
    @State private var practiceBet = 25
    /// The round in play bets practice chips.
    @State private var roundIsPractice = false
    @State private var token = TokenID.shibaInu
    @State private var bet = 1
    /// The token staked on the current round (the picker may change between rounds).
    @State private var roundToken = TokenID.shibaInu
    @State private var isSettled = true
    @State private var lastBonus = 0.0
    @State private var settledRounds = 0
    @State private var effects = Effects()
    @State private var showingHelp = false
    /// Height of the table above the controls; short screens get smaller cards so both hands fit.
    @State private var tableHeight: CGFloat = 600
    /// A card the player asked for, on its way: it lands after a short beat, like one dealt from the
    /// shoe, and the buttons wait for it.
    @State private var pendingDraw: Task<Void, Never>?

    var body: some View {
        let game = store.game
        let cardSize = tableHeight < 430 ? CGSize(width: 54, height: 78) : CGSize(width: 64, height: 92)
        ScrollView {
            VStack(spacing: 12) {
                DealerArea(table: table, cardSize: cardSize)
                // The result takes the place of the table printing, so nothing below it moves.
                ZStack {
                    if table.phase == .settled {
                        ResultBanner(results: table.results, insurance: table.insurance, bonus: lastBonus, unit: unit)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else if let insurance = table.insurance {
                        InsuranceNote(insurance: insurance, unit: unit)
                            .transition(.opacity)
                    } else {
                        TableMarkings(rules: table.rules, isPractice: table.phase == .betting ? isPracticing : roundIsPractice)
                            .transition(.opacity)
                    }
                }
                .frame(height: 56)
                if table.hands.count > 1 {
                    // Split hands sit side by side, so the whole table fits without scrolling.
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(table.hands) { hand in
                            handView(hand, cardSize: CGSize(width: cardSize.width * 0.82, height: cardSize.height * 0.82),
                                     isCompact: true)
                        }
                    }
                } else {
                    ForEach(table.hands) { hand in
                        handView(hand, cardSize: cardSize, isCompact: false)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tableHeight = $0 }
        .safeAreaInset(edge: .bottom) {
            controls(game: game)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: 600)
        }
        .background { FeltBackground(look: game.equipped(.felt)) }
        .environment(\.cardBack, game.equipped(.cardBack))
        .overlay { EffectsLayer(effects: effects).ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .navigationTitle(MiniGame.blackjack.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .gameHelp(.blackjack, isPresented: $showingHelp)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Table", selection: $tableRules) {
                        ForEach(BlackjackRules.allCases) { rules in
                            Text("\(rules.name): \(rules.dealerRule)").tag(rules)
                        }
                    }
                    .disabled(!(table.phase == .betting || table.phase == .settled))
                    Toggle("Coach", systemImage: "lightbulb", isOn: $showsCoach)
                } label: {
                    Label("Table options", systemImage: "slider.horizontal.3")
                }
            }
        }
        .onAppear { table.setRules(tableRules) }
        .onChange(of: tableRules) { _, rules in table.setRules(rules) }
        .sensoryFeedback(trigger: settledRounds) { _, _ in
            guard haptics, let best = table.results.map(\.net).max() else { return nil }
            return best > 0 ? .success : best == 0 ? .warning : .error
        }
        .task(id: table.phase) { await playDealer() }
        .onAppear(perform: pickOwnedToken)
        .onDisappear(perform: leaveTable)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { leaveTable() }
        }
        .gameScreen()
    }

    private func handView(_ hand: BlackjackHand, cardSize: CGSize, isCompact: Bool) -> some View {
        HandView(hand: hand,
                 isActive: table.activeHand?.id == hand.id && table.hands.count > 1,
                 result: table.results.indices.contains(hand.id) ? table.results[hand.id] : nil,
                 token: roundIsPractice ? nil : roundToken, cardSize: cardSize, isCompact: isCompact)
    }

    /// What the round's bets are counted in.
    private var unit: String { roundIsPractice ? "chips" : roundToken.ticker }

    // MARK: Controls

    @ViewBuilder
    private func controls(game: GameState) -> some View {
        switch table.phase {
        case .betting, .settled:
            let owned = game.tokenCount(token)
            VStack(spacing: 10) {
                CasinoModePicker(isPracticing: $isPracticing)
                if isPracticing {
                    PracticeBetControls(chips: chips, bet: $practiceBet)
                    if chips.isBroke {
                        Button("New Stack of \(CoinFormat.grouped(PracticeChips.starting)) Chips") { chips.refill() }
                            .font(.subheadline.weight(.bold))
                            .buttonStyle(.borderless)
                            .tint(Theme.gold)
                    }
                } else {
                    if TokenID.allCases.allSatisfy({ game.tokenCount($0) == 0 }) {
                        Label("Buy tokens in the Shop to place bets, or practice with chips.", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.subtext)
                    }
                    TokenBetControls(token: $token, bet: $bet,
                                     counts: Dictionary(uniqueKeysWithValues: TokenID.allCases.map { ($0, game.tokenCount($0)) }))
                    let fullBonusBet = game.blackjackBetForFullBonus(token)
                    HStack(alignment: .firstTextBaseline) {
                        Text("A win also pays \(CoinFormat.short(game.blackjackBonus(bet: bet, token: token, rules: tableRules))) coins")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        if bet < fullBonusBet && owned > bet {
                            Button("Max Bonus") { bet = min(owned, fullBonusBet) }
                                .font(.subheadline.weight(.bold))
                                .buttonStyle(.borderless)
                                .tint(Theme.gold)
                        }
                    }
                }
                Button(action: deal) {
                    Text(table.phase == .settled ? "Deal Again" : "Deal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .disabled(isPracticing ? chips.balance < practiceBet : owned < bet)
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        case .insurance:
            let cost = table.insuranceCost
            let canAfford = roundIsPractice ? chips.balance >= cost : game.tokenCount(roundToken) >= cost
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("The dealer shows an ace. Insurance?")
                        .font(.headline)
                    Text("It costs \(CoinFormat.grouped(cost)) \(unit) and pays 2 to 1 if the dealer has blackjack.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.white)
                if showsCoach {
                    coachLabel(BlackjackStrategy.takesInsurance ? "Insure" : "No insurance")
                }
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        actionButton("Insure", systemImage: "shield.fill",
                                     isAdvised: showsCoach && BlackjackStrategy.takesInsurance) { insure() }
                            .disabled(!canAfford)
                        actionButton("No Thanks", systemImage: "xmark",
                                     isAdvised: showsCoach && !BlackjackStrategy.takesInsurance) {
                            play { table, _ in table.resolveInsurance(insured: false) }
                        }
                    }
                }
            }
        case .playerTurn:
            let canAffordExtra = roundIsPractice
                ? chips.balance >= table.extraBetNeeded
                : game.tokenCount(roundToken) >= table.extraBetNeeded
            let advice = showsCoach ? table.suggestedMove : nil
            VStack(spacing: 8) {
                if let advice {
                    coachLabel(advice.name)
                }
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        actionButton("Hit", systemImage: "plus", isAdvised: advice == .hit) {
                            drawCard { play { $0.hit(using: &$1) } }
                        }
                        actionButton("Stand", systemImage: "hand.raised.fill", isAdvised: advice == .stand) {
                            play { table, _ in table.stand() }
                        }
                        if table.canDouble {
                            actionButton("Double", systemImage: "multiply", isAdvised: advice == .double) {
                                drawCard { raise(when: table.canDouble) { $0.doubleDown(using: &$1) } }
                            }
                            .disabled(!canAffordExtra)
                        }
                        if table.canSplit {
                            actionButton("Split", systemImage: "arrow.left.and.right", isAdvised: advice == .split) {
                                drawCard { raise(when: table.canSplit) { $0.split(using: &$1) } }
                            }
                            .disabled(!canAffordExtra)
                        }
                    }
                }
                .disabled(pendingDraw != nil)
            }
        case .dealerTurn:
            HStack(spacing: 10) {
                ProgressView()
                Text(dealerTurnTitle)
                    .font(.headline)
            }
            .padding()
        }
    }

    /// What the dealer's turn is doing: turning over a blackjack, paying a natural, or drawing.
    private var dealerTurnTitle: LocalizedStringKey {
        if table.dealer.count == 2 && table.dealerTotal == 21 { return "Dealer has blackjack…" }
        if table.hands.count == 1 && table.hands[0].isBlackjack { return "Natural 21!" }
        return "Dealer plays…"
    }

    private func coachLabel(_ advice: String) -> some View {
        Label("Coach: \(advice)", systemImage: "lightbulb.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.black.opacity(0.35), in: .capsule)
            .accessibilityLabel("Coach suggests \(advice)")
    }

    private func actionButton(_ title: String, systemImage: String, isAdvised: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .labelStyle(.titleOnly)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glass)
        .overlay {
            if isAdvised {
                Capsule()
                    .strokeBorder(Theme.gold, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: Round flow

    private func pickOwnedToken() {
        if store.game.tokenCount(token) == 0, let owned = TokenID.allCases.first(where: { store.game.tokenCount($0) > 0 }) {
            token = owned
        }
    }

    private func deal() {
        let stake: Int
        if isPracticing {
            guard chips.take(practiceBet) else { return }
            stake = practiceBet
        } else {
            guard bet > 0, store.placeBet(token, amount: bet) else { return }
            roundToken = token
            stake = bet
        }
        roundIsPractice = isPracticing
        isSettled = false
        lastBonus = 0
        play { $0.deal(bet: stake, using: &$1) }
    }

    /// Doubling and splitting stake the same bet again before acting. `allowed` is read at tap time,
    /// so a stale tap can never take tokens (or chips) for a move the table then refuses.
    private func raise(when allowed: Bool, _ action: (inout BlackjackTable, inout SystemRandomNumberGenerator) -> Void) {
        guard allowed else { return }
        let extra = table.extraBetNeeded
        if roundIsPractice {
            guard chips.take(extra) else { return }
        } else {
            guard store.placeBet(roundToken, amount: extra) else { return }
        }
        play(action)
    }

    /// Takes insurance: half the bet more, then the dealer checks for blackjack. The cost is read at
    /// tap time, like a double's, so a stale tap never takes tokens the table then refuses.
    private func insure() {
        guard table.phase == .insurance else { return }
        let cost = table.insuranceCost
        if roundIsPractice {
            guard chips.take(cost) else { return }
        } else {
            guard store.placeBet(roundToken, amount: cost) else { return }
        }
        play { table, _ in table.resolveInsurance(insured: true) }
    }

    /// Hits, doubles and splits land their card after a short beat; the buttons wait meanwhile.
    /// Leaving the table cancels the card on its way, before any bet is raised for it.
    private func drawCard(_ deal: @escaping () -> Void) {
        guard pendingDraw == nil else { return }
        pendingDraw = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            pendingDraw = nil
            deal()
        }
    }

    private func play(_ action: (inout BlackjackTable, inout SystemRandomNumberGenerator) -> Void) {
        var rng = SystemRandomNumberGenerator()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { action(&table, &rng) }
        settleIfFinished()
    }

    /// The dealer's turn at a steady pace: a beat to see the hole card turned over (a blackjack
    /// included), then each card the dealer draws.
    private func playDealer() async {
        var isFirstStep = true
        while table.phase == .dealerTurn {
            do {
                try await Task.sleep(for: .milliseconds(isFirstStep ? 950 : 800))
            } catch {
                return
            }
            isFirstStep = false
            play { $0.dealerStep(using: &$1) }
        }
    }

    /// Pays the round once: chips back to the practice stack, or tokens and coins through the store.
    private func settleIfFinished() {
        guard table.phase == .settled, !isSettled else { return }
        isSettled = true
        if roundIsPractice {
            chips.pay(table.totalPayout)
            lastBonus = 0
        } else {
            lastBonus = store.settleBlackjack(table.results, insurance: table.insurance, token: roundToken,
                                              rules: table.rules)
        }
        settledRounds += 1
        celebrate()
    }

    private func celebrate() {
        guard table.totalNet > 0 else { return }
        let natural = table.results.contains { $0.outcome == .blackjack }
        effects.confetti(natural ? 150 : 90, from: UnitPoint(x: 0.5, y: 0.55))
        effects.coinFountain(natural ? 28 : 16, from: UnitPoint(x: 0.5, y: 0.7))
        if natural { effects.rainCoins(24) }
    }

    /// Leaving mid-round turns down insurance, stands on every open hand and lets the dealer
    /// finish, so bets are never lost. (If the app is closed outright, the saved stake is refunded
    /// on the next launch.)
    private func leaveTable() {
        pendingDraw?.cancel()
        pendingDraw = nil
        guard [.insurance, .playerTurn, .dealerTurn].contains(table.phase) else { return }
        var rng = SystemRandomNumberGenerator()
        table.finishRound(using: &rng)
        settleIfFinished()
    }
}

// MARK: - Table pieces

private struct DealerArea: View {
    let table: BlackjackTable
    let cardSize: CGSize

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Dealer", systemImage: "person.fill")
                    .font(.headline)
                Spacer()
                if !table.dealer.isEmpty {
                    Text(table.isHoleCardHidden ? "Showing \(table.dealerUpValue ?? 0)" : "\(table.dealerTotal)")
                        .font(.headline.monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.3), in: .capsule)
                }
            }
            CardRow(cards: table.dealer, hidesSecondCard: table.isHoleCardHidden, cardSize: cardSize)
        }
        .foregroundStyle(.white)
    }
}

/// The printing on the felt between the dealer and the player.
private struct TableMarkings: View {
    let rules: BlackjackRules
    var isPractice = false

    var body: some View {
        VStack(spacing: 4) {
            Text("BLACKJACK PAYS 3 TO 2")
                .font(.subheadline.weight(.heavy))
                .tracking(2)
            Text(rules.dealerRule + (rules == .hitsSoft17 ? " · wins pay more coins" : "") + (isPractice ? " · practice" : ""))
                .font(.footnote.weight(.bold))
                .tracking(1)
        }
        .foregroundStyle(Theme.gold.opacity(0.7))
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) { Capsule().fill(Theme.gold.opacity(0.35)).frame(height: 1) }
        .overlay(alignment: .bottom) { Capsule().fill(Theme.gold.opacity(0.35)).frame(height: 1) }
        .accessibilityHidden(true)
    }
}

private struct HandView: View {
    let hand: BlackjackHand
    let isActive: Bool
    let result: BlackjackResult?
    /// The token bet, or `nil` for practice chips.
    let token: TokenID?
    let cardSize: CGSize
    /// Half the table's width, beside the other half of a split: everything stacks.
    var isCompact = false

    var body: some View {
        VStack(spacing: 8) {
            CardRow(cards: hand.cards, hidesSecondCard: false, cardSize: cardSize, overlap: isCompact ? 0.52 : 0.36)
            if isCompact {
                total
                HStack(spacing: 6) {
                    ChipStack(token: token, amount: hand.bet)
                    outcome
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            } else {
                HStack(spacing: 10) {
                    total
                    Spacer()
                    ChipStack(token: token, amount: hand.bet)
                    outcome
                }
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isActive ? Theme.gold : .white.opacity(0.18), lineWidth: isActive ? 2 : 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var total: some View {
        Text(hand.isBlackjack ? "Natural 21!" : hand.isBust ? "Bust" : "\(hand.isSoft ? "Soft " : "")\(hand.total)")
            .font(.headline.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.black.opacity(0.3), in: .capsule)
    }

    @ViewBuilder private var outcome: some View {
        if let result {
            Text(result.outcome.title)
                .font(.subheadline.bold())
                .foregroundStyle(result.net > 0 ? Theme.gold : result.net == 0 ? .white : Color(red: 1, green: 0.45, blue: 0.45))
        }
    }
}

/// The bet, shown as a casino chip with the token's artwork (a plain chip in practice).
private struct ChipStack: View {
    let token: TokenID?
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(token == nil ? Color.indigo.gradient : Theme.bitcoin.gradient)
                Circle()
                    .strokeBorder(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, dash: [4, 4]))
                    .padding(2)
                if let token {
                    TokenImage(token: token, size: 18)
                }
            }
            .frame(width: 30, height: 30)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            Text("\(CoinFormat.grouped(amount)) \(token?.ticker ?? "chips")")
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bet \(amount) \(token?.name ?? "practice chips")")
    }
}

private struct CardRow: View {
    let cards: [Card]
    let hidesSecondCard: Bool
    let cardSize: CGSize
    /// How much of each card the next one covers.
    var overlap = 0.36

    var body: some View {
        HStack(spacing: -cardSize.width * overlap) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                // A gentle fan, centred on the middle of the hand.
                let tilt = (Double(index) - Double(cards.count - 1) / 2) * 3
                PlayingCardView(card: card, isFaceDown: hidesSecondCard && index == 1, size: cardSize)
                    .rotationEffect(.degrees(tilt), anchor: .bottom)
                    .transition(.asymmetric(insertion: .offset(x: 140, y: -180).combined(with: .opacity),
                                            removal: .opacity))
            }
        }
        .frame(maxWidth: .infinity, minHeight: cardSize.height + 4)
    }
}

struct PlayingCardView: View {
    let card: Card
    var isFaceDown = false
    var size = CGSize(width: 64, height: 92)

    var body: some View {
        ZStack {
            if isFaceDown {
                CardBack()
            } else {
                CardFace(card: card)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(.black.opacity(0.18))
        }
        .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
        .accessibilityLabel(isFaceDown ? "Face-down card" : card.accessibilityName)
    }
}

private struct CardFace: View {
    let card: Card

    var body: some View {
        let color = card.suit.isRed ? Color(red: 0.85, green: 0.1, blue: 0.15) : Color.black
        ZStack {
            Color.white
            Text(card.suit.symbol)
                .font(.system(size: 34))
            VStack(spacing: -2) {
                Text(card.label)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(card.suit.symbol)
                    .font(.system(size: 13))
            }
            .padding(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack(spacing: -2) {
                Text(card.label)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(card.suit.symbol)
                    .font(.system(size: 13))
            }
            .padding(5)
            .rotationEffect(.degrees(180))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .foregroundStyle(color)
    }
}

/// The back of a card, in the card back picked in Style.
private struct CardBack: View {
    @Environment(\.cardBack) private var look

    var body: some View {
        ZStack {
            CardBackFace(look: look)
            CoinIcon(size: 30)
        }
    }
}

/// Insurance taken this round, between the dealer and the player: what it pays once the dealer
/// has checked for blackjack, or that it's lost.
private struct InsuranceNote: View {
    let insurance: BlackjackInsurance
    let unit: String

    var body: some View {
        Label(insurance.paid
              ? "Dealer blackjack: insurance pays \(CoinFormat.grouped(insurance.payout)) \(unit)"
              : "No blackjack: insurance of \(CoinFormat.grouped(insurance.stake)) \(unit) lost",
              systemImage: insurance.paid ? "shield.lefthalf.filled.badge.checkmark" : "shield.slash")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(insurance.paid ? Theme.gold : .white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.3), in: .capsule)
    }
}

private struct ResultBanner: View {
    let results: [BlackjackResult]
    let insurance: BlackjackInsurance?
    let bonus: Double
    /// What the bets are counted in: a token's ticker, or "chips".
    let unit: String

    var body: some View {
        let net = results.reduce(insurance?.net ?? 0) { $0 + $1.net }
        let handsNet = results.reduce(0) { $0 + $1.net }
        let isNatural = results.contains { $0.outcome == .blackjack }
        HStack(spacing: 14) {
            Text(handsNet > 0 ? (isNatural ? "NATURAL 21!" : "YOU WIN!") : handsNet == 0 ? "Push" : "Dealer wins")
                .font(.system(size: handsNet > 0 ? 26 : 20, weight: .heavy, design: .rounded))
                .foregroundStyle(handsNet > 0 ? AnyShapeStyle(Theme.gold.gradient) : AnyShapeStyle(.white))
                .shadow(color: handsNet > 0 ? Theme.gold.opacity(0.6) : .clear, radius: 10)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if net != 0 || bonus > 0 || insurance != nil {
                VStack(alignment: .leading, spacing: 1) {
                    if net > 0 {
                        Text("+\(CoinFormat.grouped(net)) \(unit)")
                            .font(.subheadline.bold())
                    } else if net < 0 {
                        Text("-\(CoinFormat.grouped(-net)) \(unit)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    if let insurance {
                        Text(insurance.paid ? "Insurance paid \(CoinFormat.grouped(insurance.payout))"
                                            : "Insurance lost")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    if bonus > 0 {
                        CoinAmount(amount: bonus, font: .subheadline.bold(), iconSize: 14)
                            .foregroundStyle(Theme.gold)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(net > 0 ? Theme.gold.opacity(0.25) : nil), in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

extension BlackjackOutcome {
    var title: String {
        switch self {
        case .blackjack: "Natural 21"
        case .win: "Win"
        case .push: "Push"
        case .lose: "Lose"
        }
    }
}
