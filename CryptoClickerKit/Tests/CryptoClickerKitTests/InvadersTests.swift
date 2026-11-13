import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Scam Invaders")
struct InvadersTests {
    typealias Game = InvadersGame

    /// A game past its opening banner, with the invaders holding their fire and their ground. Hard
    /// by default (one hit loses a ship), at Normal speed.
    func quiet(seed: UInt64 = 7, speed: GameSpeed = .normal, difficulty: Game.Difficulty = .hard) -> Game {
        var game = Game(seed: seed, difficulty: difficulty, speed: speed)
        game.skipBanner()
        game.holdFire()
        game.holdMarch()
        return game
    }

    /// Runs the game at 60 frames a second for `seconds`, or until `stop` says so.
    func run(_ game: inout Game, for seconds: Double, until stop: (Game) -> Bool = { _ in false }) {
        var time = 0.0
        while time < seconds && game.phase != .over && !stop(game) {
            game.update(by: 1.0 / 60)
            time += 1.0 / 60
        }
    }

    // Columns 1 and 6 stand over the gaps between firewalls, so shots there have a clear path.

    func center(of game: Game, row: Int, column: Int) -> Double {
        let invader = game.invaders.first { $0.row == row && $0.column == column }!
        return game.frame(of: invader).midX
    }

    @Test func aGameCanStartAtAWaveReachedBefore() {
        let later = Game(seed: 1, startWave: 3)
        #expect(later.wave == 3 && later.lives == Game.startingLives && later.score == 0)
        #expect(later.phase == .incoming && later.boss == nil)
        #expect(later.invaders.count == Game.rows * Game.columns)
        #expect(later.invaders.contains { $0.isGolden }) // From wave 2 on, as always.
        let bear = Game(seed: 1, startWave: 5)
        #expect(bear.isBossWave && bear.boss != nil)
        #expect(Game(seed: 1, startWave: 0).wave == 1)
    }

    @Test func wavesUnlockAsFarAsTheBestWaveReached() {
        var state = GameState.make()
        #expect(state.invadersStartWaves == 1...1)
        state.finishInvaders(score: 1_000, destroyed: 60, wave: 6)
        #expect(state.invadersStartWaves == 1...6)
        state.finishInvaders(score: 10, destroyed: 1, wave: 1)
        #expect(state.invadersStartWaves == 1...6)
    }

