import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Prestige")
struct PrestigeTests {
    func state(lifetime: Double) -> GameState {
        var state = GameState.make(coins: 5e9, miners: [.server: 40], upgrades: [.coinClicker, .overclocking])
        state.stats.lifetimeCoins = lifetime
        state.stats.runCoins = lifetime
        return state
    }

    /// Lifetime coins worth `points`³ of potential: the first point needs 11 billion coins.
    func cubed(_ points: Double) -> Double { points * points * points * Tuning.prestigeScale }

    @Test func potentialGrowsWithTheCubeRootOfLifetimeCoins() {
        #expect(Tuning.prestigeScale == 1.1e10)
        #expect(state(lifetime: 0).prestigePotential == 0)
        #expect(state(lifetime: cubed(1) - 1).prestigePotential == 0)
        #expect(state(lifetime: cubed(1)).prestigePotential == 1)
        #expect(state(lifetime: cubed(2)).prestigePotential == 2)
        #expect(state(lifetime: cubed(3)).prestigePotential == 3)
        #expect(state(lifetime: cubed(10)).prestigePotential == 10)
        #expect(state(lifetime: Tuning.prestigeScale * 0x1p60).prestigePotential == 1_048_576) // Exactly (2^20)^3 points' worth.
        #expect(state(lifetime: 1e40).prestigePotential == Tuning.maxPrestigePoints)
        #expect(state(lifetime: .infinity).prestigePotential == 0)
        #expect(state(lifetime: 1e300).prestigePotential == Tuning.maxPrestigePoints)
        #expect(state(lifetime: -5).prestigePotential == 0)
    }

    @Test func nextPrestigePoint() {
        #expect(state(lifetime: 0).nextPrestigePointAt == cubed(1))
        #expect(state(lifetime: cubed(2) + 1).nextPrestigePointAt == cubed(3))
    }

    @Test func difficultyChangesThePointsEarned() {
        var normal = state(lifetime: cubed(2))
        #expect(normal.claimablePrestigePoints == 2)
        normal.runPrestigeMultiplier = Difficulty.hard.prestigeMultiplier
        #expect(normal.claimablePrestigePoints == 3)
        normal.runPrestigeMultiplier = Difficulty.easy.prestigeMultiplier
        #expect(normal.claimablePrestigePoints == 1)
    }

    @Test func prestigingResetsTheRunAndKeepsTheRest() {
        var game = state(lifetime: cubed(2))
        game.tokens = [.dogecoin: 3]
        game.blackjackStake = BlackjackStake(token: .dogecoin, amount: 1)
        game.minerUpgrades = [.server: 2]
        game.unlockedGames = [.blackjack]
        game.achievementTiers = ["miner": 3]
        game.offlineMiningLevel = 4
        game.boost = Boost(multiplier: 7, endsAt: at(60))
        game.difficulty = .hard
        let gained = game.prestige(at: at(100))
        #expect(gained == 2)
        #expect(game.prestigePoints == 2)
        #expect(game.availablePrestigePoints == 2)
        #expect(game.prestigePotentialClaimed == 2)
        #expect(game.coins == 0)
        #expect(game.tokens.isEmpty)
        #expect(game.blackjackStake == nil)
        #expect(game.miners.isEmpty)
        #expect(game.minerUpgrades.isEmpty)
        #expect(game.upgrades.isEmpty)
        #expect(game.boost == nil)
        #expect(game.stats.runCoins == 0)
        #expect(game.stats.lifetimeCoins == cubed(2))
        #expect(game.stats.prestiges == 1)
        #expect(game.unlockedGames == [.blackjack])
        #expect(game.achievementTiers == ["miner": 3])
        #expect(game.offlineMiningLevel == 4)
        #expect(game.runPrestigeMultiplier == 1.5)
        #expect(game.runStart == at(100))
        #expect(game.lastUpdate == at(100))
        #expect(approx(game.prestigeBonus, 1.1))
        // Nothing new to claim straight away.
        #expect(game.claimablePrestigePoints == 0)
        #expect(game.prestige(at: at(200)) == 0)
        #expect(game.prestigePoints == 2)
    }

    @Test func prestigingWithNothingToClaimChangesNothing() {
        var game = state(lifetime: cubed(1) / 2)
        let before = game
        #expect(game.prestige(at: at(10)) == 0)
        #expect(game == before)
    }

