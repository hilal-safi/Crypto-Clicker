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
    /// What else the game reports when it ends, depending on the game: lines (Tetris), length
    /// (Snake), bricks, bubbles, the best tile (2048), coins hit (Pump and Dump), tokens matched
    /// (Token Swap) or invaders shot (Scam Invaders).
    public let detail: Int
    /// A second game-specific number: the level reached (Brick Breaker), the most bubbles cleared
    /// by one shot (Bubble Blaster), the best combo (Pump and Dump), the longest chain (Token Swap)
    /// or the wave reached (Scam Invaders).
    public let extra: Int
    /// A third number: the round reached (Pump and Dump), the wave (Bubble Blaster), or which
    /// mode was playing: `dailyStage` for a daily 2048 puzzle, `coinRushStage` for Snake's Coin
    /// Rush. 0 for the other games and modes.
    public let stage: Int

    /// Everything else the game reports when it ends, so a run paid on the next launch keeps all
    /// of its statistics (and earns its Arcade XP) as if it had ended normally.
    public let records: Records

    /// The `stage` of a daily 2048 puzzle, which pays like one rather than a Classic game.
    public static let dailyStage = 1
    /// The `stage` of a Snake Coin Rush, which pays and keeps its record like one.
    public static let coinRushStage = 1

    /// The rest of a game's end-of-game report. Each game fills in its own; the rest stay 0.
    public struct Records: Codable, Equatable, Sendable {
        /// Tetris: the level reached, the best combo and the Tetrises cleared.
        public var level: Int
        public var bestCombo: Int
        public var tetrises: Int
        /// Snake: coins eaten and seconds played.
        public var coins: Int
        public var seconds: Double
        /// Snake, Brick Breaker and Scam Invaders: power-ups collected.
        public var powerUps: Int
        /// Brick Breaker and Scam Invaders: bosses beaten.
        public var bosses: Int
        /// Brick Breaker, Bubble Blaster and Scam Invaders: the best streak.
        public var bestStreak: Int
        /// Bubble Blaster: gold bonus bubbles. Scam Invaders: whales shot.
        public var bonuses: Int
        /// Pump and Dump: scam tokens hit.
        public var scamsHit: Int
        /// Token Swap: specials set off.
        public var specials: Int
        /// Scam Invaders: volleys fired, and those that hit something.
        public var volleys: Int
        public var volleysHit: Int
        /// Pump and Dump: the board's side (3, 4 or 5; 0 in runs held before the bigger boards,
        /// which were all 3×3).
        public var board: Int
        /// Bubble Market: 1 for a Flash Market game.
        public var mode: Int
        /// Hash Smash and Scam Invaders: the level or wave the game started at (1 from the start).
        public var start: Int

        public init(level: Int = 0, bestCombo: Int = 0, tetrises: Int = 0, coins: Int = 0, seconds: Double = 0,
                    powerUps: Int = 0, bosses: Int = 0, bestStreak: Int = 0, bonuses: Int = 0, scamsHit: Int = 0,
                    specials: Int = 0, volleys: Int = 0, volleysHit: Int = 0, board: Int = 0, mode: Int = 0,
                    start: Int = 1) {
            self.level = level
            self.bestCombo = bestCombo
            self.tetrises = tetrises
            self.coins = coins
            self.seconds = seconds
            self.powerUps = powerUps
            self.bosses = bosses
            self.bestStreak = bestStreak
            self.bonuses = bonuses
            self.scamsHit = scamsHit
            self.specials = specials
            self.volleys = volleys
            self.volleysHit = volleysHit
            self.board = board
            self.mode = mode
            self.start = start
        }

        private enum CodingKeys: String, CodingKey {
            case level, bestCombo, tetrises, coins, seconds, powerUps, bosses, bestStreak, bonuses, scamsHit, specials
            case volleys, volleysHit, board, mode, start
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            level = c.value(.level, default: 0)
            bestCombo = c.value(.bestCombo, default: 0)
            tetrises = c.value(.tetrises, default: 0)
            coins = c.value(.coins, default: 0)
            seconds = c.value(.seconds, default: 0)
            powerUps = c.value(.powerUps, default: 0)
            bosses = c.value(.bosses, default: 0)
            bestStreak = c.value(.bestStreak, default: 0)
            bonuses = c.value(.bonuses, default: 0)
            scamsHit = c.value(.scamsHit, default: 0)
            specials = c.value(.specials, default: 0)
            volleys = c.value(.volleys, default: 0)
            volleysHit = c.value(.volleysHit, default: 0)
            board = c.value(.board, default: 0)
            mode = c.value(.mode, default: 0)
            start = max(1, c.value(.start, default: 1))
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            if level != 0 { try c.encode(level, forKey: .level) }
            if bestCombo != 0 { try c.encode(bestCombo, forKey: .bestCombo) }
            if tetrises != 0 { try c.encode(tetrises, forKey: .tetrises) }
            if coins != 0 { try c.encode(coins, forKey: .coins) }
            if seconds != 0 { try c.encode(seconds, forKey: .seconds) }
            if powerUps != 0 { try c.encode(powerUps, forKey: .powerUps) }
            if bosses != 0 { try c.encode(bosses, forKey: .bosses) }
            if bestStreak != 0 { try c.encode(bestStreak, forKey: .bestStreak) }
            if bonuses != 0 { try c.encode(bonuses, forKey: .bonuses) }
            if scamsHit != 0 { try c.encode(scamsHit, forKey: .scamsHit) }
            if specials != 0 { try c.encode(specials, forKey: .specials) }
            if volleys != 0 { try c.encode(volleys, forKey: .volleys) }
            if volleysHit != 0 { try c.encode(volleysHit, forKey: .volleysHit) }
            if board != 0 { try c.encode(board, forKey: .board) }
            if mode != 0 { try c.encode(mode, forKey: .mode) }
            if start != 1 { try c.encode(start, forKey: .start) }
        }
    }

    public init(game: MiniGame, score: Int, detail: Int, extra: Int = 0, stage: Int = 0, records: Records = Records()) {
        self.game = game
        self.score = score
        self.detail = detail
        self.extra = extra
        self.stage = stage
        self.records = records
    }

    private enum CodingKeys: String, CodingKey { case game, score, detail, extra, stage, records }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        game = try c.decode(MiniGame.self, forKey: .game)
        score = try c.decode(Int.self, forKey: .score)
        detail = try c.decode(Int.self, forKey: .detail)
        extra = c.value(.extra, default: 0)
        stage = c.value(.stage, default: 0)
        records = c.value(.records, default: Records())
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(game, forKey: .game)
        try c.encode(score, forKey: .score)
        try c.encode(detail, forKey: .detail)
        try c.encode(extra, forKey: .extra)
        if stage != 0 { try c.encode(stage, forKey: .stage) }
        if records != Records() { try c.encode(records, forKey: .records) }
    }
}

