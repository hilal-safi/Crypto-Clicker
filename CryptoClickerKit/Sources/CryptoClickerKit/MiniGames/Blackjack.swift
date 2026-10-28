import Foundation

public struct Card: Hashable, Codable, Sendable, Identifiable {
    public enum Suit: Int, CaseIterable, Codable, Sendable {
        case spades, hearts, diamonds, clubs

        public var symbol: String {
            switch self {
            case .spades: "♠"
            case .hearts: "♥"
            case .diamonds: "♦"
            case .clubs: "♣"
            }
        }

        public var name: String {
            switch self {
            case .spades: "Spades"
            case .hearts: "Hearts"
            case .diamonds: "Diamonds"
            case .clubs: "Clubs"
            }
        }

        public var isRed: Bool { self == .hearts || self == .diamonds }
    }

    /// Unique per card dealt at a table, so SwiftUI can animate cards individually.
    public let id: Int
    /// 1 is an ace, 11 to 13 are jack, queen and king.
    public let rank: Int
    public let suit: Suit

    public init(id: Int, rank: Int, suit: Suit) {
        self.id = id
        self.rank = rank
        self.suit = suit
    }

    public var isAce: Bool { rank == 1 }

    /// Blackjack points with aces counted as 1 (soft totals are handled per hand).
    public var points: Int { min(rank, 10) }

    public var label: String {
        switch rank {
        case 1: "A"
        case 11: "J"
        case 12: "Q"
        case 13: "K"
        default: "\(rank)"
        }
    }

    public var accessibilityName: String {
        let rankName: String = switch rank {
        case 1: "Ace"
        case 11: "Jack"
        case 12: "Queen"
        case 13: "King"
        default: "\(rank)"
        }
        return "\(rankName) of \(suit.name)"
    }
}

public struct BlackjackHand: Equatable, Sendable, Identifiable {
    public let id: Int
    public internal(set) var cards: [Card]
    /// Tokens staked on this hand, including a double down.
    public internal(set) var bet: Int
    public internal(set) var isDoubled = false
    public internal(set) var isDone = false
    /// Hands created by a split cannot be a natural blackjack.
    public let isSplit: Bool

    public var total: Int { BlackjackTable.evaluate(cards).total }
    public var isSoft: Bool { BlackjackTable.evaluate(cards).isSoft }
    public var isBust: Bool { total > 21 }
    public var isBlackjack: Bool { !isSplit && cards.count == 2 && total == 21 }
}

public enum BlackjackPhase: Equatable, Sendable {
    case betting, playerTurn, dealerTurn, settled
}

public enum BlackjackOutcome: Equatable, Sendable {
    case blackjack, win, push, lose
}

/// How the dealer plays: the one rule that sets the two tables apart.
public enum BlackjackRules: String, CaseIterable, Codable, Sendable, Identifiable {
    /// The classic table: the dealer stands on every 17.
    case standsOnSoft17
    /// The tough table: the dealer hits a soft 17 (a 17 counting an ace as 11), which suits the
    /// house a little better, so wins pay a bigger coin bonus.
    case hitsSoft17

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .standsOnSoft17: "Classic"
        case .hitsSoft17: "Tough"
        }
    }

    /// The rule as the felt prints it.
    public var dealerRule: String {
        switch self {
        case .standsOnSoft17: "Dealer stands on all 17s"
        case .hitsSoft17: "Dealer hits soft 17"
        }
    }
}

/// A move the coach can suggest.
public enum BlackjackMove: String, CaseIterable, Sendable {
    case hit, stand, double, split

    public var name: String {
        switch self {
        case .hit: "Hit"
        case .stand: "Stand"
        case .double: "Double"
        case .split: "Split"
        }
    }
}

public struct BlackjackResult: Equatable, Sendable {
    public let outcome: BlackjackOutcome
    /// Tokens that were staked on the hand.
    public let bet: Int
    /// Tokens returned to the player, stake included.
    public let payout: Int
    public var net: Int { payout - bet }
}

