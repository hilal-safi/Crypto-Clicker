import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Crypto Slots, video machine")
struct VideoSlotsTests {
    /// A seed whose first video spin's stops satisfy `wanted`.
    func seed(where wanted: ([Int]) -> Bool) -> UInt64? {
        (0..<2_000_000).lazy.map(UInt64.init).first { seed in
            var rng = SeededGenerator(seed: seed)
            return wanted(VideoSlots.spin(using: &rng))
        }
    }

    func player(_ tokens: [TokenID: Int] = [.dogecoin: 100]) -> GameState {
        var game = GameState.make(miners: minersEarning(10))
        game.tokens = tokens
        return game
    }

    @Test func fiveLinesOverThreeRowsAndRarerTokensPayMore() {
        #expect(VideoSlots.paylines.count == 5)
        #expect(VideoSlots.paylines.allSatisfy { $0.count == VideoSlots.reelCount && $0.allSatisfy((0..<3).contains) })
        #expect(Set(VideoSlots.paylines.map { $0.map(String.init).joined() }).count == 5)
        #expect(SlotMachineKind.video.lines == 5 && SlotMachineKind.classic.lines == 1)
        let tokens = TokenID.allCases.filter(VideoSlots.strip.contains)
        for count in 3...5 {
            let pays = tokens.map { VideoSlots.pays($0, count: count) }
            #expect(pays == pays.sorted())
        }
        #expect(tokens.allSatisfy { VideoSlots.pays($0, count: 3) < VideoSlots.pays($0, count: 4) })
        #expect(VideoSlots.pays(.bitcoin, count: 2) == 0 && VideoSlots.pays(.safeMoon, count: 5) == 0)
        // The window is the stop with its neighbours above and below, as the classic reel shows.
        #expect(VideoSlots.window(stops: [0, 0, 0, 0, 0])[0] == [VideoSlots.strip[23], VideoSlots.strip[0], VideoSlots.strip[1]])
        // Its own strip: no two neighbouring stops match, and the Bitcoin is on it once.
        #expect(VideoSlots.strip.count == 24)
        #expect(VideoSlots.strip.indices.allSatisfy { VideoSlots.strip[$0] != VideoSlots.strip[($0 + 1) % 24] })
        #expect(VideoSlots.strip.filter { $0 == .bitcoin }.count == 1)
    }

    @Test func theMachineReturnsAboutNinetyFivePercentFreeSpinsIncluded() {
        #expect((0.94...0.97).contains(VideoSlots.returnToPlayer), "\(VideoSlots.returnToPlayer)")
        #expect((0.01...0.03).contains(VideoSlots.freeSpinChance)) // About one spin in 60.
        // Played out, the machine returns what the math says.
        var rng = SeededGenerator(seed: 7)
        var paid = 0.0, spins = 0.0
        for _ in 0..<300_000 {
            let stops = VideoSlots.spin(using: &rng)
            paid += Double(VideoSlots.lineWins(stops: stops).reduce(0) { $0 + $1.pays })
            spins += 1
        }
        #expect(abs(paid / (spins * 5) - VideoSlots.lineReturn) < 0.03)
    }

    @Test func linesPayRunsFromTheLeftReel() {
        // Find stops showing three Shiba Inu on the middle row from the left, then a different token.
        let shiba = VideoSlots.strip.indices.filter { VideoSlots.strip[$0] == .shibaInu }
        let other = VideoSlots.strip.indices.first { VideoSlots.strip[$0] == .xrp }!
        let stops = [shiba[0], shiba[1], shiba[2], other, other]
        let wins = VideoSlots.lineWins(stops: stops)
        let middle = wins.first { $0.line == 0 }
        #expect(middle == SlotLineWin(line: 0, token: .shibaInu, count: 3, pays: VideoSlots.pays(.shibaInu, count: 3)))
        #expect(middle?.cells == [SlotCell(reel: 0, row: 1), SlotCell(reel: 1, row: 1), SlotCell(reel: 2, row: 1)])
        // Three in a row that doesn't start on the left reel pays nothing.
        let late = VideoSlots.lineWins(stops: [other, shiba[0], shiba[1], shiba[2], other])
        #expect(!late.contains { $0.line == 0 })
    }

