import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Token Swap")
struct TokenSwapTests {
    typealias Position = TokenSwapGame.Position

    func at(_ row: Int, _ column: Int) -> Position { Position(row: row, column: column) }

    /// A board with no matches anywhere: kinds step by 2 across and by 1 down. `changes` replaces
    /// single cells.
    func board(_ changes: [Position: Int] = [:]) -> [[Int]] {
        (0..<8).map { row in
            (0..<8).map { column in changes[Position(row: row, column: column)] ?? (row + 2 * column) % 6 }
        }
    }

    func game(_ kinds: [[Int]], blasts: Set<Position> = []) -> TokenSwapGame {
        var game = TokenSwapGame(seed: 1)
        game.place(kinds, blasts: blasts)
        return game
    }

    @Test func aNewBoardHasNoMatchesAndAMoveToMake() {
        for seed in 0..<50 {
            let game = TokenSwapGame(seed: UInt64(seed))
            #expect(TokenSwapGame.runs(in: game.board).isEmpty)
            #expect(game.hasMove)
            #expect(Set(game.board.flatMap { $0 }.map(\.id)).count == 64)
            #expect(game.score == 0 && game.timeLeft == TokenSwapGame.roundLength)
        }
        // The same seed deals the same board.
        #expect(TokenSwapGame(seed: 7).board == TokenSwapGame(seed: 7).board)
    }

    @Test func onlySwapsThatMatchAreAllowed() {
        // Row 7 reads 0 0 1 0: swapping the 1 with the 0 beside it lines up three.
        var game = game(board([at(7, 0): 0, at(7, 1): 0, at(7, 2): 1, at(7, 3): 0, at(6, 0): 2, at(6, 1): 1, at(6, 2): 1, at(6, 3): 3]))
        #expect(TokenSwapGame.runs(in: game.board).isEmpty)
        let result1 = game.swap(at(0, 0), at(0, 1)) // No match.
        #expect(!result1)
        let result2 = game.swap(at(7, 2), at(6, 3)) // Not neighbors.
        #expect(!result2)
        let result3 = game.swap(at(7, 7), at(7, 8)) // Off the board.
        #expect(!result3)
        #expect(game.moves == 0)
        let before = game.board
        let result4 = game.swap(at(7, 2), at(7, 3))
        #expect(result4)
        #expect(game.moves == 1)
        #expect(game.isResolving)
        let result5 = game.swap(at(7, 2), at(7, 3)) // Not while tokens are clearing.
        #expect(!result5)
        #expect(game.tile(at: at(7, 2)).id == before[7][3].id)
    }

    @Test func matchesClearTokensFallAndLaterWavesScoreMore() throws {
        // After the bottom row's three clear, the 1s above drop next to the swapped 1: a second wave.
        var game = game(board([at(7, 0): 0, at(7, 1): 0, at(7, 2): 1, at(7, 3): 0, at(6, 0): 2, at(6, 1): 1, at(6, 2): 1, at(6, 3): 3]))
        let above = game.board[6]
        let result6 = game.swap(at(7, 2), at(7, 3))
        #expect(result6)
        let firstWave = game.resolveStep()
        let first = try #require(firstWave)
        #expect(first.cleared == [at(7, 0), at(7, 1), at(7, 2)])
        #expect(first.chain == 1)
        #expect(first.points == 30)
        #expect(game.tile(at: at(7, 0)).id == above[0].id) // The tokens above fell one row.
        #expect(game.tile(at: at(7, 1)).id == above[1].id)
        let secondWave = game.resolveStep()
        let second = try #require(secondWave)
        #expect(second.chain == 2)
        #expect(second.cleared.contains(at(7, 3)))
        #expect(second.points == second.cleared.count * 10 * 2)
        game.resolveAll()
        #expect(!game.isResolving)
        #expect(game.score >= 90)
        #expect(game.bestChain >= 2)
        #expect(game.tokensCleared >= 6)
        #expect(TokenSwapGame.runs(in: game.board).isEmpty)
        #expect(game.hasMove)
        #expect(Set(game.board.flatMap { $0 }.map(\.id)).count == 64)
    }

    @Test func fourInARowLeavesABlastWhereThePlayerMoved() throws {
        // Row 7 reads 0 0 5 0 with a 0 above the 5: dropping it in makes four.
        var game = game(board([at(7, 0): 0, at(7, 1): 0, at(7, 2): 5, at(7, 3): 0, at(6, 2): 0, at(7, 4): 3]))
        #expect(TokenSwapGame.runs(in: game.board).isEmpty)
        let result7 = game.swap(at(6, 2), at(7, 2))
        #expect(result7)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.madeBlasts == [at(7, 2)])
        #expect(step.cleared == [at(7, 0), at(7, 1), at(7, 3)])
        #expect(step.points == 30)
        #expect(game.tile(at: at(7, 2)).isBlast)
        #expect(game.tile(at: at(7, 2)).kind == 0)
    }

