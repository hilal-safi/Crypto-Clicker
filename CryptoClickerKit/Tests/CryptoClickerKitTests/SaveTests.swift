import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Saving")
struct SaveTests {
    func decode(_ json: String) throws -> GameState {
        try GameCoding.decoder().decode(GameState.self, from: Data(json.utf8))
    }

    func richState() -> GameState {
        var state = GameState.make(coins: 123_456.75, miners: [.chromebook: 30, .server: 4],
                                   upgrades: [.coinClicker, .overclocking, .hapticEngine])
        state.offlineMiningLevel = 9
        state.tokens = [.dogecoin: 3, .bitcoin: 1]
        state.placeBlackjackBet(.dogecoin, amount: 2)
        state.prestigePoints = 7
        state.prestigePointsSpent = 3
        state.prestigePotentialClaimed = 9
        state.perks = [.headStart, .strongFingers]
        state.minerUpgrades = [.chromebook: 2]
        state.difficulty = .hard
        state.runPrestigeMultiplier = 1
        state.boost = Boost(multiplier: 7, endsAt: at(45))
        state.unlockedGames = [.blackjack, .tetris]
        state.achievementTiers = ["miner": 2, "own-server": 1]
        state.stats.lifetimeCoins = 9e12
        state.stats.maxOwned = [.chromebook: 31]
        state.stats.tokensBought = [.dogecoin: 5]
        state.stats.tetrisBestScore = 4_200
        state.stats.slotsWins = 12
        state.stats.snakeBestScore = 340
        state.stats.bricksBroken = 77
        state.stats.bubblesPopped = 410
        state.unlockedGames.insert(.bubbleBlaster)
        state.stats.taps = 3_000
        state.connectSteps(today: "2026-10-20")
        state.creditSteps([StepDay(key: "2026-10-24", steps: 4_000)], today: "2026-10-24", at: at(10))
        state.applyWatchTaps(WatchTapBatch(taps: 5, date: t0), at: t0)
        state.advance(to: at(20))
        state.refreshDaily(today: "2026-10-24", canWalk: true, at: at(20))
        state.claimDailyReward(today: "2026-10-24", yesterday: "2026-10-23", at: at(20))
        state.recordIncomeSample(at: at(20))
        state.holdArcadeRun(ArcadeRun(game: .tetris, score: 700, detail: 3, challengeDay: "2026-10-24"))
        state.stats.bestCombo = 44
        state.stats.whaleAirdrops = 2
        return state
    }

    @Test func aSaveRoundTripsExactly() throws {
        let state = richState()
        #expect(state.steps.isConnected)
        let data = try GameCoding.encoder().encode(state)
        let decoded = try GameCoding.decoder().decode(GameState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.stats.bubblesPopped == 410)
        #expect(decoded.isUnlocked(.bubbleBlaster))
        #expect(decoded.daily.quests.count == 3)
        #expect(decoded.daily.streak == 1)
        #expect(decoded.incomeHistory.count == 1)
        #expect(decoded.unfinishedRun?.challengeDay == "2026-10-24")
    }

