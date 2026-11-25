import Foundation
import Testing
@testable import CryptoClickerBridge
import CryptoClickerKit

/// The opening's starter milestones, Offline Efficiency and what time away pays.
extension BridgeTests {
    @Test func claimsAStarterMilestoneOnce() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "foreground"])
        var game = try harness.send(["cmd": "snapshot"]).object("game")
        var starters = try game.object("goals").objects("starters")
        #expect(starters.count == StarterMilestone.allCases.count)
        #expect(starters.first?["isReached"] as? Bool == false)
        #expect(game["starterClaims"] as? Int == 0)
        try harness.send(["cmd": "debugAddCoins", "amount": 1_000])
        game = try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 1]).object("game")
        #expect(game["starterClaims"] as? Int == 1)
        let claimed = try harness.send(["cmd": "claimStarter", "id": "firstChromebook"])
        let toast = try #require((claimed["toasts"] as? [[String: Any]])?.last)
        #expect(toast.string("title") == StarterMilestone.firstChromebook.title)
        starters = try claimed.object("game").object("goals").objects("starters")
        #expect(starters.first?["isClaimed"] as? Bool == true)
        #expect(try claimed.object("game")["starterClaims"] as? Int == 0)
        // A second claim pays nothing more.
        let again = try harness.send(["cmd": "claimStarter", "id": "firstChromebook"])
        #expect((again["toasts"] as? [[String: Any]])?.isEmpty ?? true)
    }

    @Test func listsOfflineEfficiencyWithoutLevelBars() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "debugAddCoins", "amount": 1e9])
        let shop = try harness.send(["cmd": "snapshot"]).object("game").object("shop")
        let powerUps = try shop.objects("powerUps")
        let efficiency = try #require(powerUps.first { $0.string("id") == "offlineEfficiency" })
        #expect(efficiency["showsPips"] as? Bool == false)
        #expect(efficiency.string("now") == "10%")
        #expect(powerUps.first?.string("id") == "offlineEfficiency")
    }

    @Test func timeAwayPaysAShareOfTheIncome() throws {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "foreground"])
        try harness.send(["cmd": "debugAddCoins", "amount": 1_000])
        try harness.send(["cmd": "buyMiner", "id": "chromebook", "quantity": 2])
        try harness.send(["cmd": "background"])
        harness.now += 3 * 3_600
        let welcome = try harness.send(["cmd": "foreground"]).object("game").object("welcomeBack")
        let note = try welcome.object("offlineNote").string("text") ?? ""
        #expect(note.contains("10% of your income"))
    }
}
