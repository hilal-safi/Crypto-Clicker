import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Starter milestones")
struct StarterMilestoneTests {
    @Test func aNewGameHasNothingReachedOrClaimed() {
        let game = GameState.make()
        for milestone in StarterMilestone.allCases {
            #expect(!game.isReached(milestone), "\(milestone)")
            #expect(!game.isClaimed(milestone), "\(milestone)")
        }
        #expect(game.claimableStarterMilestones.isEmpty)
        #expect(game.hasUnclaimedStarterMilestones)
    }

    @Test func eachMilestoneIsReachedByItsStep() {
        var game = GameState.make(coins: 10_000)
        game.buy(.chromebook, quantity: 1)
        #expect(game.isReached(.firstChromebook))
        #expect(!game.isReached(.threeMiners))
        #expect(abs(game.progress(of: .threeMiners) - 1.0 / 3) < 1e-9)
        game.buy(.chromebook, quantity: 2)
        #expect(game.isReached(.threeMiners))
        #expect(game.progress(of: .threeMiners) == 1)

        #expect(!game.isReached(.firstUpgrade))
        game.upgrades = [.coinClicker]
        #expect(game.isReached(.firstUpgrade))

        #expect(!game.isReached(.firstGameUnlocked))
        game.unlockedGames = [.snake]
        #expect(game.isReached(.firstGameUnlocked))

        #expect(!game.isReached(.firstGamePlayed))
        game.stats.snakeGames = 1
        #expect(game.isReached(.firstGamePlayed))
        #expect(game.claimableStarterMilestones == StarterMilestone.allCases)
    }

    @Test func theChromebookMilestoneShowsHowCloseTheCoinsAre() {
        let game = GameState.make(coins: 20)
        let price = game.price(of: .chromebook, quantity: 1)
        #expect(abs(game.progress(of: .firstChromebook) - 20 / price) < 1e-9)
    }

    @Test func claimingPaysOnceAndOnlyWhenReached() {
        var game = GameState.make(miners: minersEarning(10)) // 10 coins per second.
        #expect(game.claim(.firstUpgrade, at: t0) == nil) // Not reached.
        #expect(game.coins == 0)
        game.upgrades = [.coinClicker]
        // 360 seconds of income.
        #expect(game.claim(.firstUpgrade, at: t0) == .coins(3_600))
        #expect(game.coins == 3_600)
        #expect(game.stats.lifetimeCoins == 3_600)
        #expect(game.isClaimed(.firstUpgrade))
        #expect(game.claim(.firstUpgrade, at: t0) == nil) // Once only.
        #expect(game.coins == 3_600)
        // The miners behind the income also reach "own three miners", which is still to claim.
        #expect(!game.claimableStarterMilestones.contains(.firstUpgrade))
        #expect(game.claimableStarterMilestones == [.threeMiners])
    }

    @Test func rewardsAreSecondsOfIncomeWithTheDailyFloorOnDayOne() {
        let game = GameState.make() // No income yet: the reward income floor is 1 coin a second.
        #expect(game.payout(of: .firstChromebook) == .coins(90))
        #expect(game.payout(of: .threeMiners) == .coins(180))
        #expect(game.payout(of: .firstUpgrade) == .coins(360))
        #expect(game.payout(of: .firstGamePlayed) == .coins(540))
        #expect(game.payout(of: .firstGameUnlocked) == .bullRun(seconds: 20))
        #expect(StarterPayout.coins(90).text == "90 coins")
    }

    @Test func theyPayAboutAThirdOfWhatTheDailyRewardsPay() {
        // The first login reward pays 300 seconds of income, the day's three quests 600, 1,200 and
        // 1,800, and the daily Bull Run lasts a minute.
        let daily: [StarterMilestone: Double] = [.firstChromebook: 300, .threeMiners: 600, .firstUpgrade: 1_200,
                                                 .firstGamePlayed: 1_800]
        for (milestone, dailySeconds) in daily {
            guard case .coins(let seconds) = milestone.reward else {
                Issue.record("\(milestone) should pay coins")
                continue
            }
            #expect((0.25...0.35).contains(seconds / dailySeconds), "\(milestone)")
        }
        guard case .bullRun(let seconds) = StarterMilestone.firstGameUnlocked.reward else {
            Issue.record("Unlocking a game should pay a Bull Run")
            return
        }
        #expect((0.25...0.35).contains(seconds / Tuning.bullRunDuration))
    }

    @Test func unlockingAGameStartsABullRun() {
        var game = GameState.make(miners: minersEarning(10))
        game.unlockedGames = [.snake]
        #expect(game.claim(.firstGameUnlocked, at: t0) == .bullRun(seconds: 20))
        #expect(game.boost?.multiplier == Tuning.bullRunMultiplier)
        #expect(game.boost?.endsAt == t0.addingTimeInterval(20))
        #expect(game.coins == 0)
    }

