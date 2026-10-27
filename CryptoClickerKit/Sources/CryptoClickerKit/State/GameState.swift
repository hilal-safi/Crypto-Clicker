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
    /// Lines, bricks, bubbles or (in 2048) the best tile, depending on the game.
    public let detail: Int
    /// The day (a `StepDay` key) whose daily Tetris challenge this game was, if it was one.
    public let challengeDay: String?

    public init(game: MiniGame, score: Int, detail: Int, challengeDay: String? = nil) {
        self.game = game
        self.score = score
        self.detail = detail
        self.challengeDay = challengeDay
    }

    private enum CodingKeys: String, CodingKey { case game, score, detail, challengeDay }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        game = try c.decode(MiniGame.self, forKey: .game)
        score = try c.decode(Int.self, forKey: .score)
        detail = try c.decode(Int.self, forKey: .detail)
        challengeDay = c.value(.challengeDay, default: nil)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(game, forKey: .game)
        try c.encode(score, forKey: .score)
        try c.encode(detail, forKey: .detail)
        try c.encodeIfPresent(challengeDay, forKey: .challengeDay)
    }
}

/// The entire saved game as one value type. All rules live in the engine
/// extensions, so the app can only change state through tested methods.
public struct GameState: Codable, Equatable, Sendable {
    /// 2: Hard Forks became Prestige. 3: prestige potential needs 10% more lifetime coins.
    public static let saveVersion = 3

    public internal(set) var coins: Double = 0
    public internal(set) var miners: [MinerID: Int] = [:]
    /// Mk upgrade levels bought for each miner this run (0 to 5); each doubles that miner.
    public internal(set) var minerUpgrades: [MinerID: Int] = [:]
    public internal(set) var upgrades: Set<UpgradeID> = []
    public internal(set) var tokens: [TokenID: Int] = [:]

    /// Prestige points earned over all prestiges. Each adds production forever, even after
    /// being spent on perks.
    public internal(set) var prestigePoints = 0
    /// Points spent on perks.
    public internal(set) var prestigePointsSpent = 0
    /// Prestige potential (from lifetime coins) already turned into points.
    public internal(set) var prestigePotentialClaimed = 0
    public internal(set) var perks: Set<PerkID> = []
    public internal(set) var difficulty: Difficulty = .normal
    /// Lowest difficulty prestige multiplier used during the current run.
    public internal(set) var runPrestigeMultiplier = Difficulty.normal.prestigeMultiplier

