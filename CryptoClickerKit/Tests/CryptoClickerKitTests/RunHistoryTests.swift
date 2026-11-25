import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Run history")
struct RunHistoryTests {
    /// A first run, started at `t0`, that has mined `coins` with a few miners.
    func run(mining coins: Double = 1e13) -> GameState {
        var game = GameState.make(miners: [.chromebook: 3, .gpuRig: 2])
        game.stats.lifetimeCoins = coins
        game.stats.runCoins = coins
        return game
    }

    @Test func aPrestigeRecordsTheRunItEnds() throws {
        var game = run()
        let income = game.baseIdleIncome
        let first = game.prestige(at: at(86_400))
        #expect(first > 0)
        let record = try #require(game.runHistory.last)
        #expect(game.runHistory.count == 1)
        #expect(record.number == 1)
        #expect(record.startedAt == t0 && record.endedAt == at(86_400) && record.duration == 86_400)
        #expect(record.coins == 1e13 && record.points == first && record.totalPoints == first)
        #expect(record.income == income && record.tiers == 2)
        #expect(game.stats.bestRunPoints == first)
        #expect(game.stats.quickRuns == 1) // A day: within two.

        // A second run of three days, mining a hundred times as much.
        game.stats.lifetimeCoins = 1e15
        game.stats.runCoins = 1e15 - 1e13
        game.miners = [.chromebook: 1]
        let second = game.prestige(at: at(4 * 86_400))
        #expect(second > first)
        #expect(game.runHistory.map(\.number) == [1, 2])
        #expect(game.runHistory[1].duration == 3 * 86_400)
        #expect(game.runHistory[1].totalPoints == first + second && game.runHistory[1].tiers == 1)
        #expect(game.stats.quickRuns == 1) // Three days: not quick.
        #expect(game.stats.bestRunPoints == second)
        #expect(game.fastestRun?.number == 1 && game.biggestRun?.number == 2 && game.richestRun?.number == 2)
        // The first run ended with five miners, the second with one Chromebook: the first earned more.
        #expect(game.mostProductiveRun?.number == 1)
    }

    /// Runs before the first recorded one (prestiges from before version 2.1) keep their numbers.
    @Test func runsAreNumberedByPrestige() {
        var game = run()
        game.stats.prestiges = 7
        game.prestige(at: at(86_400))
        #expect(game.runHistory.map(\.number) == [8])
    }

    @Test func theHistoryKeepsTheLatestRuns() {
        var game = run()
        game.runHistory = (1...Tuning.runHistoryLimit).map { number in
            RunRecord(number: number, startedAt: t0, endedAt: t0, coins: 1, points: 1, totalPoints: number,
                      income: 1, tiers: 1)
        }
        game.stats.prestiges = Tuning.runHistoryLimit
        game.prestige(at: at(60))
        #expect(game.runHistory.count == Tuning.runHistoryLimit)
        #expect(game.runHistory.first?.number == 2 && game.runHistory.last?.number == Tuning.runHistoryLimit + 1)
    }

