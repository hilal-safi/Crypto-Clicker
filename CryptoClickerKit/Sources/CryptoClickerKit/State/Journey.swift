import Foundation

/// When each first happened, for the Journey timeline in Statistics: every miner tier's first unit,
/// each game unlocked, Offline Mining, every thousandfold of coins mined (a thousand, a million…)
/// and the first prestige. Saved with the game and kept through prestiges (they're firsts); a reset
/// starts a new one. Comparing it with the simulated players in `PacingTests` shows how real play
/// is paced.
public struct Journey: Codable, Equatable, Sendable {
    /// Each miner tier's first unit, ever.
    public internal(set) var miners: [MinerID: Date] = [:]
    /// Each game's unlock.
    public internal(set) var games: [MiniGame: Date] = [:]
    /// The first Offline Mining level.
    public internal(set) var offlineMining: Date?
    /// When lifetime coins first reached each power of a thousand: 1 for a thousand, 2 for a
    /// million, 3 for a billion, and so on.
    public internal(set) var coins: [Int: Date] = [:]
    public internal(set) var firstPrestige: Date?
    /// When recording began, for a save from before the journey was kept (`nil` when it has been
    /// kept since the game began). Firsts before it weren't recorded.
    public internal(set) var since: Date?

    public init(since: Date? = nil) {
        self.since = since
    }

    /// Notes every coin milestone `lifetime` has reached and not yet recorded.
    mutating func noteCoins(_ lifetime: Double, at date: Date) {
        guard lifetime.isFinite, lifetime >= 1_000 else { return }
        let reached = min(Int(log10(lifetime) / 3 + 1e-9), 30)
        guard reached >= 1 else { return }
        for power in 1...reached where coins[power] == nil {
            coins[power] = date
        }
    }

    private enum CodingKeys: String, CodingKey {
        case miners, games, offlineMining, coins, firstPrestige, since
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let savedMiners: [String: Date] = c.value(.miners, default: [:])
        miners = Dictionary(uniqueKeysWithValues: savedMiners.compactMap { key, date in MinerID(rawValue: key).map { ($0, date) } })
        let savedGames: [String: Date] = c.value(.games, default: [:])
        games = Dictionary(uniqueKeysWithValues: savedGames.compactMap { key, date in MiniGame(rawValue: key).map { ($0, date) } })
        offlineMining = c.value(.offlineMining, default: nil)
        let savedCoins: [String: Date] = c.value(.coins, default: [:])
        coins = Dictionary(uniqueKeysWithValues: savedCoins.compactMap { key, date in
            Int(key).flatMap { (1...30).contains($0) ? ($0, date) : nil }
        })
        firstPrestige = c.value(.firstPrestige, default: nil)
        since = c.value(.since, default: nil)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Dictionary(uniqueKeysWithValues: miners.map { ($0.key.rawValue, $0.value) }), forKey: .miners)
        try c.encode(Dictionary(uniqueKeysWithValues: games.map { ($0.key.rawValue, $0.value) }), forKey: .games)
        try c.encodeIfPresent(offlineMining, forKey: .offlineMining)
        try c.encode(Dictionary(uniqueKeysWithValues: coins.map { (String($0.key), $0.value) }), forKey: .coins)
        try c.encodeIfPresent(firstPrestige, forKey: .firstPrestige)
        try c.encodeIfPresent(since, forKey: .since)
    }
}

/// One first on the Journey timeline.
public struct JourneyEntry: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case started
        case miner(MinerID)
        case offlineMining
        case game(MiniGame)
        /// Lifetime coins reached 1,000 to this power.
        case coins(Int)
        case prestige
    }

    public let kind: Kind
    public let date: Date

    public var id: String {
        switch kind {
        case .started: "started"
        case .miner(let miner): "miner-\(miner.rawValue)"
        case .offlineMining: "offline"
        case .game(let game): "game-\(game.rawValue)"
        case .coins(let power): "coins-\(power)"
        case .prestige: "prestige"
        }
    }

    public var title: String {
        switch kind {
        case .started: "Started mining"
        case .miner(let miner): "First \(miner.name)"
        case .offlineMining: "Offline Mining"
        case .game(let game): "Unlocked \(game.name)"
        case .coins(let power): "\(CoinFormat.short(pow(1_000, Double(power)))) coins mined"
        case .prestige: "First prestige"
        }
    }

    /// An emoji for the entry.
    public var icon: String {
        switch kind {
        case .started: "⛏️"
        case .miner(let miner): miner.emoji
        case .offlineMining: "🌙"
        case .game(let game): game.info.icon
        case .coins: "🪙"
        case .prestige: "🌟"
        }
    }
}

extension GameState {
    /// Every first recorded, oldest first, starting with the game's start.
    public var journeyEntries: [JourneyEntry] {
        var entries = [JourneyEntry(kind: .started, date: created)]
        entries += journey.miners.map { JourneyEntry(kind: .miner($0.key), date: $0.value) }
        if let date = journey.offlineMining { entries.append(JourneyEntry(kind: .offlineMining, date: date)) }
        entries += journey.games.map { JourneyEntry(kind: .game($0.key), date: $0.value) }
        entries += journey.coins.map { JourneyEntry(kind: .coins($0.key), date: $0.value) }
        if let date = journey.firstPrestige { entries.append(JourneyEntry(kind: .prestige, date: date)) }
        // Same moment: the order things are listed above (a miner before the coins that bought it).
        let order = entries.enumerated().map { ($0.offset, $0.element) }
        return order.sorted { $0.1.date == $1.1.date ? $0.0 < $1.0 : $0.1.date < $1.1.date }.map(\.1)
    }
}
