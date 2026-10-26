import Foundation

/// Every balance number in one place. Tuned with a progression simulation:
/// all ten miners unlock over roughly a day and a half of casual play,
/// and the first Hard Fork becomes available after about a day.
/// Coin amounts here are whole numbers; only rates per second may be fractional.
public enum Tuning {
    // MARK: Miners
    /// Each additional unit of a miner costs this much more than the previous one.
    public static let costGrowth = 1.15
    /// Owning this many of one miner doubles that miner's output (once per milestone).
    public static let milestones = [25, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1_000]
    public static let milestoneMultiplier = 2.0

    // MARK: Tapping
    /// An automatic tap earns this share of a tap's value, so tapping yourself stays the best way to
    /// mine while the app is open: late in the game a tap is worth a whole second of production.
    public static let autoTapStrength = 0.25

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

    // MARK: Prestige
    /// Lifetime coins needed for the first fork point; points grow with the cube root of lifetime coins.
    public static let forkScale = 1e10
    public static let productionPerFork = 0.02
    /// Fork points stop counting here. Far beyond reach in play, and small enough for `Int`
    /// on Apple Watch, where `Int` is 32 bits.
    public static let maxForkPoints = 1_000_000_000
    public static let productionPerAchievementTier = 0.01

    // MARK: Airdrops
    public static let airdropInterval: ClosedRange<TimeInterval> = 180...360
    public static let airdropLifetime: TimeInterval = 15
    public static let bullRunChance = 0.3
    public static let bullRunMultiplier = 7.0
    public static let bullRunDuration: TimeInterval = 60
    public static let airdropBankShare = 0.15
    public static let airdropIncomeSeconds = 900.0

    // MARK: Mini-games
    /// A winning Blackjack hand pays this share of its stake's coin value in coins...
    public static let blackjackStakeShare = 0.5
    /// ...up to this many seconds of idle income, so bigger bets matter but can't run away.
    public static let blackjackWinSeconds = 10.0
    /// A natural pays this much more than an ordinary win.
    public static let blackjackNaturalBonus = 1.5
    /// A winning slots spin pays this share of its stake's coin value for each multiple of the bet...
    public static let slotsStakeShare = 0.05
    /// ...up to this many seconds of idle income for each multiple.
    public static let slotsWinSeconds = 0.5
    /// Arcade games pay this many seconds of idle income per point when they end.
    public static let tetrisSecondsPerPoint = 0.02
    public static let snakeSecondsPerPoint = 0.15
    public static let brickBreakerSecondsPerPoint = 0.06
    public static let bubbleSecondsPerPoint = 0.025

    // MARK: Watch
    /// Upper bound on taps accepted from a single watch batch.
    public static let maxWatchTapsPerBatch = 2_000
    public static let rememberedWatchBatches = 64
}
