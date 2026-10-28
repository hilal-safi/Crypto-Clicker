import Foundation

/// Every balance number in one place. Tuned with simulated players who catch airdrops, claim the
/// dailies, play some arcade and earn achievements (see `PacingTests`): casual play reaches the
/// first ten miners and every mini-game in about a day and a half and the first prestige after about
/// two days, and prestiges, perks and the three extra miner tiers keep new things arriving for about
/// two weeks. Prices in the catalogs are list prices: `scaledPrice` sets the pace. Coin amounts
/// here are whole numbers; only rates may be fractional.
public enum Tuning {
    // MARK: Miners
    /// Each additional unit of a miner costs this much more than the previous one.
    public static let costGrowth = 1.15
    /// Owning this many of one miner doubles that miner's output (once per milestone).
    public static let milestones = [25, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1_000]
    public static let milestoneMultiplier = 2.0

    // MARK: Miner Mk upgrades
    /// Owning this many of a miner reveals its next Mk upgrade (Mk II to Mk VI), alongside the
    /// milestone at the same count...
    public static let minerUpgradeThresholds = [25, 50, 100, 200, 400]
    /// ...which multiplies that miner's output by this much...
    public static let minerUpgradeMultiplier = 2.0
    /// ...and costs about this many units of the miner at the count that reveals it.
    public static let minerUpgradeUnits = 10.0

    // MARK: Tapping
    /// An automatic tap earns this share of a tap's value, so tapping yourself stays the best way to
    /// mine while the app is open: late in the game a tap is worth a whole second of production.
    public static let autoTapStrength = 0.25
    /// A tap within this long of the previous one keeps a combo going.
    public static let comboWindow: TimeInterval = 0.6
    /// Quick taps in a row needed to reach the biggest combo multiplier...
    public static let comboTapsToMax = 40
    /// ...which is this.
    public static let comboMaxMultiplier = 2.0

    // MARK: Time
    /// Gaps shorter than this count as live play and are paid in full (ticks, a quick app switch).
    /// Longer gaps are time away: paid up to the Offline Mining limit, with a report. Even without
    /// Offline Mining the first minute is paid, so a longer absence never pays less than a short one.
    public static let awayThreshold: TimeInterval = 60

    // MARK: Offline Mining
    /// Miners earn nothing while the app is closed until the player buys Offline Mining.
    /// Each level adds this much time away, up to a full day...
    public static let offlineMiningStep: TimeInterval = 30 * 60
    /// ...which this level reaches...
    public static let offlineMiningDayLevel = 48
    /// ...and then this much per level...
    public static let offlineMiningLateStep: TimeInterval = 3_600
    /// ...up to three days at this level.
    public static let offlineMiningMaxLevel = 96
    /// The first level's price; each level costs this many times the one before.
    public static let offlineMiningBaseCost = 1_500.0
    public static let offlineMiningCostGrowth = 1.5

    // MARK: Steps
    /// Lifetime taps needed before steps can be connected, so early coins come from playing.
    public static let stepsUnlockTaps = 2_500
    /// One step is worth this many seconds of idle income (before step upgrades).
    public static let stepSeconds = 0.06
    /// A step is never worth less than this many coins (before step upgrades).
    public static let minimumStepValue = 1.0
    /// Income used for step and mini-game rewards never drops below this, so they matter on day one.
    public static let minimumRewardIncome = 1.0
    /// Days of HealthKit history checked on each sync, including today.
    public static let stepWindowDays = 7

    // MARK: Pace
    /// Every price is its list price times this: about 58% more for the cheapest things, easing to
    /// about 52% more from a million coins up. Raising every price is the same as slowing all income.
    /// (Three rounds of slowing: 15% early and 10% overall, then 25% and 15% more, then 10% and 20%.)
    public static func priceScale(forListPrice price: Double) -> Double {
        let early = 1.15 * 1.25 * 1.1, late = 1.10 * 1.15 * 1.2, start = 5_000.0, end = 1e6
        guard price.isFinite, price > start else { return early }
        guard price < end else { return late }
        return early + (late - early) * log10(price / start) / log10(end / start)
    }

    /// A list price with the pace applied, in whole coins (rounded up).
    public static func scaledPrice(_ listPrice: Double) -> Double {
        let price = listPrice * priceScale(forListPrice: listPrice)
        guard price.isFinite, price < 0x1p52 else { return price } // Larger doubles are already whole.
        return max(0, (price - 1e-6).rounded(.up))
    }

    // MARK: Prestige
    /// Lifetime coins needed for the first point of prestige potential: 15 billion. Potential grows
    /// with the cube root of lifetime coins, so each prestige takes longer than the one before.
    public static let prestigeScale = 1.5e10
    /// The scale each older save version counted potential against, so loading one carries its
    /// prestige progress over (see `GameState.init(from:)`).
    static func prestigeScale(savedBy version: Int) -> Double {
        switch version {
        case ..<3: 1e10
        case 3: 1.1e10
        case 4: 1.265e10
        default: prestigeScale
        }
    }
    /// Production added by every prestige point ever earned, spent on perks or not.
    public static let productionPerPrestigePoint = 0.05
    /// Prestige points stop counting here. Far beyond reach in play, and small enough for `Int`
    /// on Apple Watch, where `Int` is 32 bits.
    public static let maxPrestigePoints = 1_000_000_000
    /// Prestiging is suggested once the new points would make production at least this much faster.
    public static let prestigeRecommendedSpeedUp = 1.5
    /// What the Head Start perk gives at the start of every run.
    public static let headStartMiners: [MinerID: Int] = [.chromebook: 10, .desktop: 10, .gpuRig: 5]
    public static let productionPerAchievementTier = 0.01

