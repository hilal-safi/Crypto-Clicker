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
        // A list price of 40, nearly doubled for the opening's pace (×1.8975), 20% more for the
        // opening, then 10% off (91.08 × 0.9 = 81.97, rounded up).
        #expect(MinerID.chromebook.baseCost == 82)
        #expect(state.price(of: .chromebook, quantity: 1) == 165) // 82 × 1.15⁵ = 164.93
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
        #expect(state.maxAffordable(.chromebook, budget: 81.99) == 0)
        #expect(state.maxAffordable(.chromebook, budget: 0) == 0)
        #expect(state.maxAffordable(.chromebook, budget: .infinity) == 0)
        #expect(state.maxAffordable(.chromebook, budget: .nan) == 0)
        let count = state.maxAffordable(.chromebook, budget: 1e30)
        #expect(count == 449)
        #expect(state.price(of: .chromebook, quantity: count) <= 1e30)
        #expect(state.price(of: .chromebook, quantity: count + 1) > 1e30)
    }

    @Test func maxAffordableUsesTheBalanceByDefault() {
        let state = GameState.make(coins: 410)
        // 82 + 94.3 + 108.45 + 124.71 = 409.46, rounded up to 410; a fifth unit would make it 553.
        #expect(state.maxAffordable(.chromebook) == 4)
        #expect(state.price(of: .chromebook, quantity: 4) == 410)
        #expect(state.price(of: .chromebook, quantity: 5) == 553)
    }
}

@Suite("Production")
struct ProductionTests {
    @Test func milestonesDoubleOutput() {
        // Every 25 up to 250 (10), every 50 up to 1,000 (15), every 100 up to 5,000 (40).
        #expect(Tuning.milestones.count == 65)
        #expect(Tuning.milestones.first == 25)
        #expect(Tuning.milestones.last == 5_000)
        #expect(GameState.milestoneMultiplier(owned: 0) == 1)
        #expect(GameState.milestoneMultiplier(owned: 24) == 1)
        #expect(GameState.milestoneMultiplier(owned: 25) == 2)
        #expect(GameState.milestoneMultiplier(owned: 49) == 2)
        #expect(GameState.milestoneMultiplier(owned: 50) == 4)
        #expect(GameState.milestoneMultiplier(owned: 75) == 8)
        #expect(GameState.milestoneMultiplier(owned: 100) == 16)
        #expect(GameState.milestoneMultiplier(owned: 200) == 256)
        #expect(GameState.milestoneMultiplier(owned: 250) == 1_024)
        #expect(GameState.milestoneMultiplier(owned: 299) == 1_024)
        #expect(GameState.milestoneMultiplier(owned: 300) == 2_048)
        #expect(GameState.milestoneMultiplier(owned: 349) == 2_048)
        #expect(GameState.milestoneMultiplier(owned: 350) == 4_096)
        #expect(GameState.milestoneMultiplier(owned: 500) == 32_768)
        #expect(GameState.milestoneMultiplier(owned: 1_000) == 33_554_432)
        #expect(GameState.milestoneMultiplier(owned: 1_099) == 33_554_432)
        #expect(GameState.milestoneMultiplier(owned: 1_100) == 67_108_864)
        #expect(GameState.milestoneMultiplier(owned: 5_000) == 0x1p65)
        #expect(GameState.milestoneMultiplier(owned: 10_000) == 0x1p65)
        // The gap is 25 owned through 250, 50 through 1,000 and 100 after that.
        for (previous, next) in zip(Tuning.milestones, Tuning.milestones.dropFirst()) {
            #expect(next - previous == (next <= 250 ? 25 : next <= 1_000 ? 50 : 100))
        }
    }

    @Test func nextMilestone() {
        #expect(GameState.make().nextMilestone(for: .server) == 25)
        #expect(GameState.make(miners: [.server: 25]).nextMilestone(for: .server) == 50)
        #expect(GameState.make(miners: [.server: 76]).nextMilestone(for: .server) == 100)
        #expect(GameState.make(miners: [.server: 250]).nextMilestone(for: .server) == 300)
        #expect(GameState.make(miners: [.server: 300]).nextMilestone(for: .server) == 350)
        #expect(GameState.make(miners: [.server: 1_000]).nextMilestone(for: .server) == 1_100)
        #expect(GameState.make(miners: [.server: 5_000]).nextMilestone(for: .server) == nil)
    }

