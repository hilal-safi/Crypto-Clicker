import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Prices")
struct PriceTests {
    @Test func firstUnitCostsTheBasePrice() {
        let state = GameState.make()
        for miner in MinerID.allCases {
            #expect(state.price(of: miner, quantity: 1) == miner.baseCost)
        }
    }

    @Test func pricesAreWholeCoins() {
        let state = GameState.make(miners: [.chromebook: 3, .gpuRig: 17])
        for miner in MinerID.allCases {
            for quantity in [1, 7, 10, 100] {
                let price = state.price(of: miner, quantity: quantity)
                #expect(price == price.rounded())
            }
        }
    }

    @Test func bulkPriceIsTheRoundedUpSeries() {
        let state = GameState.make(miners: [.desktop: 7])
        for quantity in [1, 10, 25, 100] {
            // Each unit rounds up on its own, so buying one at a time can cost up to a coin more per unit.
            let units = (7..<(7 + quantity)).reduce(0.0) { $0 + state.unitPrice(.desktop, index: $1) }
            let bulk = state.price(of: .desktop, quantity: quantity)
            #expect(bulk <= units)
            #expect(units < bulk + Double(quantity))
        }
        #expect(state.price(of: .desktop, quantity: 1) == state.unitPrice(.desktop, index: 7))
        #expect(state.price(of: .desktop, quantity: 0) == 0)
        #expect(state.price(of: .desktop, quantity: -3) == 0)
    }

    @Test func eachUnitCostsFifteenPercentMoreRoundedUp() {
        let state = GameState.make(miners: [.chromebook: 5])
        // A list price of 40, about doubled for the opening's pace, and 20% more for the opening.
        #expect(MinerID.chromebook.baseCost == 99)
        #expect(state.price(of: .chromebook, quantity: 1) == 200) // 99 × 1.15⁵ = 199.13
    }

    @Test func maxAffordableIsExactAtPriceBoundaries() {
        for owned in [0, 3, 40] {
            let state = GameState.make(miners: [.gpuRig: owned])
            for quantity in 1...60 {
                let exact = state.price(of: .gpuRig, quantity: quantity)
                #expect(state.maxAffordable(.gpuRig, budget: exact) == quantity)
                #expect(state.maxAffordable(.gpuRig, budget: exact.nextDown) == quantity - 1)
            }
        }
    }

    @Test func maxAffordableHandlesTinyAndHugeBudgets() {
        let state = GameState.make()
        #expect(state.maxAffordable(.chromebook, budget: 98.99) == 0)
        #expect(state.maxAffordable(.chromebook, budget: 0) == 0)
        #expect(state.maxAffordable(.chromebook, budget: .infinity) == 0)
        #expect(state.maxAffordable(.chromebook, budget: .nan) == 0)
        let count = state.maxAffordable(.chromebook, budget: 1e30)
        #expect(count == 447)
        #expect(state.price(of: .chromebook, quantity: count) <= 1e30)
        #expect(state.price(of: .chromebook, quantity: count + 1) > 1e30)
    }

    @Test func maxAffordableUsesTheBalanceByDefault() {
        let state = GameState.make(coins: 495)
        // 99 + 113.85 + 130.93 + 150.57 = 494.35, rounded up to 495; a fifth unit would make it 668.
        #expect(state.maxAffordable(.chromebook) == 4)
        #expect(state.price(of: .chromebook, quantity: 4) == 495)
        #expect(state.price(of: .chromebook, quantity: 5) == 668)
    }
}

@Suite("Production")
struct ProductionTests {
    @Test func milestonesDoubleOutput() {
        #expect(GameState.milestoneMultiplier(owned: 0) == 1)
        #expect(GameState.milestoneMultiplier(owned: 24) == 1)
        #expect(GameState.milestoneMultiplier(owned: 25) == 2)
        #expect(GameState.milestoneMultiplier(owned: 50) == 4)
        #expect(GameState.milestoneMultiplier(owned: 99) == 4)
        #expect(GameState.milestoneMultiplier(owned: 100) == 8)
        #expect(GameState.milestoneMultiplier(owned: 1_000) == 4_096)
        #expect(GameState.milestoneMultiplier(owned: 5_000) == 4_096)
    }

