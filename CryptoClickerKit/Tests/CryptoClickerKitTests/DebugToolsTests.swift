#if DEBUG
import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Testing tools")
struct DebugToolsTests {
    @Test func addedCoinsCountAsMined() {
        var game = GameState.make()
        game.debugAddCoins(2e10)
        #expect(game.coins == 2e10)
        #expect(game.stats.lifetimeCoins == 2e10)
        #expect(game.isRevealed(.solarFarm)) // Upgrades appear at a tenth of their price earned this run.
        #expect(game.claimablePrestigePoints == 1) // And a prestige becomes available.
        game.debugAddCoins(-5)
        game.debugAddCoins(.nan)
        #expect(game.coins == 2e10)
    }

    @Test func tokensMinersAndUpgradesAreFree() {
        var game = GameState.make(miners: [.desktop: 3])
        game.debugAddTokens(100)
        #expect(TokenID.allCases.allSatisfy { game.tokenCount($0) == 100 })
        game.debugAddMiners(10)
        #expect(game.owned(.desktop) == 13)
        #expect(game.owned(.spaceColony) == 10)
        #expect(game.owned(.galacticHashnet) == 10)
        #expect(game.stats.maxTotalMiners == 133)
        game.debugGiveAllUpgrades()
        #expect(game.upgrades.count == UpgradeID.allCases.count)
        #expect(game.coins == 0)
    }

    @Test func unlocksAndEvents() {
        var game = GameState.make()
        game.debugUnlockAllGames()
        #expect(MiniGame.allCases.allSatisfy(game.isUnlocked))
        game.debugUnlockSteps()
        #expect(game.areStepsUnlocked)
        game.debugStartBullRun(at: t0)
        #expect(game.activeBoost(at: at(30))?.multiplier == Tuning.bullRunMultiplier)
    }

    @Test func prestigePointsAndDailies() {
        var game = GameState.make()
        game.debugAddPrestigePoints(40)
        #expect(game.availablePrestigePoints == 40)
        #expect(approx(game.prestigeBonus, 3))
        game.refreshDaily(today: "2026-10-24", canWalk: false, at: t0)
        #expect(game.claimableQuestCount == 0)
        game.debugCompleteQuests()
        #expect(game.claimableQuestCount == 3)
        game.claimDailyReward(today: "2026-10-24", yesterday: "2026-10-23", at: t0)
        #expect(!game.isDailyRewardReady(today: "2026-10-24"))
        game.debugResetDaily(yesterday: "2026-10-23")
        #expect(game.isDailyRewardReady(today: "2026-10-24"))
        #expect(game.streakIfClaimed(today: "2026-10-24", yesterday: "2026-10-23") == 2) // The streak goes on.
        #expect(game.daily.quests.isEmpty)
    }

    @Test func offlineMiningLevelsStayInRange() {
        var game = GameState.make()
        game.debugAddOfflineMining(levels: 8)
        #expect(game.offlineCap == 4 * 3_600)
        game.debugAddOfflineMining(levels: 500)
        #expect(game.offlineMiningLevel == Tuning.offlineMiningMaxLevel)
        game.debugAddOfflineMining(levels: -1_000)
        #expect(game.offlineMiningLevel == 0)
    }

    @Test func rewindingPaysTimeAwayWithAReport() throws {
        var game = GameState.make(miners: [.desktop: 10]) // 20 coins per second.
        game.debugAddOfflineMining(levels: 2) // An hour.
        game.debugRewind(3_600)
        let result = game.advance(to: t0)
        let report = try #require(result)
        #expect(report.elapsed == 3_600)
        #expect(approx(game.coins, 72_000))
    }

    @Test func rewindingKeepsABullRunToTheTimeItHadLeft() throws {
        var game = GameState.make(miners: [.desktop: 10])
        game.debugAddOfflineMining(levels: 2)
        game.debugStartBullRun(at: t0)
        game.debugRewind(3_600)
        let result = game.advance(to: t0)
        let report = try #require(result)
        // The boost covers only its own duration at the start of the hour, then ends.
        let boosted = Tuning.bullRunDuration
        let expected = 20 * (3_600 - boosted) + 20 * Tuning.bullRunMultiplier * boosted
        #expect(approx(report.earned, expected))
        #expect(game.activeBoost(at: t0) == nil)
    }
}
#endif
