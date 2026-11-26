import Foundation
import Testing
@testable import CryptoClickerKit

/// Simulated players guard the balance: if a tuning change makes the game race ahead or stall,
/// these tests fail. They play the way people do: tap a few times a second while the app is open
/// (quick enough for combos at three taps a second), catch most airdrops, claim quests and the
/// daily reward, complete daily challenges, spend some of each session in the arcade, earn
/// achievements, buy whatever pays back fastest (Mk upgrades included), unlock games once they
/// cost a few minutes of income, prestige when the Shop suggests it and buy perks.
struct SimulatedPlayer {
    var game = GameState(now: t0)
    var now = t0
    let tapsPerSecond: Int
    /// Hours away between sessions each day, so the player can judge what Offline Mining is worth.
    let awayHours: [Double]
    var rng = SeededGenerator(seed: 1)
    /// Share of airdrops caught.
    var catchRate = 0.8
    /// Seconds of every ten minutes spent in an arcade game instead of tapping.
    var arcadeSecondsPerTen = 90.0
    /// Prestiges as soon as the shop suggests it, then spends the points on perks.
    var prestigesWhenSuggested = true
    /// Steps walked a day, spread evenly from 7 am to 10 pm. Above zero, the player connects Apple
    /// Health as soon as steps unlock, syncs every check-in and buys the step upgrades.
    var stepsPerDay = 0
    private(set) var firstBought: [MinerID: TimeInterval] = [:]
    private(set) var firstUpgrade: [UpgradeID: TimeInterval] = [:]
    /// Each power-up level bought: which, the level, and when.
    private(set) var powerUpsBought: [(powerUp: PowerUpID, level: Int, at: TimeInterval)] = []
    /// Chromebooks owned when the first Desktop was bought, and Desktops at the first GPU Rig.
    private(set) var chromebooksAtFirstDesktop: Int?
    private(set) var desktopsAtFirstGPU: Int?
    private(set) var gamesUnlockedAt: [MiniGame: TimeInterval] = [:]
    /// When each starter milestone's reward was claimed on the Goals page.
    private(set) var starterClaimedAt: [StarterMilestone: TimeInterval] = [:]
    private(set) var firstPointAt: TimeInterval?
    private(set) var prestigeTimes: [TimeInterval] = []
    private(set) var perksBoughtAt: [PerkID: TimeInterval] = [:]
    /// Seconds spent playing.
    private(set) var played: TimeInterval = 0
    private var nextAirdrop: TimeInterval = 0

    /// `seed` picks when the airdrops come and what they are, and which arcade games get played.
    init(tapsPerSecond: Int, awayHours: [Double] = [], seed: UInt64 = 1) {
        self.tapsPerSecond = tapsPerSecond
        self.awayHours = awayHours
        rng = SeededGenerator(seed: seed)
        nextAirdrop = Double.random(in: Tuning.airdropInterval, using: &rng)
    }

    var elapsed: TimeInterval { now.timeIntervalSince(t0) }
    var firstPrestigeAt: TimeInterval? { prestigeTimes.first }

    /// The day `offset` days from now, as a key in the time zone the game uses.
    func dayKey(_ offset: Int) -> String {
        StepDay.key(for: now.addingTimeInterval(Double(offset) * 86_400))
    }

    /// Income as the player experiences it while playing, with the combo a session of quick taps
    /// averages.
    func income(_ state: GameState) -> Double {
        state.baseIdleIncome + Double(tapsPerSecond) * state.tapValue(at: now) * sessionCombo(state)
    }

    /// The average combo over ten minutes of quick taps: it climbs for `comboTapsToMax` taps, then
    /// stays at the top. Taps a second apart are too slow for combos.
    func sessionCombo(_ state: GameState) -> Double {
        guard 1 / Double(tapsPerSecond) <= state.comboWindow else { return 1 }
        let taps = 600 * Double(tapsPerSecond)
        let build = Double(state.comboTapsToMax)
        let top = state.comboMaxMultiplier
        guard build < taps else { return 1 + (top - 1) * taps / build / 2 }
        return (build * (1 + top) / 2 + (taps - build) * top) / taps
    }

