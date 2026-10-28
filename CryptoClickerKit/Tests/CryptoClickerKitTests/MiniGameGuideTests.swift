import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("How to Play")
struct MiniGameGuideTests {
    @Test(arguments: MiniGame.allCases)
    func everyGameExplainsItself(_ game: MiniGame) {
        let guide = game.guide
        #expect(!guide.objective.isEmpty)
        #expect(!guide.controls.isEmpty)
        #expect(!guide.scoring.isEmpty)
        #expect(!guide.ending.isEmpty)
        #expect((2...3).contains(guide.tips.count), "\(game.name) has \(guide.tips.count) tips")
        #expect(!guide.controlHint.isEmpty && guide.controlHint.count <= 48, "\(game.name)'s hint is too long for a small phone")
        let lines = [guide.objective, guide.ending, guide.controlHint] + guide.controls + guide.scoring + guide.tips
        #expect(lines.allSatisfy { !$0.isEmpty && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        // Items are named once each, and their pictures belong to this game.
        #expect(Set(guide.items.map(\.id)).count == guide.items.count)
        for item in guide.items {
            #expect(!item.name.isEmpty && !item.detail.isEmpty && !item.symbol.isEmpty)
        }
    }

    @Test func pictureNamesNeverClashAcrossGames() {
        let ids = MiniGame.allCases.flatMap { $0.guide.items.map(\.id) }
        #expect(Set(ids).count == ids.count)
    }

    @Test func theNumbersMatchTheRules() {
        let pump = MiniGame.pumpDump.guide
        #expect(pump.items.contains { $0.detail.contains("Worth \(PumpDumpGame.goldenPoints / PumpDumpGame.coinPoints) coins") })
        #expect(pump.items.contains { $0.detail.contains("Costs \(PumpDumpGame.scamPenalty) points") })
        #expect(pump.scoring.contains { $0.contains("\(Int(PumpDumpGame.roundLength)) seconds") })
        let slots = MiniGame.slots.guide
        #expect(slots.scoring[0].contains("BTC \(SlotMachine.jackpot)×"))
        let poker = MiniGame.videoPoker.guide
        #expect(poker.scoring[0].contains("Royal Flush 800"))
        #expect(MiniGame.brickBreaker.guide.ending.contains("\(BrickBreakerGame.startingLives) balls"))
        #expect(MiniGame.bubbleBlaster.guide.items[0].detail.contains("\(BubbleShooterGame.missesPerRow) shots"))
        #expect(MiniGame.snake.guide.scoring[0].contains("\(SnakeGame.pointsPerCoin) points"))
    }
}
