import Foundation
import Testing
@testable import CryptoClickerKit

/// What the casino pays over time, for balancing. For each game (and each To the Moon target and
/// rocket): the token return (the house edge on the stake), the coin bonus as a share of the stake
/// while it's below its cap (small bets), the Bitcoin collection's prizes, and, for bets big enough
/// to reach the cap, what a second of play earns in seconds of idle income, once the tokens lost to
/// the house edge are paid for. That last figure is the one that matters for the mining economy: it
/// has to stay within reach of what the rest of the game pays, with and without the reward
/// upgrades. The reward multiplier is the mini-game one: 1 with no upgrades, 5.625 with all three
/// Bonus Rewards and Arcade Champion. Runs with the balance tests:
/// `RUN_BALANCE_TESTS=1 swift test --filter CasinoReturnTests`.
@Suite("Casino returns")
struct CasinoReturnTests {
    static let fullMultiplier = 1.25 * 1.5 * 2 * 1.5

    /// The shortest a round takes in play, in seconds: dealing, deciding and the result for a hand
    /// of 21 Million or Diamond Hands; the reels stopping and the next tap for a spin. A To the Moon
    /// round is its flight plus `moonRelaunch`.
    static let blackjackRound = 6.0
    static let pokerRound = 5.0
    static let classicSpin = 2.4
    static let videoSpin = 2.6
    static let moonRelaunch = 1.5

    struct Return {
        /// Tokens back per token staked.
        var tokens: Double
        /// Coin bonus per token staked, below the cap, before reward upgrades (stake's coin value = 1).
        var bonus: Double
        /// Seconds of income the bonus pays per round once capped, before reward upgrades.
        var cappedSeconds: Double
        /// Seconds of income a stake big enough to reach the cap is worth.
        var stakeAtCap: Double
        /// Seconds a round takes.
        var roundSeconds: Double
        /// Seconds of income the Bitcoin collection pays per round, before reward upgrades.
        var collectionSeconds = 0.0

        /// Seconds of income a second of play earns at bets that reach the cap: the bonus and the
        /// collection, times `multiplier`, less the house edge on the stake.
        func earningRate(multiplier: Double) -> Double {
            ((cappedSeconds + collectionSeconds) * multiplier - (1 - tokens) * stakeAtCap) / roundSeconds
        }
    }

    /// 21 Million on the classic table, played by basic strategy, never insuring. A natural pays
    /// 3 to 2 in whole tokens, rounded up, so a one-token bet's natural pays 2 to 1.
    func blackjack(hands: Int, bet: Int) -> Return {
        var rng = SeededGenerator(seed: 2026)
        var table = BlackjackTable(rules: .standsOnSoft17)
        var staked = 0.0, returned = 0.0, bonus = 0.0, capped = 0.0
        for _ in 0..<hands {
            table.newRound()
            table.deal(bet: bet, using: &rng)
            if table.phase == .insurance { table.resolveInsurance(insured: false) }
            while table.phase == .playerTurn, let move = table.suggestedMove {
                switch move {
                case .hit: table.hit(using: &rng)
                case .stand: table.stand()
                case .double: table.doubleDown(using: &rng)
                case .split: table.split(using: &rng)
                }
            }
            table.finishDealer(using: &rng)
            for result in table.results {
                staked += Double(result.bet)
                returned += Double(result.payout)
                guard result.outcome == .win || result.outcome == .blackjack else { continue }
                let natural = result.outcome == .blackjack ? Tuning.blackjackNaturalBonus : 1
                bonus += Double(result.bet) * Tuning.blackjackStakeShare * natural
                capped += Tuning.blackjackWinSeconds * natural
            }
        }
        // Per token of the first bet (doubles and splits add to the stake, and to what a win pays).
        let stakedPerBet = staked / Double(hands * bet)
        return Return(tokens: returned / staked, bonus: bonus / Double(hands * bet), cappedSeconds: capped / Double(hands),
                      stakeAtCap: Tuning.blackjackWinSeconds / Tuning.blackjackStakeShare * stakedPerBet,
                      roundSeconds: Self.blackjackRound)
    }

    /// Diamond Hands, holding what the coach suggests.
    func videoPoker(hands: Int) -> Return {
        var rng = SeededGenerator(seed: 2027)
        var returned = 0.0, multiples = 0.0
        for _ in 0..<hands {
            let deal = VideoPoker.deal(using: &rng)
            let held = VideoPoker.suggestedHolds(deal.cards)
            let hand = VideoPoker.evaluate(VideoPoker.draw(deal.cards, holding: held, from: deal.drawPile))
            returned += Double(hand.payout)
            if hand.payout >= 2 { multiples += Double(hand.payout) }
        }
        let average = multiples / Double(hands)
        return Return(tokens: returned / Double(hands), bonus: average * Tuning.pokerStakeShare,
                      cappedSeconds: average * Tuning.pokerWinSeconds,
                      stakeAtCap: Tuning.pokerWinSeconds / Tuning.pokerStakeShare, roundSeconds: Self.pokerRound)
    }

