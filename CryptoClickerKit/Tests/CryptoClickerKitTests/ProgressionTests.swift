import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Hard Fork")
struct PrestigeTests {
    func state(lifetime: Double) -> GameState {
        var state = GameState.make(coins: 5e9, miners: [.server: 40], upgrades: [.coinClicker])
        state.stats.lifetimeCoins = lifetime
        state.stats.runCoins = lifetime
        return state
    }

    @Test func forkPointsGrowWithTheCubeRootOfLifetimeCoins() {
        #expect(state(lifetime: 0).forkPoints == 0)
        #expect(state(lifetime: 1e10 - 1).forkPoints == 0)
        #expect(state(lifetime: 1e10).forkPoints == 1)
        #expect(state(lifetime: 8e10).forkPoints == 2)
        #expect(state(lifetime: 2.7e11).forkPoints == 3)
        #expect(state(lifetime: 1e13).forkPoints == 10)
        #expect(state(lifetime: 1e10 * 0x1p60).forkPoints == 1_048_576) // Exactly (2^20)^3 points' worth.
        #expect(state(lifetime: 1e40).forkPoints == Tuning.maxForkPoints)
        #expect(state(lifetime: .infinity).forkPoints == 0)
        #expect(state(lifetime: 1e300).forkPoints == Tuning.maxForkPoints)
        #expect(state(lifetime: -5).forkPoints == 0)
    }

    @Test func nextForkPoint() {
        #expect(state(lifetime: 0).nextForkPointAt == 1e10)
        #expect(state(lifetime: 9e10).nextForkPointAt == 27e10)
    }

    @Test func difficultyChangesTheForkReward() {
        var normal = state(lifetime: 8e10)
        #expect(normal.claimableForks == 2)
        normal.runForkMultiplier = Difficulty.hard.forkMultiplier
        #expect(normal.claimableForks == 3)
        normal.runForkMultiplier = Difficulty.easy.forkMultiplier
        #expect(normal.claimableForks == 1)
    }

    @Test func forkingResetsTheRunAndKeepsTheRest() {
        var game = state(lifetime: 8e10)
        game.tokens = [.dogecoin: 3]
        game.unlockedGames = [.blackjack]
        game.achievementTiers = ["miner": 3]
        game.boost = Boost(multiplier: 7, endsAt: at(60))
        game.difficulty = .hard
        let gained = game.hardFork(at: at(100))
        #expect(gained == 2)
        #expect(game.forks == 2)
        #expect(game.forkPointsClaimed == 2)
        #expect(game.coins == 0)
        #expect(game.miners.isEmpty)
        #expect(game.upgrades.isEmpty)
        #expect(game.boost == nil)
        #expect(game.stats.runCoins == 0)
        #expect(game.stats.lifetimeCoins == 8e10)
        #expect(game.stats.forksPerformed == 1)
        #expect(game.tokens == [.dogecoin: 3])
        #expect(game.unlockedGames == [.blackjack])
        #expect(game.achievementTiers == ["miner": 3])
        #expect(game.runForkMultiplier == 1.5)
        #expect(game.runStart == at(100))
        #expect(game.lastUpdate == at(100))
        #expect(approx(game.forkBonus, 1.04))
        // Nothing new to claim straight away.
        #expect(game.claimableForks == 0)
        #expect(game.hardFork(at: at(200)) == 0)
        #expect(game.forks == 2)
    }

    @Test func forkingWithNothingToClaimChangesNothing() {
        var game = state(lifetime: 5e9)
        let before = game
        #expect(game.hardFork(at: at(10)) == 0)
        #expect(game == before)
    }

    @Test func onlyNewPointsCountAfterAFork() {
        var game = state(lifetime: 1e10)
        #expect(game.hardFork(at: t0) == 1)
        game.stats.lifetimeCoins = 8e10
        #expect(game.claimableForks == 1)
        game.stats.lifetimeCoins = 2.7e11
        #expect(game.claimableForks == 2)
    }
}

@Suite("Difficulty")
struct DifficultyTests {
    @Test func aFreshRunTakesTheNewForkMultiplier() {
        var game = GameState.make()
        game.setDifficulty(.hard)
        #expect(game.difficulty == .hard)
        #expect(game.runForkMultiplier == 1.5)
        game.setDifficulty(.easy)
        #expect(game.runForkMultiplier == 0.5)
        game.setDifficulty(.normal)
        #expect(game.runForkMultiplier == 1)
    }

    @Test func midRunChangesNeverRaiseTheForkMultiplier() {
        var game = GameState.make(miners: [.chromebook: 1])
        game.setDifficulty(.easy)
        #expect(game.runForkMultiplier == 0.5)
        game.setDifficulty(.hard)
        #expect(game.difficulty == .hard)
        #expect(game.runForkMultiplier == 0.5)
    }

    @Test func earningsAloneAlsoLockTheMultiplier() {
        var game = GameState.make()
        game.stats.runCoins = 5_000
        game.setDifficulty(.hard)
        #expect(game.runForkMultiplier == 1)
    }

    @Test func aForkStartsTheNextRunAtTheCurrentDifficulty() {
        var game = GameState.make(miners: [.chromebook: 1])
        game.setDifficulty(.easy)
        game.setDifficulty(.hard)
        game.stats.lifetimeCoins = 1e12
        game.hardFork(at: t0)
        #expect(game.runForkMultiplier == 1.5)
    }
}

