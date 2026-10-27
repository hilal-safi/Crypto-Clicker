import Foundation

/// The hands Jacks or Better pays, lowest first.
public enum PokerHand: Int, CaseIterable, Comparable, Codable, Sendable {
    case nothing, jacksOrBetter, twoPair, threeOfAKind, straight, flush, fullHouse, fourOfAKind, straightFlush, royalFlush

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var name: String {
        switch self {
        case .nothing: "No Win"
        case .jacksOrBetter: "Jacks or Better"
        case .twoPair: "Two Pair"
        case .threeOfAKind: "Three of a Kind"
        case .straight: "Straight"
        case .flush: "Flush"
        case .fullHouse: "Full House"
        case .fourOfAKind: "Four of a Kind"
        case .straightFlush: "Straight Flush"
        case .royalFlush: "Royal Flush"
        }
    }

    /// Tokens paid back for each token bet, the bet included: the classic 8/5 Jacks or Better table,
    /// with the royal flush paying its full 800 at any bet. Played well, it returns about 97%.
    public var payout: Int {
        switch self {
        case .nothing: 0
        case .jacksOrBetter: 1
        case .twoPair: 2
        case .threeOfAKind: 3
        case .straight: 4
        case .flush: 5
        case .fullHouse: 8
        case .fourOfAKind: 25
        case .straightFlush: 50
        case .royalFlush: 800
        }
    }

    /// The hands that pay, best first, for the pay table.
    public static let paying: [PokerHand] = allCases.filter { $0 != .nothing }.reversed()
}

/// A hand of video poker in progress: the tokens bet, the five cards dealt, and the cards that
/// replace any the player doesn't hold. Saved with the game, so a hand cut short by the app
/// closing is finished on the next launch instead of lost.
public struct PokerRound: Codable, Equatable, Sendable {
    public let token: TokenID
    public let bet: Int
    public let cards: [Card]
    /// The next cards in the shuffled deck, which replace discards in order.
    public let drawPile: [Card]

    public init(token: TokenID, bet: Int, cards: [Card], drawPile: [Card]) {
        self.token = token
        self.bet = bet
        self.cards = cards
        self.drawPile = drawPile
    }
}

/// What a finished hand paid.
public struct PokerResult: Equatable, Sendable {
    public let token: TokenID
    public let bet: Int
    /// The final five cards.
    public let cards: [Card]
    public let hand: PokerHand
    /// Tokens paid back (the bet times the hand's payout).
    public let tokensWon: Int
    /// Coins paid on top for two pair or better.
    public let bonus: Double

    public var isWin: Bool { tokensWon > 0 }
    /// Tokens won beyond the bet (negative for a loss).
    public var net: Int { tokensWon - bet }
}

/// Jacks or Better: five cards from a fresh deck, hold any of them, and draw once to replace the
/// rest. A pair of jacks or better is the smallest win.
public enum VideoPoker {
    public static let handSize = 5

    /// Deals five cards from a shuffled deck and sets aside the five that would replace them.
    /// Card ids are deck positions (0 to 51), unique within a hand.
    public static func deal<R: RandomNumberGenerator>(using rng: inout R) -> (cards: [Card], drawPile: [Card]) {
        var deck: [Card] = []
        for suit in Card.Suit.allCases {
            for rank in 1...13 { deck.append(Card(id: deck.count, rank: rank, suit: suit)) }
        }
        deck.shuffle(using: &rng)
        return (Array(deck[0..<handSize]), Array(deck[handSize..<handSize * 2]))
    }

    /// The hand after the draw: held cards stay in place and the others are replaced from the pile,
    /// in order.
    public static func draw(_ cards: [Card], holding held: Set<Int>, from pile: [Card]) -> [Card] {
        var next = pile.makeIterator()
        return cards.indices.map { held.contains($0) ? cards[$0] : (next.next() ?? cards[$0]) }
    }

    // MARK: Hands

    /// The best hand five cards make. Aces count high or low in straights.
    public static func evaluate(_ cards: [Card]) -> PokerHand {
        guard cards.count == handSize else { return .nothing }
        var counts: [Int: Int] = [:]
        for card in cards { counts[card.rank, default: 0] += 1 }
        let isFlush = Set(cards.map(\.suit)).count == 1
        let ranks = cards.map(\.rank).sorted()
        let isRoyalRanks = ranks == [1, 10, 11, 12, 13]
        let isStraight = counts.count == handSize && (isRoyalRanks || ranks[4] - ranks[0] == 4)
        if isStraight && isFlush { return isRoyalRanks ? .royalFlush : .straightFlush }
        let groups = counts.values.sorted(by: >)
        if groups[0] == 4 { return .fourOfAKind }
        if groups[0] == 3 && groups[1] == 2 { return .fullHouse }
        if isFlush { return .flush }
        if isStraight { return .straight }
        if groups[0] == 3 { return .threeOfAKind }
        if groups[0] == 2 && groups[1] == 2 { return .twoPair }
        if groups[0] == 2, let pair = counts.first(where: { $0.value == 2 })?.key, isHigh(pair) { return .jacksOrBetter }
        return .nothing
    }

