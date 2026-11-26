import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Save transfer")
struct SaveTransferTests {
    /// A game that has walked with Apple Health and taken taps from a watch.
    func walker() -> GameState {
        var game = GameState.make(coins: 5_000, miners: [.chromebook: 4, .desktop: 2])
        game.stats.lifetimeCoins = 1e6
        game.stats.taps = Tuning.stepsUnlockTaps
        _ = game.connectSteps(today: "2026-11-01")
        _ = game.creditSteps([StepDay(key: "2026-11-01", steps: 4_000)], today: "2026-11-01", at: t0)
        game.watchSequences = ["watch": 12]
        return game
    }

    @Test func aCopyLeavesHealthAndWatchDataBehind() throws {
        let game = walker()
        #expect(game.steps.isConnected && game.stats.lifetimeSteps > 0)
        let copy = try SaveTransfer.game(from: SaveTransfer.data(of: game))
        #expect(copy.steps == StepLedger())
        #expect(copy.stats.lifetimeSteps == 0 && copy.stats.bestDaySteps == 0)
        #expect(copy.watchSequences.isEmpty && copy.recentWatchBatches.isEmpty)
        // Everything else comes across.
        #expect(copy.coins == game.coins && copy.miners == game.miners)
        #expect(copy.stats.lifetimeCoins == game.stats.lifetimeCoins && copy.stats.earnedFromSteps == game.stats.earnedFromSteps)
        // The steps never appear in the file.
        let text = String(decoding: try SaveTransfer.data(of: game), as: UTF8.self)
        #expect(!text.contains("2026-11-01"))
    }

    @Test func anImportKeepsThisDevicesHealthLedgerAndStartsTheClockNow() throws {
        let here = walker()
        var other = GameState.make(coins: 1e9, miners: [.server: 3])
        other.stats.lifetimeCoins = 5e9
        let copy = try SaveTransfer.game(from: SaveTransfer.data(of: other))
        let game = here.continuing(with: copy, at: at(86_400))
        #expect(game.coins == 1e9 && game.miners == [.server: 3] && game.stats.lifetimeCoins == 5e9)
        #expect(game.steps == here.steps && game.stats.lifetimeSteps == here.stats.lifetimeSteps)
        #expect(game.watchSequences == here.watchSequences)
        #expect(game.lastUpdate == at(86_400))
        // Already-paid days aren't paid again.
        var after = game
        let credit = after.creditSteps([StepDay(key: "2026-11-01", steps: 4_000)], today: "2026-11-02", at: at(86_400))
        #expect(credit.steps == 0)
        // It goes on as a game of its own, remembering the copy it came from.
        #expect(game.gameID != copy.gameID && game.gameID != here.gameID)
        #expect(game.copiedFrom == copy.lineage && game.revision == copy.revision)
    }

    // MARK: Which backups a game may replace

    /// What a copy of `game`, saved on `device`, says about itself.
    func header(_ game: GameState, device: String? = "phone") throws -> SaveTransfer.Header {
        try #require(SaveTransfer.header(of: SaveTransfer.data(of: game, device: device)))
    }

    /// `game`, saved `times` more times.
    func saved(_ game: GameState, times: Int = 1) -> GameState {
        var game = game
        for _ in 0..<times { game.countSave() }
        return game
    }

    @Test func aCopySaysWhichGameItIsAndHowFarOn() throws {
        var game = saved(GameState.make(), times: 7)
        game.stats.lifetimeCoins = 1e6
        let copy = try header(game)
        #expect(copy.lineage == SaveLineage(gameID: game.gameID, revision: 7))
        #expect(copy.device == "phone" && copy.lifetimeCoins == 1e6)
        #expect(copy == SaveTransfer.Header(of: game, device: "phone"))
        // Saved and read back, the game keeps both; a save from before them gets an id of its own.
        let loaded = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(loaded.lineage == game.lineage)
        var json = try JSONSerialization.jsonObject(with: SaveTransfer.data(of: game)) as! [String: Any]
        json["gameID"] = nil
        json["revision"] = nil
        let old = try JSONSerialization.data(withJSONObject: json)
        #expect(SaveTransfer.header(of: old)?.lineage == nil)
        #expect(try SaveTransfer.game(from: old).revision == 0)
        // A prestige keeps the game's id.
        var prestiged = game
        prestiged.stats.lifetimeCoins = 1e11
        #expect(prestiged.prestige(at: t0) > 0)
        #expect(prestiged.gameID == game.gameID)
    }