/// Casino-standard blackjack: single deck, dealer peeks for blackjack, naturals pay 3:2 (odd bets
/// round up), one split, double on any two cards (after a split too), split aces get one card. The
/// dealer stands on all 17s at the classic table and hits a soft 17 at the tough one.
/// The table never touches the wallet: the caller takes bets and pays out `results`.
public struct BlackjackTable: Sendable {
    public private(set) var phase: BlackjackPhase = .betting
    public private(set) var rules: BlackjackRules
    public private(set) var dealer: [Card] = []
    public private(set) var hands: [BlackjackHand] = []
    public private(set) var activeIndex = 0
    public private(set) var results: [BlackjackResult] = []
    private var shoe: [Card] = []
    private var nextCardID = 0

    public init(rules: BlackjackRules = .standsOnSoft17) {
        self.rules = rules
    }

    /// Changes tables between rounds; never mid-hand.
    public mutating func setRules(_ rules: BlackjackRules) {
        guard phase == .betting || phase == .settled else { return }
        self.rules = rules
    }

    // MARK: Reading the table

    public var activeHand: BlackjackHand? {
        phase == .playerTurn && hands.indices.contains(activeIndex) ? hands[activeIndex] : nil
    }

    /// The dealer's second card stays face down until the player finishes.
    public var isHoleCardHidden: Bool { phase == .playerTurn }

    public var dealerTotal: Int { Self.evaluate(dealer).total }

    /// Value of the dealer's face-up card, with an ace counted as 11.
    public var dealerUpValue: Int? {
        dealer.first.map { $0.isAce ? 11 : $0.points }
    }

    public var canHit: Bool { activeHand != nil }

    public var canDouble: Bool {
        guard let hand = activeHand else { return false }
        return hand.cards.count == 2 && !hand.isDoubled
    }

    public var canSplit: Bool {
        guard let hand = activeHand, hands.count == 1, hand.cards.count == 2 else { return false }
        return hand.cards[0].points == hand.cards[1].points
    }

    /// Extra tokens a double down or split would take from the wallet.
    public var extraBetNeeded: Int { activeHand?.bet ?? 0 }

    public var dealerShouldDraw: Bool { phase == .dealerTurn && dealerMustDraw }

    /// The dealer draws under 17, and on a soft 17 at the tough table.
    private var dealerMustDraw: Bool {
        let (total, isSoft) = Self.evaluate(dealer)
        return total < 17 || (rules == .hitsSoft17 && total == 17 && isSoft)
    }

    /// What basic strategy plays with the active hand, given the moves the table allows now.
    public var suggestedMove: BlackjackMove? {
        guard let hand = activeHand, let up = dealer.first else { return nil }
        return BlackjackStrategy.move(for: hand.cards, dealerUp: up, canDouble: canDouble, canSplit: canSplit, rules: rules)
    }

    // MARK: Playing

    /// Deals a new round. The caller must already have taken `bet` tokens.
    public mutating func deal<R: RandomNumberGenerator>(bet: Int, using rng: inout R) {
        guard bet > 0, phase == .betting || phase == .settled else { return }
        if shoe.count < 15 { shoe = Self.shuffledDeck(using: &rng) }
        results = []
        activeIndex = 0
        var player = [draw(using: &rng)]
        dealer = [draw(using: &rng)]
        player.append(draw(using: &rng))
        dealer.append(draw(using: &rng))
        hands = [BlackjackHand(id: 0, cards: player, bet: bet, isSplit: false)]
        // Dealer peek: a dealer natural ends the round at once (a player natural pushes).
        if Self.evaluate(dealer).total == 21 || hands[0].isBlackjack {
            settle()
        } else {
            phase = .playerTurn
        }
    }

    public mutating func hit<R: RandomNumberGenerator>(using rng: inout R) {
        guard phase == .playerTurn, hands.indices.contains(activeIndex) else { return }
        hands[activeIndex].cards.append(draw(using: &rng))
        let hand = hands[activeIndex]
        if hand.isBust || hand.total == 21 { finishActiveHand() }
    }