    /// Jacks, queens, kings and aces: the ranks whose pair wins.
    static func isHigh(_ rank: Int) -> Bool { rank == 1 || rank >= 11 }

    // MARK: Strategy

    /// The cards to hold for a strong (nearly perfect) play: the well-known simple strategy for
    /// Jacks or Better, best option first. Used for the Hint button and to finish a hand the app
    /// closed in the middle of.
    public static func suggestedHolds(_ cards: [Card]) -> Set<Int> {
        guard cards.count == handSize else { return [] }
        let all = Set(cards.indices)
        let hand = evaluate(cards)
        if hand == .royalFlush || hand == .straightFlush { return all }
        if hand == .fourOfAKind { return indices(of: cards, inGroupsOf: 4) }
        if let royal = draw(in: cards, size: 4, where: isRoyalDraw) { return royal }
        if hand == .fullHouse || hand == .flush || hand == .straight { return all }
        if hand == .threeOfAKind { return indices(of: cards, inGroupsOf: 3) }
        if let straightFlush = draw(in: cards, size: 4, where: isStraightFlushDraw) { return straightFlush }
        if hand == .twoPair { return indices(of: cards, inGroupsOf: 2) }
        if hand == .jacksOrBetter { return indices(of: cards, inGroupsOf: 2) }
        if let royal = draw(in: cards, size: 3, where: isRoyalDraw) { return royal }
        if let flush = draw(in: cards, size: 4, where: isSuited) { return flush }
        let pairs = indices(of: cards, inGroupsOf: 2)
        if !pairs.isEmpty { return pairs }
        if let straight = draw(in: cards, size: 4, where: isOutsideStraightDraw) { return straight }
        if let suitedHigh = draw(in: cards, size: 2, where: { isSuited($0) && $0.allSatisfy { isHigh($0.rank) } }) {
            return suitedHigh
        }
        if let straightFlush = draw(in: cards, size: 3, where: isStraightFlushDraw) { return straightFlush }
        let high = cards.indices.filter { isHigh(cards[$0].rank) }
        if high.count >= 2 {
            // The two lowest high cards (an ace counts highest): they make straights more often.
            let lowest = high.sorted { highValue(cards[$0].rank) < highValue(cards[$1].rank) }.prefix(2)
            return Set(lowest)
        }
        if let suitedTen = draw(in: cards, size: 2, where: { group in
            isSuited(group) && group.contains { $0.rank == 10 } && group.contains { [11, 12, 13].contains($0.rank) }
        }) {
            return suitedTen
        }
        if let one = high.first { return [one] }
        return []
    }

    /// Ranks with an ace above the king.
    static func highValue(_ rank: Int) -> Int { rank == 1 ? 14 : rank }

    /// Positions of the cards that belong to a rank appearing exactly `size` times.
    static func indices(of cards: [Card], inGroupsOf size: Int) -> Set<Int> {
        var counts: [Int: Int] = [:]
        for card in cards { counts[card.rank, default: 0] += 1 }
        return Set(cards.indices.filter { counts[cards[$0].rank] == size })
    }

    /// The first group of `size` cards (by position) that `test` accepts.
    static func draw(in cards: [Card], size: Int, where test: ([Card]) -> Bool) -> Set<Int>? {
        for combo in combinations(of: size, from: cards.count) where test(combo.map { cards[$0] }) {
            return Set(combo)
        }
        return nil
    }

    static func isSuited(_ group: [Card]) -> Bool { Set(group.map(\.suit)).count == 1 }

    static func isRoyalDraw(_ group: [Card]) -> Bool {
        isSuited(group) && group.allSatisfy { $0.rank == 1 || $0.rank >= 10 }
    }

    /// Suited, different ranks, all within one straight (aces high or low).
    static func isStraightFlushDraw(_ group: [Card]) -> Bool {
        guard isSuited(group), Set(group.map(\.rank)).count == group.count else { return false }
        let low = group.map(\.rank)
        let high = group.map { highValue($0.rank) }
        return (low.max()! - low.min()! <= 4) || (high.max()! - high.min()! <= 4)
    }

    /// Four ranks in a row that a card at either end completes (not A-2-3-4 or J-Q-K-A).
    static func isOutsideStraightDraw(_ group: [Card]) -> Bool {
        let ranks = group.map { highValue($0.rank) }.sorted()
        guard Set(ranks).count == 4, ranks[3] - ranks[0] == 3 else { return false }
        return ranks[0] >= 2 && ranks[3] <= 13
    }

    /// Every way to choose `size` positions out of `count`, in order.
    static func combinations(of size: Int, from count: Int) -> [[Int]] {
        guard size > 0, size <= count else { return size == 0 ? [[]] : [] }
        var result: [[Int]] = []
        var combo: [Int] = []
        func build(_ start: Int) {
            if combo.count == size {
                result.append(combo)
                return
            }
            for index in start..<count {
                combo.append(index)
                build(index + 1)
                combo.removeLast()
            }
        }
        build(0)
        return result
    }
}
