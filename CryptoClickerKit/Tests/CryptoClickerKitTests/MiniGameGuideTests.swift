import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("How to Play")
struct MiniGameGuideTests {
    @Test(arguments: MiniGame.allCases, ArcadeEdition.allCases)
    func everyGameExplainsItself(_ game: MiniGame, _ edition: ArcadeEdition) {
        let guide = game.guide(in: edition)
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

    @Test(arguments: ArcadeEdition.allCases)
    func pictureNamesNeverClashAcrossGames(_ edition: ArcadeEdition) {
        let ids = MiniGame.allCases.flatMap { $0.guide(in: edition).items.map(\.id) }
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

    /// The crypto edition explains its own pieces, with the numbers from the rules.
    @Test func theCryptoEditionNamesItsOwnPieces() {
        let chain = MiniGame.tetris.guide(in: .crypto)
        #expect(chain.items.contains { $0.id == "tetris.gas" && $0.detail.contains("every \(TetrisGame.gasSpikeEvery) pieces") })
        #expect(chain.scoring.contains { $0.contains("fee of \(TetrisGame.gasFee)") })
        #expect(!MiniGame.tetris.guide(in: .classic).items.contains { $0.id == "tetris.gas" })
        let snake = MiniGame.snake.guide(in: .crypto)
        #expect(snake.items.map(\.name).starts(with: ["Lightning", "Cold Storage", "Hardware Wallet", "Airdrop Magnet"]))
        #expect(MiniGame.snake.guide(in: .classic).items.map(\.name).starts(with: ["Speed Boost", "Slow Motion", "Shield", "Coin Magnet"]))
        #expect(snake.items.last?.detail.hasPrefix("Mining Farm, Exchange Floor and Node Network") == true)
        #expect(MiniGame.snake.guide(in: .classic).items.last?.detail.hasPrefix("Pillars, Rooms and Crossroads") == true)
        let smash = MiniGame.brickBreaker.guide(in: .crypto)
        #expect(["Fork", "Deep Liquidity", "Gas Limit", "Hash Rate", "The whale"].allSatisfy { name in smash.items.contains { $0.name == name } })
        let market = MiniGame.bubbleBlaster.guide(in: .crypto)
        #expect(market.items.map(\.name).contains("Stablecoin") && market.ending.contains("crash line"))
        #expect(MiniGame.merge2048.guide(in: .crypto).items.contains { $0.detail.contains("Lunar Base (2,048)") })
        #expect(MiniGame.videoPoker.guide(in: .crypto).controls.contains { $0.contains("HODL") })
        #expect(MiniGame.invaders.guide(in: .crypto).items.contains { $0.name == "Server racks" })
        #expect(MiniGame.invaders.guide(in: .classic).items.contains { $0.name == "Firewalls" })
    }
}

@Suite("Arcade editions")
struct ArcadeEditionTests {
    @Test func theCryptoEditionRenamesTheGamesThatCopyClassics() {
        let renamed: [MiniGame: (crypto: String, classic: String)] = [
            .tetris: ("Block Chain", "Tetris"), .merge2048: ("Merge Mining", "2048"), .snake: ("Hash Chain", "Snake"),
            .brickBreaker: ("Hash Smash", "Brick Breaker"), .bubbleBlaster: ("Bubble Market", "Bubble Blaster"),
            .blackjack: ("21 Million", "Blackjack"), .videoPoker: ("Diamond Hands", "Video Poker"),
        ]
        for game in MiniGame.allCases {
            let crypto = game.info(in: .crypto), classic = game.info(in: .classic)
            if let names = renamed[game] {
                #expect(crypto.name == names.crypto && classic.name == names.classic)
            } else {
                #expect(crypto.name == classic.name, "\(game) keeps its name")
            }
            // Prices, pay and colors are the same in both.
            #expect(crypto.listCost == classic.listCost && crypto.secondsPerPoint == classic.secondsPerPoint && crypto.color == classic.color)
        }
        // Each edition's games have their own icons.
        for edition in ArcadeEdition.allCases {
            let icons = MiniGame.allCases.map { $0.info(in: edition).icon }
            #expect(Set(icons).count == icons.count, "\(edition) repeats an icon")
        }
        #expect(ArcadeEdition.current == .crypto) // The default; nothing in the tests changes it.
    }

    @Test func piecesAndPowerUpsHaveCryptoNames() {
        #expect(SnakeGame.Arena.allCases.map { $0.name(in: .crypto) } == ["Open", "Mining Farm", "Exchange Floor", "Node Network"])
        #expect(SnakeGame.Arena.allCases.map { $0.name(in: .classic) } == ["Open", "Pillars", "Rooms", "Crossroads"])
        #expect(BrickBreakerGame.PowerUp.allCases.map { $0.name(in: .crypto) } == ["Fork", "Deep Liquidity", "Gas Limit", "Hash Rate"])
        #expect(BrickBreakerGame.PowerUp.allCases.map { $0.name(in: .classic) } == ["Multi-ball", "Wide Paddle", "Slow Ball", "Laser"])
        #expect(BubbleShooterGame.Special.allCases.map { $0.name(in: .crypto) } == ["Stablecoin", "Flash Crash"])
        let snakeCharmer = AchievementCatalog.all.first { $0.id == "snake-charmer" }
        #expect(snakeCharmer?.name(in: .crypto) == "Chain Reaction" && snakeCharmer?.name(in: .classic) == "Snake Charmer")
        #expect(snakeCharmer?.detail(in: .classic) == "Score in a single Snake game")
        // Achievements the editions share keep one name.
        let miner = AchievementCatalog.all.first { $0.id == "miner" }
        #expect(miner?.name(in: .crypto) == miner?.name(in: .classic))
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
        let racks = InvadersGame(seed: 3, firewalls: .rack)
        #expect(racks.firewalls.count == 4)
        #expect(racks.firewalls.allSatisfy { $0.standing == InvadersGame.Firewall.rows * InvadersGame.Firewall.columns })
        let arches = InvadersGame(seed: 3)
        #expect(arches.firewallStyle == .arch && arches.firewalls.allSatisfy { $0.standing == 34 })
        #expect(InvadersGame.FirewallStyle.edition(.crypto) == .rack && InvadersGame.FirewallStyle.edition(.classic) == .arch)
    }
}