    @Test func theHistorySurvivesASave() throws {
        var game = run()
        game.prestige(at: at(86_400))
        let decoded = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(decoded.runHistory == game.runHistory)
        #expect(decoded.stats.bestRunPoints == game.stats.bestRunPoints && decoded.stats.quickRuns == 1)
        // A new game saves no history, and a longer one than the limit loads as its latest runs.
        let fresh = try GameCoding.encoder().encode(GameState.make())
        #expect(String(decoding: fresh, as: UTF8.self).contains("runHistory") == false)
        var long = game
        long.runHistory = (1...Tuning.runHistoryLimit + 5).map { number in
            RunRecord(number: number, startedAt: t0, endedAt: t0, coins: 1, points: 1, totalPoints: number,
                      income: 1, tiers: 1)
        }
        let trimmed = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(long))
        #expect(trimmed.runHistory.count == Tuning.runHistoryLimit && trimmed.runHistory.first?.number == 6)
    }

    @Test func bigAndQuickRunsEarnAchievements() {
        var game = run(mining: 1e14)
        let points = game.prestige(at: at(86_400))
        #expect(points >= 10)
        let earned = game.refreshAchievements().map(\.achievement.id)
        #expect(earned.contains("big-run") && earned.contains("speedrunner"))
        #expect(game.value(of: .bestRunPoints) == Double(points) && game.value(of: .quickRuns) == 1)
    }

    @Test func prestigesUnlockFiveFinishes() {
        #expect(CoinFinish.prestigeMilestones == [1, 5, 10, 25, 50])
        #expect(!CoinFinish.forged.isUnlocked(stars: 1_000, prestiges: 0))
        #expect(CoinFinish.forged.isUnlocked(stars: 0, prestiges: 1))
        #expect(!CoinFinish.nebula.isUnlocked(stars: 0, prestiges: 24) && CoinFinish.nebula.isUnlocked(stars: 0, prestiges: 25))
        // The others still need stars, whatever the prestiges.
        #expect(!CoinFinish.silver.isUnlocked(stars: 4, prestiges: 100) && CoinFinish.silver.isUnlocked(stars: 5, prestiges: 0))
        #expect(CoinFinish.forged.requirement == "1 prestige" && CoinFinish.platinum.requirement == "5 prestiges")
        #expect(CoinFinish.roseGold.requirement == "15 stars")
        #expect(!CoinFinish.aurora.isUnlocked(stars: 1_000, prestiges: 49) && CoinFinish.aurora.isUnlocked(stars: 0, prestiges: 50))
        // The game's own check counts its stars and prestiges.
        var game = GameState.make()
        #expect(game.isUnlocked(.gold) && !game.isUnlocked(.silver) && !game.isUnlocked(.forged))
        game.debugCountPrestiges(5)
        #expect(game.isUnlocked(.forged) && game.isUnlocked(.platinum) && !game.isUnlocked(.ruby))
    }
}

@Suite("Shop details")
struct ShopDetailTests {
    @Test func anUpgradesIncomeGainIsWhatItAddsToIdleIncome() {
        var game = GameState.make(miners: minersEarning(10))
        #expect(approx(game.incomeGain(of: .overclocking), 2.5)) // Production x1.25.
        // Taps add nothing to idle income without automatic taps, and an owned upgrade adds nothing.
        #expect(game.incomeGain(of: .coinClicker) == 0)
        game.upgrades.insert(.overclocking)
        #expect(game.incomeGain(of: .overclocking) == 0)
    }

    @Test func tapUpgradesAddToTheTap() {
        let game = GameState.make(miners: minersEarning(10))
        #expect(approx(game.tapGain(of: .coinClicker), 1)) // +1 flat a tap.
        #expect(game.tapGain(of: .overclocking) >= 0)
    }

    @Test func paybackIsThePriceOverTheGain() {
        #expect(GameState.payback(price: 100, gain: 4) == 25)
        #expect(GameState.payback(price: 100, gain: 0) == nil)
        #expect(GameState.payback(price: .infinity, gain: 1) == nil)
    }
}

@Suite("Portfolio")
struct PortfolioTests {
    @Test func purchasesKeepWhatTheTokensCost() throws {
        var game = GameState.make(coins: 1e9)
        let first = game.price(of: .shibaInu, quantity: 5, at: at(0))
        #expect(game.buyTokens(.shibaInu, quantity: 5, at: at(0)) == true)
        let later = at(3 * 86_400) // Prices move every five minutes.
        let second = game.price(of: .shibaInu, quantity: 3, at: later)
        #expect(game.buyTokens(.shibaInu, quantity: 3, at: later) == true)
        #expect(approx(game.stats.totalCoinsSpentOnTokens, first + second))
        let average = try #require(game.stats.averagePricePaid(.shibaInu))
        #expect(approx(average, (first + second) / 8))
        #expect(game.stats.averagePricePaid(.bitcoin) == nil)
        // A refused purchase changes nothing, and selling keeps the average.
        #expect(game.buyTokens(.shibaInu, quantity: 0, at: later) == false)
        #expect(game.sellTokens(.shibaInu, quantity: 4, at: later) != nil)
        #expect(game.stats.averagePricePaid(.shibaInu) == average)
        // Kept through a save.
        let decoded = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(decoded.stats.coinsSpentOnTokens == game.stats.coinsSpentOnTokens)
        #expect(decoded.stats.tokensBoughtWithPrice == game.stats.tokensBoughtWithPrice)
    }

    @Test func aGameIsPlayedOnceItHasAnyRecord() {
        var game = GameState.make()
        #expect(!game.hasPlayed(.tetris) && !game.hasPlayed(.slots))
        game.finishTetris(score: 100, lines: 1, rewardPoints: 100)
        #expect(game.hasPlayed(.tetris) && !game.hasPlayed(.snake))
    }
}