    mutating func play(seconds: Int) {
        var streak = 0
        dailies()
        let inArcade = game.unlockedGames.contains { !$0.isCasino } ? Int(arcadeSecondsPerTen * Double(seconds) / 600) : 0
        for second in 0..<seconds {
            now += 1
            played += 1
            game.advance(to: now)
            if second < seconds - inArcade {
                streak = 1 / Double(tapsPerSecond) <= game.comboWindow ? streak + tapsPerSecond : 1
                game.tap(count: tapsPerSecond, at: now, combo: streak)
            } else if second == seconds - 1 {
                playArcade(minutes: Double(inArcade) / 60)
            }
            if played >= nextAirdrop && game.areAirdropsUnlocked {
                nextAirdrop = played + Double.random(in: game.airdropInterval, using: &rng)
                if Double.random(in: 0..<1, using: &rng) < catchRate {
                    game.claimAirdrop(game.airdropKind(roll: Double.random(in: 0..<1, using: &rng)), at: now)
                }
            }
            if second % 2 == 0 { shop() }
            if second % 30 == 0 {
                dailies()
                game.refreshAchievements()
                claimStarterMilestones()
            }
            notePrestige()
        }
        game.refreshAchievements()
        claimStarterMilestones()
    }

    mutating func leave(for seconds: TimeInterval) {
        now += seconds
        game.advance(to: now)
        game.refreshAchievements()
        claimStarterMilestones()
        shop()
        notePrestige()
    }

    /// Presses Claim on every starter milestone that is done (the Goals page), whenever the player
    /// looks: the rewards are coins, or a short Bull Run, and are worth having early.
    mutating func claimStarterMilestones() {
        for milestone in game.claimableStarterMilestones where game.claim(milestone, at: now) != nil {
            starterClaimedAt[milestone] = elapsed
        }
    }

    /// Steps walked so far today: the day's steps spread evenly from 7 am to 10 pm.
    func stepsSoFarToday() -> Int {
        let sinceMidnight = now.timeIntervalSince(Calendar.current.startOfDay(for: now))
        let share = min(1, max(0, (sinceMidnight - 7 * 3_600) / (15 * 3_600)))
        return Int(Double(stepsPerDay) * share)
    }

    /// Connects Apple Health once steps unlock, then syncs: yesterday's full total and today's so far.
    private mutating func syncSteps() {
        guard stepsPerDay > 0 else { return }
        let today = dayKey(0)
        if !game.steps.isConnected { game.connectSteps(today: today) }
        guard game.steps.isConnected else { return }
        let days = [StepDay(key: dayKey(-1), steps: stepsPerDay), StepDay(key: today, steps: stepsSoFarToday())]
        game.creditSteps(days, today: today, at: now)
    }

    /// Today's quests, challenge and daily reward (from the second day on).
    private mutating func dailies() {
        let today = dayKey(0)
        syncSteps()
        game.refreshDaily(today: today, canWalk: stepsPerDay > 0, at: now)
        game.claimDailyReward(today: today, yesterday: dayKey(-1), at: now)
        for quest in game.daily.quests where !quest.isClaimed && game.isComplete(quest) {
            game.claimQuest(quest.id, at: now)
        }
    }

    /// An average player's arcade game: about 90 seconds of income per minute played (45 before the
    /// arcade's pay doubled in version 2), paid
    /// through the game's own reward, so quests and challenges count it.
    private mutating func playArcade(minutes: Double) {
        let games = MiniGame.allCases.filter { !$0.isCasino && game.isUnlocked($0) }
        guard let pick = games.randomElement(using: &rng) else { return }
        let points = max(1, Int(45 * Tuning.arcadePayBoost * minutes / pick.secondsPerPoint / game.miniGameMultiplier))
        switch pick {
        case .tetris: game.finishTetris(score: points, lines: points / 150, rewardPoints: points)
        case .snake: game.finishSnake(score: points, length: points / SnakeGame.pointsPerCoin + 3)
        case .brickBreaker: game.finishBrickBreaker(score: points, bricks: points / 10, level: 2)
        case .bubbleBlaster: game.finishBubbleBlaster(score: points, popped: points / 10, bestShot: 6)
        case .merge2048: game.finishMerge2048(score: points, bestTile: 256)
        case .pumpDump: game.finishPumpDump(score: points, coinsHit: points / 12, bestCombo: 10)
        case .tokenSwap: game.finishTokenSwap(score: points, tokens: points / 14, bestChain: 3)
        case .invaders: game.finishInvaders(score: points, destroyed: points / 16, wave: 2)
        case .blackjack, .slots, .moon, .videoPoker: break
        }
    }