    @Test func onlyNewPotentialCountsAfterAPrestige() {
        var game = state(lifetime: cubed(1))
        #expect(game.prestige(at: t0) == 1)
        game.stats.lifetimeCoins = cubed(2)
        #expect(game.claimablePrestigePoints == 1)
        game.stats.lifetimeCoins = cubed(3)
        #expect(game.claimablePrestigePoints == 2)
    }

    @Test func theEstimateSuggestsAPrestigeOnceItSpeedsThingsUpByHalf() {
        var game = state(lifetime: 0)
        #expect(!game.isPrestigeRecommended)
        game.stats.lifetimeCoins = cubed(11) // 11 points: +55% production.
        #expect(approx(game.prestigeSpeedUp, 1.55))
        #expect(game.isPrestigeRecommended)
        game.prestigePoints = 30 // Production is already ×2.5; 11 more points add only 22%.
        #expect(approx(game.prestigeSpeedUp, 3.05 / 2.5))
        #expect(!game.isPrestigeRecommended)
    }

    @Test func theLastTiersWaitForTheFirstPrestige() {
        var game = GameState.make(miners: [.spaceColony: 1])
        #expect(!game.isRevealed(.lunarBase))
        game.stats.prestiges = 1
        #expect(game.isRevealed(.lunarBase))
        #expect(!game.isRevealed(.asteroidHarvester))
        #expect(MinerID.allCases.filter(\.needsPrestige) == [.lunarBase, .asteroidHarvester, .galacticHashnet])
    }

    @Test func savesFromTheHardForkVersionKeepTheirPoints() throws {
        // Versions 1 and 2 counted potential against 10 billion coins; it now takes 11 billion.
        // 5 points' worth then (1.25 trillion coins) is 4 points' worth now, so the same lifetime
        // coins have exactly as much left to claim as before.
        let json = #"{"forks": 4, "forkPointsClaimed": 5, "runForkMultiplier": 1.5, "stats": {"forksPerformed": 2}}"#
        let state = try GameCoding.decoder().decode(GameState.self, from: Data(json.utf8))
        #expect(state.prestigePoints == 4)
        #expect(state.prestigePotentialClaimed == 4)
        #expect(state.runPrestigeMultiplier == 1.5)
        #expect(state.stats.prestiges == 2)
        #expect(state.prestigePointsSpent == 0)
        let version2 = #"{"version": 2, "forkPointsClaimed": 5}"#
        #expect(try GameCoding.decoder().decode(GameState.self, from: Data(version2.utf8)).prestigePotentialClaimed == 4)
        let current = #"{"version": 3, "forkPointsClaimed": 5}"#
        #expect(try GameCoding.decoder().decode(GameState.self, from: Data(current.utf8)).prestigePotentialClaimed == 5)
    }
}

@Suite("Perks")
struct PerkTests {
    func rich(points: Int) -> GameState {
        var game = GameState.make()
        game.prestigePoints = points
        return game
    }

    @Test func perksCostPointsAndNeedTheirPrerequisite() {
        var game = rich(points: 30)
        #expect(!game.canBuy(.blueprints)) // Needs Head Start first.
        #expect(game.buyPerk(.blueprints) == false)
        #expect(game.buyPerk(.headStart) == true)
        #expect(game.buyPerk(.headStart) == false) // Owned already.
        #expect(game.buyPerk(.blueprints) == true)
        #expect(game.availablePrestigePoints == 30 - 1 - 25)
        #expect(game.buyPerk(.airdropRadar) == false) // 4 points left, it costs 5.
        #expect(game.perks == [.headStart, .blueprints])
    }

    @Test func spendingPointsNeverLowersTheProductionBonus() {
        var game = rich(points: 40)
        let bonus = game.prestigeBonus
        #expect(approx(bonus, 3))
        #expect(game.buyPerk(.headStart) == true)
        #expect(game.buyPerk(.blueprints) == true)
        #expect(game.prestigeBonus == bonus)
    }

    @Test func everyPerkIsReachableAndPricedInOrder() {
        for perk in PerkID.allCases {
            #expect(perk.cost > 0)
            if let required = perk.requires {
                #expect(required.cost < perk.cost)
                #expect(required.branch == perk.branch)
            }
        }
        #expect(PerkID.allCases.reduce(0) { $0 + $1.cost } == 6_363)
    }