    public mutating func stand() {
        guard phase == .playerTurn, hands.indices.contains(activeIndex) else { return }
        finishActiveHand()
    }

    /// Doubles the active hand's bet, deals exactly one card and stands.
    /// The caller must already have taken `extraBetNeeded` more tokens.
    public mutating func doubleDown<R: RandomNumberGenerator>(using rng: inout R) {
        guard canDouble else { return }
        hands[activeIndex].bet *= 2
        hands[activeIndex].isDoubled = true
        hands[activeIndex].cards.append(draw(using: &rng))
        finishActiveHand()
    }

    /// Splits a pair into two hands with one new card each.
    /// The caller must already have taken `extraBetNeeded` more tokens.
    public mutating func split<R: RandomNumberGenerator>(using rng: inout R) {
        guard canSplit else { return }
        let original = hands[0]
        hands = [
            BlackjackHand(id: 0, cards: [original.cards[0], draw(using: &rng)], bet: original.bet, isSplit: true),
            BlackjackHand(id: 1, cards: [original.cards[1], draw(using: &rng)], bet: original.bet, isSplit: true),
        ]
        for index in hands.indices where original.cards[0].isAce || hands[index].total == 21 {
            hands[index].isDone = true // Split aces get one card; a 21 stands automatically.
        }
        advance()
    }

    /// Plays one dealer step: draws a card while the rules say to, then settles.
    public mutating func dealerStep<R: RandomNumberGenerator>(using rng: inout R) {
        guard phase == .dealerTurn else { return }
        if dealerMustDraw { dealer.append(draw(using: &rng)) }
        if !dealerMustDraw { settle() }
    }

    /// Finishes the dealer's turn immediately (used when leaving the table mid-round).
    public mutating func finishDealer<R: RandomNumberGenerator>(using rng: inout R) {
        while phase == .dealerTurn { dealerStep(using: &rng) }
    }

    /// Clears the table for the next bet.
    public mutating func newRound() {
        guard phase == .settled else { return }
        phase = .betting
        dealer = []
        hands = []
        results = []
        activeIndex = 0
    }

    // MARK: Rules

    /// Best total at or under 21, counting one ace as 11 when it fits.
    public static func evaluate(_ cards: [Card]) -> (total: Int, isSoft: Bool) {
        var total = 0
        var hasAce = false
        for card in cards {
            total += card.points
            if card.isAce { hasAce = true }
        }
        if hasAce && total + 10 <= 21 { return (total + 10, true) }
        return (total, false)
    }

    /// Tokens a natural returns for a `bet`: the stake plus 3:2, rounding odd bets up.
    public static func naturalPayout(bet: Int) -> Int { bet + (bet * 3 + 1) / 2 }

    private mutating func finishActiveHand() {
        hands[activeIndex].isDone = true
        advance()
    }

    private mutating func advance() {
        if let next = hands.indices.first(where: { !hands[$0].isDone }) {
            activeIndex = next
        } else if hands.allSatisfy(\.isBust) {
            settle() // Every hand busted: the dealer does not need to draw.
        } else {
            phase = .dealerTurn
        }
    }

    private mutating func settle() {
        let dealerTotal = Self.evaluate(dealer).total
        let dealerNatural = dealer.count == 2 && dealerTotal == 21
        results = hands.map { hand in
            if hand.isBlackjack {
                return dealerNatural
                    ? BlackjackResult(outcome: .push, bet: hand.bet, payout: hand.bet)
                    : BlackjackResult(outcome: .blackjack, bet: hand.bet, payout: Self.naturalPayout(bet: hand.bet))
            }
            if hand.isBust || dealerNatural { return BlackjackResult(outcome: .lose, bet: hand.bet, payout: 0) }
            if dealerTotal > 21 || hand.total > dealerTotal {
                return BlackjackResult(outcome: .win, bet: hand.bet, payout: hand.bet * 2)
            }
            if hand.total == dealerTotal { return BlackjackResult(outcome: .push, bet: hand.bet, payout: hand.bet) }
            return BlackjackResult(outcome: .lose, bet: hand.bet, payout: 0)
        }
        phase = .settled
    }

