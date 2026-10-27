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
    private(set) var gamesUnlockedAt: [MiniGame: TimeInterval] = [:]
    private(set) var firstPointAt: TimeInterval?
    private(set) var prestigeTimes: [TimeInterval] = []
    private(set) var perksBoughtAt: [PerkID: TimeInterval] = [:]
    /// Seconds spent playing.
    private(set) var played: TimeInterval = 0
    private var nextAirdrop: TimeInterval = 0

    init(tapsPerSecond: Int, awayHours: [Double] = []) {
        self.tapsPerSecond = tapsPerSecond
        self.awayHours = awayHours
        nextAirdrop = Double.random(in: Tuning.airdropInterval, using: &rng)
    }

    var elapsed: TimeInterval { now.timeIntervalSince(t0) }
    var firstPrestigeAt: TimeInterval? { prestigeTimes.first }

    /// The day `offset` days from now, as a key in the time zone the game uses.
    func dayKey(_ offset: Int) -> String {
        StepDay.key(for: now.addingTimeInterval(Double(offset) * 86_400))
    }

    /// Income as the player experiences it while playing.
    func income(_ state: GameState) -> Double {
        state.baseIdleIncome + Double(tapsPerSecond) * state.tapValue(at: now)
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
                streak = 1 / Double(tapsPerSecond) <= Tuning.comboWindow ? streak + tapsPerSecond : 1
                game.tap(count: tapsPerSecond, at: now, combo: streak)
            } else if second == seconds - 1 {
                playArcade(minutes: Double(inArcade) / 60)
            }
            if played >= nextAirdrop {
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
        let current = GameState.offlineCap(level: game.offlineMiningLevel)
        let next = GameState.offlineCap(level: game.offlineMiningLevel + 1)
        let extra = awayHours.reduce(0.0) { $0 + min($1 * 3_600, next) - min($1 * 3_600, current) }
        return game.baseIdleIncome * extra / (600 * Double(awayHours.count))
    }

    private mutating func shop() {
        if saveForGames() { return }
        while true {
            let current = max(income(game), 1e-9)
            let coins = game.coins
            var best: (score: Double, apply: (inout GameState) -> Bool, miner: MinerID?, upgrade: UpgradeID?)?
            func consider(cost: Double, gain: Double, miner: MinerID? = nil, upgrade: UpgradeID? = nil,
                          _ apply: @escaping (inout GameState) -> Bool) {
                guard gain > 0 else { return }
                let score = max(0, (cost - coins) / current) + cost / gain
                if score < best?.score ?? .infinity { best = (score, apply, miner, upgrade) }
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
            guard let best, best.apply(&game) else { return }
            if let miner = best.miner, firstBought[miner] == nil { firstBought[miner] = elapsed }
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

    /// Four ten-minute check-ins a day, `days` days in a row.
    func casualPlayer(days: Int) -> SimulatedPlayer {
        let gaps: [Double] = [3, 4, 5, 10]
        var player = SimulatedPlayer(tapsPerSecond: 3, awayHours: gaps)
        for _ in 0..<days {
            for gap in gaps {
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
        // A Chromebook in the first minute and a Desktop soon after, but the GPU Rig takes a few
        // minutes, a Server ten or more, and the Data Center most of half an hour.
        #expect(player.firstBought[.chromebook].map { $0 < 60 } == true)
        #expect(player.firstBought[.desktop].map { $0 < 4 * 60 } == true)
        #expect(player.firstBought[.gpuRig].map { $0 > 3 * 60 } == true)
        #expect(player.firstBought[.server].map { $0 > 10 * 60 } == true)
        #expect(player.firstBought[.dataCenter].map { (20 * 60...50 * 60).contains($0) } == true)
        // Blackjack and Tetris cost a few thousand coins: both arrive in the first quarter hour.
        #expect(player.gamesUnlockedAt[.blackjack].map { $0 < 15 * 60 } == true)
        #expect(player.gamesUnlockedAt[.tetris].map { $0 < 15 * 60 } == true)
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
        // A first session should feel rewarding but leave the game ahead: prestige points start
        // to build, but prestiging isn't worth it yet and the last tiers are still to come.
        #expect((7...9).contains(player.firstBought.count))
        #expect(player.firstPointAt.map { $0 >= 1.5 * 3_600 } ?? true)
        #expect(player.prestigeTimes.isEmpty)
        // New games keep coming: most of them in the first three hours, the last few later.
        #expect((8...10).contains(player.gamesUnlockedAt.count))
        // Nobody who stays in the app needs Offline Mining.
        #expect(player.game.offlineMiningLevel == 0)
    }

    @Test func aRelaxedTapperIsNotReadyToPrestigeAfterTheFirstSession() {
        var player = SimulatedPlayer(tapsPerSecond: 1) // Too slow for combos.
        player.catchRate = 0.5
        player.play(seconds: 3 * 3_600)
        print("Relaxed 3h: tiers", player.firstBought.count, "| first point", hours(player.firstPointAt),
              "| games", player.gamesUnlockedAt.count, "| income", CoinFormat.short(player.game.baseIdleIncome))
        #expect((5...8).contains(player.firstBought.count))
        #expect(player.prestigeTimes.isEmpty)
    }

    @Test func aCasualPlayerReachesEveryTierAndAPrestigeWithinDays() {
        let player = casualPlayer(days: 5)
        let tiers = MinerID.allCases.map { "\($0.name) \(days(player.firstBought[$0]))" }
        let lastGame = player.gamesUnlockedAt.values.max()
        print("Casual 5 days:", tiers.joined(separator: ", "), "| prestiges", player.prestigeTimes.map(days),
              "| every game by", days(lastGame), "| points", player.game.prestigePoints,
              "| offline", CoinFormat.duration(player.game.offlineCap))
        // The first ten tiers take a day or two, and the Shop suggests the first prestige soon after.
        let tenthTier = player.firstBought[.spaceColony]
        #expect(tenthTier.map { (1 * 86_400...3 * 86_400).contains($0) } == true)
        #expect(player.firstPrestigeAt.map { (1.25 * 86_400...3 * 86_400).contains($0) } == true)
        #expect((3...7).contains(player.prestigeTimes.count))
        // Every game by about the second day, and the extra tiers after the first prestiges.
        #expect(player.gamesUnlockedAt.count == MiniGame.allCases.count)
        #expect(lastGame.map { $0 < 2.5 * 86_400 } == true)
        #expect(player.firstBought[.galacticHashnet] != nil)
        // Offline Mining covers the longest absence (ten hours) by the end of the first day.
        #expect(player.game.offlineCap >= 10 * 3_600)
    }

    /// Two weeks of casual play take a while to simulate, so this runs with the balance tests:
    /// `RUN_BALANCE_TESTS=1 swift test --filter PacingTests`.
    @Test func perksKeepComingForAboutTwoWeeks() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let player = casualPlayer(days: 14)
        let perks = PerkID.allCases.sorted { $0.cost < $1.cost }.map { "\($0.name) \(days(player.perksBoughtAt[$0]))" }
        print("Casual 14 days: prestiges", player.prestigeTimes.count, "| points", player.game.prestigePoints,
              "| perks", perks.joined(separator: ", "))
        // The cheap perks come with the first prestiges, the dearest ones after more than a week.
        #expect(player.perksBoughtAt[.headStart].map { $0 < 3 * 86_400 } == true)
        #expect(player.perksBoughtAt[.engineeringTeam].map { $0 > 7 * 86_400 } ?? true)
        #expect(player.perksBoughtAt[.compoundInterest].map { $0 > 10 * 86_400 } ?? true)
        #expect(player.perksBoughtAt.count >= 12)
    }

    @Test func offlineMiningIsEarnedInTheFirstSessionNotGivenAtTheStart() {
        var player = SimulatedPlayer(tapsPerSecond: 3, awayHours: [3, 4, 5, 10])
        player.play(seconds: 60)
        #expect(player.game.offlineMiningLevel == 0) // Not affordable in the first minute.
        player.play(seconds: 540)
        #expect(player.game.offlineMiningLevel >= 1) // Bought before the first break.
    }

    @Test func tapsStayWorthHavingAllGameLong() {
        // Half an hour in, three taps a second add more than half again to idle income...
        var early = SimulatedPlayer(tapsPerSecond: 3)
        early.play(seconds: 30 * 60)
        let earlyGame = early.game
        #expect(3 * earlyGame.tapValue(at: early.now) >= 0.5 * earlyGame.baseIdleIncome)
        // ...and days in, a single tap is worth most of a second of production.
        var late = SimulatedPlayer(tapsPerSecond: 3, awayHours: [3, 4, 5, 10])
        late.prestigesWhenSuggested = false
        for _ in 0..<3 {
            for gap in [3.0, 4, 5, 10] {
                late.play(seconds: 600)
                late.leave(for: gap * 3_600 - 600)
            }
        }
        #expect(late.game.tapValue(at: late.now) >= 0.75 * late.game.baseProduction)
        #expect(3 * late.game.tapValue(at: late.now) >= late.game.baseIdleIncome)
    }
}