    @Test func keepPerksSurviveAPrestige() {
        var game = rich(points: 2_000)
        for perk in [PerkID.headStart, .blueprints, .engineeringTeam, .strongFingers, .muscleMemory] {
            #expect(game.buyPerk(perk) == true)
        }
        game.upgrades = [.coinClicker, .overclocking, .stepBooster, .bonusReward1]
        game.minerUpgrades = [.desktop: 3]
        game.stats.lifetimeCoins = 1e13
        #expect(game.prestige(at: t0) > 0)
        #expect(game.upgrades == [.coinClicker, .overclocking]) // Tapping and production kept.
        #expect(game.minerUpgrades == [.desktop: 3])
        #expect(game.miners == [.chromebook: 10, .desktop: 10, .gpuRig: 5]) // Head Start.
        #expect(game.stats.maxOwned[.chromebook] == 10)
    }

    @Test func miningPerks() {
        var game = rich(points: 10_000)
        #expect(game.price(of: .server, quantity: 3) == GameState.wholePrice(MinerID.server.baseCost * (pow(1.15, 3) - 1) / 0.15))
        #expect(game.buyPerk(.headStart) == true)
        #expect(game.buyPerk(.bulkDiscount) == true)
        #expect(game.price(of: .server, quantity: 3) == GameState.wholePrice(MinerID.server.baseCost * 0.9 * (pow(1.15, 3) - 1) / 0.15))
        game.achievementTiers = ["miner": 3]
        #expect(approx(game.achievementBonus, 1.03))
        #expect(game.buyPerk(.compoundInterest) == true)
        #expect(approx(game.achievementBonus, 1.06))
    }

    @Test func tappingPerks() {
        var game = rich(points: 10_000)
        game.upgrades = [.automatedClicker]
        let tap = game.tapValue(at: t0)
        let strength = game.autoTapStrength
        #expect(game.buyPerk(.strongFingers) == true)
        #expect(game.tapValue(at: t0) == (tap * 1.5).rounded())
        #expect(game.comboTapsToMax == 40 && game.comboMaxMultiplier == 2)
        #expect(game.buyPerk(.comboMaster) == true)
        #expect(game.comboTapsToMax == 20 && game.comboMaxMultiplier == 3)
        #expect(game.buyPerk(.muscleMemory) == true)
        #expect(game.buyPerk(.autoClickerPro) == true)
        #expect(game.autoTapStrength == strength * 2)
    }

    @Test func fortunePerks() {
        var game = rich(points: 10_000)
        #expect(game.airdropInterval == 180...360 && game.airdropLifetime == 20)
        #expect(game.buyPerk(.airdropRadar) == true)
        #expect(game.airdropInterval == 120...240 && game.airdropLifetime == 30)
        #expect(game.bullRunDuration == 60)
        #expect(game.buyPerk(.bullMarket) == true)
        #expect(game.bullRunDuration == 120)
        #expect(approx(game.whaleChance, 0.05))
        #expect(game.buyPerk(.whaleWatcher) == true)
        #expect(approx(game.whaleChance, 0.15))
        #expect(approx(game.marketSellRate, 0.9))
        #expect(game.buyPerk(.marketInsider) == true)
        #expect(game.marketSellRate == 1)
        for perk in [PerkID.arcadeChampion, .marathon, .luckyStreak] { #expect(game.buyPerk(perk) == true) }
        #expect(game.miniGameMultiplier == 1.5)
        #expect(game.stepMultiplier == 2)
        #expect(game.dailyRewardMultiplier == 2)
    }
}

@Suite("Miner Mk upgrades")
struct MinerUpgradeTests {
    @Test func upgradesAppearAtOwnedCountsAndDoubleTheMiner() {
        var game = GameState.make(coins: 1e9, miners: [.desktop: 24])
        #expect(game.availableMinerUpgrade(.desktop) == nil)
        game.miners[.desktop] = 25
        let next = game.availableMinerUpgrade(.desktop)
        #expect(next?.level == 0)
        #expect(next?.price == GameState.wholePrice(MinerID.desktop.baseCost * pow(1.15, 25) * 10))
        let rate = game.rate(of: .desktop)
        #expect(game.buyMinerUpgrade(.desktop) == true)
        #expect(game.minerUpgradeLevel(.desktop) == 1)
        #expect(game.rate(of: .desktop) == rate * 2)
        #expect(game.stats.minerUpgradesBought == 1)
        #expect(game.availableMinerUpgrade(.desktop) == nil) // Mk III needs 50.
        game.miners[.desktop] = 50
        #expect(game.availableMinerUpgrade(.desktop)?.level == 1)
    }

