import SwiftUI
import CryptoClickerKit

/// Video Poker, Jacks or Better: bet tokens, get five cards, tap the ones to hold and draw once.
/// The rules live in `VideoPoker` and the payouts in `GameState.drawPoker`. The draw is paid (and
/// saved) the moment the button is pressed; the new cards then turn over, and the balance on
/// screen waits for them so the result isn't given away. A hand left before the draw waits for the
/// player to come back; one cut short by the app closing is played out on the next launch.
struct VideoPokerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var token = TokenID.shibaInu
    @State private var bet = 1
    @State private var phase = Phase.betting
    @State private var cards: [Card] = []
    @State private var faceUp: Set<Int> = []
    @State private var held: Set<Int> = []
    @State private var result: PokerResult?
    /// A drawn hand whose cards are still turning over.
    @State private var pending: PokerResult?
    @State private var flipTask: Task<Void, Never>?
    @State private var holdTaps = 0
    @State private var wins = 0
    @State private var effects = Effects()

    enum Phase {
        /// Choosing a bet (and, after a hand, showing how it went).
        case betting
        /// The cards are turning face up.
        case dealing
        /// Choosing which cards to hold.
        case holding
        /// The replacements are turning over.
        case drawing
    }

    var body: some View {
        let game = store.game
        GeometryReader { proxy in
            // Centered when it fits; scrolls on small phones rather than squeezing the cards.
            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    PayTable(bet: bet, highlighted: phase == .betting ? result?.hand : nil)
                    cardRow(width: min(proxy.size.width, 560))
                    outcome
                        .frame(minHeight: 60)
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
        .background { PokerBackground() }
        .overlay { EffectsLayer(effects: effects).ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .navigationTitle("Video Poker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CoinAmount(amount: store.heldCoins ?? game.coins, font: .subheadline.weight(.semibold), iconSize: 16)
                    .padding(.horizontal, 6)
            }
        }
        .sensoryFeedback(.selection, trigger: holdTaps) { _, _ in haptics }
        .sensoryFeedback(.success, trigger: wins) { _, _ in haptics }
        .onAppear(perform: resume)
        .onDisappear(perform: leaveTable)
        .gameScreen()
    }

    // MARK: Pieces

    private func cardRow(width: CGFloat) -> some View {
        let cardWidth = min(92, max(44, (width - 32 - 4 * 8) / 5))
        let size = CGSize(width: cardWidth, height: cardWidth * 1.42)
        let winning = winningCards
        return HStack(spacing: 8) {
            ForEach(0..<VideoPoker.handSize, id: \.self) { index in
                PokerCardSlot(card: cards.indices.contains(index) ? cards[index] : nil,
                              isFaceUp: faceUp.contains(index), isHeld: held.contains(index),
                              isWinning: winning.contains(index), canHold: phase == .holding, size: size) {
                    toggleHold(index)
                }
            }
        }
    }

    /// The cards that make the winning hand, to light them up.
    private var winningCards: Set<Int> {
        guard phase == .betting, let result, result.isWin else { return [] }
        switch result.hand {
        case .straight, .flush, .fullHouse, .straightFlush, .royalFlush:
            return Set(result.cards.indices)
        default:
            var counts: [Int: Int] = [:]
            for card in result.cards { counts[card.rank, default: 0] += 1 }
            return Set(result.cards.indices.filter { counts[result.cards[$0].rank, default: 0] >= 2 })
        }
    }

    @ViewBuilder
    private var outcome: some View {
        if phase == .betting, let result {
            VStack(spacing: 4) {
                Text(result.isWin ? "\(result.hand.name.uppercased())!" : "No win")
                    .font(.system(size: result.hand >= .twoPair ? 28 : 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(result.isWin ? AnyShapeStyle(Theme.gold.gradient) : AnyShapeStyle(.white.opacity(0.8)))
                    .shadow(color: result.hand >= .twoPair ? Theme.gold.opacity(0.6) : .clear, radius: 10)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if result.isWin {
                    HStack(spacing: 10) {
                        Text(result.net > 0 ? "+\(CoinFormat.grouped(result.net)) \(result.token.ticker)" : "Bet back")
                            .font(.headline)
                        if result.bonus > 0 {
                            CoinAmount(amount: result.bonus, font: .headline, iconSize: 18)
                                .foregroundStyle(Theme.gold)
                        }
                    }
                }
            }
            .foregroundStyle(.white)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            Text(phase == .betting ? "A pair of jacks or better wins. Deal to start."
                 : "Tap the cards you want to keep, then draw.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func controls(game: GameState) -> some View {
        if phase == .betting {
            let owned = game.tokenCount(token)
            VStack(spacing: 10) {
                if TokenID.allCases.allSatisfy({ game.tokenCount($0) == 0 }) {
                    Label("Buy tokens on the Coin Exchange to play.", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                TokenBetControls(token: $token, bet: $bet,
                                 counts: Dictionary(uniqueKeysWithValues: TokenID.allCases.map { ($0, game.tokenCount($0)) }))
                let fullBonusBet = game.pokerBetForFullBonus(token)
                HStack(alignment: .firstTextBaseline) {
                    Text("Two pair or better also pays \(CoinFormat.short(game.pokerBonus(bet: bet, token: token, hand: .twoPair)))–\(CoinFormat.short(game.pokerBonus(bet: bet, token: token, hand: .royalFlush))) coins")
                        .font(.caption)
                        .foregroundStyle(.subtext)
                    Spacer()
                    if bet < fullBonusBet && owned > bet {
                        Button("Max Bonus") { bet = min(owned, fullBonusBet) }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                            .tint(Theme.gold)
                    }
                }
                Button(action: deal) {
                    Text(result == nil ? "DEAL" : "DEAL AGAIN")
                        .font(.title3.weight(.black))
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .disabled(owned < bet)
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        } else {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.snappy) { held = VideoPoker.suggestedHolds(cards) }
                        holdTaps += 1
                    } label: {
                        Label("Hint", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .accessibilityHint("Holds the cards a strong player would keep")
                    Button(action: draw) {
                        Text("DRAW")
                            .font(.title3.weight(.black))
                            .tracking(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)
                }
            }
            .disabled(phase != .holding)
        }
    }

    // MARK: Hand flow

    private func pickOwnedToken() {
        if store.game.tokenCount(token) == 0, let owned = TokenID.allCases.first(where: { store.game.tokenCount($0) > 0 }) {
            token = owned
        }
    }

    /// Picks up a hand already dealt: one left before the draw waits for the player to come back.
    private func resume() {
        pickOwnedToken()
        guard let round = store.game.pokerRound, cards.isEmpty else { return }
        token = round.token
        bet = round.bet
        cards = round.cards
        faceUp = Set(cards.indices)
        phase = .holding
    }

    private func toggleHold(_ index: Int) {
        guard phase == .holding else { return }
        withAnimation(.snappy(duration: 0.2)) {
            if held.contains(index) { held.remove(index) } else { held.insert(index) }
        }
        holdTaps += 1
    }

    private func deal() {
        guard phase == .betting, let round = store.dealPoker(token, bet: bet) else { return }
        flipTask?.cancel()
        withAnimation(.snappy) {
            result = nil
            held = []
            faceUp = []
            cards = round.cards
            phase = .dealing
        }
        flipTask = Task {
            await turnUp(Array(cards.indices))
            guard !Task.isCancelled else { return }
            phase = .holding
            AccessibilityNotification.Announcement("Dealt " + cards.map(\.accessibilityName).joined(separator: ", ")).post()
        }
    }

    private func draw() {
        guard phase == .holding else { return }
        let coins = store.game.coins
        guard let drawn = store.drawPoker(holding: held) else { return }
        store.heldCoins = coins
        pending = drawn
        phase = .drawing
        let replaced = cards.indices.filter { !held.contains($0) }
        flipTask = Task {
            withAnimation(.easeIn(duration: 0.18)) { faceUp.subtract(replaced) }
            if !replaced.isEmpty && !reduceMotion { try? await Task.sleep(for: .milliseconds(230)) }
            guard !Task.isCancelled else { return }
            cards = drawn.cards
            await turnUp(replaced)
            guard !Task.isCancelled else { return }
            reveal(drawn)
        }
    }

    /// Turns cards face up one after another.
    private func turnUp(_ indices: [Int]) async {
        for index in indices {
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(110)) }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { _ = faceUp.insert(index) }
        }
    }

    /// Shows the result: the real balance, the banner and, for good hands, the celebration.
    private func reveal(_ drawn: PokerResult) {
        pending = nil
        store.heldCoins = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            result = drawn
            held = []
            phase = .betting
        }
        var announcement = drawn.isWin ? drawn.hand.name : "No win"
        if drawn.isWin { announcement += ". \(drawn.tokensWon) \(drawn.token.name) back" }
        if drawn.bonus > 0 { announcement += " and \(CoinFormat.short(drawn.bonus)) coins" }
        AccessibilityNotification.Announcement(announcement).post()
        guard drawn.isWin else { return }
        wins += 1
        switch drawn.hand {
        case .royalFlush, .straightFlush, .fourOfAKind:
            effects.confetti(170, from: UnitPoint(x: 0.5, y: 0.45))
            effects.coinFountain(28, from: UnitPoint(x: 0.5, y: 0.55))
            effects.rainCoins(drawn.hand == .royalFlush ? 40 : 20)
        case .fullHouse, .flush, .straight:
            effects.confetti(110, from: UnitPoint(x: 0.5, y: 0.45))
            effects.coinFountain(16, from: UnitPoint(x: 0.5, y: 0.55))
        case .twoPair, .threeOfAKind:
            effects.confetti(60, from: UnitPoint(x: 0.5, y: 0.45))
        case .jacksOrBetter, .nothing:
            break
        }
    }

    /// Finishes turning the cards at once (the draw itself is already paid).
    private func finishFlipsNow() {
        flipTask?.cancel()
        flipTask = nil
        if let pending {
            cards = pending.cards
            faceUp = Set(cards.indices)
            reveal(pending)
        } else if phase == .dealing {
            faceUp = Set(cards.indices)
            phase = .holding
        }
    }

    /// Leaving finishes any cards still turning; a hand waiting for the draw stays dealt (and saved)
    /// until the player comes back.
    private func leaveTable() {
        finishFlipsNow()
    }
}

// MARK: - Table pieces

/// One card: face down until dealt, lifted with a HELD tag while held, and outlined in gold when it
/// is part of a winning hand. Tapping it holds it (while holding is allowed).
private struct PokerCardSlot: View {
    let card: Card?
    let isFaceUp: Bool
    let isHeld: Bool
    let isWinning: Bool
    let canHold: Bool
    let size: CGSize
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: toggle) {
                ZStack {
                    if let card {
                        PlayingCardView(card: card, isFaceDown: true, size: size)
                            .opacity(isFaceUp ? 0 : 1)
                            .rotation3DEffect(.degrees(isFaceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                        PlayingCardView(card: card, size: size)
                            .opacity(isFaceUp ? 1 : 0)
                            .rotation3DEffect(.degrees(isFaceUp ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                    } else {
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .frame(width: size.width, height: size.height)
                    }
                }
                .overlay {
                    if isWinning {
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(Theme.gold, lineWidth: 3)
                            .shadow(color: Theme.gold, radius: 8)
                    }
                }
                .offset(y: isHeld ? -10 : 0)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(canHold) // Not disabled, which would dim the cards between hands.
            Text("HELD")
                .font(.caption.weight(.black))
                .tracking(1)
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.gold, in: .capsule)
                .opacity(isHeld ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.map { isFaceUp ? $0.accessibilityName : "Face-down card" } ?? "No card")
        .accessibilityValue(isHeld ? "Held" : "")
        .accessibilityAddTraits(canHold ? .isButton : [])
        .accessibilityHint(canHold ? (isHeld ? "Lets this card go" : "Holds this card") : "")
        .accessibilityAction {
            if canHold { toggle() }
        }
    }
}

/// What every hand pays for the current bet, in tokens (the bet included), with the hand just
/// made lit up.
private struct PayTable: View {
    let bet: Int
    let highlighted: PokerHand?

    var body: some View {
        VStack(spacing: 1) {
            ForEach(PokerHand.paying, id: \.self) { hand in
                let isLit = hand == highlighted
                HStack {
                    Text(hand.name.uppercased())
                    Spacer()
                    Text(CoinFormat.grouped(hand.payout * bet))
                }
                .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(isLit ? Color.black : Theme.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(isLit ? Theme.gold : Color.clear, in: .rect(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(.black.opacity(0.35), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1.5)
        }
        .animation(.snappy, value: highlighted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pay table: " + PokerHand.paying.map { "\($0.name) pays \($0.payout * bet)" }.joined(separator: ", "))
    }
}

/// Deep blue, like a video poker machine's screen.
private struct PokerBackground: View {
    var body: some View {
        RadialGradient(colors: [Color(red: 0.10, green: 0.19, blue: 0.48), Color(red: 0.02, green: 0.04, blue: 0.15)],
                       center: .top, startRadius: 40, endRadius: 760)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