    @Test func rateCombinesCountMilestonesAndMultipliers() {
        var state = GameState.make(miners: [.chromebook: 25], upgrades: [.overclocking, .fiberUplink])
        #expect(approx(state.rate(of: .chromebook), 25 * 0.25 * 2 * 1.25 * 2)) // A Chromebook earns a coin every four seconds.
        state.prestigePoints = 4
        state.achievementTiers = ["miner": 3, "tapper": 2]
        state.difficulty = .easy
        let expected = 25 * 0.25 * 2 * 1.25 * 2 * 1.2 * 1.05 * 1.5
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
        // A tap is 1 + 10% of 20 = 3 coins, and an automatic tap earns half of that.
        #expect(Tuning.autoTapStrength == 0.5)
        #expect(approx(state.idleIncome(at: t0), 20 + 2 * 0.5 * 3))
        #expect(approx(state.baseIdleIncome, 20 + 2 * 0.5 * 3))
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
        // The game starts with six minutes of time away; each level pays for more.
        #expect(Tuning.baseAwayTime == 6 * 60)
        #expect(GameState.make().timeAwayLimit == 6 * 60)
        #expect(GameState.offlineCap(level: 1) == 7 * 60) // The first level adds a minute...
        #expect(GameState.offlineCap(level: 2) == 8 * 60)
        #expect(GameState.offlineCap(level: 4) == 10 * 60) // ...a minute a level to 10 minutes...
        #expect(GameState.offlineCap(level: 5) == 15 * 60) // ...then 5 minutes to an hour...
        #expect(GameState.offlineCap(level: 14) == 3_600)
        #expect(GameState.offlineCap(level: 15) == 75 * 60) // ...15 minutes to 3 hours...
        #expect(GameState.offlineCap(level: 22) == 3 * 3_600)
        #expect(GameState.offlineCap(level: 23) == 3.5 * 3_600) // ...then half an hour.
        #expect(GameState.offlineCap(level: 36) == 10 * 3_600)
        #expect(GameState.offlineCap(level: 64) == 24 * 3_600)
        #expect(Tuning.offlineMiningMaxLevel == 160)
        #expect(GameState.offlineCap(level: Tuning.offlineMiningMaxLevel) == 72 * 3_600)
        #expect(GameState.offlineCap(level: 500) == 72 * 3_600)
        #expect(GameState.offlineCap(level: -3) == 0)
        // Each limit belongs to exactly one level.
        for level in 0...Tuning.offlineMiningMaxLevel {
            #expect(GameState.offlineMiningLevel(reaching: GameState.offlineCap(level: level)) == level)
        }
        #expect(GameState.offlineMiningLevel(reaching: 12 * 60) == 5) // Rounds up to the next level.
        #expect(GameState.offlineMiningLevel(reaching: 2 * 60) == 0) // The table's first five levels are gone:
        #expect(GameState.offlineMiningLevel(reaching: 6 * 60) == 0) // the game starts with six minutes.
        #expect(GameState.offlineMiningLevel(reaching: 7 * 60) == 1)
        #expect(GameState.offlineMiningLevel(reaching: 1e9) == Tuning.offlineMiningMaxLevel)
        // From the first level on, each one pays the same time as the whole table's level five on.
        for level in 1...Tuning.offlineMiningMaxLevel {
            #expect(GameState.offlineCap(level: level) == GameState.tableCap(level: level + 5), "level \(level)")
        }
        #expect(GameState.tableCap(level: 1) == 2 * 60 && GameState.tableCap(level: 5) == 6 * 60)
        #expect(GameState.tableCap(level: 6) == 7 * 60)
    }

