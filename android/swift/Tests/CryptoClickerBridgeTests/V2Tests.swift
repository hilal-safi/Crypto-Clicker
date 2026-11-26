import Foundation
import Testing
@testable import CryptoClickerBridge
import CryptoClickerKit

/// Version 2's additions: backups and save files, saves from a newer version, the run history,
/// purchase celebrations, the market's records and the goals.
@Suite(.serialized)
struct V2Tests {
    @Test func backsUpAsTheAppLeavesAndRestoresACopy() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "foreground"])
        try harness.send(["cmd": "debugAddCoins", "amount": 5_000])
        try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 3])
        try harness.send(["cmd": "background"])

        // The latest copy and the day's copy, without Health Connect's steps.
        let backups = harness.directory.appendingPathComponent("Backups", isDirectory: true)
        let latest = try Data(contentsOf: backups.appendingPathComponent("Latest.json"))
        #expect(try SaveTransfer.game(from: latest).owned(.chromebook) == 3)

        // A copy is restored only once the player confirms it, and the game carries on from it.
        try harness.send(["cmd": "foreground"])
        try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 1])
        let page = try harness.send(["cmd": "snapshot"]).object("game").object("backup")
        let entries = try page.objects("entries")
        let newest = try #require(entries.first { $0.string("place") == "Latest on this phone" })
        let asked = try harness.send(["cmd": "backup.restore", "id": try #require(newest.string("id"))])
        let pending = try asked.object("game").object("backup").object("pending")
        #expect(pending.string("source") == "this backup")
        #expect(Bridge.session?.state.owned(.chromebook) == 4)
        try harness.send(["cmd": "backup.confirm"])
        let session = try #require(Bridge.session)
        #expect(session.state.owned(.chromebook) == 3)
        // A game of its own now, remembering the copy it came from, and a snapshot of the one replaced.
        #expect(session.state.copiedFrom != nil)
        let snapshots = try FileManager.default.contentsOfDirectory(atPath: backups.appendingPathComponent("Snapshots").path)
        #expect(snapshots.contains { $0.hasSuffix("before restore.json") })
    }

    @Test func exportsAndImportsASaveFile() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "debugAddCoins", "amount": 2_000])
        try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 2])
        let exported = try #require(try harness.send(["cmd": "backup.export"]).string("data"))
        #expect(try SaveTransfer.game(from: Data(exported.utf8)).owned(.chromebook) == 2)

        let wrong = try harness.send(["cmd": "backup.readFile", "text": "{\"hello\": 1}"])
        #expect(try wrong.object("game").object("backup").string("problem") == "It isn't a Crypto Clicker save, or it's damaged.")
        try harness.send(["cmd": "backup.dismiss"])

        try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 1])
        try harness.send(["cmd": "backup.readFile", "text": exported])
        try harness.send(["cmd": "backup.confirm"])
        #expect(Bridge.session?.state.owned(.chromebook) == 2)
    }

    @Test func leavesASaveFromANewerVersionAlone() throws {
        let harness = Harness()
        try FileManager.default.createDirectory(at: harness.directory, withIntermediateDirectories: true)
        let file = harness.directory.appendingPathComponent("game.json")
        var json = try #require(try JSONSerialization.jsonObject(with: GameCoding.encoder().encode(GameState())) as? [String: Any])
        json["version"] = GameState.saveVersion + 1
        let newer = try JSONSerialization.data(withJSONObject: json)
        try newer.write(to: file)

        let started = try harness.start()
        let alert = try started.object("game").object("newerSave")
        #expect(alert.string("title") == "Update Crypto Clicker")
        // Nothing is saved over it.
        try harness.send(["cmd": "background"])
        #expect(try Data(contentsOf: file) == newer)
        let again = try harness.send(["cmd": "checkNewerSave"])
        #expect(try again.object("game").object("newerSave").string("title") == "Still saved by a newer version")

        // Starting over moves it aside, never deleted, and a new game saves in its place.
        try harness.send(["cmd": "startOverNewerSave"])
        let names = try FileManager.default.contentsOfDirectory(atPath: harness.directory.path)
        #expect(names.contains { $0.hasPrefix("game.version-") })
        #expect(try harness.send(["cmd": "snapshot"]).object("game")["newerSave"] == nil)
    }

    @Test func celebratesTheFirstMinerAndMilestones() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "debugAddCoins", "amount": 1_000_000])
        let first = try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 1])
        let note = try first.object("game").object("purchaseNote")
        #expect(note.string("highlight") == "New miner: Chromebook!")
        #expect(note.string("highlightKind") == "newMiner")
        let milestone = try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 24])
        let reached = try milestone.object("game").object("purchaseNote")
        #expect(reached.string("highlight") == "Milestone: 25 Chromebooks!")
        #expect((reached["milestones"] as? [String])?.first == "Chromebook milestone: 25 owned, output ×2")
    }

    @Test func recordsFinishedRuns() throws {
        let harness = Harness()
        try harness.start()
        let before = try harness.send(["cmd": "snapshot"]).object("game").object("runHistory")
        #expect(before.string("runsEmpty")?.hasPrefix("Each run appears here") == true)
        #expect(try before.objects("milestones").count == CoinFinish.prestigeMilestones.count)

        try harness.send(["cmd": "debugAddCoins", "amount": Tuning.prestigeScale * 2])
        try harness.send(["cmd": "prestige"])
        let after = try harness.send(["cmd": "snapshot"]).object("game").object("runHistory")
        let runs = try after.objects("runs")
        #expect(runs.count == 1)
        #expect(runs.first?.string("title") == "Run 1")
        #expect(after.string("currentTitle") == "Run 2, so far")
        // The first prestige unlocks the Forged finish.
        let milestones = try after.objects("milestones")
        #expect(milestones.first?["reached"] as? Bool == true)
        let finishes = try harness.send(["cmd": "snapshot"]).object("game").object("mine")["finishes"] as? [String]
        #expect(finishes?.contains("forged") == true)
    }

    @Test func groupsTheAchievementsAndPointsGoalsWhereTheyreDone() throws {
        let harness = Harness()
        try harness.start()
        let game = try harness.send(["cmd": "snapshot"]).object("game")
        let collections = try game.object("achievements").objects("collections")
        #expect(collections.map { $0.string("id") } == AchievementCatalog.collections.map(\.id))
        let goals = try game.object("nextGoals").objects("goals")
        #expect(goals.first?.string("kind") == "miner")
        #expect(goals.first?.string("destination") == "Opens the Shop")
    }

    @Test func showsWhatASaleComesToBeforeItsMade() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "debugAddCoins", "amount": 1e12])
        try harness.send(["cmd": "buyTokens", "id": "dogecoin", "quantity": 10])
        let tokens = try harness.send(["cmd": "snapshot"]).object("game").object("tokens")
        let doge = try #require(try tokens.objects("tokens").first { $0.string("id") == "dogecoin" })
        let sellOne = try #require((doge["sell"] as? [[String: Any]])?.first)
        let preview = try sellOne.object("preview")
        #expect(preview.string("line")?.hasPrefix("Selling 1: ") == true)
        #expect(try tokens.objects("trades").first?.string("title") == "Bought 10 DOGE")
    }
}