    private mutating func notePrestige() {
        if firstPointAt == nil && game.claimablePrestigePoints >= 1 { firstPointAt = elapsed }
        guard prestigesWhenSuggested, game.isPrestigeRecommended else { return }
        while let next = nextGame, game.unlock(next) { gamesUnlockedAt[next] = elapsed }
        game.prestige(at: now)
        prestigeTimes.append(elapsed)
        while let perk = PerkID.allCases.filter(game.canBuy).min(by: { $0.cost < $1.cost }) {
            game.buyPerk(perk)
            perksBoughtAt[perk] = elapsed
        }
    }

    private var nextGame: MiniGame? {
        MiniGame.allCases.filter { !game.isUnlocked($0) }.min { $0.unlockCost < $1.unlockCost }
    }

    /// Unlocks the next game once it costs three minutes of income or less, saving for it meanwhile
    /// (after the first few miners: nobody buys Blackjack before a Chromebook).
    private mutating func saveForGames() -> Bool {
        guard game.totalMiners >= 10 else { return false }
        while let next = nextGame {
            guard game.unlock(next) else { return next.unlockCost <= income(game) * 180 }
            gamesUnlockedAt[next] = elapsed
        }
        return false
    }

    /// What one more Offline Mining level adds, as income per second of play: the extra time it
    /// pays each day, spread over the ten minutes played per session.
    private func offlineMiningGain() -> Double {
        guard !awayHours.isEmpty else { return 0 }
        let efficiency = game.offlineEfficiency
        let current = max(GameState.offlineCap(level: game.offlineMiningLevel), Tuning.baseAwayTime)
        let next = GameState.offlineCap(level: game.offlineMiningLevel + 1)
        let extra = awayHours.reduce(0.0) { total, hours in
            total + Tuning.awayPaidSeconds(min(hours * 3_600, next), efficiency: efficiency)
                - Tuning.awayPaidSeconds(min(hours * 3_600, current), efficiency: efficiency)
        }
        return game.baseIdleIncome * extra / (600 * Double(awayHours.count))
    }

    /// What one more level of Offline Efficiency adds, as income per second of play: the share of
    /// each absence it pays, spread over the ten minutes played per session. It counts from the
    /// start of the game: it raises what the six minutes away the game starts with pay, with or
    /// without Offline Mining.
    private func offlineEfficiencyGain() -> Double {
        guard !awayHours.isEmpty else { return 0 }
        let limit = game.timeAwayLimit
        let current = game.offlineEfficiency
        let next = Double(Tuning.offlineEfficiencyPercent(level: game.powerUpLevel(.offlineEfficiency) + 1)) / 100
        let extra = awayHours.reduce(0.0) { total, hours in
            let away = min(hours * 3_600, limit)
            return total + Tuning.awayPaidSeconds(away, efficiency: next) - Tuning.awayPaidSeconds(away, efficiency: current)
        }
        return game.baseIdleIncome * extra / (600 * Double(awayHours.count))
    }