    @Test func theLastUpgradeIsMkSix() {
        var game = GameState.make(coins: 1e30, miners: [.chromebook: 500])
        var bought = 0
        while game.buyMinerUpgrade(.chromebook) { bought += 1 }
        #expect(bought == 5)
        #expect(game.availableMinerUpgrade(.chromebook) == nil)
        #expect(game.rate(of: .chromebook) == 500 * GameState.milestoneMultiplier(owned: 500) * 32)
        #expect(MinerID.gpuRig.upgradeName(level: 0) == "GPU Rig Mk II")
        #expect(MinerID.gpuRig.upgradeName(level: 4) == "GPU Rig Mk VI")
    }

    @Test func upgradesNeedTheCoins() {
        var game = GameState.make(coins: 10, miners: [.desktop: 25])
        #expect(game.buyMinerUpgrade(.desktop) == false)
        #expect(game.minerUpgradeLevel(.desktop) == 0)
        #expect(game.coins == 10)
    }
}

@Suite("Combos")
struct ComboTests {
    @Test func theMultiplierClimbsToItsMaximum() {
        let game = GameState.make()
        #expect(game.comboMultiplier(streak: 0) == 1)
        #expect(game.comboMultiplier(streak: 1) == 1)
        #expect(game.comboMultiplier(streak: 21) == 1.5)
        #expect(game.comboMultiplier(streak: 41) == 2)
        #expect(game.comboMultiplier(streak: 500) == 2)
    }

    @Test func combosMultiplyTapsAndAreRecorded() {
        var game = GameState.make(upgrades: [.coinClicker]) // 2 coins per tap.
        #expect(game.tap(at: t0) == 2)
        #expect(game.tap(at: t0, combo: 41) == 4)
        #expect(game.tap(at: t0, combo: 11) == 3) // 2 × 1.25 = 2.5, paid as a whole 3.
        #expect(game.stats.bestCombo == 41)
        #expect(game.stats.bestTap == 4)
        #expect(game.stats.taps == 3)
    }
}

@Suite("Difficulty")
struct DifficultyTests {
    @Test func aFreshRunTakesTheNewPrestigeMultiplier() {
        var game = GameState.make()
        game.setDifficulty(.hard)
        #expect(game.difficulty == .hard)
        #expect(game.runPrestigeMultiplier == 1.5)
        game.setDifficulty(.easy)
        #expect(game.runPrestigeMultiplier == 0.5)
        game.setDifficulty(.normal)
        #expect(game.runPrestigeMultiplier == 1)
    }

    @Test func midRunChangesNeverRaiseThePrestigeMultiplier() {
        var game = GameState.make(miners: [.chromebook: 1])
        game.setDifficulty(.easy)
        #expect(game.runPrestigeMultiplier == 0.5)
        game.setDifficulty(.hard)
        #expect(game.difficulty == .hard)
        #expect(game.runPrestigeMultiplier == 0.5)
    }

    @Test func earningsAloneAlsoLockTheMultiplier() {
        var game = GameState.make()
        game.stats.runCoins = 5_000
        game.setDifficulty(.hard)
        #expect(game.runPrestigeMultiplier == 1)
    }

    @Test func aPrestigeStartsTheNextRunAtTheCurrentDifficulty() {
        var game = GameState.make(miners: [.chromebook: 1])
        game.setDifficulty(.easy)
        game.setDifficulty(.hard)
        game.stats.lifetimeCoins = 1e12
        game.prestige(at: t0)
        #expect(game.runPrestigeMultiplier == 1.5)
    }
}

@Suite("Airdrops")
struct AirdropTests {
    @Test func theRollDecidesWhatAnAirdropHolds() {
        var game = GameState.make()
        #expect(game.airdropKind(roll: 0) == .whale)
        #expect(game.airdropKind(roll: 0.049) == .whale)
        #expect(game.airdropKind(roll: 0.05) == .bullRun)
        #expect(game.airdropKind(roll: 0.349) == .bullRun)
        #expect(game.airdropKind(roll: 0.35) == .coins)
        #expect(game.airdropKind(roll: 0.999) == .coins)
        game.perks = [.airdropRadar, .whaleWatcher]
        #expect(game.airdropKind(roll: 0.149) == .whale)
        #expect(game.airdropKind(roll: 0.449) == .bullRun)
    }

