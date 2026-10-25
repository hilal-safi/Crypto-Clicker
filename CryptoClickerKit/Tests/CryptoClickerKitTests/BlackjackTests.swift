import Foundation
import Testing
@testable import CryptoClickerKit

/// Cards are dealt player, dealer (up), player, dealer (hole), then in play order.
@Suite("Blackjack")
struct BlackjackTests {
    func stacked(_ ranks: [Int]) -> BlackjackTable {
        var table = BlackjackTable()
        table.stack(ranks: ranks)
        return table
    }

    func cards(_ ranks: [Int]) -> [Card] {
        ranks.enumerated().map { Card(id: $0.offset, rank: $0.element, suit: .hearts) }
    }

    @Test func handValues() {
        #expect(BlackjackTable.evaluate(cards([1, 13])) == (21, true))
        #expect(BlackjackTable.evaluate(cards([1, 1, 9])) == (21, true))
        #expect(BlackjackTable.evaluate(cards([1, 6, 10])) == (17, false))
        #expect(BlackjackTable.evaluate(cards([1, 1])) == (12, true))
        #expect(BlackjackTable.evaluate(cards([12, 11, 2])) == (22, false))
        #expect(BlackjackTable.evaluate([]) == (0, false))
    }

    @Test func naturalsPayThreeToTwoRoundingUp() {
        #expect(BlackjackTable.naturalPayout(bet: 10) == 25)
        #expect(BlackjackTable.naturalPayout(bet: 3) == 8)
        #expect(BlackjackTable.naturalPayout(bet: 1) == 3)
    }

