import Foundation

/// Crypto Slots' two machines: the classic three reels with one pay line, and the video machine's
/// five reels showing three rows, with five pay lines.
public enum SlotMachineKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case classic, video

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .classic: localized("Classic 3×1")
        case .video: localized("Video 5×3")
        }
    }

    public var reelCount: Int {
        switch self {
        case .classic: SlotMachine.reelCount
        case .video: VideoSlots.reelCount
        }
    }

    /// Pay lines a spin plays. The bet is per line, so a spin stakes the bet times this.
    public var lines: Int {
        switch self {
        case .classic: 1
        case .video: VideoSlots.paylines.count
        }
    }

    /// Tokens returned per token bet over time, free spins included.
    public var returnToPlayer: Double {
        switch self {
        case .classic: SlotMachine.returnToPlayer
        case .video: VideoSlots.returnToPlayer
        }
    }
}

/// One reel position on the video machine: the reel (0 to 4, left to right) and the row (0 at the
/// top to 2 at the bottom).
public struct SlotCell: Hashable, Sendable {
    public let reel: Int
    public let row: Int

    public init(reel: Int, row: Int) {
        self.reel = reel
        self.row = row
    }
}

/// A winning pay line on the video machine.
public struct SlotLineWin: Equatable, Sendable {
    /// Which of `VideoSlots.paylines`.
    public let line: Int
    public let token: TokenID
    /// How many of the token in a row from the left reel: 3, 4 or 5.
    public let count: Int
    /// What it pays, in line bets (stake included).
    public let pays: Int

    /// The reel positions that make the win.
    public var cells: [SlotCell] {
        (0..<count).map { SlotCell(reel: $0, row: VideoSlots.paylines[line][$0]) }
    }
}

/// The video machine: five reels on their own strip, each showing three rows, and five pay lines
/// (the three rows, a V and an upside-down V). The bet is per line, so a spin stakes five times
/// the bet. A line pays for three, four or five of the same token from the left reel, and every
/// winning line pays. Bitcoins are also scatters: three or more anywhere win free spins at the
/// same bet. Bitcoins on the middle reel go into the same collection as the classic machine's
/// line, three positions each, so it fills at the same pace. Over time it returns about 95.9% of
/// the tokens bet, free spins included (`returnToPlayer` works it out exactly from the strip and
/// the pay table), and about one spin in five wins a line.
public enum VideoSlots {
    public static let reelCount = 5
    public static let rowCount = 3

    /// The row each pay line takes on each reel, top (0) to bottom (2): the middle row, the top
    /// row, the bottom row, a V and an upside-down V.
    public static let paylines: [[Int]] = [
        [1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
    ]

    /// One reel's 24 stops: seven Shiba Inu, five Dogecoin, four XRP, three Cardano, two Solana,
    /// two Ethereum and one Bitcoin, spread so no two neighbouring stops match, even where the reel
    /// wraps.
    public static let strip: [TokenID] = [
        .dogecoin, .shibaInu, .xrp, .cardano, .shibaInu, .ethereum,
        .solana, .dogecoin, .shibaInu, .xrp, .cardano, .bitcoin,
        .dogecoin, .shibaInu, .xrp, .shibaInu, .dogecoin, .ethereum,
        .solana, .shibaInu, .cardano, .xrp, .dogecoin, .shibaInu,
    ]

    /// What three, four or five of `token` in a row from the left pay, in line bets (stake included).
    public static func pays(_ token: TokenID, count: Int) -> Int {
        guard (3...5).contains(count) else { return 0 }
        let table: [Int]
        switch token {
        case .shibaInu: table = [8, 20, 50]
        case .dogecoin: table = [11, 30, 100]
        case .xrp: table = [20, 60, 150]
        case .cardano, .solana: table = [40, 100, 200]
        case .ethereum: table = [100, 250, 1_000]
        case .bitcoin: table = [500, 2_000, 10_000]
        case .safeMoon, .tether, .bnb, .monero: return 0 // Not on the reels.
        }
        return table[count - 3]
    }

    /// The jackpot: five Bitcoins on a line.
    public static var jackpot: Int { pays(.bitcoin, count: 5) }

    /// Free spins for `scatters` Bitcoins anywhere on the reels.
    public static func freeSpins(scatters: Int) -> Int {
        switch scatters {
        case 3: 5
        case 4: 8
        case 5...: 12
        default: 0
        }
    }

    /// A random stop for each reel.
    public static func spin<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        (0..<reelCount).map { _ in Int.random(in: 0..<strip.count, using: &rng) }
    }