    @Test func aMatchedBlastClearsItsRowAndColumn() throws {
        // A Blast 0 above row 7's 0 0 5: swapping it down matches it.
        var game = game(board([at(7, 0): 0, at(7, 1): 0, at(7, 2): 5, at(6, 2): 0]), blasts: [at(6, 2)])
        let result8 = game.swap(at(6, 2), at(7, 2))
        #expect(result8)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.blasts == 1)
        #expect(step.cleared.count == 15) // The whole bottom row and column 2.
        #expect(step.points == 150)
        #expect(game.blastsSetOff == 1)
    }

    @Test func matchingAcrossAndDownAtOnceLeavesABlast() throws {
        // 0 0 _ in row 7, 0 0 above the gap in column 2, and a 0 to swap in from the right.
        var game = game(board([at(7, 0): 0, at(7, 1): 0, at(7, 2): 5, at(7, 3): 0, at(5, 2): 0, at(6, 2): 0,
                               at(4, 2): 3, at(6, 3): 4, at(7, 4): 2]))
        #expect(TokenSwapGame.runs(in: game.board).isEmpty)
        let result9 = game.swap(at(7, 2), at(7, 3))
        #expect(result9)
        let stepWave = game.resolveStep()
        let step = try #require(stepWave)
        #expect(step.madeBlasts == [at(7, 2)])
        #expect(step.cleared.count == 4)
        #expect(game.tile(at: at(7, 2)).isBlast)
    }

    @Test func timeRunsOutButFallingWavesStillCount() {
        var game = game(board([at(7, 0): 0, at(7, 1): 0, at(7, 2): 1, at(7, 3): 0, at(6, 0): 2, at(6, 1): 1, at(6, 2): 1, at(6, 3): 3]))
        game.advance(by: 59.9)
        let result10 = game.swap(at(7, 2), at(7, 3))
        #expect(result10)
        game.advance(by: 5)
        #expect(game.isTimeUp)
        #expect(!game.isOver) // Waves are still falling.
        game.resolveAll()
        #expect(game.isOver)
        #expect(game.score > 0)
        var late = TokenSwapGame(seed: 3)
        late.advance(by: 60)
        let (a, b) = late.hint!
        let result11 = late.swap(a, b) // No swaps once time is up.
        #expect(!result11)
        late.advance(by: -5)
        late.advance(by: .nan)
        #expect(late.timeLeft == 0)
    }

    @Test func aStuckBoardIsShuffled() {
        var game = TokenSwapGame(seed: 4)
        game.shuffle()
        #expect(game.shuffles == 1)
        #expect(TokenSwapGame.runs(in: game.board).isEmpty)
        #expect(game.hasMove)
    }

    @Test func randomPlayKeepsTheBoardWhole() {
        var rng = SeededGenerator(seed: 11)
        for seed in 0..<6 {
            var game = TokenSwapGame(seed: UInt64(seed))
            var total = 0
            for _ in 0..<60 {
                let swaps = game.validSwaps
                #expect(!swaps.isEmpty)
                let (a, b) = swaps.randomElement(using: &rng)!
                let result12 = game.swap(a, b)
                #expect(result12)
                total += game.resolveAll().reduce(0) { $0 + $1.points }
                #expect(TokenSwapGame.runs(in: game.board).isEmpty)
                #expect(game.board.count == 8 && game.board.allSatisfy { $0.count == 8 })
                #expect(Set(game.board.flatMap { $0 }.map(\.id)).count == 64)
            }
            #expect(game.score == total)
            #expect(game.moves == 60)
        }
    }

    // MARK: Paying

    @Test func aRoundPaysForEveryPoint() {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins a second.
        let payout = game.finishTokenSwap(score: 2_000, tokens: 180, bestChain: 4, blasts: 3)
        #expect(payout.isNewBest)
        #expect(payout.coins == (2_000 * Tuning.tokenSwapSecondsPerPoint * 10 * 1.5).rounded())
        #expect(game.stats.tokenSwapGames == 1)
        #expect(game.stats.tokenSwapTokens == 180)
        #expect(game.stats.tokenSwapBestChain == 4)
        #expect(game.stats.tokenSwapBlasts == 3)
        #expect(game.bestScore(.tokenSwap) == 2_000)
        #expect(game.record(for: .tokenSwap) == "Best 2,000 · chain of 4")
        // A round held when the app went away is paid on the next launch.
        game.holdArcadeRun(ArcadeRun(game: .tokenSwap, score: 500, detail: 40, extra: 2))
        let held = game.payUnfinishedRun()
        #expect(held?.payout.coins == (500 * Tuning.tokenSwapSecondsPerPoint * 10).rounded())
        #expect(game.stats.tokenSwapTokens == 220)
    }
}