    public internal(set) var boost: Boost?
    /// Levels of the Offline Mining power-up. Power-ups are permanent: prestiges keep them.
    public internal(set) var offlineMiningLevel = 0
    public internal(set) var unlockedGames: Set<MiniGame> = []
    public internal(set) var blackjackStake: BlackjackStake?
    public internal(set) var unfinishedRun: ArcadeRun?
    /// Highest tier count earned per achievement id (0 to 4).
    public internal(set) var achievementTiers: [String: Int] = [:]
    public internal(set) var daily = DailyProgress()
    /// Idle income sampled every half hour, oldest first, for the income chart.
    public internal(set) var incomeHistory: [IncomeSample] = []
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
        case version, coins, miners, minerUpgrades, upgrades, tokens
        // Prestige values keep the names they were saved under as Hard Forks.
        case prestigePoints = "forks"
        case prestigePotentialClaimed = "forkPointsClaimed"
        case runPrestigeMultiplier = "runForkMultiplier"
        case prestigePointsSpent, perks, difficulty
        case boost, offlineMiningLevel, unlockedGames, blackjackStake, unfinishedRun, achievementTiers, daily
        case incomeHistory, stats, steps, recentWatchBatches, lastUpdate, runStart, created
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        let version: Int = c.value(.version, default: 1)
        coins = Self.finite(c.value(.coins, default: 0))
        miners = c.enumKeyed(.miners, as: MinerID.self)
        minerUpgrades = c.enumKeyed(.minerUpgrades, as: MinerID.self)
        let savedUpgrades: [String] = c.value(.upgrades, default: [])
        upgrades = Set(savedUpgrades.compactMap(UpgradeID.init(rawValue:)))
        tokens = c.enumKeyed(.tokens, as: TokenID.self)
        prestigePoints = min(max(0, c.value(.prestigePoints, default: 0)), Tuning.maxPrestigePoints)
        prestigePointsSpent = min(max(0, c.value(.prestigePointsSpent, default: 0)), prestigePoints)
        let claimed: Int = min(max(0, c.value(.prestigePotentialClaimed, default: 0)), Tuning.maxPrestigePoints)
        // Versions 1 and 2 counted potential against 10 billion coins; carry what was claimed over
        // to the current scale, so an older save neither loses nor gains points.
        prestigePotentialClaimed = version < 3 ? Self.potentialOnCurrentScale(cubeRootPoints: claimed) : claimed
        perks = c.enumSet(.perks, as: PerkID.self)
        difficulty = c.value(.difficulty, default: .normal)
        // Only the difficulty multipliers are valid; anything else (a damaged save) falls back.
        let multiplier: Double = c.value(.runPrestigeMultiplier, default: difficulty.prestigeMultiplier)
        runPrestigeMultiplier = Difficulty.allCases.map(\.prestigeMultiplier).contains(multiplier)
            ? multiplier : difficulty.prestigeMultiplier
        boost = c.value(.boost, default: nil)
        // Offline upgrades bought in earlier versions become the matching Offline Mining level.
        let legacyLevel = savedUpgrades.compactMap { UpgradeID.legacyOfflineLevels[$0] }.max() ?? 0
        let savedLevel: Int = c.value(.offlineMiningLevel, default: 0)
        offlineMiningLevel = min(max(savedLevel, legacyLevel, 0), Tuning.offlineMiningMaxLevel)
        unlockedGames = c.enumSet(.unlockedGames, as: MiniGame.self)
        blackjackStake = c.value(.blackjackStake, default: nil)
        unfinishedRun = c.value(.unfinishedRun, default: nil)
        achievementTiers = c.value(.achievementTiers, default: [:])
        daily = c.value(.daily, default: DailyProgress())
        incomeHistory = c.value(.incomeHistory, default: [])
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
        try c.encode(minerUpgrades.stringKeyed, forKey: .minerUpgrades)
        try c.encode(upgrades.sortedRawValues, forKey: .upgrades)
        try c.encode(tokens.stringKeyed, forKey: .tokens)
        try c.encode(prestigePoints, forKey: .prestigePoints)
        try c.encode(prestigePointsSpent, forKey: .prestigePointsSpent)
        try c.encode(prestigePotentialClaimed, forKey: .prestigePotentialClaimed)
        try c.encode(perks.sortedRawValues, forKey: .perks)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(runPrestigeMultiplier, forKey: .runPrestigeMultiplier)
        try c.encodeIfPresent(boost, forKey: .boost)
        try c.encode(offlineMiningLevel, forKey: .offlineMiningLevel)
        try c.encode(unlockedGames.sortedRawValues, forKey: .unlockedGames)
        try c.encodeIfPresent(blackjackStake, forKey: .blackjackStake)
        try c.encodeIfPresent(unfinishedRun, forKey: .unfinishedRun)
        try c.encode(achievementTiers, forKey: .achievementTiers)
        try c.encode(daily, forKey: .daily)
        try c.encode(incomeHistory, forKey: .incomeHistory)
        try c.encode(stats, forKey: .stats)
        try c.encode(steps, forKey: .steps)
        try c.encode(recentWatchBatches, forKey: .recentWatchBatches)
        try c.encode(lastUpdate, forKey: .lastUpdate)
        try c.encode(runStart, forKey: .runStart)
        try c.encode(created, forKey: .created)
    }

    /// Replaces NaN or infinity with zero so a bad value can never poison later math.
    static func finite(_ value: Double) -> Double { value.isFinite ? value : 0 }

    /// The prestige potential, on today's scale, of the lifetime coins at which a version 1 or 2
    /// save had claimed `cubeRootPoints` of potential.
    static func potentialOnCurrentScale(cubeRootPoints points: Int) -> Int {
        guard points > 0 else { return 0 }
        let lifetime = pow(Double(points), 3) * 1e10 // Then: points = cube root of lifetime / 10 billion.
        return prestigePotential(lifetimeCoins: lifetime)
    }
}