    /// The token at `row` of a reel stopped at `stop`: the stop itself is the middle row.
    public static func symbol(stop: Int, row: Int) -> TokenID {
        let index = stop + row - 1
        return strip[((index % strip.count) + strip.count) % strip.count]
    }

    /// What the reels show, by reel then row.
    public static func window(stops: [Int]) -> [[TokenID]] {
        stops.map { stop in (0..<rowCount).map { symbol(stop: stop, row: $0) } }
    }

    /// Every winning line for a set of stops.
    public static func lineWins(stops: [Int]) -> [SlotLineWin] {
        guard stops.count == reelCount else { return [] }
        let window = window(stops: stops)
        return paylines.indices.compactMap { line in
            let tokens = paylines[line].indices.map { window[$0][paylines[line][$0]] }
            let first = tokens[0]
            let count = tokens.prefix { $0 == first }.count
            let pays = pays(first, count: count)
            return pays > 0 ? SlotLineWin(line: line, token: first, count: count, pays: pays) : nil
        }
    }

    /// Bitcoins anywhere on the reels (at most one a reel: the strip has one).
    public static func scatters(stops: [Int]) -> Int {
        window(stops: stops).reduce(0) { $0 + $1.filter { $0 == .bitcoin }.count }
    }

    /// The reel positions showing a Bitcoin.
    public static func scatterCells(stops: [Int]) -> [SlotCell] {
        let window = window(stops: stops)
        return window.indices.flatMap { reel in
            window[reel].indices.filter { window[reel][$0] == .bitcoin }.map { SlotCell(reel: reel, row: $0) }
        }
    }

    /// Bitcoins on the middle reel (any row), which go into the collection.
    public static func middleReelBitcoins(stops: [Int]) -> Int {
        guard stops.count == reelCount else { return 0 }
        return (0..<rowCount).filter { symbol(stop: stops[reelCount / 2], row: $0) == .bitcoin }.count
    }

    /// Average a line pays per line bet. The reels are independent and every row of a reel shows
    /// each stop equally often, so a line pays `count` of a token with the chance of that run from
    /// the left and no more.
    public static var lineReturn: Double {
        var total = 0.0
        for token in Set(strip) {
            let p = Double(strip.filter { $0 == token }.count) / Double(strip.count)
            for count in 3...reelCount {
                let run = pow(p, Double(count)) * (count < reelCount ? 1 - p : 1)
                total += run * Double(pays(token, count: count))
            }
        }
        return total
    }

    /// The chance a reel shows the Bitcoin, in any of its three rows.
    static var scatterChance: Double {
        Double(rowCount * strip.filter { $0 == .bitcoin }.count) / Double(strip.count)
    }

    /// The chance of exactly `scatters` Bitcoins on the reels.
    static func scatterChance(_ scatters: Int) -> Double {
        let q = scatterChance
        let ways = (0..<scatters).reduce(1.0) { $0 * Double(reelCount - $1) / Double($1 + 1) }
        return ways * pow(q, Double(scatters)) * pow(1 - q, Double(reelCount - scatters))
    }

    /// Free spins a spin wins on average.
    public static var freeSpinsPerSpin: Double {
        (0...reelCount).reduce(0.0) { $0 + scatterChance($1) * Double(freeSpins(scatters: $1)) }
    }

    /// The chance a spin wins free spins.
    public static var freeSpinChance: Double {
        (0...reelCount).reduce(0.0) { $0 + (freeSpins(scatters: $1) > 0 ? scatterChance($1) : 0) }
    }

    /// Average tokens returned per token bet, free spins included: a paid spin brings
    /// `1 / (1 - freeSpinsPerSpin)` spins in all, counting free spins won during free spins.
    public static var returnToPlayer: Double {
        lineReturn / (1 - freeSpinsPerSpin)
    }
}
