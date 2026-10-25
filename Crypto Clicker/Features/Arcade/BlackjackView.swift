import SwiftUI
import CryptoClickerKit

/// Blackjack against the dealer, betting crypto tokens. The rules live in `BlackjackTable`;
/// this view moves tokens in and out of the wallet and plays the dealer's turn with a little pacing.
struct BlackjackView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var table = BlackjackTable()
    @State private var token = TokenID.shibaInu
    @State private var bet = 1
    /// The token staked on the current round (the picker may change between rounds).
    @State private var roundToken = TokenID.shibaInu
    @State private var isSettled = true
    @State private var lastBonus = 0.0
    @State private var settledRounds = 0

    var body: some View {
        let game = store.game
        ScrollView {
            VStack(spacing: 14) {
                DealerArea(table: table)
                ForEach(table.hands) { hand in
                    HandView(hand: hand,
                             isActive: table.activeHand?.id == hand.id && table.hands.count > 1,
                             result: table.results.indices.contains(hand.id) ? table.results[hand.id] : nil,
                             token: roundToken)
                }
                if table.phase == .settled {
                    ResultBanner(results: table.results, bonus: lastBonus, token: roundToken)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            controls(game: game)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: 600)
        }
        .background { AppBackground(tint: .green) }
        .navigationTitle("Blackjack")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CoinAmount(amount: game.coins, font: .subheadline.weight(.semibold), iconSize: 16)
                    .padding(.horizontal, 6)
            }
        }
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
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(game: GameState) -> some View {
        switch table.phase {
        case .betting, .settled:
            let owned = game.tokenCount(token)
            VStack(spacing: 12) {
                if game.stats.totalTokensBought == 0 && TokenID.allCases.allSatisfy({ game.tokenCount($0) == 0 }) {
                    Text("Buy tokens on the Coin Exchange to place bets.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Picker("Token", selection: $token) {
                        ForEach(TokenID.allCases) { token in
                            Text("\(token.ticker) · \(CoinFormat.grouped(game.tokenCount(token)))").tag(token)
                        }
                    }
                    .pickerStyle(.menu)
                    Spacer()
                    Stepper("Bet \(CoinFormat.grouped(bet))", value: $bet, in: 1...max(1, owned))
                        .fixedSize()
                        .monospacedDigit()
                }
                let fullBonusBet = game.blackjackBetForFullBonus(token)
                HStack(alignment: .firstTextBaseline) {
                    Text("A win also pays \(CoinFormat.short(game.blackjackBonus(bet: bet, token: token))) coins")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if bet < fullBonusBet && owned > bet {
                        Button("Max Bonus") { bet = min(owned, fullBonusBet) }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                    }
                }
                Button(action: deal) {
                    Text(table.phase == .settled ? "Deal Again" : "Deal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .disabled(owned < bet)
            }
            .glassCard()
            .onChange(of: owned) { _, newValue in bet = min(bet, max(1, newValue)) }
        case .playerTurn:
            let canAffordExtra = game.tokenCount(roundToken) >= table.extraBetNeeded
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    actionButton("Hit", systemImage: "plus") { play { $0.hit(using: &$1) } }
                    actionButton("Stand", systemImage: "hand.raised.fill") { play { table, _ in table.stand() } }
                    if table.canDouble {
                        actionButton("Double", systemImage: "multiply") {
                            raise(when: table.canDouble) { $0.doubleDown(using: &$1) }
                        }
                        .disabled(!canAffordExtra)
                    }
                    if table.canSplit {
                        actionButton("Split", systemImage: "arrow.left.and.right") {
                            raise(when: table.canSplit) { $0.split(using: &$1) }
                        }
                        .disabled(!canAffordExtra)
                    }
                }
            }
        case .dealerTurn:
            HStack(spacing: 10) {
                ProgressView()
                Text("Dealer plays…")
                    .font(.headline)
            }
            .padding()
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .labelStyle(.titleOnly)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
    }

    // MARK: Round flow

    private func pickOwnedToken() {
        if store.game.tokenCount(token) == 0, let owned = TokenID.allCases.first(where: { store.game.tokenCount($0) > 0 }) {
            token = owned
        }
    }

    private func deal() {
        guard bet > 0, store.placeBet(token, amount: bet) else { return }
        roundToken = token
        isSettled = false
        lastBonus = 0
        let stake = bet
        play { $0.deal(bet: stake, using: &$1) }
    }

    /// Doubling and splitting stake the same bet again before acting. `allowed` is read at tap time,
    /// so a stale tap can never take tokens for a move the table then refuses.
    private func raise(when allowed: Bool, _ action: (inout BlackjackTable, inout SystemRandomNumberGenerator) -> Void) {
        guard allowed, store.placeBet(roundToken, amount: table.extraBetNeeded) else { return }
        play(action)
    }

    private func play(_ action: (inout BlackjackTable, inout SystemRandomNumberGenerator) -> Void) {
        var rng = SystemRandomNumberGenerator()
        withAnimation(.snappy) { action(&table, &rng) }
        settleIfFinished()
    }

    private func playDealer() async {
        while table.phase == .dealerTurn {
            do {
                try await Task.sleep(for: .milliseconds(650))
            } catch {
                return
            }
            play { $0.dealerStep(using: &$1) }
        }
    }

    private func settleIfFinished() {
        guard table.phase == .settled, !isSettled else { return }
        isSettled = true
        lastBonus = store.settleBlackjack(table.results, token: roundToken)
        settledRounds += 1
    }

    /// Leaving mid-round stands on every open hand and lets the dealer finish, so bets are never
    /// lost. (If the app is closed outright, the saved stake is refunded on the next launch.)
    private func leaveTable() {
        guard table.phase == .playerTurn || table.phase == .dealerTurn else { return }
        var rng = SystemRandomNumberGenerator()
        while table.phase == .playerTurn { table.stand() }
        table.finishDealer(using: &rng)
        settleIfFinished()
    }
}