    private mutating func draw<R: RandomNumberGenerator>(using rng: inout R) -> Card {
        if shoe.isEmpty { shoe = Self.shuffledDeck(using: &rng) }
        let template = shoe.removeLast()
        defer { nextCardID += 1 }
        return Card(id: nextCardID, rank: template.rank, suit: template.suit)
    }

    private static func shuffledDeck<R: RandomNumberGenerator>(using rng: inout R) -> [Card] {
        var deck: [Card] = []
        deck.reserveCapacity(52)
        for suit in Card.Suit.allCases {
            for rank in 1...13 { deck.append(Card(id: 0, rank: rank, suit: suit)) }
        }
        deck.shuffle(using: &rng)
        return deck
    }

    #if DEBUG
    /// Test hook: stacks the shoe so the next cards drawn are `ranks`, in order.
    /// Pads with tens so a deal does not reshuffle the stacked cards away.
    mutating func stack(ranks: [Int]) {
        let padded = ranks + Array(repeating: 10, count: max(0, 20 - ranks.count))
        shoe = padded.reversed().map { Card(id: 0, rank: $0, suit: .spades) }
    }
    #endif
}

/// Basic strategy, the standard chart for these rules (doubling after a split allowed, no
/// surrender): the move that loses least over time for each hand against each dealer card. It's
/// the coach's advice, not a promise about the next card.
public enum BlackjackStrategy {
    public static func move(for cards: [Card], dealerUp: Card, canDouble: Bool, canSplit: Bool,
                            rules: BlackjackRules) -> BlackjackMove {
        let up = dealerUp.isAce ? 11 : dealerUp.points
        let hitsSoft17 = rules == .hitsSoft17
        if canSplit, cards.count == 2, let pair = splitAdvice(cards[0].isAce ? 11 : cards[0].points, up: up), pair {
            return .split
        }
        let (total, isSoft) = BlackjackTable.evaluate(cards)
        func doubleOr(_ fallback: BlackjackMove) -> BlackjackMove { canDouble ? .double : fallback }
        if isSoft {
            switch total {
            case 20...: return .stand
            case 19: return hitsSoft17 && up == 6 ? doubleOr(.stand) : .stand
            case 18:
                if (hitsSoft17 ? 2...6 : 3...6).contains(up) { return doubleOr(.stand) }
                return up <= 8 ? .stand : .hit
            case 17: return (3...6).contains(up) ? doubleOr(.hit) : .hit
            case 15, 16: return (4...6).contains(up) ? doubleOr(.hit) : .hit
            case 13, 14: return (5...6).contains(up) ? doubleOr(.hit) : .hit
            default: return .hit // Two aces that can't split.
            }
        }
        switch total {
        case 17...: return .stand
        case 13...16: return up <= 6 ? .stand : .hit
        case 12: return (4...6).contains(up) ? .stand : .hit
        case 11: return up <= 10 || hitsSoft17 ? doubleOr(.hit) : .hit
        case 10: return up <= 9 ? doubleOr(.hit) : .hit
        case 9: return (3...6).contains(up) ? doubleOr(.hit) : .hit
        default: return .hit
        }
    }

    /// Whether to split a pair of `value`s (ace 11) against the dealer's `up` card; `nil` means play
    /// it as a total (fives, tens).
    private static func splitAdvice(_ value: Int, up: Int) -> Bool? {
        switch value {
        case 11, 8: true
        case 10, 5: nil
        case 9: (2...6).contains(up) || up == 8 || up == 9
        case 7: up <= 7
        case 6: up <= 6
        case 4: up == 5 || up == 6
        default: up <= 7 // Twos and threes.
        }
    }
}
