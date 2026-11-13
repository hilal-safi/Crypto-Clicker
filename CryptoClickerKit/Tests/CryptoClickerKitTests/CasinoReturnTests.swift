import Foundation
import Testing
@testable import CryptoClickerKit

/// What the casino pays over time, for balancing: each game's token return (the house edge on the
/// stake) and its coin bonus, both as a share of the stake's coin value while the bonus is below its
/// cap (small bets), and in seconds of income per round once it's capped (bets big for the income).
/// The reward multiplier is the mini-game one: 1 with no upgrades, 5.625 with all three Bonus
/// Rewards and Arcade Champion. Runs with the balance tests:
/// `RUN_BALANCE_TESTS=1 swift test --filter CasinoReturnTests`.
@Suite("Casino returns")
struct CasinoReturnTests {
    static let fullMultiplier = 1.25 * 1.5 * 2 * 1.5

    struct Return {
        /// Tokens back per token staked (the stake's coin value at list price).
        var tokens: Double
        /// Coin bonus per token staked, below the cap, before reward upgrades.
        var bonus: Double
        /// Seconds of income the bonus pays per round once capped, before reward upgrades.
        var cappedSeconds: Double
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
        return Return(tokens: returned / staked, bonus: bonus / Double(hands * bet), cappedSeconds: capped / Double(hands))
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
                      cappedSeconds: average * Tuning.pokerWinSeconds)
    }

    /// Crypto Slots, worked out exactly from the strip (free spins add their wins too).
    func slots() -> Return {
        var multiples = 0.0, count = 0.0
        for a in SlotMachine.strip {
            for b in SlotMachine.strip {
                for c in SlotMachine.strip {
                    let pays = SlotMachine.payout(for: [a, b, c])
                    if pays >= 2 { multiples += Double(pays) }
                    count += 1
                }
            }
        }
        let freeSpins = 1 + SlotMachine.freeSpinChance * Double(SlotMachine.freeSpinsPerTrigger)
        let average = multiples / count * freeSpins
        return Return(tokens: SlotMachine.returnToPlayer, bonus: average * Tuning.slotsStakeShare,
                      cappedSeconds: average * Tuning.slotsWinSeconds)
    }

    /// Crypto Slots' video machine: tokens exactly from the strip and the pay table, the bonus from
    /// spins played out (each paid spin brings `1 / (1 - freeSpinsPerSpin)` spins in all).
    func videoSlots(spins: Int) -> Return {
        var rng = SeededGenerator(seed: 2028)
        var multiples = 0.0
        for _ in 0..<spins {
            let pays = VideoSlots.lineWins(stops: VideoSlots.spin(using: &rng)).reduce(0) { $0 + $1.pays }
            let stakeMultiple = Double(pays) / Double(VideoSlots.paylines.count)
            if stakeMultiple >= 2 { multiples += stakeMultiple }
        }
        let average = multiples / Double(spins) / (1 - VideoSlots.freeSpinsPerSpin)
        return Return(tokens: VideoSlots.returnToPlayer, bonus: average * Tuning.slotsStakeShare,
                      cappedSeconds: average * Tuning.slotsWinSeconds)
    }

    /// To the Moon, cashing out at `target`: it gets there with chance 0.97 / target (0.95 / target
    /// on the 5× rocket, whose bonus is bigger).
    func moon(cashingOutAt target: Double, rocket: MoonRocket = .doubling) -> Return {
        let reach = MoonFlight.chance(ofReaching: target, rocket: rocket)
        let multiples = reach * (target - 1) * rocket.bonusFactor
        return Return(tokens: reach * target, bonus: multiples * Tuning.moonStakeShare,
                      cappedSeconds: multiples * Tuning.moonWinSeconds)
    }

    @Test func theCasinoKeepsAnEdgeOnTokensAndPaysItsBonusesWithinTheirCaps() {
        guard ProcessInfo.processInfo.environment["RUN_BALANCE_TESTS"] != nil else { return }
        let games: [(String, Return)] = [
            ("21 Million, 1-token bets", blackjack(hands: 400_000, bet: 1)),
            ("21 Million, 2-token bets", blackjack(hands: 400_000, bet: 2)),
            ("Diamond Hands", videoPoker(hands: 400_000)),
            ("Crypto Slots", slots()),
            ("Crypto Slots 5x3", videoSlots(spins: 400_000)),
            ("To the Moon 2x", moon(cashingOutAt: 2)),
            ("To the Moon 10x", moon(cashingOutAt: 10)),
            ("To the Moon 5x rocket, 2x", moon(cashingOutAt: 2, rocket: .fivefold)),
            ("To the Moon 5x rocket, 10x", moon(cashingOutAt: 10, rocket: .fivefold)),
        ]
        for (name, game) in games {
            let sell = 1 - Tuning.marketSellFee
            func line(_ multiplier: Double) -> String {
                // Kept tokens are bet again, so the edge counts per round; the fee only on a final sale.
                let perRound = game.tokens - 1 + game.bonus * multiplier
                return String(format: "%+.1f%% a round, %.0fs income capped", perRound * 100, game.cappedSeconds * multiplier)
            }
            print("Casino \(name): tokens back \(String(format: "%.2f%%", game.tokens * 100)) (sold \(String(format: "%.1f%%", game.tokens * sell * 100)))",
                  "| bonus \(String(format: "%.1f%%", game.bonus * 100)) of the stake",
                  "| no upgrades: \(line(1)) | all upgrades: \(line(Self.fullMultiplier))")
            // Every game keeps an edge on the tokens themselves (but for one-token naturals at 21
            // Million, rounded up to 2 to 1); the coins come from the bonus.
            #expect(game.tokens < (name.hasPrefix("21 Million, 1-token") ? 1.03 : 1.005), "\(name)")
        }
    }
}
