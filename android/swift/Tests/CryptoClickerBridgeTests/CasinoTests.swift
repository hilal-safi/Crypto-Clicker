import Foundation
import Testing
@testable import CryptoClickerBridge
import CryptoClickerKit

/// The Arcade's views and the casino tables, driven as the app drives them.
extension BridgeTests {
    /// A started game with every game unlocked and tokens to bet.
    private func casinoHarness() throws -> Harness {
        let harness = Harness()
        try harness.start()
        try harness.send(["cmd": "debugUnlockAllGames"])
        try harness.send(["cmd": "debugAddTokens", "quantity": 1_000])
        return harness
    }

    @Test func listsTheArcadeWithRecordsAndLooks() throws {
        let harness = try casinoHarness()
        let game = try harness.send(["cmd": "snapshot"]).object("game")
        let arcade = try game.object("arcade")
        #expect(try arcade.objects("casino").count == MiniGame.allCases.filter(\.isCasino).count)
        #expect(try arcade.objects("arcade").count == MiniGame.allCases.filter { !$0.isCasino }.count)
        #expect(try arcade.objects("casino").allSatisfy { $0["isUnlocked"] as? Bool == true })
        #expect(arcade["rank"] != nil)
        #expect(try game.objects("gameCards").count == MiniGame.allCases.count)
        #expect(try game.objects("guides").count == MiniGame.allCases.count)
        #expect(try !game.object("style").objects("slots").isEmpty)
        #expect((game["looks"] as? [String])?.count == CosmeticSlot.allCases.count)
    }

    @Test func playsABlackjackRoundToTheEnd() throws {
        let harness = try casinoHarness()
        var frame = try harness.send(["cmd": "play.open", "id": "blackjack"]).object("play").object("blackjack")
        #expect(frame.string("phase") == "betting")
        #expect(try frame.object("wallet")["bet"] as? Int == 1)
        frame = try harness.send(["cmd": "play.setBet", "quantity": 5]).object("play").object("blackjack")
        #expect(try frame.object("wallet")["bet"] as? Int == 5)
        frame = try harness.send(["cmd": "play.deal"]).object("play").object("blackjack")
        // Stand on every hand, turn down insurance, and let the dealer finish, as the app would.
        for _ in 0..<40 where frame.string("phase") != "settled" {
            let action = switch frame.string("phase") {
            case "insurance": "play.noInsurance"
            case "playerTurn": "play.stand"
            default: "play.dealerStep"
            }
            frame = try harness.send(["cmd": action]).object("play").object("blackjack")
        }
        #expect(frame.string("phase") == "settled")
        #expect(try frame.object("result").string("title") != nil)
        #expect(frame["rounds"] as? Int == 1)
        try harness.send(["cmd": "play.close"])
    }

    @Test func leavingBlackjackMidRoundFinishesIt() throws {
        let harness = try casinoHarness()
        try harness.send(["cmd": "play.open", "id": "blackjack"])
        let dealt = try harness.send(["cmd": "play.deal"]).object("play").object("blackjack")
        try harness.send(["cmd": "play.close"])
        // The bet was taken, and the round was paid when the table closed (or at the deal, for a natural).
        if dealt.string("phase") != "settled" {
            let games = try harness.send(["cmd": "snapshot"]).object("game").objects("gameCards")
            let blackjack = try #require(games.first { $0.string("id") == "blackjack" })
            #expect(blackjack["timesPlayed"] as? Int == 1)
        }
    }

    @Test func dealsHoldsAndDrawsDiamondHands() throws {
        let harness = try casinoHarness()
        try harness.send(["cmd": "play.open", "id": "videoPoker"])
        var frame = try harness.send(["cmd": "play.deal"]).object("play").object("poker")
        #expect(frame.string("phase") == "holding")
        #expect(try frame.objects("cards").count == 5)
        frame = try harness.send(["cmd": "play.hold", "index": 2]).object("play").object("poker")
        #expect(frame["held"] as? [Int] == [2])
        frame = try harness.send(["cmd": "play.draw"]).object("play").object("poker")
        #expect(frame.string("phase") == "drawing")
        #expect(frame["replaced"] as? [Int] == [0, 1, 3, 4])
        #expect(frame["result"] == nil)
        frame = try harness.send(["cmd": "play.reveal"]).object("play").object("poker")
        #expect(frame.string("phase") == "betting")
        #expect(try frame.object("result").string("title") != nil)
    }