    private mutating func shop() {
        if saveForGames() { return }
        while true {
            let current = max(income(game), 1e-9)
            let coins = game.coins
            var best: (score: Double, apply: (inout GameState) -> Bool, miner: MinerID?, upgrade: UpgradeID?, powerUp: PowerUpID?)?
            func consider(cost: Double, gain: Double, miner: MinerID? = nil, upgrade: UpgradeID? = nil,
                          powerUp: PowerUpID? = nil, _ apply: @escaping (inout GameState) -> Bool) {
                guard gain > 0 else { return }
                let score = max(0, (cost - coins) / current) + cost / gain
                if score < best?.score ?? .infinity { best = (score, apply, miner, upgrade, powerUp) }
            }
            for miner in MinerID.allCases where game.isRevealed(miner) {
                var copy = game
                copy.miners[miner, default: 0] += 1
                consider(cost: game.price(of: miner, quantity: 1), gain: income(copy) - current, miner: miner) {
                    $0.buy(miner, quantity: 1)
                }
                if let upgrade = game.availableMinerUpgrade(miner) {
                    var upgraded = game
                    upgraded.minerUpgrades[miner] = upgrade.level + 1
                    consider(cost: upgrade.price, gain: income(upgraded) - current) { $0.buyMinerUpgrade(miner) }
                }
            }
            for upgrade in UpgradeID.allCases where !game.upgrades.contains(upgrade) && game.isRevealed(upgrade) {
                switch upgrade.category {
                case .steps:
                    // A day's extra step coins, spread over the day's forty minutes of play.
                    guard stepsPerDay > 0, game.steps.isConnected else { continue }
                    var copy = game
                    copy.upgrades.insert(upgrade)
                    let extra = Double(stepsPerDay) * (copy.stepValue - game.stepValue)
                    consider(cost: upgrade.cost, gain: extra / 2_400, upgrade: upgrade) { $0.buy(upgrade) }
                case .miniGames:
                    // Worth about as much as a small production boost to someone who plays.
                    consider(cost: upgrade.cost, gain: current * 0.03, upgrade: upgrade) { $0.buy(upgrade) }
                case .tapping, .production:
                    var copy = game
                    copy.upgrades.insert(upgrade)
                    consider(cost: upgrade.cost, gain: income(copy) - current, upgrade: upgrade) { $0.buy(upgrade) }
                }
            }
            if let price = game.offlineMiningPrice {
                consider(cost: price, gain: offlineMiningGain()) { $0.buyOfflineMining() }
            }
            for powerUp in PowerUpID.allCases where game.isRevealed(powerUp) {
                guard let price = game.powerUpPrice(powerUp) else { continue }
                if powerUp == .offlineEfficiency {
                    consider(cost: price, gain: offlineEfficiencyGain(), powerUp: powerUp) { $0.buyPowerUp(powerUp) }
                    continue
                }
                var copy = game
                copy.powerUps[powerUp] = game.powerUpLevel(powerUp) + 1
                consider(cost: price, gain: income(copy) - current, powerUp: powerUp) { $0.buyPowerUp(powerUp) }
            }
            guard let best, best.apply(&game) else { return }
            if let powerUp = best.powerUp { powerUpsBought.append((powerUp, game.powerUpLevel(powerUp), elapsed)) }
            if let miner = best.miner, firstBought[miner] == nil {
                firstBought[miner] = elapsed
                if miner == .desktop { chromebooksAtFirstDesktop = game.owned(.chromebook) }
                if miner == .gpuRig { desktopsAtFirstGPU = game.owned(.desktop) }
            }
            if let upgrade = best.upgrade, firstUpgrade[upgrade] == nil { firstUpgrade[upgrade] = elapsed }
        }
    }
}

@Suite("Pacing")
struct PacingTests {
    func hours(_ seconds: TimeInterval?) -> String {
        seconds.map { String(format: "%.1fh", $0 / 3_600) } ?? "-"
    }

    func days(_ seconds: TimeInterval?) -> String {
        seconds.map { String(format: "day %.1f", $0 / 86_400) } ?? "-"
    }

    /// Four ten-minute check-ins every 22 hours (away 3, 4, 5 and 10 hours), until `days` days
    /// have passed, walking `stepsPerDay` steps a day.
    func casualPlayer(days: Int, stepsPerDay: Int = 0) -> SimulatedPlayer {
        let gaps: [Double] = [3, 4, 5, 10]
        var player = SimulatedPlayer(tapsPerSecond: 3, awayHours: gaps)
        player.stepsPerDay = stepsPerDay
        while player.elapsed < Double(days) * 86_400 {
            for gap in gaps where player.elapsed < Double(days) * 86_400 {
                player.play(seconds: 600)
                player.leave(for: gap * 3_600 - 600)
            }
        }
        return player
    }

    @Test func theOpeningTakesMinutesNotSeconds() {
        var player = SimulatedPlayer(tapsPerSecond: 3)
        player.play(seconds: 60 * 60)
        let first = MinerID.allCases.prefix(6).map { "\($0.name) \(Int(player.firstBought[$0] ?? -60) / 60)m" }
        print("Opening:", first.joined(separator: ", "))
        // A Chromebook in the first minute and a Desktop a minute or two later; the first GPU Rigs and
        // Servers cost less (`MinerID.openingPriceShares`), so the GPU Rig comes in about ten minutes
        // and a Server in about half an hour, but the Data Center takes more than the first hour.
        #expect(player.firstBought[.chromebook].map { $0 < 60 } == true)
        #expect(player.firstBought[.desktop].map { (60...5 * 60).contains($0) } == true)
        #expect(player.firstBought[.gpuRig].map { $0 > 8 * 60 } == true)
        #expect(player.firstBought[.server].map { $0 > 25 * 60 } == true)
        #expect(player.firstBought[.dataCenter] == nil)
        // Blackjack and Tetris cost a few thousand coins: both arrive in the first 25 minutes (airdrops,
        // from 50,000 coins mined, don't help this early).
        #expect(player.gamesUnlockedAt[.blackjack].map { $0 < 15 * 60 } == true)
        #expect(player.gamesUnlockedAt[.tetris].map { $0 < 25 * 60 } == true)
        // No daily reward or quests on the first day: the only coins counted with them are the
        // starter milestones' rewards, which are capped (900, 1,800, 3,600 and 5,400 coins).
        #expect(player.game.stats.earnedFromDaily <= 900 + 1_800 + 3_600 + 5_400)
        #expect(player.game.daily.streak == 0)
    }

