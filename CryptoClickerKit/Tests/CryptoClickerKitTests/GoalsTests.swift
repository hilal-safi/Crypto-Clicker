import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Goals")
struct GoalsTests {
    func goal(_ kind: Goal.Kind, in game: GameState) -> Goal? {
        game.nextGoals.first { $0.kind == kind }
    }

    @Test func aNewGameAimsForTheFirstMinerAndTheFirstPrestigePoint() throws {
        let game = GameState.make(coins: 20)
        let first = try #require(game.nextGoals.first)
        #expect(first.kind == .miner)
        #expect(first.title == "Buy a Chromebook")
        #expect(abs(first.progress - 20 / game.price(of: .chromebook, quantity: 1)) < 1e-9)
        let prestige = try #require(goal(.prestige, in: game))
        #expect(prestige.title == "Your first prestige point")
        // No milestone or Arcade Rank before there's a miner or a game, and no arcade achievement.
        #expect(goal(.milestone, in: game) == nil)
        #expect(goal(.arcadeRank, in: game) == nil)
        let star = try #require(goal(.achievement, in: game))
        let arcadeNames = AchievementCatalog.all.filter { AchievementCatalog.arcadeIDs.contains($0.id) }.map(\.name)
        #expect(!arcadeNames.contains { star.title.hasSuffix(": \($0)") })
    }

    @Test func theNextTierFollowsTheOneBefore() throws {
        let game = GameState.make(miners: [.chromebook: 5])
        let next = try #require(goal(.miner, in: game))
        #expect(next.title == "Buy a Desktop")
        let early = MinerID.allCases.filter { !$0.needsPrestige }
        let everything = GameState.make(miners: Dictionary(uniqueKeysWithValues: early.map { ($0, 1) }))
        let firstLocked = MinerID.allCases.first { $0.needsPrestige }
        let locked = try #require(firstLocked)
        let reveal = try #require(goal(.miner, in: everything))
        #expect(reveal.title == "Prestige to reveal the \(locked.name)")
    }

    @Test func theNearestMilestoneIsTheGoal() throws {
        let game = GameState.make(miners: [.chromebook: 22, .desktop: 3])
        let milestone = try #require(goal(.milestone, in: game))
        #expect(milestone.title == "Own 25 Chromebooks")
        #expect(milestone.detail == "3 more doubles what they mine")
        #expect(abs(milestone.progress - 22.0 / 25) < 1e-9)
        // Past the first, progress counts from the milestone before.
        let further = GameState.make(miners: [.chromebook: 40])
        let next = try #require(goal(.milestone, in: further))
        #expect(next.title == "Own 50 Chromebooks")
        #expect(abs(next.progress - 15.0 / 25) < 1e-9)
    }

    @Test func prestigeGoalsFollowTheShopsSuggestion() throws {
        let cube = { (points: Double) in points * points * points * Tuning.prestigeScale }
        var game = GameState.make()
        #expect(game.prestigePointsToRecommend == 10)
        game.stats.lifetimeCoins = cube(5)
        game.stats.runCoins = cube(5)
        let partway = try #require(goal(.prestige, in: game))
        #expect(partway.title == "A prestige worth 10 points")
        #expect(abs(partway.progress - 0.5) < 1e-9)
        game.stats.lifetimeCoins = cube(12)
        game.stats.runCoins = cube(12)
        #expect(game.isPrestigeRecommended)
        let ready = try #require(goal(.prestige, in: game))
        #expect(ready.title == "Prestige for 12 points")
        #expect(ready.progress == 1)
        // After a prestige, the suggestion asks for more: 10 plus half the points held.
        var later = GameState.make()
        later.prestigePoints = 30
        #expect(later.prestigePointsToRecommend == 25)
    }

    @Test func goalsAreOneOfEachKindWithProgressInRange() {
        var late = GameState.make(coins: 1e15, miners: [.chromebook: 120, .desktop: 80, .gpuRig: 60, .server: 30])
        late.unlockedGames = [.blackjack, .tetris]
        late.stats.lifetimeCoins = 1e15
        for game in [GameState.make(), GameState.make(coins: 1e9, miners: [.chromebook: 30, .desktop: 12]), late] {
            let goals = game.nextGoals
            #expect(!goals.isEmpty)
            #expect(Set(goals.map(\.id)).count == goals.count)
            #expect(goals.allSatisfy { (0...1).contains($0.progress) })
            #expect(goals.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
        }
        #expect(goal(.arcadeRank, in: late) != nil)
    }
}