@Suite("Airdrops")
struct AirdropTests {
    @Test func aLowRollStartsABullRun() {
        var game = GameState.make(miners: [.desktop: 10])
        let reward = game.claimAirdrop(roll: 0.1, at: at(5))
        #expect(reward == .bullRun(multiplier: 7, duration: 60))
        #expect(game.boost == Boost(multiplier: 7, endsAt: at(65)))
        #expect(game.stats.airdrops == 1)
        #expect(approx(game.production(at: at(10)), 140))
    }

    @Test func bullRunsNeverShortenARunningBoost() {
        var game = GameState.make()
        game.boost = Boost(multiplier: 7, endsAt: at(100))
        game.claimAirdrop(roll: 0, at: at(10))
        #expect(game.boost?.endsAt == at(100))
        game.claimAirdrop(roll: 0, at: at(90))
        #expect(game.boost?.endsAt == at(150))
    }

    @Test func coinDropsPayAShareOfTheBankWithinIncomeLimits() {
        var rich = GameState.make(coins: 1e6, miners: [.desktop: 5]) // 10 coins per second.
        #expect(rich.claimAirdrop(roll: 0.5, at: t0) == .coins(9_000)) // Capped at 15 minutes of income.
        #expect(rich.coins == 1e6 + 9_000)
        #expect(rich.stats.earnedFromAirdrops == 9_000)

        var saver = GameState.make(coins: 20_000, miners: [.desktop: 5])
        #expect(saver.claimAirdrop(roll: 0.99, at: t0) == .coins(3_000)) // 15% of the bank.

        var broke = GameState.make(coins: 100, miners: [.desktop: 5])
        #expect(broke.claimAirdrop(roll: 0.3, at: t0) == .coins(300)) // At least 30 seconds of income.
    }
}

@Suite("Achievements")
struct AchievementTests {
    @Test func catalogIsWellFormed() {
        let all = AchievementCatalog.all
        #expect(all.count == 37)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(AchievementCatalog.tierCount == 111)
        for achievement in all {
            #expect(achievement.thresholds.count == 3)
            #expect(achievement.thresholds == achievement.thresholds.sorted())
            #expect(Set(achievement.thresholds).count == 3)
            #expect((achievement.emoji == nil) != (achievement.imageName == nil))
        }
        #expect(all.first { $0.id == "upgrader" }?.thresholds.last == 20) // Every upgrade.
        #expect(UpgradeID.allCases.count == 20)
    }

    @Test func aNewGameHasNoAchievements() {
        var game = GameState.make()
        #expect(game.refreshAchievements().isEmpty)
        #expect(game.earnedAchievementTiers == 0)
        #expect(game.achievementBonus == 1)
    }

    @Test func reachingThresholdsAwardsEachTierOnce() {
        var game = GameState.make()
        game.stats.lifetimeCoins = 2e6
        let earned = game.refreshAchievements()
        #expect(earned.map(\.id) == ["miner#0", "miner#1"])
        #expect(earned.map(\.tierName) == ["Bronze", "Silver"])
        #expect(game.tiersEarned(AchievementCatalog.all[0]) == 2)
        #expect(game.nextThreshold(AchievementCatalog.all[0]) == 1e9)
        #expect(game.refreshAchievements().isEmpty)
        #expect(approx(game.achievementBonus, 1.02))
    }

    @Test func earnedTiersAreNeverLost() {
        var game = GameState.make()
        game.stats.taps = 6_000
        game.refreshAchievements()
        game.stats.taps = 0
        #expect(game.refreshAchievements().isEmpty)
        #expect(game.achievementTiers["tapper"] == 2)
    }

    @Test func metricsReadTheMatchingStats() {
        var game = GameState.make()
        game.stats.maxOwned = [.aiMiner: 120]
        game.stats.tokensBought = [.bitcoin: 2, .xrp: 9]
        game.stats.forksPerformed = 5
        game.stats.blackjackNaturals = 1
        let ids = Set(game.refreshAchievements().map(\.id))
        #expect(ids == ["own-aiMiner#0", "own-aiMiner#1", "token-bitcoin#0", "token-xrp#0",
                        "exchanger#0", "hard-forker#0", "hard-forker#1", "natural#0"])
        #expect(game.nextThreshold(AchievementCatalog.all.first { $0.id == "hard-forker" }!) == 25)
    }

    @Test func newGameAchievementsReadTheirStats() {
        var game = GameState.make()
        game.stats.slotsWins = 10
        game.stats.snakeBestScore = 300
        game.stats.bricksBroken = 50
        game.stats.bubblesPopped = 1_000
        let ids = Set(game.refreshAchievements().map(\.id))
        #expect(ids == ["high-roller#0", "snake-charmer#0", "snake-charmer#1", "brick-smasher#0",
                        "bubble-popper#0", "bubble-popper#1"])
    }

    @Test func finishedAchievementsHaveNoNextThreshold() {
        var game = GameState.make()
        game.stats.airdrops = 1_000
        game.refreshAchievements()
        #expect(game.nextThreshold(AchievementCatalog.all.first { $0.id == "airdrop-hunter" }!) == nil)
    }
}