    @Test func anActivePlayerUnlocksSeveralTiersAndGamesInTheFirstSession() {
        var player = SimulatedPlayer(tapsPerSecond: 3)
        player.play(seconds: 3 * 3_600)
        let tiers = MinerID.allCases.map { "\($0.name) \(hours(player.firstBought[$0]))" }
        let games = MiniGame.allCases.sorted { $0.unlockCost < $1.unlockCost }.map { "\($0.name) \(hours(player.gamesUnlockedAt[$0]))" }
        print("Active 3h:", tiers.joined(separator: ", "), "| first point", hours(player.firstPointAt),
              "| income", CoinFormat.short(player.game.baseIdleIncome))
        print("Active 3h games:", games.joined(separator: ", "))
        // A first session should feel rewarding but leave most of the game ahead: a Data Center after
        // more than an hour, six or seven tiers in three hours, and no prestige points yet.
        #expect(player.firstBought[.dataCenter].map { $0 > 3_600 } == true)
        #expect((6...8).contains(player.firstBought.count))
        #expect(player.firstPointAt.map { $0 >= 1.5 * 3_600 } ?? true)
        #expect(player.prestigeTimes.isEmpty)
        // New games keep coming: about half of them in the first three hours, the rest later.
        #expect((5...8).contains(player.gamesUnlockedAt.count))
        // Nobody who stays in the app needs Offline Mining.
        #expect(player.game.offlineMiningLevel == 0)
    }

    @Test func aRelaxedTapperIsNotReadyToPrestigeAfterTheFirstSession() {
        var player = SimulatedPlayer(tapsPerSecond: 1) // Too slow for combos.
        player.catchRate = 0.5
        player.play(seconds: 3 * 3_600)
        print("Relaxed 3h: tiers", player.firstBought.count, "| first point", hours(player.firstPointAt),
              "| games", player.gamesUnlockedAt.count, "| income", CoinFormat.short(player.game.baseIdleIncome))
        #expect((4...7).contains(player.firstBought.count))
        #expect(player.prestigeTimes.isEmpty)
    }

    /// A few short looks over half a day: tapping twice a second, catching half the airdrops and
    /// never playing the arcade.
    @Test func aLightPlayerEarnsTensOfThousandsNotMillionsInTheFirstHalfDay() {
        var player = SimulatedPlayer(tapsPerSecond: 2, awayHours: [2, 3, 3, 3])
        player.catchRate = 0.5
        player.arcadeSecondsPerTen = 0
        for gap in [2.0, 3, 3, 3, 1] {
            player.play(seconds: 240)
            player.leave(for: gap * 3_600 - 240)
        }
        let lifetime = player.game.stats.lifetimeCoins
        print("Light 12h:", CoinFormat.short(lifetime), "mined | tiers", player.firstBought.count,
              "| offline", CoinFormat.duration(player.game.offlineCap))
        // Twenty minutes of play spread over twelve hours: a few miner tiers and some tens of
        // thousands of coins, not millions. The game starts with six minutes away at a tenth of the
        // income, so time away pays little in the first half day: a few minutes more at most.
        #expect((15_000...150_000).contains(lifetime))
        #expect((2...4).contains(player.firstBought.count))
        #expect(player.game.timeAwayLimit <= 10 * 60)
    }

