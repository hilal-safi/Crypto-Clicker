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
        ([TokenID.shibaInu, .shibaInu, .shibaInu], 4),
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

    @Test func theMachineReturnsAboutNinetyFivePercentFreeSpinsIncluded() {
        // One order of the trio: 3 Cardano × 3 Solana × 2 Ethereum stops; six orders.
        let chance: Double = 6.0 * 18.0 / 13_824.0
        #expect(SlotMachine.freeSpinChance == chance)
        let perTrigger: Double = 3.0 / (1.0 - 3.0 * chance)
        #expect(abs(SlotMachine.freeSpinsPerTrigger - perTrigger) < 1e-12)
        #expect(abs(SlotMachine.paytableReturn - 0.933_883) < 1e-5)
        let rtp = SlotMachine.returnToPlayer
        #expect(rtp > 0.95 && rtp < 0.96)
        let expected: Double = SlotMachine.paytableReturn * (1.0 + chance * perTrigger)
        #expect(abs(rtp - expected) < 1e-12)
    }

    @Test func playedOutTheMachineReturnsWhatTheMathSays() {
        // Spin as a player would, free spins and all, and compare tokens back with tokens bet.
        var rng = SeededGenerator(seed: 2026)
        var bet = 0.0, back = 0.0, freeLeft = 0
        for _ in 0..<300_000 {
            let line = SlotMachine.line(stops: SlotMachine.spin(using: &rng))
            if freeLeft > 0 { freeLeft -= 1 } else { bet += 1 }
            back += Double(SlotMachine.payout(for: line))
            if SlotMachine.triggersFreeSpins(line) { freeLeft += SlotMachine.freeSpinsAwarded }
        }
        #expect(abs(back / bet - SlotMachine.returnToPlayer) < 0.04)
    }

    @Test func theTrioWinsFreeSpinsInAnyOrder() {
        #expect(SlotMachine.triggersFreeSpins([.cardano, .solana, .ethereum]))
        #expect(SlotMachine.triggersFreeSpins([.ethereum, .cardano, .solana]))
        #expect(!SlotMachine.triggersFreeSpins([.ethereum, .ethereum, .solana]))
        #expect(!SlotMachine.triggersFreeSpins([.cardano, .solana]))
    }

    @Test func winningReelsPointAtTheWin() throws {
        func spin(_ line: [TokenID]) throws -> SlotsSpin {
            let stops = try line.map { token in try #require(SlotMachine.strip.firstIndex(of: token)) }
            return SlotsSpin(stops: stops, token: .dogecoin, bet: 1, multiple: SlotMachine.payout(for: line), bonus: 0)
        }
        #expect(try spin([.xrp, .xrp, .xrp]).winningReels == [0, 1, 2])
        #expect(try spin([.bitcoin, .xrp, .bitcoin]).winningReels == [0, 2])
        #expect(try spin([.dogecoin, .dogecoin, .xrp]).winningReels == [0, 1])
        #expect(try spin([.xrp, .bitcoin, .solana]).winningReels == [1])
        #expect(try spin([.solana, .cardano, .ethereum]).winningReels == [0, 1, 2])
        #expect(try spin([.xrp, .solana, .xrp]).winningReels.isEmpty)
        #expect(try spin([.xrp, .solana, .xrp]).net == -1)
    }

    @Test func paysStayWithinThirtyTwoBits() {
        #expect(SlotMachine.tokensPaid(bet: Int(Int32.max), multiple: 500) == Int(Int32.max))
        #expect(SlotMachine.tokensPaid(bet: 3, multiple: 25) == 75)
        #expect(SlotMachine.tokensPaid(bet: -3, multiple: 25) == 0)
    }

    /// A seed whose first spin lands a line that satisfies `wanted`.
    func seed(where wanted: ([TokenID]) -> Bool) -> UInt64? {
        (0..<1_000_000).lazy.map(UInt64.init).first { seed in
            var rng = SeededGenerator(seed: seed)
            return wanted(SlotMachine.line(stops: SlotMachine.spin(using: &rng)))
        }
    }

    @Test func freeSpinsArePlayedAtTheWinningBetForNothing() throws {
        var rng = SeededGenerator(seed: try #require(seed(where: SlotMachine.triggersFreeSpins)))
        var game = GameState.make(miners: [.desktop: 10])
        game.tokens = [.dogecoin: 10]
        let triggerSpin = game.spinSlots(.dogecoin, bet: 2, using: &rng)
        let trigger = try #require(triggerSpin)
        #expect(trigger.freeSpinsWon == SlotMachine.freeSpinsAwarded)
        #expect(trigger.multiple == 0)
        #expect(!trigger.isFree)
        #expect(game.slotsFreeSpins == SlotsFreeSpins(token: .dogecoin, bet: 2, left: SlotMachine.freeSpinsAwarded))
        #expect(game.tokenCount(.dogecoin) == 8)
        // Free spins take nothing and keep the bet and token that won them, whatever is asked for.
        var played = 0
        while game.slotsFreeSpins != nil && played < 100 {
            let before = game.tokenCount(.dogecoin)
            let freeSpin = game.spinSlots(.shibaInu, bet: 1, using: &rng)
            let free = try #require(freeSpin)
            #expect(free.isFree)
            #expect(free.token == .dogecoin && free.bet == 2)
            #expect(game.tokenCount(.dogecoin) == before + free.payout)
            #expect(free.net == free.payout)
            played += 1
        }
        #expect(played >= SlotMachine.freeSpinsAwarded)
        #expect(game.stats.slotsFreeSpinsPlayed == played)
        #expect(game.stats.slotsSpins == played + 1)
        #expect(game.stats.slotsWagered == 2 * TokenID.dogecoin.price) // Only the paid spin.
        #expect(game.stats.slotsFreeSpinRounds >= 1)
        // Out of free spins, spins cost again.
        #expect(game.tokenCount(.shibaInu) == 0)
        let paid = game.spinSlots(.shibaInu, bet: 1, using: &rng)
        #expect(paid == nil)
    }

    @Test func waitingFreeSpinsSurviveASave() throws {
        var game = GameState.make()
        game.slotsFreeSpins = SlotsFreeSpins(token: .xrp, bet: 3, left: 2)
        let decoded = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(decoded.slotsFreeSpins == SlotsFreeSpins(token: .xrp, bet: 3, left: 2))
    }

    @Test func everyTenthBitcoinOnTheLinePaysAPrize() throws {
        var rng = SeededGenerator(seed: try #require(seed { $0.filter { $0 == .bitcoin }.count == 1 }))
        var game = GameState.make(miners: [.desktop: 10]) // 10 coins per second.
        game.tokens = [.shibaInu: 10]
        game.stats.slotsBitcoins = SlotMachine.bitcoinsPerPrize - 1
        #expect(game.slotsBitcoinsTowardPrize == SlotMachine.bitcoinsPerPrize - 1)
        #expect(game.slotsCollectionPrize == 600) // 60 seconds.
        let result = game.spinSlots(.shibaInu, bet: 1, using: &rng)
        let spin = try #require(result)
        #expect(spin.bitcoins == 1)
        #expect(spin.collectionPrize == 600)
        #expect(game.coins == spin.bonus + 600)
        #expect(game.slotsBitcoinsTowardPrize == 0)
    }

    @Test func theBiggestWinCountsProfitAndBonus() throws {
        var rng = SeededGenerator(seed: try #require(seed { $0 == [.xrp, .xrp, .xrp] }))
        var game = GameState.make(miners: [.desktop: 10])
        game.tokens = [.shibaInu: 10]
        let result = game.spinSlots(.shibaInu, bet: 1, using: &rng)
        let spin = try #require(result)
        #expect(spin.multiple == 15)
        #expect(game.stats.slotsBiggestWin == Double(15 - 1) * TokenID.shibaInu.price + spin.bonus)
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
        var game = GameState.make(miners: [.desktop: 10]) // 10 coins per second.
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
        var game = GameState.make(miners: [.desktop: 10]) // 10 coins per second.
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
        var game = GameState.make(miners: [.desktop: 10])
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