    @Test func claimsAreSavedAndKeptThroughAPrestige() throws {
        var game = GameState.make(coins: 1_000)
        game.buy(.chromebook, quantity: 1)
        #expect(game.claim(.firstChromebook, at: t0) != nil)
        let saved = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(saved.starterMilestonesClaimed == [.firstChromebook])
        // A save from before the milestones, or with a name this version doesn't know.
        let none = try GameCoding.decoder().decode(GameState.self, from: Data("{}".utf8))
        #expect(none.starterMilestonesClaimed.isEmpty)
        let odd = try GameCoding.decoder().decode(GameState.self,
                                                  from: Data(#"{"starterMilestones": ["firstUpgrade", "bogus"]}"#.utf8))
        #expect(odd.starterMilestonesClaimed == [.firstUpgrade])
        // The miners go in a prestige, but the milestone stays reached and claimed.
        game.stats.lifetimeCoins = 1e11
        #expect(game.prestige(at: at(10)) > 0)
        #expect(game.owned(.chromebook) == 0)
        #expect(game.isReached(.firstChromebook))
        #expect(game.isClaimed(.firstChromebook))
        #expect(game.claim(.firstChromebook, at: at(20)) == nil)
    }

    @Test func aRewardIsLockedWhenTheMilestoneIsCompletedWhateverTheIncomeDoesAfter() {
        var game = GameState.make(miners: minersEarning(5)) // 5 coins a second.
        game.upgrades = [.coinClicker]
        #expect(game.starterRewardsLocked.isEmpty)
        game.lockStarterRewards()
        // 360 seconds of income, locked in when the milestone was seen completed.
        #expect(game.starterRewardsLocked[.firstUpgrade] == 1_800)
        // The income grows a great deal, but the reward doesn't follow it.
        game.miners = [.server: 10]
        #expect(game.baseIdleIncome > 100)
        #expect(game.payout(of: .firstUpgrade) == .coins(1_800))
        // Looking again doesn't re-lock a milestone that is already locked.
        game.lockStarterRewards()
        #expect(game.starterRewardsLocked[.firstUpgrade] == 1_800)
        // Claiming stays manual: nothing is paid until then, and then the locked amount is.
        #expect(game.coins == 0)
        #expect(game.claim(.firstUpgrade, at: t0) == .coins(1_800))
        #expect(game.coins == 1_800)
        #expect(game.starterRewardsLocked[.firstUpgrade] == nil)
        // A milestone completed later is locked at its own time, here at its cap.
        game.stats.snakeGames = 1
        game.lockStarterRewards()
        #expect(game.starterRewardsLocked[.firstGamePlayed] == 5_400)
    }

    @Test func aRewardIsNeverWorthMoreThanTenTimesWhatItPaysAtTheFloor() {
        // At this income the reward income would pay far more than ten times the 360 coins the
        // first upgrade pays at the one-coin floor.
        var game = GameState.make(coins: 10_000, miners: [.server: 10])
        game.upgrades = [.coinClicker]
        #expect(game.baseIdleIncome > 100)
        #expect(Tuning.starterRewardCapMultiple == 10)
        #expect(game.payout(of: .firstUpgrade) == .coins(3_600))
        // Each coin reward has its own cap: 900, 1,800, 3,600 and 5,400.
        game.buy(.chromebook, quantity: 3)
        game.stats.snakeGames = 1
        game.lockStarterRewards()
        #expect(game.payout(of: .firstChromebook) == .coins(900))
        #expect(game.payout(of: .threeMiners) == .coins(1_800))
        #expect(game.payout(of: .firstUpgrade) == .coins(3_600))
        #expect(game.payout(of: .firstGamePlayed) == .coins(5_400))
        // Below the cap it is plain seconds of income, and never under the day-one floor.
        #expect(GameState.make().payout(of: .firstChromebook) == .coins(90))
    }

    @Test func lockedRewardsAreSaved() throws {
        var game = GameState.make(miners: minersEarning(5))
        game.upgrades = [.coinClicker]
        game.lockStarterRewards()
        var saved = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(saved.starterRewardsLocked[.firstUpgrade] == 1_800)
        saved.miners = [.server: 10]
        #expect(saved.payout(of: .firstUpgrade) == .coins(1_800))
        // A save from before the rewards were locked has none locked.
        let none = try GameCoding.decoder().decode(GameState.self, from: Data("{}".utf8))
        #expect(none.starterRewardsLocked.isEmpty)
    }

    @Test func refreshingTheAchievementsLocksTheRewards() {
        var game = GameState.make()
        game.unlockedGames = [.snake]
        _ = game.refreshAchievements()
        #expect(game.claimableStarterMilestones == [.firstGameUnlocked])
        #expect(game.starterRewardsLocked.isEmpty) // A Bull Run has no coins to lock.
        game.upgrades = [.coinClicker]
        _ = game.refreshAchievements()
        #expect(game.starterRewardsLocked[.firstUpgrade] == 360) // 360 seconds at the one-coin floor.
    }

    @Test func theSectionHidesOnceEveryMilestoneIsClaimed() {
        var game = GameState.make(coins: 10_000)
        game.buy(.chromebook, quantity: 3)
        game.upgrades = [.coinClicker]
        game.unlockedGames = [.snake]
        game.stats.snakeGames = 1
        for milestone in StarterMilestone.allCases { #expect(game.claim(milestone, at: t0) != nil) }
        #expect(!game.hasUnclaimedStarterMilestones)
        #expect(game.claimableStarterMilestones.isEmpty)
    }
}