    @Test func aCasualPlayerReachesTheTenthTierAndAPrestigeInAboutTenDays() {
        let player = casualPlayer(days: 14)
        let tiers = MinerID.allCases.map { "\($0.name) \(days(player.firstBought[$0]))" }
        let lastGame = player.gamesUnlockedAt.values.max()
        let starter = StarterMilestone.allCases.map { "\($0.rawValue) \(hours(player.starterClaimedAt[$0]))" }
        print("Casual 14 days:", tiers.joined(separator: ", "), "| first point", days(player.firstPointAt),
              "| prestiges", player.prestigeTimes.map(days), "| every game by", days(lastGame),
              "| points", player.game.prestigePoints, "| offline", CoinFormat.duration(player.game.offlineCap),
              "| efficiency", player.game.powerUpLevel(.offlineEfficiency), "of", PowerUpID.offlineEfficiency.maxLevel,
              "| Immersion Cooling", days(player.firstUpgrade[.immersionCooling]),
              "| starter", starter.joined(separator: ", "))
        // Without steps: the Data Center takes about a day and a half (the Server and the Data Center
        // cost more, and the first production upgrades give less, though the first few Servers cost
        // less, and the arcade pays twice what it did). Time away pays a share of the income
        // now (a tenth to begin with, 5% more a level), so the later tiers come about 40% later
        // than they did when it paid all of it: the first prestige point (15 billion mined) in
        // about five days, the tenth tier in about eight, and the Shop suggests the first prestige
        // at about eight and a half, with two more by the end of the second week (a walker gets
        // there sooner: see the walking test).
        #expect(player.firstBought[.dataCenter].map { (1.2 * 86_400...3 * 86_400).contains($0) } == true)
        #expect(player.firstUpgrade[.immersionCooling].map { (2.5 * 86_400...5.5 * 86_400).contains($0) } == true)
        #expect(player.firstPointAt.map { (4.5 * 86_400...7.5 * 86_400).contains($0) } == true)
        let tenthTier = player.firstBought[.spaceColony]
        #expect(tenthTier.map { (7.5 * 86_400...12 * 86_400).contains($0) } == true)
        #expect(player.firstPrestigeAt.map { (7 * 86_400...11 * 86_400).contains($0) } == true)
        #expect((2...4).contains(player.prestigeTimes.count))
        // Every game within about ten days, and the whole first ladder before the first prestige
        // (which opens the three tiers beyond it).
        #expect(player.gamesUnlockedAt.count == MiniGame.allCases.count)
        #expect(lastGame.map { $0 < 11 * 86_400 } == true)
        #expect(tenthTier.map { $0 <= (player.firstPrestigeAt ?? 0) } == true)
        // Offline Mining covers the longest absence (ten hours) by about the twelfth day, and
        // Offline Efficiency, bought from the first day, is past half of the income by the end.
        #expect(player.game.offlineCap >= 10 * 3_600)
        #expect(player.game.powerUpLevel(.offlineEfficiency) >= 8)
        // Every starter milestone is done and claimed on the first day.
        #expect(player.starterClaimedAt.count == StarterMilestone.allCases.count)
        #expect(player.starterClaimedAt.values.max().map { $0 < 86_400 } == true)
    }

    @Test func offlineMiningGrowsOverTheFirstWeekNotTheFirstDay() {
        let player = casualPlayer(days: 1)
        // The game starts with six minutes away, and the first levels add only a minute each, so
        // the first day ends with about that and a few levels of Offline Efficiency; the hour
        // comes on the third day.
        print("Casual 1 day: time away", CoinFormat.duration(player.game.timeAwayLimit), "| level",
              player.game.offlineMiningLevel, "| efficiency", player.game.powerUpLevel(.offlineEfficiency))
        #expect((6 * 60...2 * 3_600).contains(player.game.timeAwayLimit))
    }