// MARK: - Table pieces

private struct DealerArea: View {
    let table: BlackjackTable

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Dealer")
                    .font(.headline)
                Spacer()
                if !table.dealer.isEmpty {
                    Text(table.isHoleCardHidden ? "Showing \(table.dealerUpValue ?? 0)" : "\(table.dealerTotal)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            CardRow(cards: table.dealer, hidesSecondCard: table.isHoleCardHidden)
        }
        .glassCard()
    }
}

private struct HandView: View {
    let hand: BlackjackHand
    let isActive: Bool
    let result: BlackjackResult?
    let token: TokenID

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(hand.isBlackjack ? "Blackjack!" : hand.isBust ? "Bust" : "\(hand.isSoft ? "Soft " : "")\(hand.total)")
                    .font(.headline.monospacedDigit())
                Spacer()
                Label("\(CoinFormat.grouped(hand.bet)) \(token.ticker)", image: token.imageName)
                    .labelStyle(TokenLabelStyle())
                    .font(.subheadline.weight(.semibold))
                if let result {
                    Text(result.outcome.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(result.net > 0 ? .green : result.net == 0 ? .orange : .red)
                }
            }
            CardRow(cards: hand.cards, hidesSecondCard: false)
        }
        .glassCard(tint: isActive ? Theme.bitcoin.opacity(0.25) : nil)
        .accessibilityElement(children: .combine)
    }
}

private struct TokenLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .frame(width: 18, height: 18)
            configuration.title
        }
    }
}

private struct CardRow: View {
    let cards: [Card]
    let hidesSecondCard: Bool

    var body: some View {
        HStack(spacing: -22) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                PlayingCardView(card: card, isFaceDown: hidesSecondCard && index == 1)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }
}

struct PlayingCardView: View {
    let card: Card
    var isFaceDown = false

    var body: some View {
        ZStack {
            if isFaceDown {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Theme.bitcoin, .orange.mix(with: .black, by: 0.3)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                CoinIcon(size: 28)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white)
                VStack(spacing: 0) {
                    Text(card.label)
                        .font(.title2.bold())
                    Text(card.suit.symbol)
                        .font(.title)
                }
                .foregroundStyle(card.suit.isRed ? Color.red : Color.black)
            }
        }
        .frame(width: 64, height: 92)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.black.opacity(0.15))
        }
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        .accessibilityLabel(isFaceDown ? "Face-down card" : card.accessibilityName)
    }
}

private struct ResultBanner: View {
    let results: [BlackjackResult]
    let bonus: Double
    let token: TokenID

    var body: some View {
        let net = results.reduce(0) { $0 + $1.net }
        VStack(spacing: 4) {
            Text(net > 0 ? "You win \(CoinFormat.grouped(net)) \(token.ticker)" : net == 0 ? "Push" : "You lose \(CoinFormat.grouped(-net)) \(token.ticker)")
                .font(.headline)
            if bonus > 0 {
                Text("+\(CoinFormat.short(bonus)) coins")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bitcoin)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
    }
}

extension BlackjackOutcome {
    var title: String {
        switch self {
        case .blackjack: "Blackjack"
        case .win: "Win"
        case .push: "Push"
        case .lose: "Lose"
        }
    }
}
