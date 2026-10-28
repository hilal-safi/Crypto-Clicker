import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Pump and Dump")
struct PumpDumpTests {
    /// Taps `count` coins in a row, as fast as the rules allow.
    func tapCoins(_ count: Int, in game: inout PumpDumpGame) {
        for index in 0..<count {
            game.place(.coin, inHole: index % PumpDumpGame.holes)
            game.tap(hole: index % PumpDumpGame.holes)
        }
    }

    /// Lets the rest of the round play out with nobody tapping.
    func finishRound(_ game: inout PumpDumpGame, seed: UInt64 = 5) {
        var rng = SeededGenerator(seed: seed)
        game.advance(by: PumpDumpGame.roundLength, using: &rng)
    }

    @Test func coinsScoreAndBuildACombo() {
        var game = PumpDumpGame()
        game.place(.coin, inHole: 0)
        #expect(game.tap(hole: 0) == .coin(points: 10))
        game.place(.coin, inHole: 4)
        #expect(game.tap(hole: 4) == .coin(points: 11)) // ×1.1 for the second hit in a row.
        game.place(.golden, inHole: 8)
        #expect(game.tap(hole: 8) == .golden(points: 60)) // 50 × 1.2.
        #expect(game.score == 81)
        #expect(game.roundScore == 81)
        #expect(game.combo == 3)
        #expect(game.coinsHit == 3)
        #expect(game.goldenHit == 1)
        #expect(game.target(inHole: 0) == nil)
        #expect(game.accuracy == 1)
        #expect(PumpDumpGame.comboMultiplier(hitsInARow: 100) == PumpDumpGame.maxComboMultiplier)
    }

    @Test func scamsCostPointsAndEndTheCombo() {
        var game = PumpDumpGame()
        tapCoins(3, in: &game)
        #expect(game.score == 33)
        game.place(.scam, inHole: 2)
        #expect(game.tap(hole: 2) == .scam(penalty: 30))
        #expect(game.score == 3)
        #expect(game.combo == 0)
        #expect(game.scamsHit == 1)
        #expect(game.bestCombo == 3)
        // A combo of three or more that ends is remembered for the "combo lost" message.
        #expect(game.comboBreaks == 1)
        #expect(game.lastLostCombo == 3)
        game.place(.scam, inHole: 2)
        game.tap(hole: 2)
        #expect(game.score == 0) // Never below zero.
        #expect(game.comboBreaks == 1) // Nothing was lost the second time.
    }