    @Test func aBullRunBoostsProduction() {
        var game = GameState.make(miners: [.desktop: 10])
        let reward = game.claimAirdrop(.bullRun, at: at(5))
        #expect(reward == .bullRun(multiplier: 7, duration: 60))
        #expect(game.boost == Boost(multiplier: 7, endsAt: at(65)))
        #expect(game.stats.airdrops == 1)
        #expect(approx(game.production(at: at(10)), 140))
        game.perks = [.airdropRadar, .bullMarket]
        #expect(game.claimAirdrop(.bullRun, at: at(10)) == .bullRun(multiplier: 7, duration: 120))
        #expect(game.boost?.endsAt == at(130))
    }

    @Test func bullRunsNeverShortenARunningBoost() {
        var game = GameState.make()
        game.boost = Boost(multiplier: 7, endsAt: at(100))
        game.claimAirdrop(.bullRun, at: at(10))
        #expect(game.boost?.endsAt == at(100))
        game.claimAirdrop(.bullRun, at: at(90))
        #expect(game.boost?.endsAt == at(150))
    }

    @Test func coinDropsPayAShareOfTheBankWithinIncomeLimits() {
        var rich = GameState.make(coins: 1e6, miners: [.desktop: 5]) // 10 coins per second.
        #expect(rich.claimAirdrop(.coins, at: t0) == .coins(9_000)) // Capped at 15 minutes of income.
        #expect(rich.coins == 1e6 + 9_000)
        #expect(rich.stats.earnedFromAirdrops == 9_000)

        var saver = GameState.make(coins: 20_000, miners: [.desktop: 5])
        #expect(saver.claimAirdrop(.coins, at: t0) == .coins(3_000)) // 15% of the bank.

        var broke = GameState.make(coins: 100, miners: [.desktop: 5])
        #expect(broke.claimAirdrop(.coins, at: t0) == .coins(300)) // At least 30 seconds of income.
    }

    @Test func whalesPayAnHourOfIncome() {
        var game = GameState.make(coins: 1e12, miners: [.desktop: 5])
        #expect(game.claimAirdrop(.whale, at: t0) == .whale(36_000))
        #expect(game.stats.whaleAirdrops == 1)
        #expect(game.stats.airdrops == 1)
        #expect(game.stats.earnedFromAirdrops == 36_000)
    }
}

@Suite("Achievements")
struct AchievementTests {
    @Test func catalogIsWellFormed() {
        let all = AchievementCatalog.all
        #expect(all.count == 51)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(AchievementCatalog.tierCount == 204)
        for achievement in all {
            #expect(achievement.thresholds.count == 4)
            #expect(achievement.thresholds == achievement.thresholds.sorted())
            #expect(Set(achievement.thresholds).count == 4)
            #expect((achievement.emoji == nil) != (achievement.imageName == nil))
        }
        #expect(all.first { $0.id == "upgrader" }?.thresholds.last == 20) // Every upgrade.
        #expect(UpgradeID.allCases.count == 20)
        #expect(all.first { $0.id == "own-spaceColony" }?.detail == "Own Space Mining Colonies at once")
        // Every coin finish can be unlocked.
        #expect(CoinFinish.allCases.allSatisfy { $0.starsNeeded <= AchievementCatalog.tierCount })
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
        game.stats.prestiges = 5
        game.stats.blackjackNaturals = 1
        let ids = Set(game.refreshAchievements().map(\.id))
        #expect(ids == ["own-aiMiner#0", "own-aiMiner#1", "token-bitcoin#0", "token-xrp#0",
                        "exchanger#0", "hard-forker#0", "hard-forker#1", "natural#0"])
        #expect(game.nextThreshold(AchievementCatalog.all.first { $0.id == "hard-forker" }!) == 25)
    }

    @Test func newSystemsHaveAchievements() {
        var game = GameState.make()
        game.stats.minerUpgradesBought = 5
        game.stats.bestCombo = 100
        game.stats.tokensSold = 10
        game.stats.questsCompleted = 5
        game.stats.longestStreak = 7
        game.stats.whaleAirdrops = 1
        game.perks = [.headStart]
        let ids = Set(game.refreshAchievements().map(\.id))
        #expect(ids == ["engineer#0", "combo-king#0", "combo-king#1", "trader#0", "quest-master#0",
                        "loyal-miner#0", "loyal-miner#1", "whale-spotter#0", "perk-collector#0"])
    }

    @Test func gameAchievementsReadTheirStats() {
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
