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
        #expect(MinerID.chromebook.baseCost == 103) // A list price of 50, about doubled for the opening's pace.
        #expect(state.price(of: .chromebook, quantity: 1) == 208) // 103 × 1.15⁵ = 207.17
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
        #expect(state.maxAffordable(.chromebook, budget: 102.99) == 0)
        #expect(state.maxAffordable(.chromebook, budget: 0) == 0)
        #expect(state.maxAffordable(.chromebook, budget: .infinity) == 0)
        #expect(state.maxAffordable(.chromebook, budget: .nan) == 0)
        let count = state.maxAffordable(.chromebook, budget: 1e30)
        #expect(count == 447)
        #expect(state.price(of: .chromebook, quantity: count) <= 1e30)
        #expect(state.price(of: .chromebook, quantity: count + 1) > 1e30)
    }

    @Test func maxAffordableUsesTheBalanceByDefault() {
        let state = GameState.make(coins: 515)
        // 103 + 118.45 + 136.22 + 156.65 = 514.32, rounded up to 515; a fifth unit would make it 695.
        #expect(state.maxAffordable(.chromebook) == 4)
        #expect(state.price(of: .chromebook, quantity: 4) == 515)
        #expect(state.price(of: .chromebook, quantity: 5) == 695)
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
        #expect(approx(state.rate(of: .chromebook), 25 * 0.5 * 2 * 1.75 * 2)) // A Chromebook earns a coin every two seconds.
        state.prestigePoints = 4
        state.achievementTiers = ["miner": 3, "tapper": 2]
        state.difficulty = .easy
        let expected = 25 * 0.5 * 2 * 1.75 * 2 * 1.2 * 1.05 * 1.5
        #expect(approx(state.rate(of: .chromebook), expected))
        #expect(approx(state.baseProduction, expected))
        #expect(state.rate(of: .desktop) == 0)
    }

    @Test func difficultyScalesProduction() {
        var state = GameState.make(miners: [.desktop: 10])
        state.difficulty = .hard
        #expect(approx(state.baseProduction, 10 * 1 * 0.6))
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
        let state = GameState.make(miners: [.desktop: 20], upgrades: [.coinClicker, .upgradedClicker, .mechanicalKeyboard])
        // Production 20/s; taps earn 1 + 1 flat and 20% of a second's production: 2 + 4 = 6 coins.
        #expect(state.tapValue(at: t0) == 6)
        let quarter = GameState.make(miners: [.desktop: 8], upgrades: [.upgradedClicker])
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
        let state = GameState.make(miners: [.desktop: 20], upgrades: [.automatedClicker, .roboticFinger, .upgradedClicker])
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

    @Test func offlineMiningAddsHalfHoursUpToADayThenHours() {
        #expect(GameState.make().offlineCap == 0)
        #expect(GameState.offlineCap(level: 1) == 30 * 60)
        #expect(GameState.offlineCap(level: 2) == 3_600)
        #expect(GameState.offlineCap(level: 47) == 23.5 * 3_600)
        #expect(GameState.offlineCap(level: 48) == 24 * 3_600)
        #expect(GameState.offlineCap(level: 49) == 25 * 3_600)
        #expect(GameState.offlineCap(level: 50) == 26 * 3_600)
        #expect(GameState.offlineCap(level: Tuning.offlineMiningMaxLevel) == 72 * 3_600)
        #expect(GameState.offlineCap(level: 500) == 72 * 3_600)
        #expect(GameState.offlineCap(level: -3) == 0)
    }

    @Test func offlineMiningLevelsCostMoreEachTimeAndStopAtTheMaximum() {
        var state = GameState.make(coins: 1_000)
        #expect(state.offlineMiningPrice == 3_084) // A list price of 1,500, about doubled for the opening's pace.
        #expect(state.buyOfflineMining() == false) // Can't afford it yet.
        state.coins = 3_084 + 4_626 + 100
        let first = state.buyOfflineMining()
        #expect(first)
        #expect(state.offlineMiningLevel == 1)
        #expect(state.offlineCap == 30 * 60)
        #expect(state.offlineMiningPrice == 4_626) // 2,250 × 2.055625, rounded up.
        let second = state.buyOfflineMining()
        #expect(second)
        #expect(state.coins == 100)
        #expect(state.stats.spent == 7_710)
        state.offlineMiningLevel = Tuning.offlineMiningMaxLevel
        state.coins = 1e300
        #expect(state.offlineMiningPrice == nil)
        #expect(state.buyOfflineMining() == false)
        #expect(state.offlineMiningLevel == Tuning.offlineMiningMaxLevel)
    }

    @Test func aPrestigeKeepsOfflineMining() {
        var state = GameState.make(coins: 5, miners: [.desktop: 3])
        state.offlineMiningLevel = 12
        state.stats.lifetimeCoins = 1e11
        #expect(state.prestige(at: at(10)) > 0)
        #expect(state.offlineMiningLevel == 12)
        #expect(state.offlineCap == 6 * 3_600)
    }

    @Test func rewardIncomeHasAFloorAndIgnoresBoosts() {
        var state = GameState.make()
        #expect(state.rewardIncome == 1)
        state.miners = [.desktop: 50]
        state.boost = Boost(multiplier: 7, endsAt: at(60))
        #expect(approx(state.rewardIncome, 50 * 1 * 4))
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
        #expect(state.coins == 300 - 222) // 103 + 118.45, rounded up.
        #expect(state.stats.spent == 222)
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
