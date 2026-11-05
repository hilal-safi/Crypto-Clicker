import Foundation

/// Every balance number in one place. Tuned with simulated players who catch airdrops, claim the
/// dailies, play some arcade and earn achievements (see `PacingTests`): someone who keeps playing
/// buys a Data Center after a little over an hour; casual play (four ten-minute visits a day)
/// reaches the Data Center in about a day, the first prestige point around day two, every
/// mini-game in about four days and the tenth miner and the first suggested prestige in about
/// five, and prestiges and perks keep new things arriving for about three weeks. Prices in the catalogs are list prices: `scaledPrice` sets the pace. Coin amounts here
/// are whole numbers; only rates may be fractional.
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
    /// A combo climbs by this much (+0.1)...
    public static let comboStep = 0.1
    /// ...every this many quick taps in a row (on average: 4.4 means 4 or 5), so ×2 takes 44 taps
    /// after the first. Quick Combos and Combo Master make each step come sooner.
    public static let comboTapsPerStep = 4.4
    /// The biggest combo multiplier without power-ups...
    public static let comboMaxMultiplier = 2.0
    /// ...and with every level of Combo Booster and Combo Overdrive, the most it can be.
    public static let comboTopMultiplier = 10.0
    /// Combo Master's combos reach at least this.
    public static let comboMasterMultiplier = 3.0

    // MARK: Combo power-ups
    /// Each Combo Booster level raises the biggest combo by this much...
    public static let comboBoosterStep = 0.5
    /// ...and each Combo Overdrive level by this much.
    public static let comboOverdriveStep = 1.0
    /// Each Quick Combos level makes combos build this much faster (0.5 is 50%).
    public static let quickComboStep = 0.5
    /// First-level list prices, and how much dearer each level is than the one before. Someone who
    /// keeps playing gets the first Combo Booster in under an hour and Quick Combos within the first
    /// hour and a half; both reach their last levels around the first prestige, and Overdrive over
    /// the runs after it (power-ups are kept when you prestige).
    public static let comboBoosterBaseCost = 40_000.0
    public static let comboBoosterCostGrowth = 8.0
    public static let comboOverdriveBaseCost = 1e10
    public static let comboOverdriveCostGrowth = 10.0
    public static let quickCombosBaseCost = 100_000.0
    public static let quickCombosCostGrowth = 10.0

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
    /// The first level's price (before the pace), and each level costs this many times the one before.
    /// Early levels are dear on purpose: time away is paid at the full rate, and a long absence
    /// with cheap levels would buy enough miners to multiply income in one go.
    public static let offlineMiningBaseCost = 3_500.0
    public static let offlineMiningCostGrowth = 1.5

    // MARK: Steps
    /// Lifetime taps needed before steps can be connected, so early coins come from playing.
    public static let stepsUnlockTaps = 2_000
    /// One step is worth this many seconds of idle income (before step upgrades).
    public static let stepSeconds = 0.06
    /// A step is never worth less than this many coins (before step upgrades).
    public static let minimumStepValue = 1.0
    /// Income used for step and mini-game rewards never drops below this, so they matter on day one.
    public static let minimumRewardIncome = 1.0
    /// Days of HealthKit history checked on each sync, including today.
    public static let stepWindowDays = 7
    /// Steps walked since the last sync are paid quietly; a toast says so from this many.
    public static let stepsToastMinimum = 100

    // MARK: Pace
    /// Every price is its list price times this: about double for everything under 5,000 coins,
    /// easing to about 52% more from a million coins up, so the opening is the slowest part.
    /// Raising every price is the same as slowing all income. (Four rounds of slowing: 15% early and
    /// 10% overall, then 25% and 15% more, then 10% and 20%, then 30% more on the opening only.)
    public static func priceScale(forListPrice price: Double) -> Double {
        let early = 1.15 * 1.25 * 1.1 * 1.3, late = 1.10 * 1.15 * 1.2, start = 5_000.0, end = 1e6
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
    /// A rare whale airdrop pays this many seconds of income, but never more than the coins mined
    /// so far in the run (see `GameState.whaleAmount`).
    public static let whaleChance = 0.05
    public static let whaleIncomeSeconds = 3_600.0

    // MARK: Daily
    /// Quests issued each day.
    public static let questsPerDay = 3
    /// The login streak's rewards repeat after this many days.
    public static let streakCycle = 7
    /// Income history for the Statistics chart: a sample every minute while the game is open, so
    /// the chart has a shape from the first minutes of a game...
    public static let incomeSampleInterval: TimeInterval = 60
    /// ...thinned as they age to one per five minutes after an hour, one per half hour after a day,
    /// one per six hours after a week and one a day after a month (keeping each period's highest),
    /// so the chart covers an hour in minutes and all time in days...
    public static let incomeHistoryTiers: [(age: TimeInterval, bucket: TimeInterval)] = [
        (3_600, 5 * 60), (86_400, 30 * 60), (7 * 86_400, 6 * 3_600), (30 * 86_400, 86_400),
    ]
    /// ...and at most this many in all: about five years of days.
    public static let maxIncomeSamples = 2_000

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
    /// The tough table (the dealer hits soft 17) pays this much more coin bonus for a win.
    public static let blackjackToughTableBonus = 1.1
    /// A winning slots spin pays this share of its stake's coin value for each multiple of the bet...
    public static let slotsStakeShare = 0.05
    /// ...up to this many seconds of idle income for each multiple.
    public static let slotsWinSeconds = 3.0
    /// Every `SlotMachine.bitcoinsPerPrize` Bitcoins collected on the line pay this many seconds of income.
    public static let slotsCollectionSeconds = 60.0
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
    public static let snakeSecondsPerPoint = 0.3
    /// Coin Rush scores faster than Classic (three coins out at once), so its points pay this share.
    public static let snakeCoinRushPay = 0.6
    /// Flash Market's rows come on the clock, so it scores faster than Bubble Market's waves; its
    /// points pay this share.
    public static let bubbleFlashPay = 0.65
    public static let brickBreakerSecondsPerPoint = 0.36
    public static let invadersSecondsPerPoint = 0.09
    public static let bubbleSecondsPerPoint = 0.11
    public static let merge2048SecondsPerPoint = 0.055
    /// Each Token Swap level star pays this many seconds of income, once, the first time it's
    /// earned (times the level's difficulty multiplier): the first star for winning, then the
    /// second and third for higher scores.
    public static let tokenSwapStarSeconds: [Double] = [120, 60, 60]
    /// Winning a random Token Swap level pays this many seconds of income on top of its points
    /// (times the level's difficulty multiplier).
    public static let tokenSwapRandomWinSeconds = 60.0
    /// Winning the day's Token Swap puzzle pays this many seconds of income, once a day.
    public static let tokenSwapDailySeconds = 600.0
    /// Pump and Dump runs go on round after round, and later rounds score faster.
    public static let pumpDumpSecondsPerPoint = 0.043
    public static let tokenSwapSecondsPerPoint = 0.023
    /// Making a 2048 tile also pays this many seconds of income.
    public static let merge2048WinSeconds = 600.0
    /// Each star of the daily 2048 puzzle pays this many seconds of income, once a day.
    public static let merge2048DailyStarSeconds = 200.0
    /// ...and this much more for a new best score.
    public static let newBestBonus = 0.5

    // MARK: Daily challenge
    /// Completing the day's challenge pays this many seconds of income...
    public static let challengeRewardSeconds = 900.0
    /// ...and completing this many in one week (Monday to Sunday)...
    public static let weeklyChallengeGoal = 5
    /// ...pays this many more.
    public static let weeklyChallengeBonusSeconds = 7_200.0

    // MARK: Arcade Rank
    /// XP for each arcade game finished...
    public static let arcadeXPPerGame = 10
    /// ...and each casino round, up to `arcadeCasinoXPPerDay` a day, so XP rewards playing, not betting.
    public static let arcadeXPPerCasinoRound = 2
    public static let arcadeCasinoXPPerDay = 40
    /// More for a new best score (or a faster Sprint), the first game of each kind each day, the daily
    /// challenge, each star (Token Swap levels and the daily 2048 puzzle), each tier of a game
    /// achievement, and the week's variety goal.
    public static let arcadeXPNewBest = 20
    public static let arcadeXPFirstPlayToday = 15
    public static let arcadeXPChallenge = 50
    public static let arcadeXPPerStar = 5
    public static let arcadeXPPerAchievementTier = 25
    public static let arcadeXPWeeklyGoal = 100
    /// Playing this many different games in a week (Monday to Sunday) pays `weeklyVarietySeconds` of income.
    public static let weeklyVarietyGames = 6
    public static let weeklyVarietySeconds = 1_800.0

    // MARK: Watch
    /// Upper bound on taps accepted from a single watch batch.
    public static let maxWatchTapsPerBatch = 2_000
    public static let rememberedWatchBatches = 64

    /// Airdrops kept in the history in Statistics.
    public static let rememberedAirdrops = 10
}
