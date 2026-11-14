import Foundation
import Testing
@testable import CryptoClickerKit

/// Hash Smash's walls keep their mix at every level, classic and random: some bonus bricks (from
/// level 2 on classic walls, from level 1 on random ones), a few explosive ones, armor within its
/// share and getting tougher, plain bricks for the rest, and a fair number of hits.
@Suite("Hash Smash layouts")
struct BrickLayoutTests {
    typealias Game = BrickBreakerGame

    static let wallLevels = [1, 2, 3, 4, 6, 9, 11, 12, 24, 26, 49, 51, 99, 101, 149]
    static let bossLevels = [5, 10, 25, 50, 100]

    func wall(_ style: Game.LevelStyle, level: Int, seed: UInt64) -> Game {
        var game = Game(seed: seed, levels: style)
        game.jump(toLevel: level)
        return game
    }

    @Test(arguments: Game.LevelStyle.allCases)
    func everyWallKeepsItsMix(style: Game.LevelStyle) {
        for level in Self.wallLevels {
            for seed in UInt64(1)...(style == .classic ? 1 : 25) {
                let game = wall(style, level: level, seed: seed)
                let label = "\(style) level \(level) seed \(seed)"
                let count = Double(game.bricks.count)
                func number(_ kind: Game.BrickKind) -> Int { game.bricks.filter { $0.kind == kind }.count }
                let armored = number(.armored), bonus = number(.bonus), explosive = number(.explosive), plain = number(.normal)
                #expect(game.boss == nil && !game.bricks.isEmpty, "\(label)")
                // Power-ups keep coming: from level 2 on classic walls, from level 1 on random ones.
                if style == .generated || level >= 2 { #expect(bonus >= 1, "\(label): no bonus bricks") }
                #expect(bonus <= Game.maxBonusBricks && explosive <= Game.maxExplosiveBricks, "\(label)")
                #expect(bonus + explosive <= max(1, game.bricks.count / 4), "\(label): \(bonus + explosive) specials")
                // Armor within its share, from level 3 on (random walls from level 1).
                let share = style == .classic ? Game.classicArmorShare : Game.generatedArmorShare.upperBound
                #expect(Double(armored) <= share * count + 1, "\(label): \(armored) armored of \(game.bricks.count)")
                if style == .generated || level >= 3 { #expect(armored >= 2, "\(label): \(armored) armored") }
                // Plain bricks always a good part of it.
                #expect(Double(plain) >= 0.3 * count, "\(label): \(plain) plain of \(game.bricks.count)")
                // Armor as strong as the level allows, and no more.
                let strength = Game.armorStrength(level: level)
                #expect(game.bricks.filter { $0.kind == .armored }.allSatisfy { strength.contains($0.maxHits) }, "\(label)")
                #expect(game.bricks.filter { $0.kind != .armored }.allSatisfy { $0.maxHits == 1 }, "\(label)")
                // A fair number of hits: never more than a full wall, never a pushover.
                let hits = Double(game.bricks.reduce(0) { $0 + $1.maxHits })
                let full = Double(Game.fullWallHits(level: level))
                #expect(hits <= 1.05 * full && hits >= 0.35 * full, "\(label): \(Int(hits)) hits of \(Int(full))")
                // Inside the field, one brick a cell.
                #expect(Set(game.bricks.map { $0.row * Game.columns + $0.column }).count == game.bricks.count, "\(label)")
                #expect(game.bricks.allSatisfy { $0.frame.minX >= 0 && $0.frame.maxX <= Game.width }, "\(label)")
            }
        }
    }

    @Test func laterWallsAreTougher() {
        func averageHits(_ level: Int, _ style: Game.LevelStyle) -> Double {
            let seeds = UInt64(1)...20
            return seeds.map { seed -> Double in
                let bricks = wall(style, level: level, seed: seed).bricks
                return Double(bricks.reduce(0) { $0 + $1.maxHits }) / Double(bricks.count)
            }.reduce(0, +) / Double(seeds.count)
        }
        for style in Game.LevelStyle.allCases {
            #expect(averageHits(1, style) < averageHits(6, style), "\(style)")
            #expect(averageHits(6, style) < averageHits(26, style), "\(style)")
        }
    }

    @Test(arguments: Game.LevelStyle.allCases)
    func bossLevelsStayBossLevels(style: Game.LevelStyle) {
        for level in Self.bossLevels {
            let game = wall(style, level: level, seed: 3)
            #expect(game.boss != nil, "\(style) level \(level)")
            #expect(game.bricks.filter { $0.kind == .bonus }.count == 2, "\(style) level \(level)")
        }
    }
}
