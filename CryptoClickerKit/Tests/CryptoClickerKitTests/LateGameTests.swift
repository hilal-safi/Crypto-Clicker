import Foundation
import Testing
@testable import CryptoClickerKit

/// The late game with every multiplier at once, which the pacing tests (a few weeks of casual play)
/// never reach: every tier at a thousand with every Mk, full Legacy, every upgrade, every achievement
/// star with Compound Interest, every perk, a million prestige points and a Bull Run.
@Suite("Late game")
struct LateGameTests {
    func maxedGame() -> GameState {
        var game = GameState.make(miners: Dictionary(uniqueKeysWithValues: MinerID.allCases.map { ($0, 1_000) }),
                                  upgrades: Set(UpgradeID.allCases))
        game.minerUpgrades = Dictionary(uniqueKeysWithValues: MinerID.allCases.map { ($0, Tuning.minerUpgradeThresholds.count) })
        game.debugEarnAllAchievements()
        game.perks = Set(PerkID.allCases)
        game.prestigePoints = 1_000_000
        game.offlineMiningLevel = Tuning.offlineMiningMaxLevel
        game.boost = Boost(multiplier: 7, endsAt: t0.addingTimeInterval(60))
        return game
    }

    @Test func everyMultiplierTogetherStaysFiniteAndInOrder() {
        let game = maxedGame()
        // Legacy reaches the oldest tiers: the Chromebook has every tier four or more above it.
        #expect(game.legacyTiers(for: .chromebook) == MinerID.allCases.count - Tuning.legacyTierGap)
        #expect(game.legacyTiers(for: .galacticHashnet) == 0)
        // Huge, but finite and positive, and the newest tier still earns the most.
        for value in [game.baseProduction, game.baseIdleIncome, game.idleIncome(at: t0), game.tapValue(at: t0),
                      game.globalMultiplier, game.achievementBonus, game.prestigeBonus] {
            #expect(value.isFinite && value > 0)
        }
        #expect(game.rate(of: .galacticHashnet) > game.rate(of: .chromebook))
        #expect(game.idleIncome(at: t0) > game.baseIdleIncome) // The Bull Run counts.
        // Every price is still a finite whole number, so the Shop can show it and buy.
        for miner in MinerID.allCases {
            let price = game.price(of: miner, quantity: 1)
            #expect(price.isFinite && price == price.rounded(), "\(miner)")
        }
        #expect(game.offlineMiningPrice == nil) // Bought to the end.
    }

    @Test func aMaxedGameStillBuysAndSaves() throws {
        var game = maxedGame()
        game.coins = 1e300
        let price = game.price(of: .galacticHashnet, quantity: 1)
        let bought = game.buy(.galacticHashnet, quantity: 1)
        #expect(bought)
        #expect(game.owned(.galacticHashnet) == 1_001)
        #expect(game.coins == 1e300 - price)
        let saved = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(saved.baseProduction == game.baseProduction)
        #expect(saved.prestigePoints == game.prestigePoints)
        #expect(saved.earnedAchievementTiers == AchievementCatalog.tierCount)
        #expect(saved.coins == game.coins)
    }
}