    @Test func offlineMiningLevelsCostMoreEachTimeAndStopAtTheMaximum() {
        var state = GameState.make(coins: 1_000)
        // The first level (seven minutes) costs 10,000, where the table (3,500 and 40% more five
        // times, less 10%) would charge 16,942: the first ten levels are marked down, the first
        // the most. The second costs 14,817.
        #expect(state.offlineMiningPrice == 10_000)
        state.coins = 1_000
        #expect(state.buyOfflineMining() == false) // Can't afford it yet.
        let secondPrice = GameState.offlineMiningShopPrice(level: 2)
        #expect(secondPrice == 14_817)
        state.coins = 10_000 + secondPrice + 100
        let first = state.buyOfflineMining()
        #expect(first)
        #expect(state.offlineMiningLevel == 1)
        #expect(state.offlineCap == 7 * 60)
        #expect(state.offlineMiningPrice == secondPrice)
        let second = state.buyOfflineMining()
        #expect(second)
        #expect(state.coins == 100)
        #expect(state.offlineCap == 8 * 60)
        // The Shop's levels cost what the same time away costs in the whole table, less 10%
        // (35% more a level from the eleventh, to three and a half hours at table level 28, Shop
        // level 23), in whole coins. The first ten are marked down, more the earlier they are.
        let cut = Tuning.offlineMiningPriceCut
        #expect(cut == 0.9)
        let price = GameState.offlineMiningShopPrice(level:)
        let unscaled = GameState.offlineMiningUnscaledPrice(level:)
        #expect(price(1) == 10_000)
        #expect(abs(GameState.offlineMiningOpeningScale(level: 10) - 0.9) < 1e-12)
        for level in 1...10 {
            #expect(price(level) < unscaled(level), "level \(level)")
            #expect(GameState.offlineMiningOpeningScale(level: level) < 1, "level \(level)")
            if level > 1 {
                #expect(GameState.offlineMiningOpeningScale(level: level) > GameState.offlineMiningOpeningScale(level: level - 1))
            }
        }
        #expect([1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(price)
                == [10_000, 14_817, 21_886, 32_240, 47_376, 66_981, 94_506, 133_093, 187_115, 262_649])
        for level in 11...23 {
            let table = level + 5
            #expect(GameState.offlineMiningOpeningScale(level: level) == 1, "level \(level)")
            #expect(price(level) == Tuning.whole(3_500 * pow(1.4, Double(min(table, 10) - 1)) * pow(1.35, Double(max(0, table - 10))) * cut),
                    "level \(level)")
            if level > 11 { #expect(abs(price(level) / price(level - 1) - 1.35) < 0.001, "level \(level)") }
        }
        #expect(price(11) == 393_973)
        #expect(price(23) == 14_436_793)
        // From here on, `tablePrice` is the Shop's price for a level of the whole table (five
        // more than the Shop's).
        let tablePrice: (Int) -> Double = { price($0 - 5) }
        // After that each level is as many times the one before as on the curve, which is 20% over
        // the curve to table level 30 and 10% after (but see the easing below), less 15% off for
        // levels 31 to 50, 10% to 80 and 5% after, and 10% off all of it.
        let list = GameState.offlineMiningListPrice(level:)
        let curve = GameState.offlineMiningCurvePrice(level:)
        let discount: (Int) -> Double = { $0 <= 30 ? 1 : $0 <= 50 ? 0.85 : $0 <= 80 ? 0.9 : 0.95 }
        // From level 42 to 50 the step eases from 45% by 0.27/38 a level instead.
        let eased: (Int) -> Double? = { (42...50).contains($0) ? 1.45 - 0.27 * Double($0 - 42) / 38 : nil }
        for level in 29...50 {
            let step = (eased(level) ?? list(level) / list(level - 1)) * discount(level) / discount(level - 1)
            #expect(abs(tablePrice(level) / tablePrice(level - 1) - step) < 1e-6, "level \(level)")
        }
        #expect(tablePrice(50) == 8_153_249_141_964) // Fourteen and a half hours (9,059,165,713,293 less 10%).
        // Then it keeps easing to level 105 and holds, so the last level costs 180 sextillion.
        let full: (Int) -> Double = { tablePrice($0) / discount($0) / cut }
        let steps = (51...Tuning.offlineMiningTableLevels).map { full($0) / full($0 - 1) }
        #expect(abs(steps[0] - (1.45 - 0.27 * 9 / 38)) < 1e-9) // Carries on from the first easing.
        #expect(zip(steps, steps.dropFirst()).prefix(54).allSatisfy { $0 > $1 }) // Gentler each level to 105.
        #expect(steps.suffix(60).allSatisfy { abs($0 - steps[54]) < 1e-9 }) // Then steady.
        #expect((1.17...1.2).contains(steps[54])) // About 18%.
        #expect(abs(price(Tuning.offlineMiningMaxLevel) / (2e23 * cut) - 1) < 1e-9)
        #expect(tablePrice(30) == 70_723_791) // Full price (78,581,989 less 10%).
        #expect(tablePrice(31) == 121_967_270) // 15% off (135,519,188 less 10%).
        for level in 28...Tuning.offlineMiningTableLevels {
            #expect(approx(list(level), curve(level) * (level <= 30 ? 1.2 : 1.1)), "level \(level)")
        }
        // Every level costs more than the one before.
        #expect((1...Tuning.offlineMiningMaxLevel - 1).allSatisfy { price($0 + 1) > price($0) })
        #expect(approx(GameState.offlineMiningListPrice(level: 41), 1.3e11 * 1.1)) // Ten hours.
        #expect(approx(GameState.offlineMiningListPrice(level: 69), 1e16 * 1.1)) // A day.
        #expect(approx(GameState.offlineMiningListPrice(level: Tuning.offlineMiningTableLevels), 1e23 * 1.1)) // Three days.
        state.offlineMiningLevel = Tuning.offlineMiningMaxLevel
        state.coins = 1e300
        #expect(state.offlineMiningPrice == nil)
        #expect(state.buyOfflineMining() == false)
        #expect(state.offlineMiningLevel == Tuning.offlineMiningMaxLevel)
    }

    @Test func aPrestigeKeepsOfflineMining() {
        var state = GameState.make(coins: 5, miners: [.desktop: 3])
        state.offlineMiningLevel = 14
        state.powerUps[.offlineEfficiency] = 6
        state.stats.lifetimeCoins = 1e11
        #expect(state.prestige(at: at(10)) > 0)
        #expect(state.offlineMiningLevel == 14)
        #expect(state.offlineCap == 3_600)
        #expect(state.powerUpLevel(.offlineEfficiency) == 6) // Power-ups stay after a prestige.
        #expect(approx(state.offlineEfficiency, 0.4))
    }

    @Test func offlineEfficiencyIsTheFirstPowerUpSoTheShopListsItUnderOfflineMining() {
        #expect(PowerUpID.allCases.first == .offlineEfficiency)
        #expect(Array(PowerUpID.allCases.dropFirst()) == [.comboBooster, .comboOverdrive, .quickCombos, .comboKeeper])
    }

    @Test func offlineEfficiencyStartsAtATenthAndAddsFivePercentPerLevel() {
        var state = GameState.make()
        #expect(state.offlineEfficiency == 0.1)
        #expect(PowerUpID.offlineEfficiency.maxLevel == 18)
        for level in 0...18 {
            state.powerUps[.offlineEfficiency] = level
            #expect(approx(state.offlineEfficiency, Double(10 + 5 * level) / 100), "level \(level)")
            #expect(Tuning.offlineEfficiencyPercent(level: level) == 10 + 5 * level)
        }
        #expect(state.offlineEfficiency == 1) // Level 18 pays all of it.
        #expect(Tuning.offlineEfficiencyPercent(level: 40) == 100) // Never more than all.
        #expect(Tuning.offlineEfficiencyPercent(level: -2) == 10)
        // The Shop draws no bar per level for it (there would be too many).
        #expect(!PowerUpID.offlineEfficiency.showsLevelPips)
        #expect(PowerUpID.comboBooster.showsLevelPips)
        // A gap under a minute is live play, paid in full; time away pays the share.
        #expect(Tuning.awayPaidSeconds(30, efficiency: 0.1) == 30)
        #expect(Tuning.awayPaidSeconds(59, efficiency: 0.1) == 59)
        #expect(approx(Tuning.awayPaidSeconds(60, efficiency: 0.1), 6))
        #expect(approx(Tuning.awayPaidSeconds(3_600, efficiency: 0.1), 360))
        #expect(approx(Tuning.awayPaidSeconds(3_600, efficiency: 1), 3_600))
        #expect(approx(state.paidAwaySeconds(7_200), 7_200))
    }

    @Test func offlineEfficiencyIsBoughtInEighteenLevelsAtTheShopsPrices() {
        // 15,000 for the first (15%) to 1.2 quadrillion for the 18th (all of it); the even levels
        // are set prices, the odd ones sit between; no pace or premium.
        let prices: [Double] = [15_000, 75_000, 250_000, 3_000_000, 8_500_000, 25_000_000,
                                110_000_000, 500_000_000, 1_500_000_000, 5_000_000_000, 20_000_000_000,
                                85_000_000_000, 290_000_000_000, 1_000_000_000_000, 7_500_000_000_000,
                                56_000_000_000_000, 340_000_000_000_000, 1_200_000_000_000_000]
        #expect(Tuning.offlineEfficiencyPrices == prices)
        #expect(prices.count == 18)
        for (level, expected) in prices.enumerated() {
            #expect(PowerUpID.offlineEfficiency.shopPrice(afterLevel: level) == expected, "level \(level + 1)")
        }
        // The levels that were set one by one.
        let set: [Int: Double] = [1: 15_000, 2: 75_000, 3: 250_000, 4: 3_000_000, 6: 25_000_000, 8: 500_000_000,
                                  10: 5_000_000_000, 12: 85_000_000_000, 14: 1_000_000_000_000,
                                  16: 56_000_000_000_000, 17: 340_000_000_000_000, 18: 1_200_000_000_000_000]
        for (level, price) in set { #expect(prices[level - 1] == price, "level \(level)") }
        // Every level costs more than the one before, and the odd ones in between sit between
        // their neighbours.
        #expect(zip(prices, prices.dropFirst()).allSatisfy { $0 < $1 })
        #expect(prices.reduce(0, +) == 1_604_902_146_840_000) // All 18 levels.
        // It shows in the Shop from the start of the game (the six minutes away are paid at its
        // share), once lifetime coins reach a tenth of its first price.
        var state = GameState.make(coins: 2e15)
        #expect(!state.isRevealed(.offlineEfficiency))
        state.stats.lifetimeCoins = 1_499
        #expect(!state.isRevealed(.offlineEfficiency))
        state.stats.lifetimeCoins = 1_500
        #expect(state.isRevealed(.offlineEfficiency))
        #expect(state.offlineMiningLevel == 0) // No Offline Mining needed.
        for (level, price) in prices.enumerated() {
            let before = state.coins
            let bought = state.buyPowerUp(.offlineEfficiency)
            #expect(bought, "level \(level + 1)")
            #expect(state.coins == before - price)
            #expect(state.powerUpLevel(.offlineEfficiency) == level + 1)
            #expect(approx(state.offlineEfficiency, Double(15 + 5 * level) / 100), "level \(level + 1)")
        }
        #expect(state.powerUpLevel(.offlineEfficiency) == 18)
        let boughtPastTheEnd = state.buyPowerUp(.offlineEfficiency)
        #expect(!boughtPastTheEnd) // Nothing after the 18th.
        #expect(state.offlineEfficiency == 1)
    }

    @Test func rewardIncomeHasAFloorAndIgnoresBoosts() {
        var state = GameState.make()
        #expect(state.rewardIncome == 1)
        state.miners = [.desktop: 50]
        state.boost = Boost(multiplier: 7, endsAt: at(60))
        #expect(approx(state.rewardIncome, 50 * MinerID.desktop.baseRate * 4))
    }

    @Test func multipliersStackMultiplicatively() {
        let state = GameState.make(upgrades: [.stepBooster, .upgradedStepBooster, .ultimateStepBooster, .proofOfStride, .megaStepBooster,
                                              .gigaStepBooster, .bonusReward1, .bonusReward2, .bonusReward3])
        #expect(state.stepMultiplier == 202.5) // 1.25 × 1.5 × 2 × 3 × 3 × 6
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
        #expect(state.coins == 300 - 177) // 82 + 94.3, rounded up.
        #expect(state.stats.spent == 177)
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
        #expect(state.coins == 5_000 - 1_898) // A list price of 1,000, about 1.9 times that for the opening's pace.
        #expect(MiniGame.tetris.unlockCost == 7_590)
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
