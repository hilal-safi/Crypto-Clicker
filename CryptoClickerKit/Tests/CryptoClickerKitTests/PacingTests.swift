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
    private(set) var firstBought: [MinerID: TimeInterval] = [:]
    private(set) var firstUpgrade: [UpgradeID: TimeInterval] = [:]
    /// Each power-up level bought: which, the level, and when.
    private(set) var powerUpsBought: [(powerUp: PowerUpID, level: Int, at: TimeInterval)] = []
    /// Chromebooks owned when the first Desktop was bought, and Desktops at the first GPU Rig.
    private(set) var chromebooksAtFirstDesktop: Int?
    private(set) var desktopsAtFirstGPU: Int?
    private(set) var gamesUnlockedAt: [MiniGame: TimeInterval] = [:]
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
            }
            notePrestige()
        }
        game.refreshAchievements()
    }

    mutating func leave(for seconds: TimeInterval) {
        now += seconds
        game.advance(to: now)
        game.refreshAchievements()
        shop()
        notePrestige()
    }

    /// Today's quests, challenge and daily reward (from the second day on).
    private mutating func dailies() {
        let today = dayKey(0)
        game.refreshDaily(today: today, canWalk: false, at: now)
        game.claimDailyReward(today: today, yesterday: dayKey(-1), at: now)
        for quest in game.daily.quests where !quest.isClaimed && game.isComplete(quest) {
            game.claimQuest(quest.id, at: now)
        }
    }

    /// An average player's arcade game: about 45 seconds of income per minute played, paid
    /// through the game's own reward, so quests and challenges count it.
    private mutating func playArcade(minutes: Double) {
        let games = MiniGame.allCases.filter { !$0.isCasino && game.isUnlocked($0) }
        guard let pick = games.randomElement(using: &rng) else { return }
        let points = max(1, Int(45 * minutes / pick.secondsPerPoint / game.miniGameMultiplier))
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
        let current = max(GameState.offlineCap(level: game.offlineMiningLevel), Tuning.awayThreshold)
        let next = GameState.offlineCap(level: game.offlineMiningLevel + 1)
        let extra = awayHours.reduce(0.0) { $0 + min($1 * 3_600, next) - min($1 * 3_600, current) }
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
                case .steps: continue
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
    /// have passed.
    func casualPlayer(days: Int) -> SimulatedPlayer {
        let gaps: [Double] = [3, 4, 5, 10]
        var player = SimulatedPlayer(tapsPerSecond: 3, awayHours: gaps)
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
        // A Chromebook in the first minute and a Desktop a minute or two later, but the GPU Rig takes
        // about ten minutes, a Server about half an hour, and the Data Center more than the first hour.
        #expect(player.firstBought[.chromebook].map { $0 < 60 } == true)
        #expect(player.firstBought[.desktop].map { (60...5 * 60).contains($0) } == true)
        #expect(player.firstBought[.gpuRig].map { $0 > 8 * 60 } == true)
        #expect(player.firstBought[.server].map { $0 > 25 * 60 } == true)
        #expect(player.firstBought[.dataCenter] == nil)
        // Blackjack and Tetris cost a few thousand coins: both arrive in the first 25 minutes (airdrops,
        // from 50,000 coins mined, don't help this early).
        #expect(player.gamesUnlockedAt[.blackjack].map { $0 < 15 * 60 } == true)
        #expect(player.gamesUnlockedAt[.tetris].map { $0 < 25 * 60 } == true)
        // No daily reward or quests on the first day.
        #expect(player.game.stats.earnedFromDaily == 0)
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
        // New games keep coming: more than half of them in the first three hours, the rest later.
        #expect((6...9).contains(player.gamesUnlockedAt.count))
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
        // thousands of coins, not millions. Offline Mining starts at a minute a level, so time away
        // pays little in the first half day: a few minutes at most.
        #expect((15_000...150_000).contains(lifetime))
        #expect((2...4).contains(player.firstBought.count))
        #expect(player.game.offlineCap <= 10 * 60)
    }

    @Test func aCasualPlayerReachesTheTenthTierAndAPrestigeInAboutAWeek() {
        let player = casualPlayer(days: 8)
        let tiers = MinerID.allCases.map { "\($0.name) \(days(player.firstBought[$0]))" }
        let lastGame = player.gamesUnlockedAt.values.max()
        print("Casual 8 days:", tiers.joined(separator: ", "), "| first point", days(player.firstPointAt),
              "| prestiges", player.prestigeTimes.map(days), "| every game by", days(lastGame),
              "| points", player.game.prestigePoints, "| offline", CoinFormat.duration(player.game.offlineCap))
        // The Data Center takes a day or more, and the middle of the climb about twice as long as
        // the start: the first prestige point (15 billion mined) comes around day three, the tenth
        // tier in about six days, and the Shop suggests the first prestige within the week.
        #expect(player.firstBought[.dataCenter].map { (1 * 86_400...2 * 86_400).contains($0) } == true)
        #expect(player.firstPointAt.map { (2 * 86_400...3.5 * 86_400).contains($0) } == true)
        let tenthTier = player.firstBought[.spaceColony]
        #expect(tenthTier.map { (5 * 86_400...7 * 86_400).contains($0) } == true)
        #expect(player.firstPrestigeAt.map { (5.5 * 86_400...7.25 * 86_400).contains($0) } == true)
        #expect((1...2).contains(player.prestigeTimes.count))
        // Every game within the week, and the whole first ladder before the first prestige (which
        // opens the three tiers beyond it).
        #expect(player.gamesUnlockedAt.count == MiniGame.allCases.count)
        #expect(lastGame.map { $0 < 7 * 86_400 } == true)
        #expect(tenthTier.map { $0 <= (player.firstPrestigeAt ?? 0) } == true)
        // Offline Mining covers the longest absence (ten hours) within the first week.
        #expect(player.game.offlineCap >= 10 * 3_600)
    }

    @Test func offlineMiningGrowsOverTheFirstWeekNotTheFirstDay() {
        let player = casualPlayer(days: 1)
        // Five minutes a level up to the hour: most of an hour by the end of the first day, so the
        // first nights pay only part of the time away.
        print("Casual 1 day: offline", CoinFormat.duration(player.game.offlineCap), "| level", player.game.offlineMiningLevel)
        #expect((30 * 60...2 * 3_600).contains(player.game.offlineCap))
    }

    /// Three weeks of casual play take a while to simulate, so this runs with the balance tests:
    /// `RUN_BALANCE_TESTS=1 swift test --filter PacingTests`.
    @Test func perksKeepComingForAboutThreeWeeks() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let player = casualPlayer(days: 21)
        let perks = PerkID.allCases.sorted { $0.cost < $1.cost }.map { "\($0.name) \(days(player.perksBoughtAt[$0]))" }
        print("Casual 21 days: prestiges", player.prestigeTimes.count, "| points", player.game.prestigePoints,
              "| Lunar Base", days(player.firstBought[.lunarBase]), "| Galactic Hashnet", days(player.firstBought[.galacticHashnet]),
              "| perks", perks.joined(separator: ", "))
        // The cheap perks come with the first prestige, the dearest ones after two weeks or more,
        // and the last miner tier within the three weeks.
        #expect(player.perksBoughtAt[.headStart].map { $0 < 7.5 * 86_400 } == true)
        #expect(player.firstBought[.lunarBase] != nil)
        #expect(player.firstBought[.galacticHashnet] != nil)
        #expect(player.perksBoughtAt[.engineeringTeam].map { $0 > 14 * 86_400 } ?? true)
        #expect(player.perksBoughtAt[.compoundInterest].map { $0 > 18 * 86_400 } ?? true)
        #expect(player.perksBoughtAt.count >= 13)
    }

    @Test func offlineMiningIsEarnedInTheFirstSessionsNotGivenAtTheStart() {
        var player = SimulatedPlayer(tapsPerSecond: 3, awayHours: [3, 4, 5, 10])
        player.play(seconds: 60)
        #expect(player.game.offlineMiningLevel == 0) // Not affordable in the first minute.
        player.play(seconds: 29 * 60)
        #expect(player.game.offlineMiningLevel >= 1) // Bought in the first half hour of play.
    }

    @Test func tapsStayWorthHavingAllGameLong() {
        // An hour in, three taps a second add more than half again to idle income...
        var early = SimulatedPlayer(tapsPerSecond: 3)
        early.play(seconds: 60 * 60)
        let earlyGame = early.game
        #expect(3 * earlyGame.tapValue(at: early.now) >= 0.5 * earlyGame.baseIdleIncome)
        // ...and days in, a single tap is worth most of a second of production.
        var late = SimulatedPlayer(tapsPerSecond: 3, awayHours: [3, 4, 5, 10])
        late.prestigesWhenSuggested = false
        for _ in 0..<5 {
            for gap in [3.0, 4, 5, 10] {
                late.play(seconds: 600)
                late.leave(for: gap * 3_600 - 600)
            }
        }
        // (Four of the five tapping upgrades by then, 65%: Satoshi's Touch comes later.)
        #expect(late.game.tapValue(at: late.now) >= 0.6 * late.game.baseProduction)
        #expect(3 * late.game.tapValue(at: late.now) >= late.game.baseIdleIncome)
    }
}