    /// The collection's prize in seconds of income for each Bitcoin, before reward upgrades.
    static var secondsPerBitcoin: Double { Tuning.slotsCollectionSeconds / Double(SlotMachine.bitcoinsPerPrize) }

    /// Crypto Slots' classic machine, worked out exactly from the strip (free spins add their wins
    /// and their Bitcoins too).
    func classicSlots() -> Return {
        var multiples = 0.0, bitcoins = 0.0, count = 0.0
        for a in SlotMachine.strip {
            for b in SlotMachine.strip {
                for c in SlotMachine.strip {
                    let line = [a, b, c]
                    let pays = SlotMachine.payout(for: line)
                    if pays >= 2 { multiples += Double(pays) }
                    bitcoins += Double(line.filter { $0 == .bitcoin }.count)
                    count += 1
                }
            }
        }
        let spins = 1 + SlotMachine.freeSpinChance * SlotMachine.freeSpinsPerTrigger
        let average = multiples / count * spins
        return Return(tokens: SlotMachine.returnToPlayer, bonus: average * Tuning.slotsStakeShare,
                      cappedSeconds: average * Tuning.slotsWinSeconds,
                      stakeAtCap: Tuning.slotsWinSeconds / Tuning.slotsStakeShare, roundSeconds: Self.classicSpin,
                      collectionSeconds: bitcoins / count * spins * Self.secondsPerBitcoin)
    }

    /// Crypto Slots' video machine: tokens exactly from the strip and the pay table, the bonus and
    /// the collection from spins played out (each paid spin brings `1 / (1 - freeSpinsPerSpin)`
    /// spins in all). Its stake is the bet on all five lines.
    func videoSlots(spins: Int) -> Return {
        var rng = SeededGenerator(seed: 2028)
        var multiples = 0.0, bitcoins = 0.0
        for _ in 0..<spins {
            let stops = VideoSlots.spin(using: &rng)
            let pays = VideoSlots.lineWins(stops: stops).reduce(0) { $0 + $1.pays }
            let stakeMultiple = Double(pays) / Double(VideoSlots.paylines.count)
            if stakeMultiple >= 2 { multiples += stakeMultiple }
            bitcoins += Double(VideoSlots.middleReelBitcoins(stops: stops))
        }
        let perPaidSpin = 1 / (1 - VideoSlots.freeSpinsPerSpin)
        let average = multiples / Double(spins) * perPaidSpin
        return Return(tokens: VideoSlots.returnToPlayer, bonus: average * Tuning.slotsStakeShare,
                      cappedSeconds: average * Tuning.slotsWinSeconds,
                      stakeAtCap: Tuning.slotsWinSeconds / Tuning.slotsStakeShare, roundSeconds: Self.videoSpin,
                      collectionSeconds: bitcoins / Double(spins) * perPaidSpin * Self.secondsPerBitcoin)
    }

    /// To the Moon, cashing out at `target`: it gets there with chance R / target (R is 97%, or
    /// 95% on the 5× rocket, whose bonus is bigger). The bonus is capped per flight by the time it
    /// takes to get there, and a flight lasts until it crashes or cashes out: on average R × the
    /// rocket's growth time × (1 - 1 / target).
    func moon(cashingOutAt target: Double, rocket: MoonRocket = .doubling) -> Return {
        let reach = MoonFlight.chance(ofReaching: target, rocket: rocket)
        let flight = MoonFlight.time(toReach: target, rocket: rocket)
        let capSeconds = Tuning.moonWinSecondsPerFlightSecond * flight
        let averageFlight = rocket.returnToPlayer * MoonFlight.doublingTime / log(rocket.growth) * (1 - 1 / target)
        return Return(tokens: reach * target, bonus: reach * (target - 1) * Tuning.moonStakeShare * rocket.bonusFactor,
                      cappedSeconds: reach * capSeconds * rocket.bonusFactor,
                      stakeAtCap: capSeconds / (Tuning.moonStakeShare * (target - 1)),
                      roundSeconds: averageFlight + Self.moonRelaunch)
    }

