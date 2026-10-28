import Foundation

/// Records and counts for every mini-game, read from the statistics, for the Arcade and
/// Statistics screens.
extension GameState {
    /// The record line under a game in the Arcade: "Best 12,345 · longest 38".
    public func record(for game: MiniGame) -> String {
        let s = stats
        return switch game {
        case .blackjack:
            "\(CoinFormat.grouped(s.blackjackWins)) hands won · best streak \(CoinFormat.grouped(s.blackjackBestStreak))"
        case .slots:
            "\(CoinFormat.grouped(s.slotsWins)) wins · \(CoinFormat.grouped(s.slotsJackpots)) jackpots"
        case .moon:
            s.moonCashOuts > 0 ? "Best cash-out \(CoinFormat.flight(s.moonBestMultiplier))" : "No cash-outs yet"
        case .videoPoker:
            s.pokerHands > 0
                ? "\(CoinFormat.grouped(s.pokerWins)) hands won · best \((PokerHand(rawValue: s.pokerBestHand) ?? .nothing).name.lowercased())"
                : "No hands yet"
        case .tetris:
            s.tetrisBestSprint > 0
                ? "Best \(CoinFormat.grouped(s.tetrisBestScore)) · Sprint \(CoinFormat.stopwatch(s.tetrisBestSprint))"
                : "Best \(CoinFormat.grouped(s.tetrisBestScore))"
        case .merge2048:
            s.merge2048BestTile > 0
                ? "Best \(CoinFormat.grouped(s.merge2048BestScore)) · top tile \(s.merge2048BestTile)"
                : "Best 0"
        case .snake:
            s.snakeLongest > 0
                ? "Best \(CoinFormat.grouped(s.snakeBestScore)) · longest \(CoinFormat.grouped(s.snakeLongest))"
                : "Best \(CoinFormat.grouped(s.snakeBestScore))"
        case .brickBreaker:
            s.brickBreakerBestLevel > 0
                ? "Best \(CoinFormat.grouped(s.brickBreakerBestScore)) · level \(CoinFormat.grouped(s.brickBreakerBestLevel))"
                : "Best \(CoinFormat.grouped(s.brickBreakerBestScore))"
        case .bubbleBlaster:
            s.bubbleBestWave > 0
                ? "Best \(CoinFormat.grouped(s.bubbleBestScore)) · wave \(CoinFormat.grouped(s.bubbleBestWave))"
                : "Best \(CoinFormat.grouped(s.bubbleBestScore))"
        case .pumpDump:
            s.pumpDumpBestRound > 0
                ? "Best \(CoinFormat.grouped(s.pumpDumpBestScore)) · round \(s.pumpDumpBestRound) · combo \(CoinFormat.grouped(s.pumpDumpBestCombo))"
                : s.pumpDumpBestCombo > 0
                    ? "Best \(CoinFormat.grouped(s.pumpDumpBestScore)) · combo \(CoinFormat.grouped(s.pumpDumpBestCombo))"
                    : "Best \(CoinFormat.grouped(s.pumpDumpBestScore))"
        case .tokenSwap:
            (tokenSwap.totalStars > 0 ? "\(tokenSwap.totalStars) stars · " : "")
                + (s.tokenSwapBestChain > 1
                    ? "Best \(CoinFormat.grouped(s.tokenSwapBestScore)) · chain of \(CoinFormat.grouped(s.tokenSwapBestChain))"
                    : "Best \(CoinFormat.grouped(s.tokenSwapBestScore))")
        }
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
        case .blackjack, .slots, .moon, .videoPoker: 0
        }
    }

    /// Arcade games played in all.
    public var arcadeGamesPlayed: Int {
        MiniGame.allCases.filter { !$0.isCasino }.reduce(0) { $0 + timesPlayed($1) }
    }
}