    // MARK: Airdrops
    public static let airdropInterval: ClosedRange<TimeInterval> = 180...360
    public static let airdropLifetime: TimeInterval = 20
    /// With the Airdrop Radar perk.
    public static let radarAirdropInterval: ClosedRange<TimeInterval> = 120...240
    public static let radarAirdropLifetime: TimeInterval = 30
    public static let bullRunChance = 0.3
    public static let bullRunMultiplier = 7.0
    public static let bullRunDuration: TimeInterval = 60
    /// With the Bull Market perk.
    public static let bullMarketDuration: TimeInterval = 120
    /// An ordinary coin airdrop pays this share of the balance, up to this many seconds of income
    /// (and at least `airdropMinimumSeconds`).
    public static let airdropBankShare = 0.15
    public static let airdropIncomeSeconds = 900.0
    public static let airdropMinimumSeconds = 30.0
    /// A rare whale airdrop pays this many seconds of income.
    public static let whaleChance = 0.05
    public static let whaleIncomeSeconds = 3_600.0

    // MARK: Daily
    /// Quests issued each day.
    public static let questsPerDay = 3
    /// The login streak's rewards repeat after this many days.
    public static let streakCycle = 7
    /// Income history: one sample per interval, for a week.
    public static let incomeSampleInterval: TimeInterval = 30 * 60
    public static let maxIncomeSamples = 336

    // MARK: Market
    /// Token prices move every five minutes...
    public static let marketTick: TimeInterval = 5 * 60
    /// ...between these factors of a token's list price.
    public static let marketPriceRange: ClosedRange<Double> = 0.7...1.4
    /// Chance per tick that news breaks for a token.
    public static let marketNewsChance = 0.0025
    /// How far a story moves a price at first, in log terms: 0.04 is about 4%, 0.1 about 10%.
    public static let marketNewsStrength: ClosedRange<Double> = 0.04...0.10
    /// News moves a price for up to this many ticks (six hours).
    public static let marketNewsTicks = 72
    /// Share of a sale the market keeps (Market Insider waives it).
    public static let marketSellFee = 0.1

    // MARK: Mini-games
    /// A winning Blackjack hand pays this share of its stake's coin value in coins...
    public static let blackjackStakeShare = 0.5
    /// ...up to this many seconds of idle income, so bigger bets matter but can't run away.
    public static let blackjackWinSeconds = 60.0
    /// A natural pays this much more than an ordinary win.
    public static let blackjackNaturalBonus = 1.5
    /// A winning slots spin pays this share of its stake's coin value for each multiple of the bet...
    public static let slotsStakeShare = 0.05
    /// ...up to this many seconds of idle income for each multiple.
    public static let slotsWinSeconds = 3.0
    /// A To the Moon cash-out pays this share of its stake's coin value for each multiple above 1×...
    public static let moonStakeShare = 0.05
    /// ...up to this many seconds of idle income for each multiple above 1×.
    public static let moonWinSeconds = 15.0
    /// A Video Poker hand of two pair or better pays this share of its stake's coin value for each
    /// multiple of the bet...
    public static let pokerStakeShare = 0.05
    /// ...up to this many seconds of idle income for each multiple.
    public static let pokerWinSeconds = 15.0
    /// Arcade games pay this many seconds of idle income per point when they end. Simulated skilled
    /// players (see ArcadeBalanceTests) earn about two minutes of income for each minute they play
    /// in any of them, on top of the mining that carries on meanwhile; an average player about one.
    /// Tetris pays on its points before the level multiplier (`TetrisGame.rewardPoints`)...
    public static let tetrisSecondsPerPoint = 0.025
    public static let snakeSecondsPerPoint = 0.6
    public static let brickBreakerSecondsPerPoint = 0.4
    public static let bubbleSecondsPerPoint = 0.1
    public static let merge2048SecondsPerPoint = 0.055
    /// Each Token Swap level star pays this many seconds of income, once, the first time it's
    /// earned (times the level's difficulty multiplier): the first star for winning, then the
    /// second and third for higher scores.
    public static let tokenSwapStarSeconds: [Double] = [120, 60, 60]
    /// Winning the day's Token Swap puzzle pays this many seconds of income, once a day.
    public static let tokenSwapDailySeconds = 600.0
    /// Pump and Dump runs go on round after round, and later rounds score faster.
    public static let pumpDumpSecondsPerPoint = 0.043
    public static let tokenSwapSecondsPerPoint = 0.023
    /// Making a 2048 tile also pays this many seconds of income.
    public static let merge2048WinSeconds = 600.0
    /// ...and this much more for a new best score.
    public static let newBestBonus = 0.5

    // MARK: Daily challenge
    /// Completing the day's challenge pays this many seconds of income...
    public static let challengeRewardSeconds = 900.0
    /// ...and completing this many in one week (Monday to Sunday)...
    public static let weeklyChallengeGoal = 5
    /// ...pays this many more.
    public static let weeklyChallengeBonusSeconds = 7_200.0

    // MARK: Watch
    /// Upper bound on taps accepted from a single watch batch.
    public static let maxWatchTapsPerBatch = 2_000
    public static let rememberedWatchBatches = 64
}
