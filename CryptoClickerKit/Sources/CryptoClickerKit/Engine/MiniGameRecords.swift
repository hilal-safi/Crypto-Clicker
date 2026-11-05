import Foundation

/// One fact in a game's record: a label and its value, "Best" and "12,345".
public struct RecordFact: Equatable, Sendable {
    public let label: String
    public let value: String

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

/// Records and counts for every mini-game, read from the statistics, for the Arcade and
/// Statistics screens.
extension GameState {
    /// The record under a game in the Arcade: always the same two facts for a game, so every row
    /// reads alike. Arcade games lead with their best score ("Best" 12,345, then "Wave" 5);
    /// casino games with their wins. A dash stands for something not done yet.
    public func record(for game: MiniGame) -> [RecordFact] {
        let s = stats
        let none = "–"
        func count(_ value: Int) -> String { CoinFormat.grouped(value) }
        let best = RecordFact(localized("Best"), count(bestScore(game)))
        return switch game {
        case .blackjack:
            [RecordFact(localized("Wins"), count(s.blackjackWins)), RecordFact(localized("Best streak"), count(s.blackjackBestStreak))]
        case .slots:
            [RecordFact(localized("Wins"), count(s.slotsWins)), RecordFact(localized("Jackpots"), count(s.slotsJackpots))]
        case .moon:
            [RecordFact(localized("Best"), s.moonCashOuts > 0 ? CoinFormat.flight(s.moonBestMultiplier) : none),
             RecordFact(localized("Cash-outs"), count(s.moonCashOuts))]
        case .videoPoker:
            [RecordFact(localized("Wins"), count(s.pokerWins)),
             RecordFact(localized("Best hand"), s.pokerWins > 0 ? (PokerHand(rawValue: s.pokerBestHand) ?? .nothing).name : none)]
        case .tetris:
            [best, RecordFact(localized("Rush"), s.tetrisBestSprint > 0 ? CoinFormat.stopwatch(s.tetrisBestSprint) : none)]
        case .merge2048:
            [best, RecordFact(localized("Top miner"), s.merge2048BestTile > 0 ? Merge2048Game.miner(for: s.merge2048BestTile).name : none)]
        case .snake:
            [best, RecordFact(localized("Chain"), count(s.snakeLongest))]
        case .brickBreaker:
            [best, RecordFact(localized("Level"), count(s.brickBreakerBestLevel))]
        case .bubbleBlaster:
            [best, RecordFact(localized("Wave"), count(s.bubbleBestWave))]
        case .pumpDump:
            [best, RecordFact(localized("Round"), count(s.pumpDumpBestRound))]
        case .invaders:
            [best, RecordFact(localized("Wave"), count(s.invadersBestWave))]
        case .tokenSwap:
            [best, RecordFact(localized("Stars"), count(tokenSwap.totalStars))]
        }
    }

    /// The record in one line: "Best 12,345 · Wave 5".
    public func recordLine(for game: MiniGame) -> String {
        record(for: game).map { "\($0.label) \($0.value)" }.joined(separator: " · ")
    }

    /// Games played (arcade), or hands, spins and flights (casino).
    public func timesPlayed(_ game: MiniGame) -> Int {
        let s = stats
        return switch game {
        case .blackjack: s.blackjackHands
        case .slots: s.slotsSpins
        case .moon: s.moonFlights
        case .videoPoker: s.pokerHands
        case .tetris: s.tetrisGames
        case .merge2048: s.merge2048Games
        case .snake: s.snakeGames
        case .brickBreaker: s.brickBreakerGames
        case .bubbleBlaster: s.bubbleGames
        case .pumpDump: s.pumpDumpGames
        case .tokenSwap: s.tokenSwapGames + s.tokenSwapLevelsPlayed
        case .invaders: s.invadersGames
        }
    }

    /// The best score in an arcade game (0 for casino games, which have no score).
    public func bestScore(_ game: MiniGame) -> Int {
        let s = stats
        return switch game {
        case .tetris: s.tetrisBestScore
        case .merge2048: s.merge2048BestScore
        case .snake: s.snakeBestScore
        case .brickBreaker: s.brickBreakerBestScore
        case .bubbleBlaster: s.bubbleBestScore
        case .pumpDump: s.pumpDumpBestScore
        case .tokenSwap: s.tokenSwapBestScore
        case .invaders: s.invadersBestScore
        case .blackjack, .slots, .moon, .videoPoker: 0
        }
    }

    /// Arcade games played in all.
    public var arcadeGamesPlayed: Int {
        MiniGame.allCases.filter { !$0.isCasino }.reduce(0) { $0 + timesPlayed($1) }
    }
}