    @Test func tappingAnEmptyHoleEndsTheCombo() {
        var game = PumpDumpGame()
        game.place(.coin, inHole: 3)
        game.tap(hole: 3)
        #expect(game.tap(hole: 5) == .miss)
        #expect(game.combo == 0)
        #expect(game.score == 10)
        #expect(game.misses == 1)
        #expect(game.accuracy == 0.5)
        #expect(game.taps == 2)
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

    @Test func aCoinCanStillBeTappedAsItSinks() {
        var game = PumpDumpGame()
        var rng = SeededGenerator(seed: 2)
        game.place(.coin, inHole: 7, stay: 0.1)
        game.advance(by: 0.15, using: &rng) // Its time is up, but it's still sinking.
        let sinking = game.target(inHole: 7)
        #expect(sinking.map(game.isSinking) == true)
        #expect(game.tap(hole: 7) == .coin(points: 10))
        #expect(game.escaped == 0)
    }

    @Test func coinsThatGetAwayEndTheCombo() {
        var game = PumpDumpGame()
        var rng = SeededGenerator(seed: 2)
        tapCoins(4, in: &game)
        game.place(.coin, inHole: 7, stay: 0.1)
        game.place(.scam, inHole: 8, stay: 0.1)
        game.advance(by: 0.1 + PumpDumpGame.sinkTime + 0.01, using: &rng)
        #expect(game.target(inHole: 7) == nil)
        #expect(game.target(inHole: 8) == nil)
        #expect(game.escaped == 1) // The scam leaving doesn't count.
        #expect(game.escapedHoles == [7])
        #expect(game.combo == 0)
        #expect(game.lastLostCombo == 4)
        // The marks only last until the next step.
        game.advance(by: 0.01, using: &rng)
        #expect(game.escapedHoles.isEmpty)
    }

    @Test func aRoundLastsThirtySecondsAtAnyFrameRate() {
        var smooth = PumpDumpGame()
        var choppy = PumpDumpGame()
        var rngA = SeededGenerator(seed: 9)
        var rngB = SeededGenerator(seed: 9)
        var appeared = Set<Int>()
        while smooth.phase == .playing {
            smooth.advance(by: 1.0 / 120, using: &rngA)
            appeared.formUnion(smooth.targets.map(\.id))
            #expect(smooth.targets.count <= 4)
            #expect(Set(smooth.targets.map(\.hole)).count == smooth.targets.count)
        }
        while choppy.phase == .playing { choppy.advance(by: 0.25, using: &rngB) }
        #expect(smooth.time == PumpDumpGame.roundLength)
        #expect(smooth.targets.isEmpty)
        #expect(smooth.escaped == choppy.escaped)
        #expect(appeared.count > 30)
        // Nobody tapped, so the run is over.
        #expect(smooth.isOver)
        var over = smooth
        #expect(over.tap(hole: 0) == .miss)
        #expect(over.misses == 0)
        over.startNextRound()
        #expect(over.round == 1 && over.isOver)
    }

    @Test func reachingTheGoalClearsTheRoundAndTheNextIsHarder() {
        var game = PumpDumpGame()
        #expect(game.goal == 300)
        #expect(game.objective == .combo(10))
        tapCoins(20, in: &game) // 10 + 11 + … + 29 = 390, and a combo of 20.
        #expect(game.score == 390)
        #expect(game.isObjectiveMet)
        finishRound(&game)
        #expect(game.phase == .roundCleared)
        #expect(game.lastBonus == PumpDumpGame.objectiveBonus(round: 1))
        #expect(game.roundScore == 440) // The bonus counts toward the goal.
        #expect(game.score == 440)
        #expect(game.objectivesMet == 1)
        #expect(game.targets.isEmpty)
        // Nothing moves until the next round starts.
        var rng = SeededGenerator(seed: 1)
        game.advance(by: 1, using: &rng)
        #expect(game.time == PumpDumpGame.roundLength)
        game.startNextRound()
        #expect(game.phase == .playing)
        #expect(game.round == 2)
        #expect(game.time == 0 && game.roundScore == 0 && game.combo == 0 && game.lastBonus == 0)
        #expect(game.score == 440) // The run's total carries on.
        #expect(game.goal == 475)
        #expect(game.objective == .goldenCoins(2))
        #expect(game.objectiveProgress == (0, 2))
        // Later rounds are quicker.
        #expect(game.pace > 1)
    }

    @Test func fallingShortOfTheGoalEndsTheRun() {
        var game = PumpDumpGame()
        tapCoins(10, in: &game) // 145 points: short of 300, even with the combo bonus.
        finishRound(&game)
        #expect(game.lastBonus == 50)
        #expect(game.roundScore == 195)
        #expect(game.isOver)
        #expect(game.round == 1)
    }

    @Test func objectivesTakeTurnsAndGetHarder() {
        #expect(PumpDumpGame.objective(for: 1) == .combo(10))
        #expect(PumpDumpGame.objective(for: 2) == .goldenCoins(2))
        #expect(PumpDumpGame.objective(for: 3) == .noMistakes)
        #expect(PumpDumpGame.objective(for: 4) == .combo(15))
        #expect(PumpDumpGame.objective(for: 5) == .goldenCoins(3))
        #expect(PumpDumpGame.objectiveBonus(round: 4) == 200)

        var golden = PumpDumpGame()
        golden.jump(toRound: 2)
        golden.place(.golden, inHole: 0)
        golden.tap(hole: 0)
        #expect(golden.objectiveProgress == (1, 2))
        #expect(!golden.isObjectiveMet)
        golden.place(.golden, inHole: 1)
        golden.tap(hole: 1)
        #expect(golden.isObjectiveMet)

        var careful = PumpDumpGame()
        careful.jump(toRound: 3)
        #expect(careful.isObjectiveMet && !careful.isObjectiveFailed)
        careful.tap(hole: 4) // An empty hole is a mistake.
        #expect(careful.objectiveProgress == (0, 1))
        #expect(careful.isObjectiveFailed)
        var scammed = PumpDumpGame()
        scammed.jump(toRound: 3)
        scammed.place(.scam, inHole: 0)
        scammed.tap(hole: 0)
        #expect(scammed.isObjectiveFailed)
    }

    @Test func goalsRiseFasterThanTheRoundsDo() {
        let goals = (1...12).map(PumpDumpGame.goal(round:))
        #expect(goals.prefix(4) == [300, 475, 700, 975])
        let steps = zip(goals.dropFirst(), goals).map { $0 - $1 }
        #expect(zip(steps.dropFirst(), steps).allSatisfy { $0 > $1 })
    }

    @Test(arguments: [1, 4, 8, 30])
    func laterRoundsStayFairForAFinger(round: Int) {
        var game = PumpDumpGame()
        game.jump(toRound: round)
        var rng = SeededGenerator(seed: UInt64(round))
        var seen: [Int: PumpDumpGame.Target] = [:]
        while game.phase == .playing {
            game.advance(by: 1.0 / 60, using: &rng)
            for target in game.targets { seen[target.id] = target }
            #expect(game.targets.count <= 5)
        }
        let targets = seen.values.sorted { $0.appearedAt < $1.appearedAt }
        #expect(!targets.isEmpty)
        for target in targets {
            #expect(target.leavesAt - target.appearedAt >= PumpDumpGame.minimumStay - 1e-9)
            if let turnsAt = target.turnsAt { #expect(turnsAt > target.appearedAt + 0.3) }
        }
        let gaps = zip(targets.dropFirst(), targets).map { $0.appearedAt - $1.appearedAt }
        #expect(gaps.allSatisfy { $0 >= PumpDumpGame.minimumGap - 1e-9 })
        // Scams and rug pulls never take over.
        let bad = targets.filter { $0.kind == .scam || $0.kind == .rug }.count
        #expect(Double(bad) / Double(targets.count) < 0.65)
        #expect(game.pace <= 1.7)
    }

    @Test func aSkilledRunGoesSeveralRoundsAndThenEnds() {
        for seed in 1...4 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let run = PumpDumpBot.play(using: &rng, maxRounds: 40)
            #expect(run.isOver)
            #expect((3...12).contains(run.round), "seed \(seed) reached round \(run.round)")
            #expect(run.score >= (1..<run.round).reduce(0) { $0 + PumpDumpGame.goal(round: $1) })
            // The same seed plays the same run.
            var again = SeededGenerator(seed: UInt64(seed))
            #expect(PumpDumpBot.play(using: &again, maxRounds: 40).score == run.score)
        }
    }

    @Test func runsPayAndCountTowardTheRecords() {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        let payout = game.finishPumpDump(score: 400, coinsHit: 40, bestCombo: 18, scamsHit: 2, rounds: 3)
        #expect(payout.isNewBest)
        #expect(payout.coins == (400 * Tuning.pumpDumpSecondsPerPoint * 10 * 1.5).rounded())
        #expect(game.stats.pumpDumpGames == 1)
        #expect(game.stats.pumpDumpBestScore == 400)
        #expect(game.stats.pumpDumpCoinsHit == 40)
        #expect(game.stats.pumpDumpScamsHit == 2)
        #expect(game.stats.pumpDumpBestCombo == 18)
        #expect(game.stats.pumpDumpBestRound == 3)
        #expect(game.record(for: .pumpDump) == "Best 400 · round 3 · combo 18")
        // A run held when the app went away is paid on the next launch, round and all.
        game.holdArcadeRun(ArcadeRun(game: .pumpDump, score: 200, detail: 15, extra: 9, stage: 4))
        let held = game.payUnfinishedRun()
        #expect(held?.payout.isNewBest == false)
        #expect(game.stats.pumpDumpCoinsHit == 55)
        #expect(game.stats.pumpDumpBestRound == 4)
    }

    @Test func aHeldRunSurvivesSavingWithItsRound() throws {
        let run = ArcadeRun(game: .pumpDump, score: 900, detail: 70, extra: 12, stage: 3)
        let decoded = try JSONDecoder().decode(ArcadeRun.self, from: JSONEncoder().encode(run))
        #expect(decoded == run)
        // Saves from before rounds had no stage.
        let old = try JSONDecoder().decode(ArcadeRun.self, from: Data(#"{"game":"pumpDump","score":5,"detail":1,"extra":2}"#.utf8))
        #expect(old.stage == 0)
    }
}