    @Test func aBackupReplacesOnlyEarlierCopiesOfTheSameGame() throws {
        var game = saved(GameState.make(), times: 10)
        game.stats.lifetimeCoins = 1e9
        let earlier = try header(saved(GameState.make()).withLineage(of: game, revision: 4))
        // Nothing there yet, or an earlier copy of this game made here: replaced.
        #expect(SaveTransfer.conflict(replacing: nil, with: game, device: "phone") == nil)
        #expect(SaveTransfer.conflict(replacing: earlier, with: game, device: "phone") == nil)
        #expect(SaveTransfer.conflict(replacing: try header(game), with: game, device: "phone") == nil)
        // The same game further on (it was saved more times than this one has been): kept.
        let further = try header(saved(game, times: 3))
        #expect(SaveTransfer.conflict(replacing: further, with: game, device: "phone") == .furtherOn)
        // The same game saved on another device (the iPhone itself copied to a new one): only
        // replaced while this one has mined as much.
        var other = game
        other.stats.lifetimeCoins = 2e9
        #expect(SaveTransfer.conflict(replacing: try header(other, device: "old phone"), with: game, device: "phone") == .furtherOn)
        #expect(SaveTransfer.conflict(replacing: try header(game, device: "old phone"), with: saved(game), device: "phone") == nil)
    }

    @Test func aResetOrAnotherGameNeverReplacesACopyWithProgress() throws {
        var played = saved(GameState.make(), times: 50)
        played.stats.lifetimeCoins = 1e12
        let backup = try header(played)
        // After a reset: a new game, even one saved more times, leaves the old game's copy alone.
        var fresh = saved(GameState.make(), times: 80)
        fresh.stats.lifetimeCoins = 5e12
        #expect(SaveTransfer.conflict(replacing: backup, with: fresh, device: "phone") == .otherGame)
        // A copy of a game with nothing in it can go.
        #expect(SaveTransfer.conflict(replacing: try header(saved(GameState.make())), with: fresh, device: "phone") == nil)
        // A copy from before games had ids: only by what was mined.
        var json = try JSONSerialization.jsonObject(with: SaveTransfer.data(of: played)) as! [String: Any]
        json["gameID"] = nil
        let legacy = try #require(SaveTransfer.header(of: JSONSerialization.data(withJSONObject: json)))
        #expect(SaveTransfer.conflict(replacing: legacy, with: fresh, device: "phone") == nil)
        #expect(SaveTransfer.conflict(replacing: legacy, with: saved(GameState.make()), device: "phone") == .furtherOn)
        // One from a newer version of the game is never replaced by this one, even an empty one.
        json["version"] = GameState.saveVersion + 1
        let newer = try #require(SaveTransfer.header(of: JSONSerialization.data(withJSONObject: json)))
        #expect(SaveTransfer.conflict(replacing: newer, with: fresh, device: "phone") == .newerVersion)
    }

    /// Restoring an older copy on the same iPhone: the game carried on from it never replaces the
    /// copy further on, however many times it's saved, until the player chooses.
    @Test func aGameRestoredFromAnOlderCopyNeverReplacesTheNewerOne() throws {
        var played = saved(GameState.make(), times: 30)
        played.stats.lifetimeCoins = 1e9
        let daily = try SaveTransfer.game(from: SaveTransfer.data(of: played))
        var later = saved(played, times: 20)
        later.stats.lifetimeCoins = 5e9
        let latest = try header(later)
        let restored = later.continuing(with: daily, at: at(60))
        #expect(SaveTransfer.conflict(replacing: latest, with: restored, device: "phone") == .furtherOn)
        #expect(SaveTransfer.conflict(replacing: latest, with: saved(restored, times: 500), device: "phone") == .furtherOn)
        // But the copy it came from, or an earlier one, is replaced: carrying on from a backup on a
        // new iPhone takes over that backup.
        #expect(SaveTransfer.conflict(replacing: try header(played, device: "old phone"), with: saved(restored), device: "phone") == nil)
        let older = try header(saved(GameState.make()).withLineage(of: played, revision: 3))
        #expect(SaveTransfer.conflict(replacing: older, with: saved(restored), device: "phone") == nil)
        // Once it has, the backups that follow are of the restored game itself.
        let taken = try header(saved(restored))
        #expect(SaveTransfer.conflict(replacing: taken, with: saved(restored, times: 2), device: "phone") == nil)
    }

    @Test func onlyReadableSavesFromThisVersionOrOlderAreRead() throws {
        #expect(throws: SaveTransfer.ReadError.unreadable) { try SaveTransfer.game(from: Data("hello".utf8)) }
        #expect(throws: SaveTransfer.ReadError.unreadable) { try SaveTransfer.game(from: Data(#"{"name":"not a save"}"#.utf8)) }
        var json = try JSONSerialization.jsonObject(with: SaveTransfer.data(of: GameState.make())) as! [String: Any]
        json["version"] = GameState.saveVersion + 1
        let newer = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: SaveTransfer.ReadError.newerVersion) { try SaveTransfer.game(from: newer) }
        json["version"] = 8 // An older save is read, and migrated like any other.
        #expect(throws: Never.self) { try SaveTransfer.game(from: JSONSerialization.data(withJSONObject: json)) }
    }

    @Test func theSummaryShowsWhatACopyHolds() {
        var game = GameState.make(miners: [.chromebook: 3, .desktop: 1])
        game.stats.lifetimeCoins = 12_345
        game.debugCountPrestiges(2)
        let summary = SaveTransfer.Summary(of: game)
        #expect(summary.lifetimeCoins == 12_345 && summary.prestiges == 2 && summary.totalMiners == 4)
        #expect(summary.savedAt == game.lastUpdate)
    }
}
