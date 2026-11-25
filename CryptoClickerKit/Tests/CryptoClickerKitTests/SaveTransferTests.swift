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