    @Test func randomWavesDontUnlockClassicWaves() throws {
        var state = GameState.make()
        state.finishInvaders(score: 1_000, destroyed: 60, wave: 9, waves: .generated)
        #expect(state.invadersStartWaves == 1...1)
        #expect(state.stats.invadersBestWave == 9) // Still the furthest wave reached, for records.
        // A random game paid on the next launch doesn't either.
        state.holdArcadeRun(ArcadeRun(game: .invaders, score: 500, detail: 30, extra: 11, records: .init(mode: 1)))
        state.payUnfinishedRun()
        #expect(state.invadersStartWaves == 1...1 && state.stats.invadersBestWave == 11)
        state.finishInvaders(score: 1_000, destroyed: 60, wave: 4)
        #expect(state.invadersStartWaves == 1...4)
        // Saves from before keep every wave they had unlocked.
        let old = try GameCoding.decoder().decode(Stats.self, from: Data(#"{"invadersBestWave":7}"#.utf8))
        #expect(old.invadersClassicBestWave == 7)
    }

    @Test func easyPaysLessAndHardPaysMore() {
        var state = GameState.make(miners: minersEarning(10))
        state.finishInvaders(score: 5_000, destroyed: 100, wave: 7) // A best to stay under.
        let regular = state.finishInvaders(score: 1_000, destroyed: 20, wave: 2)
        let easy = state.finishInvaders(score: 1_000, destroyed: 20, wave: 2, difficulty: .easy)
        let hard = state.finishInvaders(score: 1_000, destroyed: 20, wave: 2, difficulty: .hard)
        #expect(regular.coins == state.arcadeReward(.invaders, score: 1_000))
        #expect(easy.coins == state.arcadeReward(.invaders, score: 800))
        #expect(hard.coins == state.arcadeReward(.invaders, score: 1_200))
        // A Hard game paid on the next launch too.
        state.holdArcadeRun(ArcadeRun(game: .invaders, score: 1_000, detail: 20, extra: 2, records: .init(difficulty: .hard)))
        #expect(state.payUnfinishedRun()?.payout.coins == state.arcadeReward(.invaders, score: 1_200))
    }

    @Test func everyoneFiresFivePercentMoreOften() {
        let game = Game(seed: 1)
        #expect(abs(game.enemyFireInterval - 1.15 / 1.05) < 1e-9)
        #expect(abs(Game.bossFireInterval(wave: 5) - 1.8 / 1.05) < 1e-9)
    }

    @Test func eachDifficultyTakesItsOwnHitsAndSpeed() {
        #expect(Game.Difficulty.allCases.map(\.hitsPerShip) == [3, 2, 1])
        #expect(Game.Difficulty.allCases.map(\.speed) == [.slow, .normal, .fast])
        #expect(Game(seed: 1).difficulty == .regular && Game(seed: 1).gameSpeed == .normal)
        #expect(Game(seed: 1, difficulty: .easy).gameSpeed == .slow)
        for difficulty in Game.Difficulty.allCases {
            var game = quiet(difficulty: difficulty)
            #expect(game.health == difficulty.hitsPerShip && game.maxHealth == difficulty.hitsPerShip)
            game.moveShip(to: 0.5)
            // Every hit but the last leaves the ship flying, damaged, and blinking for a moment.
            for left in stride(from: difficulty.hitsPerShip - 1, through: 1, by: -1) {
                game.dropEnemyShot(at: Vector2(x: 0.5, y: 1.3))
                run(&game, for: 0.5) { $0.health == left }
                #expect(game.health == left && game.lives == Game.startingLives && game.phase == .playing, "\(difficulty)")
                #expect(game.invulnerableFor > 0)
                // A second shot right behind passes through.
                game.dropEnemyShot(at: Vector2(x: 0.5, y: 1.3))
                run(&game, for: 0.3)
                #expect(game.health == left)
                run(&game, for: 1)
            }
            #expect(game.hitsTaken == difficulty.hitsPerShip - 1)
            game.dropEnemyShot(at: Vector2(x: 0.5, y: 1.3))
            run(&game, for: 0.5) { $0.phase != .playing }
            #expect(game.lives == Game.startingLives - 1 && game.phase == .shipLost, "\(difficulty)")
            // The next ship comes in whole.
            #expect(game.health == difficulty.hitsPerShip)
        }
    }

    @Test func theShieldIsAnExtraHitThatMendsADamagedShipFirst() {
        var game = quiet(difficulty: .regular)
        game.moveShip(to: 0.5)
        game.give(.shield)
        #expect(game.health == 3 && game.hasShield)
        game.give(.shield) // Never more than one over full.
        #expect(game.health == 3)
        game.dropEnemyShot(at: Vector2(x: 0.5, y: 1.3))
        run(&game, for: 0.5) { !$0.hasShield }
        #expect(game.health == 2 && game.shieldSaves == 1 && game.lives == Game.startingLives)
        run(&game, for: 1)
        game.dropEnemyShot(at: Vector2(x: 0.5, y: 1.3))
        run(&game, for: 0.5) { $0.health == 1 }
        #expect(game.health == 1 && game.shieldSaves == 1)
        game.give(.shield) // Mends the damage.
        #expect(game.health == 2 && !game.hasShield)
    }

    @Test func aGameStartedFurtherInPaysASmallerShare() {
        var state = GameState.make(miners: minersEarning(10))
        state.finishInvaders(score: 5_000, destroyed: 100, wave: 7)
        // From wave 6: 1 / (1 + 0.1 × 5) = two thirds of its points.
        let later = state.finishInvaders(score: 3_000, destroyed: 50, wave: 8, startWave: 6)
        #expect(later.coins == state.arcadeReward(.invaders, score: 2_000))
        state.holdArcadeRun(ArcadeRun(game: .invaders, score: 1_500, detail: 30, extra: 7, records: .init(start: 6)))
        #expect(state.payUnfinishedRun()?.payout.coins == state.arcadeReward(.invaders, score: 1_000))
    }

    @Test func aGameStartsWithAFullFormationBehindFourFirewalls() {
        var game = Game(seed: 1)
        #expect(game.invaders.count == Game.rows * Game.columns)
        #expect(game.invaders.filter { $0.row == 0 }.allSatisfy { $0.kind == .rugPuller })
        #expect(game.invaders.filter { (1...2).contains($0.row) }.allSatisfy { $0.kind == .pumpBot })
        #expect(game.invaders.filter { $0.row >= 3 }.allSatisfy { $0.kind == .memeCoin })
        #expect(!game.invaders.contains { $0.isGolden }) // Golden invaders come from wave 2.
        #expect(game.firewalls.count == 4 && game.firewalls.allSatisfy { $0.standing == 40 }) // Solid server racks, 5 by 8.
        #expect(game.lives == 5 && game.wave == 1 && game.score == 0)
        // The banner holds for a moment, then the march begins.
        #expect(game.phase == .incoming)
        run(&game, for: 1.3)
        #expect(game.phase == .playing)
        // Every invader sits inside the field, above the firewalls.
        for invader in game.invaders {
            let frame = game.frame(of: invader)
            #expect(frame.minX >= 0 && frame.maxX <= Game.width && frame.maxY < 1.18)
        }
    }

    @Test func holdingFireShootsAtMostTwoVolleysAtOnce() {
        var game = quiet()
        game.moveShip(to: 0.5) // Between columns and between firewalls: nothing to hit.
        game.isFiring = true
        game.update(by: 1.0 / 60)
        #expect(game.shots.count == 1 && game.volleysFired == 1)
        run(&game, for: 0.39)
        #expect(game.volleysFired == 2)
        run(&game, for: 0.3)
        #expect(game.shots.count <= 2)
        game.isFiring = false
        let fired = game.volleysFired
        run(&game, for: 1)
        #expect(game.volleysFired == fired && game.shots.isEmpty)
    }

    @Test func aShotDestroysTheInvaderItHitsAndTheStreakRaisesThePoints() {
        var game = quiet()
        game.keepInvaders(at: (0..<5).map { (row: $0, column: 1) })
        game.moveShip(to: center(of: game, row: 4, column: 1))
        game.isFiring = true
        run(&game, for: 5) { $0.invaders.isEmpty }
        // Bottom up: two meme coins, two pump bots and a rug puller, each 10% more than the last.
        #expect(game.invadersDestroyed == 5)
        #expect(game.bestStreak == 5)
        let fromInvaders = 10 + 11 + 24 + 26 + 42
        // Clearing wave 1 adds 100, and 50 more for keeping every ship.
        #expect(game.score == fromInvaders + 150)
        #expect(game.lastWaveBonus == 150)
        #expect(game.phase == .waveCleared)
        #expect(game.accuracy == 1)
    }

    @Test func aVolleyThatMissesEndsTheStreak() {
        var game = quiet()
        game.keepInvaders(at: [(row: 4, column: 1), (row: 4, column: 6)])
        game.moveShip(to: center(of: game, row: 4, column: 1))
        game.isFiring = true
        run(&game, for: 3) { $0.invadersDestroyed == 1 }
        #expect(game.streak == 1)
        // Into the gap between columns: the volley flies off the top.
        game.moveShip(to: 0.5)
        run(&game, for: 3) { $0.streak == 0 }
        #expect(game.streak == 0)
        #expect(game.bestStreak == 1)
        #expect(game.accuracy < 1)
    }

    @Test func goldenInvadersPayDoubleAndDropAPowerUp() {
        var game = Game(seed: 3)
        game.jump(toWave: 2)
        game.skipBanner()
        game.holdFire()
        game.holdMarch()
        let golden = game.invaders.filter(\.isGolden)
        #expect(golden.count == 1)
        let target = golden[0]
        game.keepInvaders(at: [(row: target.row, column: target.column)])
        game.moveShip(to: game.frame(of: target).midX)
        game.isFiring = true
        // (Shots may have to chip through a firewall first.)
        run(&game, for: 8) { $0.invadersDestroyed == 1 }
        #expect(game.invadersDestroyed == 1)
        #expect(game.score >= 2 * target.kind.points)
        #expect(game.events.contains { if case .invaderDestroyed(_, _, true, _) = $0 { true } else { false } })
    }

    @Test func fallingPowerUpsAreCaughtWithTheShip() {
        var game = quiet()
        game.moveShip(to: 0.5)
        game.dropCapsule(.rapidFire, at: Vector2(x: 0.5, y: 1.3))
        run(&game, for: 0.5) { $0.powerUpsCaught > 0 }
        #expect(game.powerUpsCaught == 1 && game.isActive(.rapidFire))
        // One that misses the ship falls away.
        game.dropCapsule(.laser, at: Vector2(x: 0.1, y: 1.3))
        run(&game, for: 1)
        #expect(game.capsules.isEmpty && !game.isActive(.laser))
        // Timed power-ups run out.
        run(&game, for: 9)
        #expect(!game.isActive(.rapidFire))
    }

    @Test func spreadShotFiresThreeAndRapidFireFiresMoreOften() {
        var spread = quiet()
        spread.give(.spreadShot)
        spread.moveShip(to: 0.5)
        spread.isFiring = true
        spread.update(by: 1.0 / 60)
        #expect(spread.shots.count == 3 && spread.volleysFired == 1)

        func volleys(in seconds: Double, rapid: Bool) -> Int {
            var game = quiet()
            if rapid { game.give(.rapidFire) }
            game.moveShip(to: 0.5)
            game.isFiring = true
            run(&game, for: seconds)
            return game.volleysFired
        }
        // Into empty sky, where the volleys in the air cap it: near targets it's more.
        #expect(2 * volleys(in: 3, rapid: true) > 3 * volleys(in: 3, rapid: false))
    }

    @Test func aLaserBurnsThroughAWholeColumn() {
        var game = quiet()
        game.keepInvaders(at: (0..<5).map { (row: $0, column: 1) } + [(row: 4, column: 6)])
        game.give(.laser)
        game.moveShip(to: center(of: game, row: 4, column: 1))
        game.isFiring = true
        game.update(by: 1.0 / 60)
        game.isFiring = false
        run(&game, for: 1.5)
        #expect(game.invadersDestroyed == 5)
        #expect(game.volleysFired == 1 && game.volleysHit == 1)
    }

    @Test func shotsChipTheFirewalls() {
        var game = quiet()
        // The first firewall's second column, from below: its bottom block goes first.
        game.moveShip(to: 0.12)
        game.isFiring = true
        game.update(by: 1.0 / 60)
        game.isFiring = false
        run(&game, for: 0.5)
        let wall = game.firewalls[0]
        #expect(wall.standing == 39)
        #expect(!wall.isStanding(row: 4, column: 1) && wall.isStanding(row: 3, column: 1))
        #expect(game.streak == 0) // Hitting a wall is a miss.
        // An invader's shot lands on top and takes a neighbor with it.
        game.dropEnemyShot(at: Vector2(x: 0.12, y: 1.1))
        run(&game, for: 0.5)
        #expect(game.firewalls[0].standing == 37)
        #expect(!game.firewalls[0].isStanding(row: 0, column: 1))
    }

    @Test func aHitCostsAShipThenTheNewOneBlinksAndAShieldSavesOne() {
        var game = quiet()
        game.moveShip(to: 0.5)
        game.give(.rapidFire)
        game.dropEnemyShot(at: Vector2(x: 0.5, y: 1.3))
        run(&game, for: 0.5) { $0.phase != .playing }
        #expect(game.lives == 4 && game.shipsLost == 1)
        #expect(game.phase == .shipLost)
        #expect(!game.isActive(.rapidFire)) // Power-ups go with the ship.
        run(&game, for: 1.4)
        #expect(game.phase == .playing && game.invulnerableFor > 0)
        // While it blinks, shots pass through.
        game.dropEnemyShot(at: Vector2(x: 0.5, y: 1.3))
        run(&game, for: 0.4)
        #expect(game.lives == 4)
        run(&game, for: 1.5)
        game.give(.shield)
        game.dropEnemyShot(at: Vector2(x: 0.5, y: 1.3))
        run(&game, for: 0.5)
        #expect(game.lives == 4 && game.shieldSaves == 1 && !game.hasShield)
        // The last ship ends the game.
        for _ in 0..<4 {
            run(&game, for: 3.2)
            game.dropEnemyShot(at: Vector2(x: 0.5, y: 1.3))
            run(&game, for: 0.5) { $0.phase != .playing }
        }
        #expect(game.lives == 0 && game.phase == .over)
    }

    @Test func theFormationMarchesDropsAtTheEdgesAndLandingEndsTheGame() {
        var game = Game(seed: 5)
        game.skipBanner()
        game.holdFire()
        let start = game.formationOrigin
        let pose = game.marchPose
        run(&game, for: game.marchInterval + 0.01)
        #expect(abs(game.formationOrigin.x - start.x - Game.stepX) < 1e-9)
        #expect(game.formationOrigin.y == start.y && game.marchPose != pose)
        // At the right edge the next step drops instead, and turns back.
        game.placeFormation(at: Vector2(x: Game.width - Game.sideMargin - (Double(Game.columns - 1) * Game.columnSpacing + Game.invaderSize.width) - 0.001,
                                        y: start.y))
        let edge = game.formationOrigin
        run(&game, for: game.marchInterval + 0.01)
        #expect(abs(game.formationOrigin.y - edge.y - Game.dropY) < 1e-9)
        #expect(game.formationOrigin.x == edge.x)
        run(&game, for: game.marchInterval + 0.01)
        #expect(game.formationOrigin.x < edge.x)
        // Invaders crush the firewalls they reach, and reaching the ship's line is the end.
        game.placeFormation(at: Vector2(x: game.formationOrigin.x, y: 1.16 - 4 * Game.rowSpacing))
        run(&game, for: 2 * game.marchInterval + 0.02)
        #expect(game.firewalls.contains { $0.standing < 40 })
        game.placeFormation(at: Vector2(x: game.formationOrigin.x, y: Game.shipTop - Game.invaderSize.height - 4 * Game.rowSpacing + 0.001))
        run(&game, for: 2 * game.marchInterval + 0.02)
        #expect(game.phase == .over && game.lives == 0)
    }

    @Test func theMarchSpeedsUpAsTheFormationThinsAndEachWave() {
        var game = quiet()
        let full = game.marchInterval
        game.keepInvaders(at: [(row: 0, column: 0)])
        #expect(game.marchInterval < full / 4)
        var later = Game(seed: 1)
        later.jump(toWave: 6)
        #expect(later.marchInterval < full)
        #expect(later.enemyFireInterval < Game(seed: 1).enemyFireInterval)
        #expect(later.maxEnemyShots > Game(seed: 1).maxEnemyShots)
        #expect(Game.formationTop(wave: 6) > Game.formationTop(wave: 1))
        #expect(Game.formationTop(wave: 40) == Game.formationTop(wave: 7)) // It stops getting lower.
    }

    @Test func clearingAWaveBringsTheNextWithAGoldenInvader() {
        var game = quiet()
        game.keepInvaders(at: [(row: 4, column: 1)])
        game.moveShip(to: center(of: game, row: 4, column: 1))
        game.isFiring = true
        run(&game, for: 3) { $0.phase == .waveCleared }
        game.isFiring = false
        run(&game, for: 1.1)
        #expect(game.wave == 2 && game.phase == .incoming)
        #expect(game.invaders.count == 40 && game.invaders.filter { $0.isGolden }.count == 1)
        #expect(game.firewalls.allSatisfy { $0.standing == 40 })
        #expect(abs(game.formationOrigin.y - Game.formationTop(wave: 2)) < 1e-9)
    }

    @Test func everyFifthWaveIsABossThatGivesBackAShip() {
        var game = quiet()
        game.jump(toWave: 5)
        game.skipBanner()
        game.holdFire()
        game.holdMarch()
        #expect(game.isBossWave)
        let boss = game.boss!
        #expect(boss.maxHits == 25 && game.invaders.count == 16)
        #expect(Game.bossHits(wave: 10) == 40)
        // Lose a ship first, so the boss has one to give back.
        game.dropEnemyShot(at: Vector2(x: game.shipX, y: 1.3))
        run(&game, for: 0.5) { $0.phase == .shipLost }
        run(&game, for: 3.2)
        #expect(game.lives == 4)
        game.setBossHits(1)
        game.keepInvaders(at: [])
        // Wait for the boss to slide over the ship, then fire.
        game.moveShip(to: 0.5)
        run(&game, for: 6) { abs($0.boss!.frame.midX - 0.5) < 0.05 }
        game.isFiring = true
        run(&game, for: 2) { $0.boss == nil }
        #expect(game.bossesDefeated == 1 && game.lives == 5)
        #expect(game.score >= 500)
        #expect(game.phase == .waveCleared)
    }

    @Test func shootingTheWhalePaysABonusAndDropsAPowerUp() {
        var game = quiet()
        game.sendWhale(at: 0.5, speedX: 0)
        game.moveShip(to: 0.5) // Between the formation's columns, under the whale.
        game.isFiring = true
        run(&game, for: 2) { $0.whalesHit > 0 }
        game.isFiring = false
        #expect(game.whalesHit == 1 && game.whale == nil)
        #expect([50, 100, 150, 300].contains(game.score))
        #expect(game.capsules.count == 1)
    }

    @Test func fastMarchesAndFiresSoonerThanSlow() {
        let slow = Game(seed: 1, speed: .slow), normal = Game(seed: 1), fast = Game(seed: 1, speed: .fast)
        #expect(slow.marchInterval > normal.marchInterval && normal.marchInterval > fast.marchInterval)
        #expect(slow.enemyShotSpeed < fast.enemyShotSpeed)
    }

    @Test func aLongFrameCountsAsAtMostAFewHundredths() {
        var game = Game(seed: 1)
        game.update(by: 5)
        #expect(abs(game.holdFor - (Game.incomingHold - 0.05)) < 1e-9)
        game.update(by: .infinity)
        game.update(by: -1)
        #expect(abs(game.holdFor - (Game.incomingHold - 0.05)) < 1e-9)
    }

    @Test(arguments: Game.WaveStyle.allCases)
    func theSameSeedAndMovesPlayTheSameGame(_ waves: Game.WaveStyle) {
        func play(seed: UInt64) -> (Int, Int, Int, Int) {
            var game = Game(seed: seed, waves: waves)
            for frame in 0..<(60 * 40) {
                game.moveShip(to: 0.5 + 0.4 * sin(Double(frame) / 50))
                game.isFiring = frame % 90 < 70
                game.update(by: 1.0 / 60)
            }
            return (game.score, game.invadersDestroyed, game.lives, game.wave)
        }
        #expect(play(seed: 9) == play(seed: 9))
    }

    @Test func aLongRandomGameKeepsItsRules() {
        var rng = SeededGenerator(seed: 4)
        let games: [(GameSpeed, Game.WaveStyle)] = GameSpeed.allCases.map { ($0, .classic) } + [(.normal, .generated), (.fast, .generated)]
        for (speed, waves) in games {
            var game = Game(seed: 12, speed: speed, waves: waves)
            var frames = 0
            while game.phase != .over && frames < 60 * 240 {
                frames += 1
                if frames % 20 == 0 { game.moveShip(to: Double.random(in: 0...1, using: &rng)) }
                game.isFiring = Bool.random(using: &rng) || frames % 3 == 0
                game.update(by: frames % 97 == 0 ? 0.3 : 1.0 / 60)
                #expect((0...Game.startingLives).contains(game.lives))
                #expect(game.score >= 0 && game.streak <= game.bestStreak)
                #expect(game.shots.count <= 3 * 4)
                #expect(game.volleysHit <= game.volleysFired)
                if game.phase == .playing {
                    #expect(game.invaders.allSatisfy { game.frame(of: $0).maxY < Game.shipTop })
                }
            }
            #expect(game.invadersDestroyed > 0)
        }
    }
}

@Suite("Scam Invaders: random waves")
struct InvadersRandomWaveTests {
    typealias Game = InvadersGame

    static func layout(_ game: Game) -> String {
        game.invaders.map { "\($0.row),\($0.column),\($0.kind)" }.sorted().joined(separator: " ")
    }

    @Test func randomWavesAreMirroredFormationsOfAFairSize() {
        var points = 0, count = 0, classicPoints = 0
        var goldenCounts = Set<Int>(), rackShapes = Set<String>()
        for seed in UInt64(1)...40 {
            var game = Game(seed: seed, waves: .generated)
            var classic = Game(seed: seed)
            for wave in 1...12 where wave % Game.bossEvery != 0 {
                game.jump(toWave: wave)
                classic.jump(toWave: wave)
                let invaders = game.invaders
                let label = "seed \(seed) wave \(wave)"
                #expect((Game.generatedMinimum...Game.rows * Game.columns).contains(invaders.count), "\(label): \(invaders.count)")
                #expect(invaders.allSatisfy { (0..<Game.rows).contains($0.row) && (0..<Game.columns).contains($0.column) }, "\(label)")
                #expect(Set(invaders.map { "\($0.row),\($0.column)" }).count == invaders.count, "\(label) has two in one place")
                // Mirrored left to right, kinds and all.
                let kinds = Dictionary(uniqueKeysWithValues: invaders.map { ("\($0.row),\($0.column)", $0.kind) })
                #expect(invaders.allSatisfy { kinds["\($0.row),\(Game.columns - 1 - $0.column)"] == $0.kind }, "\(label) isn't mirrored")
                // On the classic formation's bottom row, so it comes down no later.
                #expect(invaders.map(\.row).max() == Game.rows - 1, "\(label)")
                // Every kind, and one to three golden invaders (four from wave 6) from the very first wave.
                #expect(Set(invaders.map(\.kind)).count == Game.InvaderKind.allCases.count, "\(label)")
                let golden = invaders.filter(\.isGolden).count
                #expect((1...(wave >= 6 ? 4 : 3)).contains(golden), "\(label): \(golden) golden")
                goldenCounts.insert(golden)
                // Server racks of their own: two to five, inside the field, apart, above the ship.
                let racks = game.firewalls
                #expect((2...5).contains(racks.count), "\(label)")
                #expect(racks.allSatisfy { $0.frame.minX > 0 && $0.frame.maxX < Game.width && $0.frame.maxY < Game.shipTop - 0.05 })
                #expect(zip(racks, racks.dropFirst()).allSatisfy { $0.frame.maxX < $1.frame.minX }, "\(label) racks overlap")
                #expect(racks.allSatisfy { $0.standing == $0.rows * $0.columns })
                rackShapes.insert(racks.map { "\($0.rows)x\($0.columns)@\(Int($0.frame.minX * 100))" }.joined(separator: " "))
                points += invaders.reduce(0) { $0 + $1.kind.points }
                count += invaders.count
                classicPoints += classic.invaders.reduce(0) { $0 + $1.kind.points }
            }
        }
        // Each invader is worth about what the classic's are (18 points on average), and a made-up
        // wave holds about three quarters as many.
        let perInvader = Double(points) / Double(count)
        print("Random waves: \(Double(count) / 400) invaders a wave, \(perInvader) points each")
        #expect(abs(perInvader - 18) < 1)
        #expect(Double(points) >= 0.7 * Double(classicPoints) && Double(points) <= 0.9 * Double(classicPoints))
        #expect(goldenCounts == [1, 2, 3, 4])
        #expect(rackShapes.count > 300) // Racks differ from wave to wave.
    }

    @Test func classicWavesAreTheSameEveryGame() {
        for wave in 1...12 {
            var first = Game(seed: 1)
            first.jump(toWave: wave)
            let golden = first.invaders.filter(\.isGolden).map { "\($0.row),\($0.column)" }
            #expect(golden.count == (wave == 1 ? 0 : 1), "wave \(wave)")
            #expect(first.firewalls.count == 4 && first.firewalls.allSatisfy { $0.rows == 5 && $0.columns == 8 })
            for seed in UInt64(2)...15 {
                var other = Game(seed: seed)
                other.jump(toWave: wave)
                #expect(Self.layout(other) == Self.layout(first), "wave \(wave)")
                #expect(other.invaders.filter(\.isGolden).map { "\($0.row),\($0.column)" } == golden, "wave \(wave) seed \(seed)")
                #expect(other.firewalls.map(\.frame) == first.firewalls.map(\.frame))
            }
        }
    }

    @Test func randomWavesAreRarelyTheSameAndBossesStayBosses() {
        var layouts = Set<String>()
        for seed in UInt64(1)...30 {
            var game = Game(seed: seed, waves: .generated)
            game.jump(toWave: 3)
            layouts.insert(Self.layout(game))
        }
        #expect(layouts.count >= 25)
        // Classic waves are the same every time.
        var classic = Set<String>()
        for seed in UInt64(1)...10 {
            var game = Game(seed: seed)
            game.jump(toWave: 3)
            classic.insert(Self.layout(game))
        }
        #expect(classic.count == 1)
        // A boss wave is the same in both.
        var boss = Game(seed: 5, waves: .generated)
        boss.jump(toWave: 5)
        var classicBoss = Game(seed: 5)
        classicBoss.jump(toWave: 5)
        #expect(boss.boss != nil && Self.layout(boss) == Self.layout(classicBoss))
    }

    @Test func aRandomWaveSetsOffEitherWayAndAWholeGameRunsOnThem() {
        var directions = Set<Bool>()
        for seed in UInt64(1)...16 {
            var game = Game(seed: seed, waves: .generated)
            game.skipBanner()
            game.holdFire()
            let start = game.formationOrigin.x
            var time = 0.0
            while game.formationOrigin.x == start && time < 2 {
                game.update(by: 1.0 / 60)
                time += 1.0 / 60
            }
            #expect(game.formationOrigin.x != start)
            directions.insert(game.formationOrigin.x > start)
        }
        #expect(directions.count == 2)
        // The next wave is made up too.
        var game = Game(seed: 3, waves: .generated)
        let first = Self.layout(game)
        game.jump(toWave: 2)
        #expect(game.waveStyle == .generated && Self.layout(game) != first)
    }
}