    @Test func nextMilestone() {
        #expect(GameState.make().nextMilestone(for: .server) == 25)
        #expect(GameState.make(miners: [.server: 25]).nextMilestone(for: .server) == 50)
        #expect(GameState.make(miners: [.server: 1_000]).nextMilestone(for: .server) == nil)
    }

    @Test func rateCombinesCountMilestonesAndMultipliers() {
        var state = GameState.make(miners: [.chromebook: 25], upgrades: [.overclocking, .fiberUplink])
        #expect(approx(state.rate(of: .chromebook), 25 * 0.25 * 2 * 1.75 * 2)) // A Chromebook earns a coin every four seconds.
        state.prestigePoints = 4
        state.achievementTiers = ["miner": 3, "tapper": 2]
        state.difficulty = .easy
        let expected = 25 * 0.25 * 2 * 1.75 * 2 * 1.2 * 1.05 * 1.5
        #expect(approx(state.rate(of: .chromebook), expected))
        #expect(approx(state.baseProduction, expected))
        #expect(state.rate(of: .desktop) == 0)
    }

    @Test func difficultyScalesProduction() {
        var state = GameState.make(miners: minersEarning(10))
        state.difficulty = .hard
        #expect(approx(state.baseProduction, 20 * 0.5 * 0.6))
    }

    @Test func ratePerUnitIsTheMarginalRateBeforeMilestones() {
        let state = GameState.make(miners: [.server: 30])
        #expect(approx(state.ratePerUnit(of: .server), 35 * 2))
    }

    @Test func tapsStartAtOneCoin() {
        let state = GameState.make()
        #expect(state.tapValue(at: t0) == 1)
        #expect(state.idleIncome(at: t0) == 0)
    }

    @Test func tapUpgradesAddFlatValueAndAShareOfProduction() {
        let state = GameState.make(miners: minersEarning(20), upgrades: [.coinClicker, .upgradedClicker, .mechanicalKeyboard])
        // Production 20/s; taps earn 1 + 1 flat and 20% of a second's production: 2 + 4 = 6 coins.
        #expect(state.tapValue(at: t0) == 6)
        let quarter = GameState.make(miners: minersEarning(8), upgrades: [.upgradedClicker])
        // 1 + 8% of 8 is 1.64, which pays a whole 2 coins.
        #expect(quarter.tapValue(at: t0) == 2)
    }

    @Test func tapUpgradesAddUpToAWholeSecondOfProduction() {
        let tapping = UpgradeID.allCases.filter {
            if case .tapPercent = $0.effect { return true }
            return false
        }
        #expect(tapping == [.upgradedClicker, .mechanicalKeyboard, .neuralInterface, .hapticEngine, .satoshisTouch])
        let state = GameState.make(miners: [.server: 100], upgrades: Set(tapping))
        #expect(approx(state.tapShare, 1))
        // Late in the game a single tap is worth a whole second of mining.
        #expect(state.tapValue(at: t0) == (1 + state.baseProduction).rounded())
    }

    @Test func tapsAreAlwaysWholeCoins() {
        var state = GameState.make(miners: [.server: 33, .gpuRig: 7], upgrades: [.coinClicker, .neuralInterface])
        state.prestigePoints = 3
        state.achievementTiers = ["miner": 2]
        for seconds in [0.0, 5, 30] {
            state.boost = Boost(multiplier: 7, endsAt: at(10))
            let value = state.tapValue(at: at(seconds))
            #expect(value == value.rounded())
            #expect(value >= 1)
        }
    }

