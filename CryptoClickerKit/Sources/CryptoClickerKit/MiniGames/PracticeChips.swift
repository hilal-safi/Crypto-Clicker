import Foundation

/// Chips for practising at the casino games: Blackjack, Video Poker and To the Moon play exactly
/// as usual, but bet these instead of tokens, so no tokens, coins, statistics or challenges change.
/// They aren't saved: a practice session starts with a fresh stack.
public struct PracticeChips: Equatable, Sendable {
    public static let starting = 1_000
    /// The bets a practice round offers.
    public static let bets = [10, 25, 50, 100]

    public private(set) var balance: Int

    public init(balance: Int = PracticeChips.starting) {
        self.balance = max(0, balance)
    }

    /// Takes a bet; fails (and takes nothing) if the stack can't cover it.
    @discardableResult
    public mutating func take(_ bet: Int) -> Bool {
        guard bet > 0, balance >= bet else { return false }
        balance -= bet
        return true
    }

    /// Pays winnings (a stake returned included) back onto the stack.
    public mutating func pay(_ amount: Int) {
        balance = balance.addingCount(amount)
    }

    /// The stack can't cover the smallest bet.
    public var isBroke: Bool { balance < (Self.bets.first ?? 1) }

    /// A fresh stack, for when the last one is gone.
    public mutating func refill() {
        balance = Self.starting
    }
}