    @Test func aSpinStakesTheBetOnEveryLineAndPaysEveryWinningLine() throws {
        var game = player()
        var rng = SeededGenerator(seed: 11)
        let result = game.spinSlots(.dogecoin, bet: 2, machine: .video, using: &rng)
        let spin = try #require(result)
        #expect(spin.machine == .video && spin.stake == 10)
        #expect(spin.multiple == spin.lineWins.reduce(0) { $0 + $1.pays })
        #expect(game.tokenCount(.dogecoin) == 100 - 10 + spin.payout)
        #expect(game.stats.slotsWagered == 10 * TokenID.dogecoin.price)
        #expect(spin.isWin == !spin.lineWins.isEmpty)
        // Too few tokens for every line: nothing happens.
        var poor = player([.dogecoin: 9])
        #expect(poor.spinSlots(.dogecoin, bet: 2, machine: .video, using: &rng) == nil)
        #expect(poor.tokenCount(.dogecoin) == 9)
    }

    @Test func winsPayACoinBonusForEachMultipleOfTheStake() throws {
        let stops = try #require(seed { !VideoSlots.lineWins(stops: $0).isEmpty })
        var rng = SeededGenerator(seed: stops)
        var game = player()
        let result = game.spinSlots(.dogecoin, bet: 1, machine: .video, using: &rng)
        let spin = try #require(result)
        #expect(spin.isWin && spin.stakeMultiple >= 2)
        // Small stakes: the share of the stake's value for each multiple of the stake.
        let stakeValue = 5 * TokenID.dogecoin.price
        let perMultiple = min(stakeValue * Tuning.slotsStakeShare, Tuning.slotsWinSeconds * 10)
        #expect(spin.bonus == GameState.wholeCoins(perMultiple * spin.stakeMultiple * game.miniGameMultiplier))
        #expect(!spin.winningCells.isEmpty)
    }

    @Test func threeBitcoinsAnywhereWinFreeSpinsOnTheVideoMachineOnly() throws {
        let trigger = try #require(seed { VideoSlots.scatters(stops: $0) >= 3 })
        var rng = SeededGenerator(seed: trigger)
        var game = player()
        let result = game.spinSlots(.dogecoin, bet: 1, machine: .video, using: &rng)
        let spin = try #require(result)
        #expect(spin.freeSpinsWon >= VideoSlots.freeSpins(scatters: 3))
        let waiting = try #require(game.slotsFreeSpins)
        #expect(waiting.machine == .video && waiting.bet == 1 && waiting.token == .dogecoin)
        // The classic machine waits until they're played...
        var other = SeededGenerator(seed: 1)
        #expect(game.spinSlots(.dogecoin, bet: 1, machine: .classic, using: &other) == nil)
        // ...and they cost nothing on the video machine.
        let before = game.tokenCount(.dogecoin)
        let freeResult = game.spinSlots(.shibaInu, bet: 9, machine: .video, using: &other)
        let free = try #require(freeResult)
        #expect(free.isFree && free.bet == 1 && free.token == .dogecoin)
        #expect(game.tokenCount(.dogecoin) == before + free.payout)
        #expect(free.net == free.payout)
    }

    @Test func freeSpinsFromBeforeTheVideoMachineBelongToTheClassicOne() throws {
        let old = try GameCoding.decoder().decode(SlotsFreeSpins.self, from: Data(#"{"token":"xrp","bet":3,"left":2}"#.utf8))
        #expect(old == SlotsFreeSpins(token: .xrp, bet: 3, left: 2, machine: .classic))
        let video = SlotsFreeSpins(token: .xrp, bet: 3, left: 2, machine: .video)
        let decoded = try GameCoding.decoder().decode(SlotsFreeSpins.self, from: GameCoding.encoder().encode(video))
        #expect(decoded == video)
    }

    @Test func middleReelBitcoinsGoIntoTheCollection() throws {
        let bitcoin = VideoSlots.strip.firstIndex(of: .bitcoin)!
        // The middle reel's three positions, as many as the classic machine's line.
        #expect(VideoSlots.middleReelBitcoins(stops: [0, 0, bitcoin, 0, 0]) == 1)
        #expect(VideoSlots.middleReelBitcoins(stops: [0, 0, bitcoin + 1, 0, 0]) == 1) // Top row.
        #expect(VideoSlots.middleReelBitcoins(stops: [bitcoin, bitcoin, 0, bitcoin, bitcoin]) == 0)
        #expect(VideoSlots.scatters(stops: [bitcoin + 1, bitcoin, bitcoin - 1, 0, 0]) == 3)
    }
}
