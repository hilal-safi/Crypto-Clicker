import Foundation
import Testing
@testable import CryptoClickerBridge
import CryptoClickerKit

/// Drives the bridge the way the Android app does, through JSON, with a clock the tests move.
final class Harness {
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000) // A fixed afternoon in May 2026.
    let directory: URL

    init() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bridge-tests-\(UUID().uuidString)", isDirectory: true)
        Bridge.reset()
        Bridge.clock = { [weak self] in self?.now ?? Date() }
    }

    deinit {
        Bridge.reset()
        Bridge.clock = { Date() }
        try? FileManager.default.removeItem(at: directory)
    }

    @discardableResult
    func send(_ request: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: request)
        let response = try JSONSerialization.jsonObject(with: Bridge.handle(data))
        return try #require(response as? [String: Any])
    }

    @discardableResult
    func start() throws -> [String: Any] {
        try send(["cmd": "start", "dir": directory.path, "timeZone": "America/Toronto"])
    }
}

extension Dictionary where Key == String, Value == Any {
    func object(_ key: String) throws -> [String: Any] { try #require(self[key] as? [String: Any]) }
    func objects(_ key: String) throws -> [[String: Any]] { try #require(self[key] as? [[String: Any]]) }
    func string(_ key: String) -> String? { self[key] as? String }
}

/// The bridge keeps one game for the process, so these run one at a time.
@Suite(.serialized)
struct BridgeTests {
    @Test func startsANewGame() throws {
        let harness = Harness()
        let response = try harness.start()
        #expect(response["ok"] as? Bool == true)
        let live = try response.object("live")
        #expect(live.string("balance") == "0")
        let shop = try response.object("game").object("shop")
        let miners = try shop.objects("miners")
        #expect(miners.first?.string("id") == "chromebook")
        #expect(miners.first?.string("emoji") == "💻")
        #expect((miners.first?["buy"] as? [[String: Any]])?.count == 4)
        #expect(try shop.object("lockedMiner").string("text") == "Buy a Chromebook to reveal")
    }

    @Test func tapsEarnCoinsAndBuildACombo() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "foreground"])
        var last: [String: Any] = [:]
        for _ in 0..<6 { last = try harness.send(["cmd": "tap", "noGame": true]) }
        #expect(try last.object("tap").string("earned")?.hasPrefix("+") == true)
        let combo = try last.object("live").object("combo")
        #expect(combo.string("title") == "Combo ×1.1")
        #expect(combo.string("taps") == "6 taps!")
        #expect(last["game"] == nil)
        // The combo lapses once the taps stop.
        harness.now += 5
        let later = try harness.send(["cmd": "tick"])
        #expect(try later.object("live")["combo"] == nil)
    }

    @Test func buysMinersAndShowsThePurchasePopup() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "foreground"])
        try harness.send(["cmd": "debugAddCoins", "amount": 1_000_000])
        let response = try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 10])
        #expect(response["bought"] as? Bool == true)
        let game = try response.object("game")
        let chromebook = try #require(try game.object("shop").objects("miners").first { $0.string("id") == "chromebook" })
        #expect(chromebook["owned"] as? Int == 10)
        #expect(chromebook.string("ownedText") == "Owned 10")
        let note = try game.object("purchaseNote")
        #expect(note.string("title") == "10 items purchased!")
        #expect(note.string("names") == "Chromebook ×10")
        // It goes nine seconds after the last purchase.
        harness.now += 10
        let later = try harness.send(["cmd": "tick"])
        #expect(try later.object("game")["purchaseNote"] == nil)
    }

    @Test func refusesWhatItCantAfford() throws {
        let harness = Harness()
        try harness.start()
        let response = try harness.send(["cmd": "buyMiner", "id": "desktop", "quantity": 1])
        #expect(response["bought"] as? Bool == false)
        #expect(response["ok"] as? Bool == true)
    }

    @Test func paysTimeAwayAndWelcomesThePlayerBack() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "foreground"])
        try harness.send(["cmd": "debugAddCoins", "amount": 1_000])
        try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 2])
        try harness.send(["cmd": "background"])
        harness.now += 2 * 3_600
        let back = try harness.send(["cmd": "foreground"])
        let welcome = try back.object("game").object("welcomeBack")
        #expect(welcome.string("away")?.hasPrefix("You were away for 2h") == true)
        // Without Offline Mining, only the first minute is paid, and the screen says so.
        #expect(try welcome.object("offlineNote").string("button") == "Get Offline Mining")
        #expect(try welcome.objects("time").first?.string("title") == "Away")
        #expect(try welcome.objects("sources").first?.string("name") == "Chromebook")
        let dismissed = try harness.send(["cmd": "dismissWelcomeBack"])
        #expect(try dismissed.object("game")["welcomeBack"] == nil)
    }

    @Test func savesInTheIOSFormatAndLoadsItAgain() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "foreground"])
        try harness.send(["cmd": "debugAddCoins", "amount": 5_000])
        try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 3])
        let saved = try harness.send(["cmd": "background"])
        let balance = try saved.object("live").string("balanceExact")

        // The file is the same game.json the iPhone app writes.
        let data = try Data(contentsOf: harness.directory.appendingPathComponent("game.json"))
        let state = try GameCoding.decoder().decode(GameState.self, from: data)
        #expect(state.owned(.chromebook) == 3)

        // As if Android had ended the process: a new session reads the save.
        Bridge.reset()
        let reopened = try harness.start()
        #expect(try reopened.object("live").string("balanceExact") == balance)
    }

    @Test func startingAgainKeepsTheGameRunning() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "debugAddCoins", "amount": 777])
        // The activity is recreated (the phone rotated): the unsaved coins are still there.
        let again = try harness.start()
        #expect(try again.object("live").string("balance") == "777")
    }

    @Test func sendsTheGameOnlyWhenItChanged() throws {
        let harness = Harness()
        let first = try harness.start()
        let revision = try #require(first["revision"] as? Int)
        let same = try harness.send(["cmd": "snapshot", "known": revision])
        #expect(same["game"] == nil)
        #expect(same["live"] != nil)
        let stale = try harness.send(["cmd": "snapshot", "known": revision - 1])
        #expect(stale["game"] != nil)
    }

    @Test func reportsUnknownCommandsAndBadIDs() throws {
        let harness = Harness()
        try harness.start()
        let unknown = try harness.send(["cmd": "nonsense"])
        #expect(unknown["ok"] as? Bool == false)
        #expect(unknown.string("error")?.contains("nonsense") == true)
        let badMiner = try harness.send(["cmd": "buyMiner", "id": "toaster"])
        #expect(badMiner["ok"] as? Bool == false)
        let notJSON = try JSONSerialization.jsonObject(with: Bridge.handle(Data("{".utf8))) as? [String: Any]
        #expect(notJSON?["ok"] as? Bool == false)
    }

    @Test func refusesCommandsBeforeTheGameStarts() throws {
        _ = Harness()
        let data = try JSONSerialization.data(withJSONObject: ["cmd": "tap"])
        let response = try JSONSerialization.jsonObject(with: Bridge.handle(data)) as? [String: Any]
        #expect(response?["ok"] as? Bool == false)
    }

    @Test func usesTheDeviceTimeZone() throws {
        let harness = Harness()
        try harness.start()
        let info = try harness.send(["cmd": "info"]).object("info")
        #expect(info.string("timeZone") == "America/Toronto")
        #expect(info["debugTools"] as? Bool == true)
    }
}
