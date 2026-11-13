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
        #expect(MiniGame.brickBreaker.guide.ending.contains("\(BrickBreakerGame.startingLives) lives"))
        #expect(MiniGame.bubbleBlaster.guide.items[0].detail.contains("\(BubbleShooterGame.missesPerRow) shots"))
        #expect(MiniGame.snake.guide.scoring[0].contains("\(SnakeGame.pointsPerCoin) points"))
    }

    /// Each game explains its own pieces, with the numbers from the rules.
    @Test func everyGameNamesItsOwnPieces() {
        let chain = MiniGame.tetris.guide
        #expect(chain.items.contains { $0.id == "tetris.gas" && $0.detail.contains("every \(TetrisGame.gasSpikeEvery) pieces") })
        #expect(chain.scoring.contains { $0.contains("fee of \(TetrisGame.gasFee)") })
        let snake = MiniGame.snake.guide
        #expect(snake.items.map(\.name).starts(with: ["Lightning", "Cold Storage", "Hardware Wallet", "Airdrop Magnet"]))
        #expect(snake.items.last?.detail.hasPrefix("Mining Farm, Exchange Floor and Node Network") == true)
        let smash = MiniGame.brickBreaker.guide
        #expect(["Fork", "Deep Liquidity", "Gas Limit", "Hash Rate", "The whale"].allSatisfy { name in smash.items.contains { $0.name == name } })
        let market = MiniGame.bubbleBlaster.guide
        #expect(market.items.map(\.name).contains("Stablecoin") && market.ending.contains("crash line"))
        #expect(MiniGame.merge2048.guide.items.contains { $0.detail.contains("Lunar Base (2,048)") })
        #expect(MiniGame.videoPoker.guide.controls.contains { $0.contains("HODL") })
        #expect(MiniGame.invaders.guide.items.contains { $0.name == "Server racks" })
    }
}

@Suite("Crypto arcade")
struct CryptoArcadeTests {
    @Test func theGamesHaveCryptoNames() {
        let names: [MiniGame: String] = [
            .tetris: "Block Chain", .merge2048: "Merge Mining", .snake: "Hash Chain", .brickBreaker: "Hash Smash",
            .bubbleBlaster: "Bubble Market", .blackjack: "21 Million", .videoPoker: "Diamond Hands",
        ]
        for (game, name) in names {
            #expect(game.name == name)
        }
        // Every game has its own icon.
        let icons = MiniGame.allCases.map(\.info.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test func piecesAndPowerUpsHaveCryptoNames() {
        #expect(SnakeGame.Arena.allCases.map(\.name) == ["Open", "Mining Farm", "Exchange Floor", "Node Network"])
        #expect(BrickBreakerGame.PowerUp.allCases.map(\.name) == ["Fork", "Deep Liquidity", "Gas Limit", "Hash Rate"])
        #expect(BubbleShooterGame.Special.allCases.map(\.name) == ["Stablecoin", "Flash Crash"])
        let snakeCharmer = AchievementCatalog.all.first { $0.id == "snake-charmer" }
        #expect(snakeCharmer?.name == "Chain Reaction" && snakeCharmer?.detail == "Score in a single Hash Chain game")
    }

    @Test func mergeMiningClimbsTheMinerLadderToTheMoon() {
        #expect(Merge2048Game.miner(for: 2) == .chromebook)
        #expect(Merge2048Game.miner(for: 4) == .desktop)
        #expect(Merge2048Game.miner(for: 128) == .robotAssistant)
        #expect(Merge2048Game.miner(for: Merge2048Game.winningValue) == .lunarBase)
        #expect(Merge2048Game.miner(for: 4_096) == .asteroidHarvester)
        #expect(Merge2048Game.miner(for: 8_192) == .galacticHashnet)
        #expect(Merge2048Game.miner(for: 131_072) == .galacticHashnet)
        // Every goal tile is a different miner until the top of the ladder.
        let goals = Merge2048Game.goalTiles.prefix(6).map(Merge2048Game.miner(for:))
        #expect(Set(goals).count == goals.count)
    }

    @Test func serverRacksStandSolid() {
        let racks = InvadersGame(seed: 3)
        #expect(racks.firewalls.count == 4)
        #expect(racks.firewalls.allSatisfy { $0.standing == InvadersGame.Firewall.classicRows * InvadersGame.Firewall.classicColumns })
    }
}
