import Foundation
import Testing
@testable import CryptoClickerBridge

/// `android/contract/response.json` is a response with every key the bridge can send. The Kotlin
/// unit tests decode it strictly (every key known, every required key present); this test checks
/// that real responses use no key the contract doesn't have. Together they keep the Swift and
/// Kotlin sides of the JSON in step.
enum Contract {
    static let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CryptoClickerBridgeTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // swift
        .deletingLastPathComponent() // android
        .appendingPathComponent("contract/response.json")

    /// The source tree isn't there when the tests run on an Android emulator.
    static var isAvailable: Bool { FileManager.default.fileExists(atPath: url.path) }

    static func load() throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try #require(object as? [String: Any])
    }

    /// Every key in `actual` must be in `contract`, at every level. Arrays are checked element by
    /// element against the contract array's first element.
    static func check(_ actual: Any, against contract: Any, path: String) -> [String] {
        switch (actual, contract) {
        case let (actual as [String: Any], contract as [String: Any]):
            return actual.keys.sorted().flatMap { key -> [String] in
                guard let expected = contract[key] else { return ["\(path).\(key) is not in the contract"] }
                return check(actual[key]!, against: expected, path: "\(path).\(key)")
            }
        case let (actual as [Any], contract as [Any]):
            guard let first = contract.first else {
                return actual.isEmpty ? [] : ["\(path) has elements but the contract's array is empty"]
            }
            return actual.enumerated().flatMap { index, element in
                check(element, against: first, path: "\(path)[\(index)]")
            }
        case (is String, is String):
            return []
        case (is [String: Any], _), (is [Any], _), (is String, _):
            return ["\(path) has a different type in the contract"]
        default:
            // Numbers and booleans (both NSNumber once parsed).
            return contract is String || contract is [Any] || contract is [String: Any]
                ? ["\(path) has a different type in the contract"] : []
        }
    }
}

// In the same (serialized) suite as the other bridge tests: they share the one game per process.
extension BridgeTests {
    @Test(.enabled(if: Contract.isAvailable))
    func responsesUseOnlyKeysInTheContract() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "foreground"])
        // Fill in every optional part: miners with Mk upgrades and milestones, power-ups (one locked),
        // Offline Mining, upgrades on sale and bought, the purchase popup, a Bull Run, a combo, toasts,
        // and a welcome-back report.
        try harness.send(["cmd": "debugAddCoins", "amount": 1e12])
        try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 30])
        try harness.send(["cmd": "buyMiner", "id": "desktop", "quantity": 30])
        try harness.send(["cmd": "buyMinerUpgrade", "id": "chromebook"])
        try harness.send(["cmd": "buyOfflineMining"])
        try harness.send(["cmd": "buyPowerUp", "id": "comboBooster"])
        try harness.send(["cmd": "buyUpgrade", "id": "coinClicker"])
        try harness.send(["cmd": "debugBullRun"])
        for _ in 0..<8 { try harness.send(["cmd": "tap"]) }

        var responses = [try harness.send(["cmd": "snapshot"])]
        try harness.send(["cmd": "background"])
        harness.now += 6 * 3_600
        responses.append(try harness.send(["cmd": "foreground"]))
        responses.append(try harness.send(["cmd": "tap"]))
        responses.append(try harness.send(["cmd": "info"]))
        responses.append(try harness.send(["cmd": "nonsense"]))

        let contract = try Contract.load()
        for response in responses {
            let problems = Contract.check(response, against: contract, path: "response")
            #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
        }
        // The richest response really had the parts that only show up some of the time.
        let game = try responses[1].object("game")
        #expect(game["welcomeBack"] != nil)
        #expect(try responses[0].object("game")["purchaseNote"] != nil)
        #expect(try responses[0].object("live")["bullRun"] != nil)
    }
}
