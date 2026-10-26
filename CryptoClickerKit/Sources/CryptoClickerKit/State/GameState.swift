import Foundation

/// A temporary production multiplier, such as a Bull Run airdrop.
public struct Boost: Codable, Equatable, Sendable {
    public let multiplier: Double
    public let endsAt: Date

    public init(multiplier: Double, endsAt: Date) {
        self.multiplier = multiplier
        self.endsAt = endsAt
    }
}

/// Tokens staked on a Blackjack round that has not been settled yet. Saved with the game,
/// so a round cut short by the app closing is refunded instead of lost.
public struct BlackjackStake: Codable, Equatable, Sendable {
    public let token: TokenID
    public internal(set) var amount: Int
}

/// An arcade game in progress when the app went to the background. Saved with the game, so its
/// points are still paid if iOS closes the app before the player comes back.
public struct ArcadeRun: Codable, Equatable, Sendable {
    public let game: MiniGame
    public let score: Int
    /// Lines, bricks or bubbles, depending on the game.
    public let detail: Int

    public init(game: MiniGame, score: Int, detail: Int) {
        self.game = game
        self.score = score
        self.detail = detail
    }
}

/// The entire saved game as one value type. All rules live in the engine
/// extensions, so the app can only change state through tested methods.
public struct GameState: Codable, Equatable, Sendable {
    public static let saveVersion = 1

    public internal(set) var coins: Double = 0
    public internal(set) var miners: [MinerID: Int] = [:]
    public internal(set) var upgrades: Set<UpgradeID> = []
    public internal(set) var tokens: [TokenID: Int] = [:]

    /// Permanent prestige currency earned by Hard Forks.
    public internal(set) var forks = 0
    /// Fork points (cube root of lifetime coins) already converted into forks.
    public internal(set) var forkPointsClaimed = 0
    public internal(set) var difficulty: Difficulty = .normal
    /// Lowest difficulty fork multiplier used during the current run.
    public internal(set) var runForkMultiplier = Difficulty.normal.forkMultiplier

    public internal(set) var boost: Boost?
    /// Levels of the Offline Mining power-up. Power-ups are permanent: Hard Forks keep them.
    public internal(set) var offlineMiningLevel = 0
    public internal(set) var unlockedGames: Set<MiniGame> = []
    public internal(set) var blackjackStake: BlackjackStake?
    public internal(set) var unfinishedRun: ArcadeRun?
    /// Highest tier count earned per achievement id (0 to 3).
    public internal(set) var achievementTiers: [String: Int] = [:]
    public internal(set) var stats = Stats()
    public internal(set) var steps = StepLedger()
    /// Watch tap batches already applied, newest last, so a resend is never paid twice.
    public internal(set) var recentWatchBatches: [UUID] = []

    /// When income was last credited.
    public internal(set) var lastUpdate: Date
    public internal(set) var runStart: Date
    public internal(set) var created: Date

    public init(now: Date = Date()) {
        lastUpdate = now
        runStart = now
        created = now
    }

    private enum CodingKeys: String, CodingKey {
        case version, coins, miners, upgrades, tokens, forks, forkPointsClaimed, difficulty, runForkMultiplier
        case boost, offlineMiningLevel, unlockedGames, blackjackStake, unfinishedRun, achievementTiers, stats, steps
        case recentWatchBatches, lastUpdate, runStart, created
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        coins = Self.finite(c.value(.coins, default: 0))
        miners = c.enumKeyed(.miners, as: MinerID.self)
        let savedUpgrades: [String] = c.value(.upgrades, default: [])
        upgrades = Set(savedUpgrades.compactMap(UpgradeID.init(rawValue:)))
        tokens = c.enumKeyed(.tokens, as: TokenID.self)
        forks = c.value(.forks, default: 0)
        forkPointsClaimed = c.value(.forkPointsClaimed, default: 0)
        difficulty = c.value(.difficulty, default: .normal)
        runForkMultiplier = c.value(.runForkMultiplier, default: difficulty.forkMultiplier)
        boost = c.value(.boost, default: nil)
        // Offline upgrades bought in earlier versions become the matching Offline Mining level.
        let legacyLevel = savedUpgrades.compactMap { UpgradeID.legacyOfflineLevels[$0] }.max() ?? 0
        let savedLevel: Int = c.value(.offlineMiningLevel, default: 0)
        offlineMiningLevel = min(max(savedLevel, legacyLevel, 0), Tuning.offlineMiningMaxLevel)
        unlockedGames = c.enumSet(.unlockedGames, as: MiniGame.self)
        blackjackStake = c.value(.blackjackStake, default: nil)
        unfinishedRun = c.value(.unfinishedRun, default: nil)
        achievementTiers = c.value(.achievementTiers, default: [:])
        stats = c.value(.stats, default: Stats())
        steps = c.value(.steps, default: StepLedger())
        recentWatchBatches = c.value(.recentWatchBatches, default: [])
        lastUpdate = c.value(.lastUpdate, default: now)
        runStart = c.value(.runStart, default: now)
        created = c.value(.created, default: now)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.saveVersion, forKey: .version)
        try c.encode(coins, forKey: .coins)
        try c.encode(miners.stringKeyed, forKey: .miners)
        try c.encode(upgrades.sortedRawValues, forKey: .upgrades)
        try c.encode(tokens.stringKeyed, forKey: .tokens)
        try c.encode(forks, forKey: .forks)
        try c.encode(forkPointsClaimed, forKey: .forkPointsClaimed)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(runForkMultiplier, forKey: .runForkMultiplier)
        try c.encodeIfPresent(boost, forKey: .boost)
        try c.encode(offlineMiningLevel, forKey: .offlineMiningLevel)
        try c.encode(unlockedGames.sortedRawValues, forKey: .unlockedGames)
        try c.encodeIfPresent(blackjackStake, forKey: .blackjackStake)
        try c.encodeIfPresent(unfinishedRun, forKey: .unfinishedRun)
        try c.encode(achievementTiers, forKey: .achievementTiers)
        try c.encode(stats, forKey: .stats)
        try c.encode(steps, forKey: .steps)
        try c.encode(recentWatchBatches, forKey: .recentWatchBatches)
        try c.encode(lastUpdate, forKey: .lastUpdate)
        try c.encode(runStart, forKey: .runStart)
        try c.encode(created, forKey: .created)
    }

    /// Replaces NaN or infinity with zero so a bad value can never poison later math.
    static func finite(_ value: Double) -> Double { value.isFinite ? value : 0 }
}
