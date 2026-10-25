import Foundation

/// Every balance number in one place. Tuned with a progression simulation:
/// all ten miners unlock over roughly a day and a half of casual play,
/// and the first Hard Fork becomes available after about a day.
public enum Tuning {
    // MARK: Miners
    /// Each additional unit of a miner costs this much more than the previous one.
    public static let costGrowth = 1.15
    /// Owning this many of one miner doubles that miner's output (once per milestone).
    public static let milestones = [25, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1_000]
    public static let milestoneMultiplier = 2.0

    // MARK: Time
    /// Gaps at least this long count as time away: paid up to the offline cap, with a report.
    /// Shorter gaps (live ticks, a quick app switch) are paid in full.
    public static let awayThreshold: TimeInterval = 60
    public static let baseOfflineCap: TimeInterval = 2 * 3_600

    // MARK: Steps
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
    /// Tetris pays this many seconds of idle income per point scored.
    public static let tetrisSecondsPerPoint = 0.02

    // MARK: Watch
    /// Upper bound on taps accepted from a single watch batch.
    public static let maxWatchTapsPerBatch = 2_000
    public static let rememberedWatchBatches = 64
}