    @Test func autoTapsCountAsIdleIncome() {
        let state = GameState.make(miners: minersEarning(20), upgrades: [.automatedClicker, .roboticFinger, .upgradedClicker])
        #expect(state.autoTapsPerSecond == 2)
        // A tap is 1 + 10% of 20 = 3 coins, and an automatic tap earns a quarter of that.
        #expect(approx(state.idleIncome(at: t0), 20 + 2 * 0.25 * 3))
        #expect(approx(state.baseIdleIncome, 20 + 2 * 0.25 * 3))
    }

    @Test func incomeRatesMatchIdleIncomeWithAndWithoutBoost() {
        var state = GameState.make(miners: [.server: 60, .gpuRig: 12],
                                   upgrades: [.coinClicker, .upgradedClicker, .automatedClicker, .neuralInterface, .overclocking])
        state.prestigePoints = 4
        state.boost = Boost(multiplier: 7, endsAt: at(60))
        let rates = state.incomeRates
        #expect(approx(state.idleIncome(at: at(10)), rates.boosted))
        #expect(approx(state.idleIncome(at: at(60)), rates.normal))
        #expect(rates.boosted > rates.normal * 6)
        #expect(approx(state.baseIdleIncome, state.idleIncome(at: at(61))))
        #expect(state.boostMultiplier(at: at(59.9)) == 7)
        #expect(state.boostMultiplier(at: at(60)) == 1)
        #expect(state.activeBoost(at: at(60)) == nil)
    }

    @Test func legacyLiftsOldMinersOnceNewerTiersReachAHundred() {
        var game = GameState.make(miners: [.chromebook: 50, .desktop: 50, .dataCenter: 99, .mineCenter: 100])
        // The Mine Center is five tiers above the Chromebook and four above the Desktop.
        #expect(game.legacyMultiplier(.chromebook) == Tuning.legacyMultiplier)
        #expect(game.legacyMultiplier(.desktop) == Tuning.legacyMultiplier)
        #expect(game.legacyMultiplier(.gpuRig) == 1) // Only three tiers below it.
        #expect(game.legacyMultiplier(.mineCenter) == 1)
        let before = game.rate(of: .chromebook)
        game.miners[.dataCenter] = 100 // Four above the Chromebook, but not the Desktop.
        #expect(game.legacyTiers(for: .chromebook) == 2)
        #expect(game.legacyTiers(for: .desktop) == 1)
        #expect(approx(game.rate(of: .chromebook), before * Tuning.legacyMultiplier))
        // With every tier at a hundred, the Chromebook counts the nine from the Data Center up.
        for miner in MinerID.allCases { game.miners[miner] = 100 }
        #expect(game.legacyTiers(for: .chromebook) == 9)
        #expect(game.legacyTiers(for: .galacticHashnet) == 0)
        // What reaching a hundred would lift: owned tiers four or more below, until it's reached.
        var climbing = GameState.make(miners: [.chromebook: 10, .gpuRig: 3, .mineCenter: 40, .server: 5])
        #expect(climbing.legacyBeneficiaries(of: .mineCenter) == [.chromebook])  // The Desktop isn't owned.
        #expect(climbing.legacyBeneficiaries(of: .server).isEmpty) // Nothing four tiers below.
        climbing.miners[.desktop] = 1
        #expect(climbing.legacyBeneficiaries(of: .mineCenter) == [.chromebook, .desktop])
        climbing.miners[.mineCenter] = 100
        #expect(climbing.legacyBeneficiaries(of: .mineCenter).isEmpty)
    }

