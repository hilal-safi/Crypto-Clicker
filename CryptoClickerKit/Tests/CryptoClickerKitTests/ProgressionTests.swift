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

    /// Lifetime coins worth `points`³ of potential: the first point needs 15 billion coins.
    func cubed(_ points: Double) -> Double { points * points * points * Tuning.prestigeScale }

    @Test func nothingBetWithTheOldRunsTokensSurvivesAPrestige() throws {
        var game = state(lifetime: cubed(10))
        game.tokens = [.bitcoin: 40]
        game.slotsFreeSpins = SlotsFreeSpins(token: .bitcoin, bet: 10, left: 3)
        game.moonRound = MoonRound(token: .bitcoin, bet: 10, crashPoint: 50, autoCashOut: nil)
        let points = game.prestige(at: t0)
        #expect(points == 10)
        #expect(game.tokens.isEmpty)
        #expect(game.slotsFreeSpins == nil)
        #expect(game.moonRound == nil)
        // The free spins can't pay the old run's tokens into the new one: with no tokens, the
        // slots refuse the spin.
        var rng = SeededGenerator(seed: 7)
        let spin = game.spinSlots(.bitcoin, bet: 10, using: &rng)
        #expect(spin == nil)
        #expect(game.tokenCount(.bitcoin) == 0)
        // And it all survives a save: nothing comes back on loading.
        let loaded = try GameCoding.decoder().decode(GameState.self, from: try GameCoding.encoder().encode(game))
        #expect(loaded.slotsFreeSpins == nil && loaded.moonRound == nil && loaded.tokens.isEmpty)
    }

    @Test func potentialGrowsWithTheCubeRootOfLifetimeCoins() {
        #expect(Tuning.prestigeScale == 1.5e10)
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
        // Versions 1 and 2 counted potential against 10 billion coins, version 3 against 11 billion and
        // version 4 against 12.65 billion; it now takes 15 billion. 5 points' worth then (1.25 to 1.58
        // trillion coins) is 4 points' worth now, so the same lifetime coins have exactly as much left
        // to claim as before.
        let json = #"{"forks": 4, "forkPointsClaimed": 5, "runForkMultiplier": 1.5, "stats": {"forksPerformed": 2}}"#
        let state = try GameCoding.decoder().decode(GameState.self, from: Data(json.utf8))
        #expect(state.prestigePoints == 4)
        #expect(state.prestigePotentialClaimed == 4)
        #expect(state.runPrestigeMultiplier == 1.5)
        #expect(state.stats.prestiges == 2)
        #expect(state.prestigePointsSpent == 0)
        let version2 = #"{"version": 2, "forkPointsClaimed": 5}"#
        #expect(try GameCoding.decoder().decode(GameState.self, from: Data(version2.utf8)).prestigePotentialClaimed == 4)
        let version3 = #"{"version": 3, "forkPointsClaimed": 5}"#
        #expect(try GameCoding.decoder().decode(GameState.self, from: Data(version3.utf8)).prestigePotentialClaimed == 4)
        let version3Big = #"{"version": 3, "forkPointsClaimed": 100}"#
        #expect(try GameCoding.decoder().decode(GameState.self, from: Data(version3Big.utf8)).prestigePotentialClaimed == 90)
        let version4 = #"{"version": 4, "forkPointsClaimed": 5}"#
        #expect(try GameCoding.decoder().decode(GameState.self, from: Data(version4.utf8)).prestigePotentialClaimed == 4)
        let version4Big = #"{"version": 4, "forkPointsClaimed": 100}"#
        #expect(try GameCoding.decoder().decode(GameState.self, from: Data(version4Big.utf8)).prestigePotentialClaimed == 94)
        let current = #"{"version": 5, "forkPointsClaimed": 5}"#
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
        #expect(game.buyPerk(.marketInsider) == false) // 4 points left, it costs 8.
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
        #expect(PerkID.allCases.reduce(0) { $0 + $1.cost } == 12_305)
        // Each perk costs no more than twice the one before it.
        let costs = PerkID.allCases.map(\.cost).sorted()
        for (cheaper, dearer) in zip(costs, costs.dropFirst()) { #expect(dearer <= cheaper * 2) }
    }

    @Test func keepPerksSurviveAPrestige() {
        var game = rich(points: 10_000)
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
        var game = rich(points: 25_000)
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
        #expect(game.comboTapsToMax == 45 && game.comboMaxMultiplier == 2)
        #expect(game.buyPerk(.comboMaster) == true)
        // Twice as fast (2.2 taps a step), and up to ×3: twenty steps of 0.1.
        #expect(game.comboTapsToMax == 45 && game.comboMaxMultiplier == 3)
        #expect(game.comboSpeed == 2)
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
        #expect(game.rate(of: .chromebook) == 500 * MinerID.chromebook.baseRate * GameState.milestoneMultiplier(owned: 500) * 32)
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
    @Test func theMultiplierClimbsATenthEveryFourAndAHalfTaps() {
        let game = GameState.make()
        #expect(game.comboMultiplier(streak: 0) == 1)
        #expect(game.comboMultiplier(streak: 1) == 1)
        // 4.4 taps for each +0.1, 10% slower than it was: ×1.1 on the 6th tap, ×1.5 on the 23rd.
        #expect(game.comboMultiplier(streak: 5) == 1)
        #expect(game.comboMultiplier(streak: 6) == 1.1)
        #expect(game.comboMultiplier(streak: 22) == 1.4)
        #expect(game.comboMultiplier(streak: 23) == 1.5)
        #expect(game.comboMultiplier(streak: 44) == 1.9)
        #expect(game.comboMultiplier(streak: 45) == 2)
        #expect(game.comboMultiplier(streak: 500) == 2)
        #expect(game.comboTapsToMax == 45)
        // Every value is an exact tenth.
        for streak in 1...60 {
            let value = game.comboMultiplier(streak: streak)
            #expect((value * 10).rounded() / 10 == value)
        }
    }

    @Test func combosMultiplyTapsAndAreRecorded() {
        var game = GameState.make(upgrades: [.coinClicker]) // 2 coins per tap.
        #expect(game.tap(at: t0) == 2)
        #expect(game.tap(at: t0, combo: 45) == 4)
        #expect(game.tap(at: t0, combo: 15) == 3) // 2 × 1.3 = 2.6, paid as a whole 3.
        #expect(game.stats.bestCombo == 45)
        #expect(game.stats.bestTap == 4)
        #expect(game.stats.taps == 3)
    }

    @Test func comboPowerUpsRaiseTheTopToTenAndBuildUpToFourTimesFaster() {
        var game = GameState.make()
        game.powerUps = [.comboBooster: 6]
        #expect(game.comboMaxMultiplier == 5)
        game.powerUps[.comboOverdrive] = 5
        #expect(game.comboMaxMultiplier == 10)
        #expect(game.comboMultiplier(streak: 397) == 10) // 90 steps × 4.4 taps, plus the first.
        #expect(game.comboMultiplier(streak: 396) == 9.9)
        game.powerUps[.quickCombos] = 6
        #expect(game.comboSpeed == 4)
        #expect(abs(game.comboTapsPerStep - 1.1) < 1e-12)
        #expect(game.comboTapsToMax == 100)
        #expect(game.comboMultiplier(streak: 100) == 10)
        // Combo Master doubles the speed again, and never lowers the top.
        game.perks = [.comboMaster]
        #expect(game.comboSpeed == 8)
        #expect(game.comboMaxMultiplier == 10)
        // Levels beyond the last count as the last.
        game.powerUps = [.comboBooster: 99]
        game.perks = []
        #expect(game.comboMaxMultiplier == 5)
    }

    @Test func powerUpsAreBoughtLevelByLevelAndKeptThroughPrestiges() throws {
        var game = GameState.make(coins: 1e15)
        #expect(!game.isRevealed(.comboBooster) && !game.isRevealed(.quickCombos))
        game.stats.lifetimeCoins = 1e15
        #expect(game.isRevealed(.comboBooster) && game.isRevealed(.quickCombos))
        #expect(!game.isRevealed(.comboOverdrive)) // Not until Combo Booster is at its last level.
        let first = try #require(game.powerUpPrice(.comboBooster))
        #expect(first == Tuning.shopPrice(Tuning.comboBoosterBaseCost))
        let bought = game.buyPowerUp(.comboBooster)
        #expect(bought)
        #expect(game.powerUpLevel(.comboBooster) == 1 && game.comboMaxMultiplier == 2.5)
        #expect(game.coins == 1e15 - first)
        #expect(game.powerUpPrice(.comboBooster) == Tuning.shopPrice(Tuning.comboBoosterBaseCost * Tuning.comboBoosterCostGrowth))
        while game.buyPowerUp(.comboBooster) {}
        #expect(game.powerUpLevel(.comboBooster) == 6 && game.powerUpPrice(.comboBooster) == nil)
        #expect(game.isRevealed(.comboOverdrive))
        while game.buyPowerUp(.comboOverdrive) {}
        while game.buyPowerUp(.quickCombos) {}
        #expect(game.comboMaxMultiplier == 10 && game.comboSpeed == 4)
        #expect(game.stats.powerUpLevelsBought == 17)
        // Kept through a prestige and saved with the game.
        game.prestige(at: at(10))
        #expect(game.comboMaxMultiplier == 10)
        let loaded = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(loaded.powerUps == game.powerUps)
        // Not enough coins: nothing changes.
        var poor = GameState.make(coins: 10)
        poor.stats.lifetimeCoins = 1e6
        let tried = poor.buyPowerUp(.comboBooster)
        #expect(!tried && poor.powerUpLevel(.comboBooster) == 0 && poor.coins == 10)
    }

    @Test func powerUpTextReadsTheirEffects() {
        #expect(PowerUpID.comboBooster.effect(atLevel: 3) == "Biggest combo ×3.5")
        #expect(PowerUpID.comboOverdrive.effect(atLevel: 5) == "Biggest combo ×10")
        #expect(PowerUpID.quickCombos.effect(atLevel: 2) == "Combos build 2× as fast")
        #expect(PowerUpID.comboKeeper.effect(atLevel: 2) == "Combos wait 1s between taps")
        #expect(PowerUpID.comboBooster.summary.contains("×5"))
        #expect(PowerUpID.comboOverdrive.summary.contains("×10"))
        #expect(PowerUpID.quickCombos.summary.contains("4×"))
        #expect(PowerUpID.comboKeeper.summary.contains("0.6s") && PowerUpID.comboKeeper.summary.contains("1.8s"))
        // The Shop's Now and Next show the value alone.
        #expect(PowerUpID.comboBooster.value(atLevel: 0) == "×2")
        #expect(PowerUpID.comboBooster.value(atLevel: 3) == "×3.5")
        #expect(PowerUpID.quickCombos.value(atLevel: 4) == "3× as fast")
        #expect(PowerUpID.comboKeeper.value(atLevel: 0) == "0.6s")
        #expect(PowerUpID.comboKeeper.value(atLevel: 1) == "0.8s")
        #expect(PowerUpID.comboKeeper.value(atLevel: 6) == "1.8s")
        #expect(PowerUpID.comboKeeper.value(atLevel: 9) == "1.8s") // Never past the last level.
    }

    @Test func comboKeeperGivesMoreTimeBetweenTapsUpToThreeTimesAsLong() throws {
        var game = GameState.make(coins: 1e15)
        game.stats.lifetimeCoins = 1e15
        #expect(game.comboWindow == Tuning.comboWindow)
        #expect(game.isRevealed(.comboKeeper))
        let first = try #require(game.powerUpPrice(.comboKeeper))
        #expect(first == Tuning.shopPrice(Tuning.comboKeeperBaseCost))
        let bought = game.buyPowerUp(.comboKeeper)
        #expect(bought)
        #expect(approx(game.comboWindow, 0.8))
        while game.buyPowerUp(.comboKeeper) {}
        #expect(game.powerUpLevel(.comboKeeper) == 6)
        #expect(approx(game.comboWindow, 1.8))
        #expect(game.powerUpPrice(.comboKeeper) == nil)
        // Kept through a prestige, like every power-up.
        game.prestige(at: at(10))
        #expect(approx(game.comboWindow, 1.8))
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
        var game = GameState.make(miners: minersEarning(20)) // 20 coins per second.
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
        var rich = GameState.make(coins: 1e6, miners: minersEarning(10)) // 10 coins per second.
        #expect(rich.claimAirdrop(.coins, at: t0) == .coins(9_000)) // Capped at 15 minutes of income.
        #expect(rich.coins == 1e6 + 9_000)
        #expect(rich.stats.earnedFromAirdrops == 9_000)

        var saver = GameState.make(coins: 20_000, miners: minersEarning(10))
        #expect(saver.claimAirdrop(.coins, at: t0) == .coins(3_000)) // 15% of the bank.

        var broke = GameState.make(coins: 100, miners: minersEarning(10))
        #expect(broke.claimAirdrop(.coins, at: t0) == .coins(300)) // At least 30 seconds of income.
    }

    @Test func whalesPayAnHourOfIncome() {
        var game = GameState.make(coins: 1e12, miners: minersEarning(10)) // 10 coins per second.
        game.stats.runCoins = 1e6
        #expect(game.claimAirdrop(.whale, at: t0) == .whale(36_000))
        #expect(game.stats.whaleAirdrops == 1)
        #expect(game.stats.airdrops == 1)
        #expect(game.stats.earnedFromAirdrops == 36_000)
    }

    @Test func anEarlyWhalePaysNoMoreThanTheRunHasMined() {
        var early = GameState.make(miners: minersEarning(10)) // 10 coins per second.
        early.stats.runCoins = 5_000
        // Not an hour (36,000): at most what the run has mined so far, so it can't skip the opening.
        #expect(early.whaleAmount == 5_000)
        #expect(early.claimAirdrop(.whale, at: t0) == .whale(5_000))
        // Never less than an ordinary airdrop's 30 seconds of income.
        #expect(GameState.make(miners: minersEarning(10)).whaleAmount == 300)
    }

    @Test func airdropsAreLoggedCaughtOrMissed() throws {
        var game = GameState.make(coins: 1e12, miners: minersEarning(10)) // 10 coins per second.
        game.stats.runCoins = 1e6
        game.claimAirdrop(.coins, at: at(1))
        game.claimAirdrop(.whale, at: at(2))
        game.claimAirdrop(.bullRun, at: at(3))
        game.missAirdrop(.whale, at: at(4))
        #expect(game.recentAirdrops == [
            AirdropLog(kind: .coins, date: at(1), caught: true, coins: 9_000),
            AirdropLog(kind: .whale, date: at(2), caught: true, coins: 36_000),
            AirdropLog(kind: .bullRun, date: at(3), caught: true),
            AirdropLog(kind: .whale, date: at(4), caught: false),
        ])
        #expect(game.stats.airdrops == 3 && game.stats.airdropsMissed == 1)
        #expect(game.stats.bullRuns == 1 && game.stats.whaleAirdrops == 1)
        #expect(game.stats.bestAirdrop == 36_000)
        // Kept through a save, and through a prestige.
        var loaded = try GameCoding.decoder().decode(GameState.self, from: try GameCoding.encoder().encode(game))
        #expect(loaded.recentAirdrops == game.recentAirdrops)
        #expect(loaded.stats.airdropsMissed == 1 && loaded.stats.bullRuns == 1 && loaded.stats.bestAirdrop == 36_000)
        loaded.stats.lifetimeCoins = 1e12
        #expect(loaded.prestige(at: at(10)) > 0)
        #expect(loaded.recentAirdrops.count == 4 && loaded.stats.airdropsMissed == 1)
    }

    @Test func theAirdropHistoryKeepsTheLatestTen() {
        var game = GameState.make(miners: minersEarning(10))
        for second in 0..<25 { game.missAirdrop(.coins, at: at(Double(second))) }
        #expect(game.recentAirdrops.count == Tuning.rememberedAirdrops)
        #expect(game.recentAirdrops.first?.date == at(15) && game.recentAirdrops.last?.date == at(24))
        #expect(game.stats.airdropsMissed == 25)
    }
}