/// The entire saved game as one value type. All rules live in the engine
/// extensions, so the app can only change state through tested methods.
public struct GameState: Codable, Equatable, Sendable {
    /// 2: Hard Forks became Prestige. 3: prestige potential needs 10% more lifetime coins.
    /// 4: and 15% more again. 5: 15 billion for the first point. 6: Offline Mining levels of five
    /// minutes up to an hour, then half an hour.
    public static let saveVersion = 6

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
    /// Levels of each power-up besides Offline Mining. Kept through prestiges.
    public internal(set) var powerUps: [PowerUpID: Int] = [:]
    public internal(set) var unlockedGames: Set<MiniGame> = []
    public internal(set) var blackjackStake: BlackjackStake?
    /// A To the Moon flight in the air.
    public internal(set) var moonRound: MoonRound?
    /// A Video Poker hand dealt but not yet drawn.
    public internal(set) var pokerRound: PokerRound?
    /// Free spins won at Crypto Slots and not yet played.
    public internal(set) var slotsFreeSpins: SlotsFreeSpins?
    public internal(set) var unfinishedRun: ArcadeRun?
    /// Token Swap levels won, and the daily puzzle. Kept through prestiges.
    public internal(set) var tokenSwap = TokenSwapProgress()
    /// The day's 2048 puzzle. Kept through prestiges.
    public internal(set) var merge2048Daily = Merge2048DailyProgress()
    /// Arcade Rank, the week's variety goal and the cosmetics picked. Kept through prestiges.
    public internal(set) var arcade = ArcadeProgress()
    /// When each first happened, for the Journey timeline. Kept through prestiges.
    public internal(set) var journey = Journey()
    /// Highest tier count earned per achievement id (0 to 4).
    public internal(set) var achievementTiers: [String: Int] = [:]
    public internal(set) var daily = DailyProgress()
    /// Idle income sampled every half hour, oldest first, for the income chart.
    public internal(set) var incomeHistory: [IncomeSample] = []
    public internal(set) var stats = Stats()
    public internal(set) var steps = StepLedger()
    /// Watch tap batches already applied, newest last, so a resend is never paid twice.
    public internal(set) var recentWatchBatches: [UUID] = []
    /// For each watch (by source id), the number of the last tap batch applied from it.
    public internal(set) var watchSequences: [String: Int] = [:]
    /// The latest airdrops, caught or missed, newest last.
    public internal(set) var recentAirdrops: [AirdropLog] = []