    @Test func offlineMiningGrowsByMinutesThenLongerSteps() {
        #expect(GameState.make().offlineCap == 0)
        #expect(GameState.offlineCap(level: 1) == 60)
        #expect(GameState.offlineCap(level: 2) == 2 * 60)
        #expect(GameState.offlineCap(level: 10) == 10 * 60) // A minute a level to 10 minutes...
        #expect(GameState.offlineCap(level: 11) == 15 * 60) // ...then 5 minutes to an hour...
        #expect(GameState.offlineCap(level: 20) == 3_600)
        #expect(GameState.offlineCap(level: 21) == 75 * 60) // ...15 minutes to 3 hours...
        #expect(GameState.offlineCap(level: 28) == 3 * 3_600)
        #expect(GameState.offlineCap(level: 29) == 3.5 * 3_600) // ...then half an hour.
        #expect(GameState.offlineCap(level: 42) == 10 * 3_600)
        #expect(GameState.offlineCap(level: 70) == 24 * 3_600)
        #expect(GameState.offlineCap(level: Tuning.offlineMiningMaxLevel) == 72 * 3_600)
        #expect(GameState.offlineCap(level: 500) == 72 * 3_600)
        #expect(GameState.offlineCap(level: -3) == 0)
        // Each limit belongs to exactly one level.
        for level in 0...Tuning.offlineMiningMaxLevel {
            #expect(GameState.offlineMiningLevel(reaching: GameState.offlineCap(level: level)) == level)
        }
        #expect(GameState.offlineMiningLevel(reaching: 12 * 60) == 11) // Rounds up to the next level.
        #expect(GameState.offlineMiningLevel(reaching: 1e9) == Tuning.offlineMiningMaxLevel)
    }

    @Test func offlineMiningLevelsCostMoreEachTimeAndStopAtTheMaximum() {
        var state = GameState.make(coins: 1_000)
        // The first minute costs 2,500: a list price of 1,216.16, about doubled for the opening's pace.
        #expect(state.offlineMiningPrice == 2_500)
        state.coins = 1_000
        #expect(state.buyOfflineMining() == false) // Can't afford it yet.
        state.coins = 2_500 + 2_684 + 100
        let first = state.buyOfflineMining()
        #expect(first)
        #expect(state.offlineMiningLevel == 1)
        #expect(state.offlineCap == 60)
        #expect(state.offlineMiningPrice == 2_684) // About 7% more for each minute to the hour.
        let second = state.buyOfflineMining()
        #expect(second)
        #expect(state.coins == 100)
        #expect(state.stats.spent == 5_184)
        // Every level costs more than the one before, steeply up to ten hours and more gently after.
        var previous = 0.0
        for level in 1...Tuning.offlineMiningMaxLevel {
            let price = GameState.offlineMiningListPrice(level: level)
            #expect(price > previous, "level \(level)")
            previous = price
        }
        #expect(approx(GameState.offlineMiningListPrice(level: 20), 8e4)) // An hour.
        #expect(approx(GameState.offlineMiningListPrice(level: 42), 1.3e11)) // Ten hours.
        #expect(approx(GameState.offlineMiningListPrice(level: 70), 1e16)) // A day.
        #expect(approx(GameState.offlineMiningListPrice(level: Tuning.offlineMiningMaxLevel), 1e23)) // Three days.
        state.offlineMiningLevel = Tuning.offlineMiningMaxLevel
        state.coins = 1e300
        #expect(state.offlineMiningPrice == nil)
        #expect(state.buyOfflineMining() == false)
        #expect(state.offlineMiningLevel == Tuning.offlineMiningMaxLevel)
    }

    @Test func aPrestigeKeepsOfflineMining() {
        var state = GameState.make(coins: 5, miners: [.desktop: 3])
        state.offlineMiningLevel = 20
        state.stats.lifetimeCoins = 1e11
        #expect(state.prestige(at: at(10)) > 0)
        #expect(state.offlineMiningLevel == 20)
        #expect(state.offlineCap == 3_600)
    }

    @Test func rewardIncomeHasAFloorAndIgnoresBoosts() {
        var state = GameState.make()
        #expect(state.rewardIncome == 1)
        state.miners = [.desktop: 50]
        state.boost = Boost(multiplier: 7, endsAt: at(60))
        #expect(approx(state.rewardIncome, 50 * MinerID.desktop.baseRate * 4))
    }

    @Test func multipliersStackMultiplicatively() {
        let state = GameState.make(upgrades: [.stepBooster, .upgradedStepBooster, .ultimateStepBooster,
                                              .bonusReward1, .bonusReward2, .bonusReward3])
        #expect(state.stepMultiplier == 12)
        #expect(state.miniGameMultiplier == 3.75)
    }
}

