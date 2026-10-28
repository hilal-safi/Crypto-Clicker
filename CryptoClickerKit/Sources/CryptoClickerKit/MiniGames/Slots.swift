import Foundation

/// A three-reel slot machine whose symbols are the exchange's crypto tokens. Every reel uses the
/// same strip, where rarer tokens pay more. A Cardano, a Solana and an Ethereum on the line, in any
/// order, win free spins at the same bet. With them it returns about 95.6% of the tokens bet over
/// time (`returnToPlayer` works it out exactly from the strip and the pay table).
///
/// Every Bitcoin that lands on the line goes into a collection, and every `bitcoinsPerPrize` of
/// them pays a coin prize; it never changes the odds of a spin.
///
/// The machine never touches the wallet: `GameState.spinSlots` takes the bet, spins and pays in
/// one step, and the view only animates the reels to the result.
public enum SlotMachine {
    public static let reelCount = 3

    /// One reel's 24 stops: six Shiba Inu, five Dogecoin, four XRP, three Cardano, three Solana,
    /// two Ethereum and one Bitcoin. No two neighbouring stops match, even where the reel wraps.
    public static let strip: [TokenID] = [
        .shibaInu, .dogecoin, .xrp, .cardano,
        .shibaInu, .dogecoin, .solana, .ethereum,
        .shibaInu, .dogecoin, .xrp, .bitcoin,
        .shibaInu, .dogecoin, .cardano, .solana,
        .shibaInu, .dogecoin, .xrp, .ethereum,
        .shibaInu, .xrp, .cardano, .solana,
    ]

    /// Three of a kind pays this many times the bet, stake included.
    public static func threeOfAKind(_ token: TokenID) -> Int {
        switch token {
        case .shibaInu: 4
        case .dogecoin: 8
        case .xrp: 15
        case .cardano: 25
        case .solana: 40
        case .ethereum: 100
        case .bitcoin: 500
        }
    }

    /// Any two Bitcoins on the line.
    public static let twoBitcoins = 25
    /// The first two reels match.
    public static let pairOnFirstTwo = 2
    /// A single Bitcoin anywhere returns the bet.
    public static let oneBitcoin = 1

    /// The best that `line` pays, as a multiple of the bet (stake included); 0 when it loses.
    public static func payout(for line: [TokenID]) -> Int {
        guard line.count == reelCount else { return 0 }
        if line[0] == line[1] && line[1] == line[2] { return threeOfAKind(line[0]) }
        let bitcoins = line.filter { $0 == .bitcoin }.count
        if bitcoins == 2 { return twoBitcoins }
        if line[0] == line[1] { return pairOnFirstTwo }
        if bitcoins == 1 { return oneBitcoin }
        return 0
    }

    /// The jackpot: three Bitcoins.
    public static var jackpot: Int { threeOfAKind(.bitcoin) }

    /// One of each of these on the line, in any order, wins free spins.
    public static let freeSpinTrigger: Set<TokenID> = [.cardano, .solana, .ethereum]
    /// Free spins a trigger wins (more during free spins add on).
    public static let freeSpinsAwarded = 3
    /// Bitcoins on the line that make up one collection prize.
    public static let bitcoinsPerPrize = 10

    /// Whether `line` wins free spins.
    public static func triggersFreeSpins(_ line: [TokenID]) -> Bool {
        line.count == reelCount && Set(line) == freeSpinTrigger
    }

    /// Tokens a spin pays for `bet` at `multiple`, kept within a 32-bit count.
    public static func tokensPaid(bet: Int, multiple: Int) -> Int {
        Int(min(Double(max(0, bet)) * Double(max(0, multiple)), Double(Int32.max)))
    }

    /// A random stop for each reel.
    public static func spin<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        (0..<reelCount).map { _ in Int.random(in: 0..<strip.count, using: &rng) }
    }

    /// The symbols on the pay line for a set of stops.
    public static func line(stops: [Int]) -> [TokenID] {
        stops.map { strip[(($0 % strip.count) + strip.count) % strip.count] }
    }

    /// Average tokens the pay table returns per token bet, over every equally likely combination
    /// of stops, before free spins.
    public static var paytableReturn: Double {
        average { Double(payout(for: $0)) }
    }

    /// The chance a spin wins free spins.
    public static var freeSpinChance: Double {
        average { triggersFreeSpins($0) ? 1.0 : 0.0 }
    }

    /// Free spins a trigger brings on average, counting the ones won again during them.
    public static var freeSpinsPerTrigger: Double {
        Double(freeSpinsAwarded) / (1 - Double(freeSpinsAwarded) * freeSpinChance)
    }

    /// Average tokens returned per token bet, free spins included: each paid spin also brings
    /// `freeSpinChance × freeSpinsPerTrigger` spins that cost nothing.
    public static var returnToPlayer: Double {
        paytableReturn * (1 + freeSpinChance * freeSpinsPerTrigger)
    }

    /// The average of `value` over every combination of stops.
    private static func average(_ value: ([TokenID]) -> Double) -> Double {
        var total = 0.0
        for a in strip {
            for b in strip {
                for c in strip { total += value([a, b, c]) }
            }
        }
        return total / Double(strip.count * strip.count * strip.count)
    }
}

/// Free spins waiting to be played, at the bet and token that won them. Saved with the game, so
/// they're still there after the app closes.
public struct SlotsFreeSpins: Codable, Equatable, Sendable {
    public let token: TokenID
    public let bet: Int
    public internal(set) var left: Int
}

/// One finished spin: where the reels stopped and what it paid.
public struct SlotsSpin: Equatable, Sendable {
    public let stops: [Int]
    public let token: TokenID
    public let bet: Int
    /// Tokens returned as a multiple of the bet (0 for a loss, 1 gives the bet back).
    public let multiple: Int
    /// Coins paid on top of the tokens for a winning spin.
    public let bonus: Double
    /// A free spin: no tokens were taken for it.
    public var isFree = false
    /// Free spins this spin won, and how many are left to play.
    public var freeSpinsWon = 0
    public var freeSpinsLeft = 0
    /// Bitcoins on the line, added to the collection, and coins its prizes paid.
    public var bitcoins = 0
    public var collectionPrize = 0.0

    public init(stops: [Int], token: TokenID, bet: Int, multiple: Int, bonus: Double) {
        self.stops = stops
        self.token = token
        self.bet = bet
        self.multiple = multiple
        self.bonus = bonus
    }

    public var line: [TokenID] { SlotMachine.line(stops: stops) }
    public var payout: Int { SlotMachine.tokensPaid(bet: bet, multiple: multiple) }
    /// Tokens gained or lost: the payout less the bet (a free spin cost nothing).
    public var net: Int { payout - (isFree ? 0 : bet) }
    public var isWin: Bool { multiple >= 2 }
    public var isJackpot: Bool { multiple == SlotMachine.jackpot }

    /// Which reels make the win, for highlighting: all three for three of a kind, the Bitcoins for
    /// Bitcoin pays, the first two for a pair, and the trio for free spins.
    public var winningReels: [Int] {
        let line = line
        if line[0] == line[1] && line[1] == line[2] { return [0, 1, 2] }
        let bitcoins = line.indices.filter { line[$0] == .bitcoin }
        if bitcoins.count == 2 { return bitcoins }
        if line[0] == line[1] { return [0, 1] }
        if bitcoins.count == 1 { return bitcoins }
        if SlotMachine.triggersFreeSpins(line) { return [0, 1, 2] }
        return []
    }
}