@Suite("Achievements")
struct AchievementTests {
    @Test func catalogIsWellFormed() {
        let all = AchievementCatalog.all
        #expect(all.count == 65)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(AchievementCatalog.tierCount == 260)
        for achievement in all {
            #expect(achievement.thresholds.count == 4)
            #expect(achievement.thresholds == achievement.thresholds.sorted())
            #expect(Set(achievement.thresholds).count == 4)
            #expect((achievement.emoji == nil) != (achievement.imageName == nil))
        }
        #expect(all.first { $0.id == "upgrader" }?.thresholds.last == 22) // Every upgrade.
        #expect(UpgradeID.allCases.count == 22)
        #expect(all.first { $0.id == "own-spaceColony" }?.detail == "Own Space Mining Colonies at once")
        // Every coin finish can be unlocked.
        #expect(CoinFinish.allCases.allSatisfy { $0.starsNeeded <= AchievementCatalog.tierCount })
    }

    /// Rims and tap effects unlock one after another with achievement stars, the first from the
    /// start and the last well within reach.
    @Test func coinRimsAndTapEffectsUnlockWithStars() {
        let rims = CoinRim.allCases.map(\.starsNeeded)
        let effects = CoinTapEffect.allCases.map(\.starsNeeded)
        for stars in [rims, effects] {
            #expect(stars.first == 0)
            #expect(zip(stars, stars.dropFirst()).allSatisfy { $0 < $1 })
            #expect((stars.last ?? .max) <= AchievementCatalog.tierCount / 2)
        }
        #expect(Set(CoinRim.allCases.map(\.name)).count == CoinRim.allCases.count)
        #expect(Set(CoinTapEffect.allCases.map(\.name)).count == CoinTapEffect.allCases.count)
        #expect(CoinRim.plain.isUnlocked(stars: 0) && !CoinRim.glow.isUnlocked(stars: 2) && CoinRim.glow.isUnlocked(stars: 3))
        #expect(CoinTapEffect.none.isUnlocked(stars: 0) && !CoinTapEffect.hashStorm.isUnlocked(stars: 79))
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
        game.stats.bestCombo = 110
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
