import Foundation

/// A three-reel slot machine whose symbols are the exchange's crypto tokens. Every reel uses the
/// same strip, where rarer tokens pay more. It returns about 95% of the tokens bet over time.
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
        case .shibaInu: 5
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

    /// A random stop for each reel.
    public static func spin<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        (0..<reelCount).map { _ in Int.random(in: 0..<strip.count, using: &rng) }
    }

    /// The symbols on the pay line for a set of stops.
    public static func line(stops: [Int]) -> [TokenID] {
        stops.map { strip[(($0 % strip.count) + strip.count) % strip.count] }
    }

    /// Average tokens returned per token bet, over every equally likely combination of stops.
    public static var returnToPlayer: Double {
        let size = strip.count
        var total = 0
        for a in 0..<size {
            for b in 0..<size {
                for c in 0..<size { total += payout(for: [strip[a], strip[b], strip[c]]) }
            }
        }
        return Double(total) / Double(size * size * size)
    }
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

    public var line: [TokenID] { SlotMachine.line(stops: stops) }
    public var payout: Int { bet * multiple }
    public var isWin: Bool { multiple >= 2 }
    public var isJackpot: Bool { multiple == SlotMachine.jackpot }
}