    @Test func practiceHandsLeaveTheWalletAlone() throws {
        let harness = try casinoHarness()
        try harness.send(["cmd": "play.open", "id": "videoPoker"])
        try harness.send(["cmd": "play.setPractice", "flag": true])
        var frame = try harness.send(["cmd": "play.deal"]).object("play").object("poker")
        #expect(try frame.object("wallet").string("chips") == "975 chips")
        try harness.send(["cmd": "play.draw"])
        frame = try harness.send(["cmd": "play.reveal"]).object("play").object("poker")
        #expect(try frame.object("result")["xp"] == nil)
        let cards = try harness.send(["cmd": "snapshot"]).object("game").objects("gameCards")
        #expect(try #require(cards.first { $0.string("id") == "videoPoker" })["timesPlayed"] as? Int == 0)
    }

    @Test func spinsBothSlotMachines() throws {
        let harness = try casinoHarness()
        try harness.send(["cmd": "play.open", "id": "slots", "options": ["machine": "classic"]])
        var frame = try harness.send(["cmd": "play.spin"]).object("play").object("slots")
        #expect(frame["isSpinning"] as? Bool == true)
        #expect(frame["result"] == nil)
        frame = try harness.send(["cmd": "play.reveal"]).object("play").object("slots")
        #expect(frame["isSpinning"] as? Bool == false)
        #expect(try frame.object("result").string("title") != nil)
        // Free spins won on one machine keep it; otherwise the video machine can be picked.
        if frame.string("free") == nil {
            frame = try harness.send(["cmd": "play.set", "options": ["machine": "video"]]).object("play").object("slots")
            #expect(frame.string("machine") == "video")
            #expect(frame["reelCount"] as? Int == 5)
            try harness.send(["cmd": "play.spin"])
            frame = try harness.send(["cmd": "play.reveal"]).object("play").object("slots")
            #expect(try frame.object("result").string("title") != nil)
        }
        #expect(try !frame.objects("paytable").isEmpty)
    }

    @Test func fliesToTheMoonAndCashesOut() throws {
        let harness = try casinoHarness()
        try harness.send(["cmd": "play.open", "id": "moon", "options": ["rocket": "doubling", "autoDoubling": "0", "autoFivefold": "0"]])
        var frame = try harness.send(["cmd": "play.launch"]).object("play").object("moon")
        #expect(frame["isFlying"] as? Bool == true)
        let endsAfter = try #require(frame["endsAfter"] as? Double)
        harness.now += min(0.5, endsAfter / 2)
        frame = try harness.send(["cmd": "play.cashOut"]).object("play").object("moon")
        #expect(frame["isFlying"] as? Bool == false)
        #expect(try frame.object("result").string("title") != nil)
    }

    @Test func aFlightEndsByItselfWhenItsTimeComes() throws {
        let harness = try casinoHarness()
        try harness.send(["cmd": "play.open", "id": "moon", "options": ["rocket": "fivefold", "autoDoubling": "2.0", "autoFivefold": "5.0"]])
        var frame = try harness.send(["cmd": "play.launch"]).object("play").object("moon")
        let endsAfter = try #require(frame["endsAfter"] as? Double)
        // Too early: the flight carries on.
        frame = try harness.send(["cmd": "play.settle"]).object("play").object("moon")
        #expect(frame["isFlying"] as? Bool == (endsAfter > 0.5))
        harness.now += endsAfter + 0.05
        frame = try harness.send(["cmd": "play.settle"]).object("play").object("moon")
        #expect(frame["isFlying"] as? Bool == false)
        let result = try frame.object("result")
        // It either reached the automatic cash-out at 5× or crashed before it.
        #expect(result["isWin"] as? Bool == (frame.string("multiplier") == "5.00×"))
    }
}