    @Test func enumKeyedValuesAreWrittenAsReadableJSON() throws {
        let data = try GameCoding.encoder().encode(richState())
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["version"] as? Int == GameState.saveVersion)
        #expect((json["miners"] as? [String: Int]) == ["chromebook": 30, "server": 4])
        #expect((json["upgrades"] as? [String]) == ["coinClicker", "hapticEngine", "overclocking"])
        #expect(json["offlineMiningLevel"] as? Int == 9)
        #expect((json["tokens"] as? [String: Int]) == ["bitcoin": 1, "dogecoin": 1])
        #expect((json["blackjackStake"] as? [String: Any])?["token"] as? String == "dogecoin")
        #expect(json["difficulty"] as? String == "hard")
        // Prestige values keep the names they had as Hard Forks, so older builds can still read them.
        #expect(json["forks"] as? Int == 7)
        #expect(json["forkPointsClaimed"] as? Int == 9)
        #expect((json["perks"] as? [String]) == ["headStart", "strongFingers"])
        #expect((json["minerUpgrades"] as? [String: Int]) == ["chromebook": 2])
    }

    @Test func anOpenBlackjackStakeSurvivesASave() throws {
        let data = try GameCoding.encoder().encode(richState())
        var reloaded = try GameCoding.decoder().decode(GameState.self, from: data)
        #expect(reloaded.blackjackStake == BlackjackStake(token: .dogecoin, amount: 2))
        reloaded.refundBlackjackStake()
        #expect(reloaded.tokenCount(.dogecoin) == 3)
    }

    @Test func anEmptySaveLoadsAsANewGame() throws {
        let state = try decode("{}")
        #expect(state.coins == 0)
        #expect(state.miners.isEmpty)
        #expect(state.difficulty == .normal)
        #expect(state.runPrestigeMultiplier == 1)
        #expect(state.prestigePoints == 0)
        #expect(state.perks.isEmpty)
        #expect(state.daily == DailyProgress())
        #expect(state.stats == Stats())
        #expect(state.steps == StepLedger())
    }

    @Test func unknownItemsAreDroppedAndTheRestIsKept() throws {
        let state = try decode("""
            {"miners": {"chromebook": 2, "warpDrive": 5},
             "upgrades": ["coinClicker", "timeMachine"],
             "tokens": {"pepe": 9, "xrp": 1},
             "unlockedGames": ["blackjack", "chess"],
             "difficulty": "nightmare",
             "perks": ["headStart", "timeTravel"],
             "minerUpgrades": {"desktop": 2, "toaster": 1},
             "forks": 3}
            """)
        #expect(state.miners == [.chromebook: 2])
        #expect(state.upgrades == [.coinClicker])
        #expect(state.tokens == [.xrp: 1])
        #expect(state.unlockedGames == [.blackjack])
        #expect(state.difficulty == .normal)
        #expect(state.prestigePoints == 3)
        #expect(state.perks == [.headStart])
        #expect(state.minerUpgrades == [.desktop: 2])
    }

    @Test func offlineUpgradesFromEarlierVersionsBecomeOfflineMiningLevels() throws {
        // Cloud Backup gave 4 hours, Server Lease 8 and the Always-On Rig a day.
        #expect(try decode(#"{"upgrades": ["coinClicker", "cloudBackup"]}"#).offlineMiningLevel == 8)
        #expect(try decode(#"{"upgrades": ["cloudBackup", "serverLease"]}"#).offlineCap == 8 * 3_600)
        let rig = try decode(#"{"upgrades": ["alwaysOnRig", "overclocking"]}"#)
        #expect(rig.offlineCap == 24 * 3_600)
        #expect(rig.upgrades == [.overclocking])
        // A level saved by this version wins when it is higher, and nothing goes past the maximum.
        #expect(try decode(#"{"upgrades": ["cloudBackup"], "offlineMiningLevel": 20}"#).offlineMiningLevel == 20)
        #expect(try decode(#"{"offlineMiningLevel": 5000}"#).offlineMiningLevel == Tuning.offlineMiningMaxLevel)
        #expect(try decode(#"{"offlineMiningLevel": -2}"#).offlineMiningLevel == 0)
        #expect(try decode("{}").offlineCap == 0)
    }

    @Test func corruptFieldsFallBackToDefaults() throws {
        let state = try decode("""
            {"coins": "lots", "forks": 2.5, "boost": {"multiplier": 7}, "stats": {"taps": 12, "lifetimeCoins": []},
             "steps": {"isConnected": true, "credited": {"2026-10-24": "many"}},
             "prestigePointsSpent": 50, "daily": {"quests": "none", "questDay": "2026-10-24", "streak": 4}}
            """)
        #expect(state.coins == 0)
        #expect(state.prestigePoints == 0)
        #expect(state.prestigePointsSpent == 0) // Never more than the points earned.
        #expect(state.daily.quests.isEmpty)
        #expect(state.daily.questDay == nil) // Unreadable quests are issued again.
        #expect(state.daily.streak == 4)
        #expect(state.boost == nil)
        #expect(state.stats.taps == 12)
        #expect(state.stats.lifetimeCoins == 0)
        #expect(state.steps.isConnected)
        #expect(state.steps.credited.isEmpty)
    }

    @Test func nonFiniteNumbersNeverPoisonTheBalance() throws {
        #expect(try decode(#"{"coins": "nan"}"#).coins == 0)
        #expect(try decode(#"{"coins": "inf"}"#).coins == 0)
        var state = GameState.make()
        state.stats.peakIncome = .infinity
        let data = try GameCoding.encoder().encode(state)
        #expect(try GameCoding.decoder().decode(GameState.self, from: data).stats.peakIncome == .infinity)
    }

    @Test func aBrokenFileStillThrows() {
        #expect(throws: (any Error).self) { try decode("not json") }
        #expect(throws: (any Error).self) { try decode("[]") }
    }
}
