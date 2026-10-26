import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Crypto Slots")
struct SlotsTests {
    @Test func theStripHoldsEveryTokenWithBitcoinRarest() {
        let strip = SlotMachine.strip
        #expect(strip.count == 24)
        let counts = Dictionary(strip.map { ($0, 1) }, uniquingKeysWith: +)
        #expect(counts[.shibaInu] == 6)
        #expect(counts[.bitcoin] == 1)
        #expect(Set(strip) == Set(TokenID.allCases))
        // Rarer tokens pay more.
        let pays = TokenID.allCases.map(SlotMachine.threeOfAKind)
        #expect(pays == pays.sorted())
        // Neighbouring stops always differ, so a spinning reel never seems to stand still.
        for index in strip.indices {
            #expect(strip[index] != strip[(index + 1) % strip.count])
        }
    }

    @Test(arguments: [
        ([TokenID.bitcoin, .bitcoin, .bitcoin], 500),
        ([TokenID.ethereum, .ethereum, .ethereum], 100),
        ([TokenID.shibaInu, .shibaInu, .shibaInu], 5),
        ([TokenID.bitcoin, .xrp, .bitcoin], 25),
        ([TokenID.bitcoin, .bitcoin, .solana], 25),
        ([TokenID.dogecoin, .dogecoin, .bitcoin], 2),
        ([TokenID.xrp, .solana, .bitcoin], 1),
        ([TokenID.xrp, .solana, .xrp], 0),
        ([TokenID.cardano, .solana, .ethereum], 0),
    ])
    func payouts(_ line: [TokenID], _ multiple: Int) {
        #expect(SlotMachine.payout(for: line) == multiple)
    }

    @Test func theMachineReturnsAboutNinetyFivePercent() {
        let rtp = SlotMachine.returnToPlayer
        #expect(rtp > 0.94 && rtp < 0.96)
    }

    @Test func spinsLandOnTheStrip() {
        var rng = SeededGenerator(seed: 11)
        for _ in 0..<500 {
            let stops = SlotMachine.spin(using: &rng)
            #expect(stops.count == SlotMachine.reelCount)
            #expect(stops.allSatisfy { SlotMachine.strip.indices.contains($0) })
        }
        let strip = SlotMachine.strip
        #expect(SlotMachine.line(stops: [24, -1, 0]) == [strip[0], strip[23], strip[0]])
    }

    @Test func aSpinTakesTheBetAndPaysInOneStep() throws {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        game.tokens = [.shibaInu: 50]
        var rng = SeededGenerator(seed: 3)
        let result = game.spinSlots(.shibaInu, bet: 4, using: &rng)
        let spin = try #require(result)
        #expect(spin.multiple == SlotMachine.payout(for: spin.line))
        #expect(game.tokenCount(.shibaInu) == 50 - 4 + spin.payout)
        #expect(game.coins == spin.bonus)
        #expect(game.stats.slotsSpins == 1)
        #expect(game.stats.slotsWins == (spin.isWin ? 1 : 0))
        // Bets the wallet can't cover change nothing.
        #expect(game.spinSlots(.shibaInu, bet: 1_000, using: &rng) == nil)
        #expect(game.spinSlots(.bitcoin, bet: 1, using: &rng) == nil)
        #expect(game.spinSlots(.shibaInu, bet: 0, using: &rng) == nil)
        #expect(game.stats.slotsSpins == 1)
    }

    @Test func theCoinBonusGrowsWithTheMultipleUpToAnIncomeCap() {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins per second.
        game.tokens = [.shibaInu: 1]
        // One Shiba Inu stakes 1,000 coins: 5% is 50 per multiple, capped at 3 seconds (30 coins) per multiple.
        #expect(game.slotsBonus(bet: 1, token: .shibaInu, multiple: 5) == 150)
        #expect(game.slotsBonus(bet: 1, token: .shibaInu, multiple: 1) == 0) // The bet back is not a win.
        #expect(game.slotsBonus(bet: 1, token: .shibaInu, multiple: 0) == 0)
        let newcomer = GameState.make() // The 1 coin per second floor.
        #expect(newcomer.slotsBonus(bet: 1, token: .shibaInu, multiple: 500) == 1_500)
    }

    @Test func aJackpotPaysFiveHundredTimesTheBet() throws {
        // Find a seed whose first spin lands three Bitcoins (1 in 13,824).
        let seed = (0..<1_000_000).lazy.map(UInt64.init).first { seed in
            var rng = SeededGenerator(seed: seed)
            return SlotMachine.line(stops: SlotMachine.spin(using: &rng)) == [.bitcoin, .bitcoin, .bitcoin]
        }
        var rng = SeededGenerator(seed: try #require(seed))
        var game = GameState.make(miners: [.desktop: 5])
        game.tokens = [.dogecoin: 2]
        let result = game.spinSlots(.dogecoin, bet: 2, using: &rng)
        let spin = try #require(result)
        #expect(spin.isJackpot)
        #expect(game.tokenCount(.dogecoin) == 1_000)
        #expect(spin.bonus == 15_000) // Capped at 30 coins per multiple.
        #expect(game.stats.slotsJackpots == 1)
        #expect(game.stats.slotsWins == 1)
    }
}