    /// When income was last credited.
    public internal(set) var lastUpdate: Date
    public internal(set) var runStart: Date
    public internal(set) var created: Date

    public init(now: Date = Date()) {
        lastUpdate = now
        runStart = now
        created = now
        daily.firstDay = StepDay.key(for: now)
    }

    private enum CodingKeys: String, CodingKey {
        case version, coins, miners, minerUpgrades, upgrades, tokens
        // Prestige values keep the names they were saved under as Hard Forks.
        case prestigePoints = "forks"
        case prestigePotentialClaimed = "forkPointsClaimed"
        case runPrestigeMultiplier = "runForkMultiplier"
        case prestigePointsSpent, perks, difficulty
        case boost, offlineMiningLevel, powerUps, unlockedGames, blackjackStake, moonRound, pokerRound, unfinishedRun, tokenSwap
        case merge2048Daily, slotsFreeSpins, arcade, journey
        case achievementTiers, daily
        case incomeHistory, stats, steps, recentWatchBatches, watchSequences, recentAirdrops, lastUpdate, runStart, created
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
        // Older versions counted potential against fewer lifetime coins; carry what was claimed over
        // to the current scale, so an older save neither loses nor gains points.
        let savedScale = Tuning.prestigeScale(savedBy: version)
        prestigePotentialClaimed = savedScale == Tuning.prestigeScale
            ? claimed : Self.potentialOnCurrentScale(cubeRootPoints: claimed, savedScale: savedScale)
        perks = c.enumSet(.perks, as: PerkID.self)
        difficulty = c.value(.difficulty, default: .normal)
        // Only the difficulty multipliers are valid; anything else (a damaged save) falls back.
        let multiplier: Double = c.value(.runPrestigeMultiplier, default: difficulty.prestigeMultiplier)
        runPrestigeMultiplier = Difficulty.allCases.map(\.prestigeMultiplier).contains(multiplier)
            ? multiplier : difficulty.prestigeMultiplier
        boost = c.value(.boost, default: nil)
        // Offline upgrades bought in earlier versions, and levels from before version 6 (which added
        // more time each), become the level that pays for the same time away.
        let legacyCap = (savedUpgrades.compactMap { UpgradeID.legacyOfflineHours[$0] }.max() ?? 0) * 3_600
        let savedLevel: Int = c.value(.offlineMiningLevel, default: 0)
        let savedCap = version < 6 ? Self.version5OfflineCap(level: savedLevel) : Self.offlineCap(level: savedLevel)
        offlineMiningLevel = Self.offlineMiningLevel(reaching: max(savedCap, legacyCap))
        powerUps = c.enumKeyed(.powerUps, as: PowerUpID.self).mapValues { max(0, $0) }
        unlockedGames = c.enumSet(.unlockedGames, as: MiniGame.self)
        blackjackStake = c.value(.blackjackStake, default: nil)
        moonRound = c.value(.moonRound, default: nil)
        pokerRound = c.value(.pokerRound, default: nil)
        slotsFreeSpins = c.value(.slotsFreeSpins, default: nil)
        unfinishedRun = c.value(.unfinishedRun, default: nil)
        tokenSwap = c.value(.tokenSwap, default: TokenSwapProgress())
        merge2048Daily = c.value(.merge2048Daily, default: Merge2048DailyProgress())
        arcade = c.value(.arcade, default: ArcadeProgress())
        // A save from before the journey was kept starts recording now.
        journey = c.value(.journey, default: Journey(since: now))
        achievementTiers = c.value(.achievementTiers, default: [:])
        daily = c.value(.daily, default: DailyProgress())
        incomeHistory = c.value(.incomeHistory, default: [])
        stats = c.value(.stats, default: Stats())
        steps = c.value(.steps, default: StepLedger())
        recentWatchBatches = c.value(.recentWatchBatches, default: [])
        watchSequences = c.value(.watchSequences, default: [:])
        recentAirdrops = c.value(.recentAirdrops, default: [])
        lastUpdate = c.value(.lastUpdate, default: now)
        runStart = c.value(.runStart, default: now)
        created = c.value(.created, default: now)
        // A save from before Arcade Rank starts with XP for the games already played.
        if !c.contains(.arcade) { arcade.xp = legacyArcadeXP }
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
        try c.encode(powerUps.stringKeyed, forKey: .powerUps)
        try c.encode(unlockedGames.sortedRawValues, forKey: .unlockedGames)
        try c.encodeIfPresent(blackjackStake, forKey: .blackjackStake)
        try c.encodeIfPresent(moonRound, forKey: .moonRound)
        try c.encodeIfPresent(pokerRound, forKey: .pokerRound)
        try c.encodeIfPresent(slotsFreeSpins, forKey: .slotsFreeSpins)
        try c.encodeIfPresent(unfinishedRun, forKey: .unfinishedRun)
        try c.encode(tokenSwap, forKey: .tokenSwap)
        try c.encode(merge2048Daily, forKey: .merge2048Daily)
        try c.encode(arcade, forKey: .arcade)
        try c.encode(journey, forKey: .journey)
        try c.encode(achievementTiers, forKey: .achievementTiers)
        try c.encode(daily, forKey: .daily)
        try c.encode(incomeHistory, forKey: .incomeHistory)
        try c.encode(stats, forKey: .stats)
        try c.encode(steps, forKey: .steps)
        try c.encode(recentWatchBatches, forKey: .recentWatchBatches)
        if !watchSequences.isEmpty { try c.encode(watchSequences, forKey: .watchSequences) }
        if !recentAirdrops.isEmpty { try c.encode(recentAirdrops, forKey: .recentAirdrops) }
        try c.encode(lastUpdate, forKey: .lastUpdate)
        try c.encode(runStart, forKey: .runStart)
        try c.encode(created, forKey: .created)
    }

    /// Replaces NaN or infinity with zero so a bad value can never poison later math.
    static func finite(_ value: Double) -> Double { value.isFinite ? value : 0 }

    /// The prestige potential, on today's scale, of the lifetime coins at which an older save had
    /// claimed `cubeRootPoints` of potential against `savedScale`.
    static func potentialOnCurrentScale(cubeRootPoints points: Int, savedScale: Double) -> Int {
        guard points > 0 else { return 0 }
        let lifetime = pow(Double(points), 3) * savedScale // Then: points = cube root of lifetime / scale.
        return prestigePotential(lifetimeCoins: lifetime)
    }
}