    /// Three weeks of casual play take a while to simulate, so this runs with the balance tests:
    /// `RUN_BALANCE_TESTS=1 swift test --filter PacingTests`.
    @Test func perksKeepComingForAboutThreeWeeks() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let player = casualPlayer(days: 21)
        let perks = PerkID.allCases.sorted { $0.cost < $1.cost }.map { "\($0.name) \(days(player.perksBoughtAt[$0]))" }
        print("Casual 21 days: prestiges", player.prestigeTimes.map(days), "| points", player.game.prestigePoints,
              "| Lunar Base", days(player.firstBought[.lunarBase]), "| Galactic Hashnet", days(player.firstBought[.galacticHashnet]),
              "| perks", perks.joined(separator: ", "))
        // Without steps, about nine prestiges and four or five thousand points in three weeks (the
        // arcade pays twice what it did, and this player plays some every visit): later prestiges
        // wait until they would nearly double production, so each is a bigger jump than the first.
        #expect((6...11).contains(player.prestigeTimes.count))
        #expect((2_000...8_000).contains(player.game.prestigePoints))
        // The cheap perks come with the first prestige, the dearest ones after two weeks or more,
        // and the last miner tier within the three weeks.
        #expect(player.perksBoughtAt[.headStart].map { $0 < 11 * 86_400 } == true)
        #expect(player.firstBought[.lunarBase] != nil)
        #expect(player.firstBought[.galacticHashnet] != nil)
        #expect(player.perksBoughtAt[.engineeringTeam].map { $0 > 14 * 86_400 } ?? true)
        #expect(player.perksBoughtAt[.compoundInterest].map { $0 > 18 * 86_400 } ?? true)
        #expect(player.perksBoughtAt.count >= 8)
    }

    /// A light player for three weeks: two five-minute looks a day (away 10 and 14 hours between),
    /// a tap a second (too slow for combos), half the airdrops caught and no arcade, but the daily
    /// reward and quests claimed: ten minutes a day. The game should still move for them: the
    /// first four tiers in two days, the Data Center in about a week, a new tier every few days
    /// after that, most of the arcade unlocked, and a first prestige point (in about 19 days)
    /// before the three weeks are out. Runs with the balance tests.
    @Test func aLightPlayerKeepsProgressingForThreeWeeks() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let gaps: [Double] = [10, 14]
        var player = SimulatedPlayer(tapsPerSecond: 1, awayHours: gaps, seed: 3)
        player.catchRate = 0.5
        player.arcadeSecondsPerTen = 0
        while player.elapsed < 21 * 86_400 {
            for gap in gaps where player.elapsed < 21 * 86_400 {
                player.play(seconds: 300)
                player.leave(for: gap * 3_600 - 300)
            }
        }
        let tiers = MinerID.allCases.map { "\($0.name) \(days(player.firstBought[$0]))" }
        print("Light 21 days:", tiers.joined(separator: ", "), "| first point", days(player.firstPointAt),
              "| prestiges", player.prestigeTimes.map(days), "| games", player.gamesUnlockedAt.count,
              "| offline", CoinFormat.duration(player.game.timeAwayLimit), "| efficiency", player.game.powerUpLevel(.offlineEfficiency),
              "| income", CoinFormat.short(player.game.baseIdleIncome))
        #expect(player.firstBought[.server].map { $0 < 2.5 * 86_400 } == true)
        #expect(player.firstBought[.dataCenter].map { $0 < 9 * 86_400 } == true)
        #expect(player.firstBought.count >= 7)
        #expect(player.firstPointAt.map { $0 < 21 * 86_400 } == true)
        #expect(player.gamesUnlockedAt.count >= 6)
    }

    /// The casual player again, walking 2,500, 5,000 or 10,000 steps a day. A step pays a twentieth
    /// of a second's income, the first three boosters only make that 3.75 times as much, and the
    /// first day's steps pay a coin each, so the first days' walks pay little and can't race the
    /// opening. The Giga and Mega Step Boosters (×3 each, from about the sixth or seventh day) are
    /// where walking starts to pay, and Proof of Stride (×5, in the second run) makes it pay a lot:
    /// the first prestige comes at about eight days either way, and steps pay about a quarter of
    /// three weeks' coins at 2,500 or 5,000 steps and half at 10,000, with about 10, 12 and 14
    /// prestiges. Runs with the balance tests.
    @Test(arguments: [2_500, 5_000, 10_000]) func walkingPaysLittleEarlyAndMoreLateInARun(steps: Int) {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        // The first three days: steps are a few percent of the coins at most.
        let opening = casualPlayer(days: 3, stepsPerDay: steps).game.stats
        #expect(opening.earnedFromSteps / opening.lifetimeCoins < 0.03)
        let walker = casualPlayer(days: 21, stepsPerDay: steps)
        let stats = walker.game.stats
        let share = stats.earnedFromSteps / stats.lifetimeCoins
        print("Walker \(steps) steps: Data Center", days(walker.firstBought[.dataCenter]), "| first point", days(walker.firstPointAt),
              "| first prestige", days(walker.firstPrestigeAt), "| prestiges", walker.prestigeTimes.count,
              "| points", walker.game.prestigePoints, "| steps paid", String(format: "%.1f%%", share * 100),
              "| first three days", String(format: "%.1f%%", opening.earnedFromSteps / opening.lifetimeCoins * 100),
              "| boosters", UpgradeID.allCases.filter { $0.category == .steps }.map { days(walker.firstUpgrade[$0]) })
        // About eight days, walking or not (see the casual player): close enough.
        let firstPrestige: ClosedRange<Double> = 7.8...8.8
        #expect(walker.firstPrestigeAt.map { firstPrestige.contains($0 / 86_400) } == true)
        #expect((9...15).contains(walker.prestigeTimes.count))
        // Steps pay a real share over three weeks, and never much more than half, even at 10,000.
        #expect(share > Double(steps) / 50_000)
        #expect(share < 0.6)
        // The first two boosters in the first four days and the third in about five;
        // the Giga Step Booster about the seventh day; the Mega Step Booster, in the trillions, about
        // the end of the first run or early in the second, and Proof of Stride, the biggest, at 100 trillion, in the second.
        #expect([UpgradeID.stepBooster, .upgradedStepBooster].allSatisfy { walker.firstUpgrade[$0].map { $0 < 4 * 86_400 } == true })
        #expect(walker.firstUpgrade[.ultimateStepBooster].map { (4.5 * 86_400...6 * 86_400).contains($0) } == true)
        #expect(walker.firstUpgrade[.gigaStepBooster].map { (6 * 86_400...8 * 86_400).contains($0) } == true)
        #expect(walker.firstUpgrade[.megaStepBooster].map { (7 * 86_400...10.75 * 86_400).contains($0) } == true)
        #expect(walker.firstUpgrade[.proofOfStride].map { (10 * 86_400...13.5 * 86_400).contains($0) } == true)
    }

    @Test func offlineUpgradesAreEarnedOverTheFirstDaysNotTheFirstHalfHour() {
        var player = SimulatedPlayer(tapsPerSecond: 3, awayHours: [3, 4, 5, 10])
        player.play(seconds: 60)
        #expect(player.game.offlineMiningLevel == 0) // Not affordable in the first minute.
        #expect(player.game.powerUpLevel(.offlineEfficiency) == 0)
        player.play(seconds: 29 * 60)
        // Six minutes away at a tenth of the income pay so little that a miner pays back far
        // sooner: Offline Mining and Offline Efficiency wait for the first days (see the casual
        // player), though either can be bought from the first minute.
        #expect(player.game.offlineMiningLevel == 0)
        #expect(player.game.powerUpLevel(.offlineEfficiency) == 0)
        // The starter milestones are another matter: the Chromebook, three miners and the first
        // game unlocked are done and claimed in the first minutes.
        #expect(player.starterClaimedAt[.firstChromebook].map { $0 < 5 * 60 } == true)
        #expect(player.starterClaimedAt[.threeMiners].map { $0 < 15 * 60 } == true)
        #expect(player.starterClaimedAt[.firstGameUnlocked].map { $0 < 30 * 60 } == true)
    }

    @Test func tapsStayWorthHavingAllGameLong() {
        // An hour in, three taps a second add a fifth or more to idle income (the Mechanical
        // Keyboard, which makes taps count for more, comes a little later now)...
        var early = SimulatedPlayer(tapsPerSecond: 3)
        early.play(seconds: 60 * 60)
        let earlyGame = early.game
        #expect(3 * earlyGame.tapValue(at: early.now) >= 0.2 * earlyGame.baseIdleIncome)
        // ...and days in, a single tap is worth a good part of a second of production.
        var late = SimulatedPlayer(tapsPerSecond: 3, awayHours: [3, 4, 5, 10])
        late.prestigesWhenSuggested = false
        for _ in 0..<5 {
            for gap in [3.0, 4, 5, 10] {
                late.play(seconds: 600)
                late.leave(for: gap * 3_600 - 600)
            }
        }
        // (Three of the five tapping upgrades by then, 40%: the Haptic Engine and Satoshi's Touch
        // come later. Automatic taps, now worth half a tap, are part of idle income, so three taps a
        // second still add most of it again.)
        #expect(late.game.tapValue(at: late.now) >= 0.35 * late.game.baseProduction)
        #expect(3 * late.game.tapValue(at: late.now) >= 0.75 * late.game.baseIdleIncome)
    }
}