    @Test func theCasinoKeepsAnEdgeOnTokensAndNoGameOutearns21Million() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        // 400,000 hands and spins each; CASINO_HANDS=50000 gives a quicker, rougher look.
        let hands = Int(ProcessInfo.processInfo.environment["CASINO_HANDS"] ?? "") ?? 400_000
        let twoTokens = blackjack(hands: hands, bet: 2)
        var games: [(String, Return)] = [
            ("21 Million, 1-token bets", blackjack(hands: hands, bet: 1)),
            ("21 Million, 2-token bets", twoTokens),
            ("Diamond Hands", videoPoker(hands: hands)),
            ("Crypto Slots classic", classicSlots()),
            ("Crypto Slots 5x3", videoSlots(spins: hands)),
        ]
        for rocket in MoonRocket.allCases {
            for target in MoonFlight.autoCashOutChoices {
                games.append(("To the Moon \(rocket.shortName) rocket at \(CoinFormat.flight(target))", moon(cashingOutAt: target, rocket: rocket)))
            }
        }
        let sell = 1 - Tuning.marketSellFee
        let ceiling = twoTokens.earningRate(multiplier: Self.fullMultiplier)
        for (name, game) in games {
            // Kept tokens are bet again, so the edge counts per round; the fee only on a final sale.
            let small = game.tokens - 1 + game.bonus
            print("Casino \(name): tokens back \(String(format: "%.2f%%", game.tokens * 100)) (sold \(String(format: "%.1f%%", game.tokens * sell * 100)))",
                  "| small bets: bonus \(String(format: "%.1f%%", game.bonus * 100)) of the stake, \(String(format: "%+.1f%%", small * 100)) a round",
                  "| collection \(String(format: "%.2f", game.collectionSeconds))s a round",
                  "| at the cap, income per second of play: \(String(format: "%.1f", game.earningRate(multiplier: 1)))x, all upgrades \(String(format: "%.1f", game.earningRate(multiplier: Self.fullMultiplier)))x")
            // Every game keeps an edge on the tokens themselves (but for one-token naturals at 21
            // Million, rounded up to 2 to 1); the coins come from the bonus.
            if !name.hasPrefix("21 Million, 1-token") { #expect(game.tokens < 1.005, "\(name)") }
            // Without the reward upgrades no game pays more than a few seconds of income per second
            // played, and with them none outearns 21 Million (whose bonus the review measured first).
            #expect(game.earningRate(multiplier: 1) < 5, "\(name)")
            if !name.hasPrefix("21 Million") { #expect(game.earningRate(multiplier: Self.fullMultiplier) <= ceiling, "\(name)") }
        }
        print("Casino ceiling: 21 Million with every reward upgrade earns \(String(format: "%.1f", ceiling))x idle income per second of play")
        #expect(ceiling < 25)
    }

    /// One-token 21 Million is the one bet where the player keeps an edge on tokens: a natural pays
    /// 3 to 2, rounded up to a whole token, so 2 to 1. That's deliberate (a one-token natural paying
    /// 1 to 1 would feel broken) and small: about 1.7% of a one-token stake (at SafeMoon's 100
    /// coins, under 2 coins a hand), so it's pinned here rather than left inside a range.
    @Test func oneTokenBlackjackKeepsItsSmallPinnedEdge() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let one = blackjack(hands: 400_000, bet: 1)
        let two = blackjack(hands: 400_000, bet: 2)
        print("21 Million one-token return \(String(format: "%.4f", one.tokens)), two-token \(String(format: "%.4f", two.tokens))")
        #expect(abs(one.tokens - 1.0173) < 0.0005)
        #expect(two.tokens < 1)
        // The edge comes from the naturals alone: every other outcome pays the same at any bet.
        #expect(one.tokens - two.tokens < 0.025)
    }

    /// The slot machines win often enough to feel generous: about two spins in nine on the classic
    /// machine, about one in five on the video one, while both keep the house edge.
    @Test func theSlotMachinesWinOftenEnough() {
        var wins = 0.0, count = 0.0
        for a in SlotMachine.strip {
            for b in SlotMachine.strip {
                for c in SlotMachine.strip {
                    if SlotMachine.payout(for: [a, b, c]) >= 2 { wins += 1 }
                    count += 1
                }
            }
        }
        #expect((0.21...0.24).contains(wins / count), "\(wins / count)")
        #expect((0.95...0.98).contains(SlotMachine.returnToPlayer))
        var rng = SeededGenerator(seed: 5)
        var videoWins = 0
        for _ in 0..<100_000 {
            let stops = VideoSlots.spin(using: &rng)
            if !VideoSlots.lineWins(stops: stops).isEmpty { videoWins += 1 }
        }
        #expect((0.17...0.21).contains(Double(videoWins) / 100_000), "\(videoWins)")
        #expect((0.95...0.97).contains(VideoSlots.returnToPlayer))
    }
}