@Suite("Shop")
struct ShopTests {
    @Test func tiersRevealOneAtATime() {
        var state = GameState.make()
        #expect(state.isRevealed(.chromebook))
        #expect(!state.isRevealed(.desktop))
        state.miners[.chromebook] = 1
        #expect(state.isRevealed(.desktop))
        #expect(!state.isRevealed(.gpuRig))
    }

    @Test func upgradesRevealAtATenthOfTheirPrice() {
        var state = GameState.make()
        #expect(!state.isRevealed(.coinClicker))
        state.stats.runCoins = UpgradeID.coinClicker.cost * 0.1
        #expect(state.isRevealed(.coinClicker))
        #expect(!state.isRevealed(.upgradedClicker))
    }

    @Test func buyingMinersSpendsCoinsAndRecordsStats() {
        var state = GameState.make(coins: 300)
        #expect(state.buy(.chromebook, quantity: 2) == true)
        #expect(state.owned(.chromebook) == 2)
        #expect(state.coins == 300 - 213) // 99 + 113.85, rounded up.
        #expect(state.stats.spent == 213)
        #expect(state.stats.maxOwned[.chromebook] == 2)
        #expect(state.stats.maxTotalMiners == 2)
    }

    @Test func buyingFailsWithoutEnoughCoinsOrBeforeReveal() {
        var state = GameState.make(coins: 79)
        #expect(state.buy(.chromebook, quantity: 1) == false)
        #expect(state.coins == 79)
        state.coins = 1e9
        #expect(state.buy(.desktop, quantity: 1) == false)
        #expect(state.buy(.chromebook, quantity: 0) == false)
        #expect(state.buy(.chromebook, quantity: 100_000) == false) // Price overflows to infinity.
        #expect(state.coins == 1e9)
    }

    @Test func upgradesAreBoughtOnce() {
        var state = GameState.make(coins: 1_000)
        state.stats.runCoins = 1_000
        #expect(state.buy(.coinClicker) == true)
        #expect(state.buy(.coinClicker) == false)
        #expect(state.coins == 1_000 - UpgradeID.coinClicker.cost)
        #expect(state.stats.maxUpgrades == 1)
        #expect(state.buy(.upgradedClicker) == false) // Revealed, but costs more than is left.
    }

    @Test func miniGameUpgradesWaitForAGame() {
        var state = GameState.make(coins: 1e12)
        state.stats.runCoins = 1e12
        #expect(!state.isRevealed(.bonusReward1))
        let early = state.buy(.bonusReward1)
        #expect(!early)
        let unlocked = state.unlock(.blackjack)
        #expect(unlocked)
        #expect(state.isRevealed(.bonusReward1))
        let bought = state.buy(.bonusReward1)
        #expect(bought)
    }

    @Test func hiddenUpgradesCannotBeBought() {
        var state = GameState.make(coins: 1e12)
        #expect(state.buy(.dysonSwarm) == false)
    }

    @Test func miniGamesUnlockOnce() {
        var state = GameState.make(coins: 5_000)
        #expect(state.unlock(.blackjack) == true)
        #expect(state.isUnlocked(.blackjack))
        #expect(state.unlock(.blackjack) == false)
        #expect(state.unlock(.tetris) == false)
        #expect(state.coins == 5_000 - 2_056) // A list price of 1,000, about doubled for the opening's pace.
        #expect(MiniGame.tetris.unlockCost == 8_223)
    }

    @Test func tappingPaysAndRecords() {
        var state = GameState.make(upgrades: [.coinClicker])
        #expect(state.tap(count: 3, at: t0) == 6)
        #expect(state.coins == 6)
        #expect(state.stats.taps == 3)
        #expect(state.stats.bestTap == 2)
        #expect(state.stats.earnedFromTaps == 6)
        #expect(state.tap(count: 0, at: t0) == 0)
        #expect(state.stats.taps == 3)
    }
}
