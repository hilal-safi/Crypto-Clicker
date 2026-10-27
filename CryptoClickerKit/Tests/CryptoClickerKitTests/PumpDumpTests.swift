import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Pump and Dump")
struct PumpDumpTests {
    @Test func coinsScoreAndBuildACombo() {
        var game = PumpDumpGame()
        game.place(.coin, inHole: 0)
        #expect(game.tap(hole: 0) == .coin(points: 10))
        game.place(.coin, inHole: 4)
        #expect(game.tap(hole: 4) == .coin(points: 11)) // ×1.1 for the second hit in a row.
        game.place(.golden, inHole: 8)
        #expect(game.tap(hole: 8) == .golden(points: 60)) // 50 × 1.2.
        #expect(game.score == 81)
        #expect(game.combo == 3)
        #expect(game.coinsHit == 3)
        #expect(game.goldenHit == 1)
        #expect(game.target(inHole: 0) == nil)
        #expect(PumpDumpGame.comboMultiplier(hitsInARow: 100) == PumpDumpGame.maxComboMultiplier)
    }

    @Test func scamsCostPointsAndEndTheCombo() {
        var game = PumpDumpGame()
        game.place(.coin, inHole: 1)
        game.tap(hole: 1)
        game.place(.scam, inHole: 2)
        #expect(game.tap(hole: 2) == .scam(penalty: 30))
        #expect(game.score == 0) // Never below zero.
        #expect(game.combo == 0)
        #expect(game.scamsHit == 1)
        #expect(game.bestCombo == 1)
    }

    @Test func tappingAnEmptyHoleEndsTheCombo() {
        var game = PumpDumpGame()
        game.place(.coin, inHole: 3)
        game.tap(hole: 3)
        #expect(game.tap(hole: 5) == .miss)
        #expect(game.combo == 0)
        #expect(game.score == 10)
    }

    @Test func aRugPullTurnsIntoAScam() {
        var game = PumpDumpGame()
        var rng = SeededGenerator(seed: 1)
        game.place(.rug, inHole: 6, stay: 1, turnsAfter: 0.5)
        let rug = game.target(inHole: 6)
        #expect(rug?.isScam(at: game.time) == false)
        #expect(rug?.isWarning(at: game.time + 0.2) == true)
        #expect(rug?.isScam(at: game.time + 0.5) == true)
        // Tapped while it's still a coin, it pays like one.
        var early = game
        #expect(early.tap(hole: 6) == .coin(points: 10))
        game.advance(by: 0.3, using: &rng)
        game.advance(by: 0.25, using: &rng) // Now past the turn, half a second in.
        #expect(game.tap(hole: 6) == .scam(penalty: 30))
    }

    @Test func coinsThatGetAwayEndTheCombo() {
        var game = PumpDumpGame()
        var rng = SeededGenerator(seed: 2)
        game.place(.coin, inHole: 0)
        game.tap(hole: 0)
        game.place(.coin, inHole: 7, stay: 0.1)
        game.place(.scam, inHole: 8, stay: 0.1)
        game.advance(by: 0.2, using: &rng)
        #expect(game.target(inHole: 7) == nil)
        #expect(game.escaped == 1)
        #expect(game.combo == 0)
    }

    @Test func aRoundLastsThirtySecondsAtAnyFrameRate() {
        var smooth = PumpDumpGame()
        var choppy = PumpDumpGame()
        var rngA = SeededGenerator(seed: 9)
        var rngB = SeededGenerator(seed: 9)
        var appeared = Set<Int>()
        while !smooth.isOver {
            smooth.advance(by: 1.0 / 120, using: &rngA)
            appeared.formUnion(smooth.targets.map(\.id))
            #expect(smooth.targets.count <= 4)
            #expect(Set(smooth.targets.map(\.hole)).count == smooth.targets.count)
        }
        while !choppy.isOver { choppy.advance(by: 0.25, using: &rngB) }
        #expect(smooth.time == PumpDumpGame.roundLength)
        #expect(smooth.targets.isEmpty)
        #expect(smooth.escaped == choppy.escaped)
        #expect(appeared.count > 30)
        var over = smooth
        #expect(over.tap(hole: 0) == .miss)
    }

    @Test func roundsPayAndCountTowardTheRecords() {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        let payout = game.finishPumpDump(score: 400, coinsHit: 40, bestCombo: 18, scamsHit: 2)
        #expect(payout.isNewBest)
        #expect(payout.coins == 330) // 400 × 0.055 × 10 × 1.5
        #expect(game.stats.pumpDumpGames == 1)
        #expect(game.stats.pumpDumpBestScore == 400)
        #expect(game.stats.pumpDumpCoinsHit == 40)
        #expect(game.stats.pumpDumpScamsHit == 2)
        #expect(game.stats.pumpDumpBestCombo == 18)
        #expect(game.record(for: .pumpDump) == "Best 400 · combo 18")
        game.holdArcadeRun(ArcadeRun(game: .pumpDump, score: 200, detail: 15, extra: 9))
        #expect(game.payUnfinishedRun()?.payout.isNewBest == false)
        #expect(game.stats.pumpDumpCoinsHit == 55)
    }
}