    @Test func aPlayerNaturalSettlesAtOnce() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([1, 9, 13, 7])
        table.deal(bet: 10, using: &rng)
        #expect(table.phase == .settled)
        #expect(table.results == [BlackjackResult(outcome: .blackjack, bet: 10, payout: 25)])
        #expect(table.hands[0].isBlackjack)
    }

    @Test func theDealerPeeksForANatural() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([10, 1, 9, 13])
        table.deal(bet: 10, using: &rng)
        #expect(table.phase == .settled)
        #expect(table.results == [BlackjackResult(outcome: .lose, bet: 10, payout: 0)])
        #expect(!table.isHoleCardHidden)
    }

    @Test func twoNaturalsPush() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([1, 1, 13, 12])
        table.deal(bet: 4, using: &rng)
        #expect(table.results == [BlackjackResult(outcome: .push, bet: 4, payout: 4)])
    }

    @Test func theHoleCardStaysHiddenDuringThePlayersTurn() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([10, 9, 8, 7])
        table.deal(bet: 5, using: &rng)
        #expect(table.phase == .playerTurn)
        #expect(table.isHoleCardHidden)
        #expect(table.dealerUpValue == 9)
        #expect(table.activeHand?.total == 18)
        #expect(table.canHit && table.canDouble && !table.canSplit)
        #expect(table.extraBetNeeded == 5)
    }

    @Test func theDealerStandsOnSoftSeventeen() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([10, 1, 8, 6])
        table.deal(bet: 10, using: &rng)
        table.stand()
        #expect(table.phase == .dealerTurn)
        #expect(!table.dealerShouldDraw)
        table.dealerStep(using: &rng)
        #expect(table.dealer.count == 2)
        #expect(table.results == [BlackjackResult(outcome: .win, bet: 10, payout: 20)])
    }

    @Test func theDealerDrawsBelowSeventeen() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([10, 5, 9, 6, 10])
        table.deal(bet: 10, using: &rng)
        table.stand()
        #expect(table.dealerShouldDraw)
        table.dealerStep(using: &rng)
        #expect(table.dealerTotal == 21)
        #expect(table.phase == .settled)
        #expect(table.results.map(\.outcome) == [.lose])
    }

    @Test func finishDealerPlaysOutTheHand() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([10, 2, 9, 2, 2, 2, 2, 10])
        table.deal(bet: 10, using: &rng)
        table.stand()
        table.finishDealer(using: &rng)
        #expect(table.dealerTotal == 20)
        #expect(table.dealer.count == 6)
        #expect(table.results.map(\.outcome) == [.lose])
    }

    @Test func bustingEndsTheRoundWithoutDealerCards() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([10, 9, 6, 7, 10])
        table.deal(bet: 10, using: &rng)
        table.hit(using: &rng)
        #expect(table.phase == .settled)
        #expect(table.dealer.count == 2)
        #expect(table.results == [BlackjackResult(outcome: .lose, bet: 10, payout: 0)])
    }

    @Test func twentyOneStandsAutomatically() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([5, 9, 6, 7, 10])
        table.deal(bet: 10, using: &rng)
        table.hit(using: &rng)
        #expect(table.hands[0].total == 21)
        #expect(table.phase == .dealerTurn)
        #expect(!table.hands[0].isBlackjack)
    }

    @Test func doublingDownTakesOneCardAndDoublesTheBet() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([6, 9, 5, 7, 10, 10])
        table.deal(bet: 10, using: &rng)
        table.doubleDown(using: &rng)
        #expect(table.hands[0].bet == 20)
        #expect(table.hands[0].isDoubled)
        #expect(table.hands[0].cards.count == 3)
        #expect(table.phase == .dealerTurn)
        table.finishDealer(using: &rng)
        #expect(table.results == [BlackjackResult(outcome: .win, bet: 20, payout: 40)])
    }

    @Test func doublingIsOnlyForTwoCardHands() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([2, 9, 3, 7, 2])
        table.deal(bet: 10, using: &rng)
        table.hit(using: &rng)
        #expect(!table.canDouble)
        table.doubleDown(using: &rng)
        #expect(table.hands[0].bet == 10)
        #expect(table.hands[0].cards.count == 3)
    }

    @Test func splittingPlaysTwoHandsAgainstOneDealer() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([8, 9, 8, 7, 3, 10, 10, 2])
        table.deal(bet: 10, using: &rng)
        #expect(table.canSplit)
        table.split(using: &rng)
        #expect(table.hands.map(\.total) == [11, 18])
        #expect(table.activeIndex == 0)
        #expect(!table.canSplit) // One split per round.
        table.hit(using: &rng) // 21 stands and moves to the second hand.
        #expect(table.activeIndex == 1)
        table.stand()
        table.finishDealer(using: &rng)
        #expect(table.dealerTotal == 18)
        #expect(table.results == [BlackjackResult(outcome: .win, bet: 10, payout: 20),
                                  BlackjackResult(outcome: .push, bet: 10, payout: 10)])
    }

    @Test func tenValueCardsCanBeSplit() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([10, 9, 13, 7])
        table.deal(bet: 10, using: &rng)
        #expect(table.canSplit)
    }

    @Test func splitAcesGetOneCardAndPayEvenMoney() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([1, 9, 1, 7, 13, 5, 10])
        table.deal(bet: 10, using: &rng)
        table.split(using: &rng)
        #expect(table.hands.allSatisfy(\.isDone) == true)
        #expect(table.hands[0].total == 21)
        #expect(!table.hands[0].isBlackjack)
        #expect(table.phase == .dealerTurn)
        table.finishDealer(using: &rng)
        #expect(table.dealerTotal == 26)
        #expect(table.results == [BlackjackResult(outcome: .win, bet: 10, payout: 20),
                                  BlackjackResult(outcome: .win, bet: 10, payout: 20)])
    }

    @Test func theDealerStillPlaysWhenOneSplitHandBusts() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([8, 9, 8, 6, 10, 3, 6, 10])
        table.deal(bet: 10, using: &rng)
        table.split(using: &rng)
        table.hit(using: &rng) // 8 + 10 + 6 = 24: bust.
        #expect(table.activeIndex == 1)
        table.stand() // 8 + 3 = 11.
        #expect(table.phase == .dealerTurn)
        table.finishDealer(using: &rng) // 15 + 10 = 25: bust.
        #expect(table.results.map(\.outcome) == [.lose, .win])
    }

    @Test func actionsOutsideTheirPhaseAreIgnored() {
        var rng = SeededGenerator(seed: 7)
        var table = BlackjackTable()
        table.hit(using: &rng)
        table.stand()
        table.doubleDown(using: &rng)
        table.split(using: &rng)
        table.dealerStep(using: &rng)
        table.newRound()
        #expect(table.phase == .betting)
        table.deal(bet: 0, using: &rng)
        #expect(table.phase == .betting)
        #expect(table.hands.isEmpty)
    }

    @Test func newRoundClearsTheTable() {
        var rng = SeededGenerator(seed: 7)
        var table = stacked([10, 9, 6, 7, 10])
        table.deal(bet: 10, using: &rng)
        table.hit(using: &rng)
        table.newRound()
        #expect(table.phase == .betting)
        #expect(table.hands.isEmpty && table.dealer.isEmpty && table.results.isEmpty)
    }

    /// Plays thousands of seeded rounds with a simple strategy and checks every invariant.
    @Test func randomRoundsKeepEveryInvariant() {
        var rng = SeededGenerator(seed: 2_024)
        var table = BlackjackTable()
        var seenIDs = Set<Int>()
        for round in 0..<5_000 {
            let bet = 1 + round % 7
            table.deal(bet: bet, using: &rng)
            while table.phase == .playerTurn {
                if table.canSplit && round % 3 == 0 {
                    table.split(using: &rng)
                } else if table.canDouble && table.activeHand?.total == 11 {
                    table.doubleDown(using: &rng)
                } else if (table.activeHand?.total ?? 21) < 17 {
                    table.hit(using: &rng)
                } else {
                    table.stand()
                }
            }
            table.finishDealer(using: &rng)
            #expect(table.phase == .settled)
            #expect(table.results.count == table.hands.count)
            for (hand, result) in zip(table.hands, table.results) {
                #expect(result.bet == hand.bet)
                let allowed = [0, hand.bet, hand.bet * 2, BlackjackTable.naturalPayout(bet: hand.bet)]
                #expect(allowed.contains(result.payout))
                if hand.isBust { #expect(result.outcome == .lose) }
                if result.outcome == .blackjack { #expect(hand.isBlackjack) }
            }
            let dealerFinished = table.hands.allSatisfy(\.isBust) || table.dealer.count == 2 && table.dealerTotal == 21
                || table.hands.contains(where: \.isBlackjack) || table.dealerTotal >= 17
            #expect(dealerFinished)
            for card in table.dealer + table.hands.flatMap(\.cards) {
                #expect((1...13).contains(card.rank))
                #expect(seenIDs.insert(card.id).inserted)
            }
            table.newRound()
        }
    }
}
