import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Video Poker")
struct VideoPokerTests {
    /// Cards from short names: "As" is the ace of spades, "Th" the ten of hearts.
    func hand(_ names: String) -> [Card] {
        names.split(separator: " ").enumerated().map { index, name in
            let ranks: [Character: Int] = ["A": 1, "T": 10, "J": 11, "Q": 12, "K": 13]
            let rankChar = name.first!
            let rank = ranks[rankChar] ?? Int(String(rankChar))!
            let suit: Card.Suit = switch name.last! {
            case "s": .spades
            case "h": .hearts
            case "d": .diamonds
            default: .clubs
            }
            return Card(id: index, rank: rank, suit: suit)
        }
    }

    @Test func handsAreRankedLikeJacksOrBetter() {
        #expect(VideoPoker.evaluate(hand("As Ks Qs Js Ts")) == .royalFlush)
        #expect(VideoPoker.evaluate(hand("9h Kh Qh Jh Th")) == .straightFlush)
        #expect(VideoPoker.evaluate(hand("Ad 2d 3d 4d 5d")) == .straightFlush) // Aces count low too.
        #expect(VideoPoker.evaluate(hand("7s 7h 7d 7c 2s")) == .fourOfAKind)
        #expect(VideoPoker.evaluate(hand("7s 7h 7d 2c 2s")) == .fullHouse)
        #expect(VideoPoker.evaluate(hand("2h 9h Jh Kh 4h")) == .flush)
        #expect(VideoPoker.evaluate(hand("Ac Kd Qs Jh Ts")) == .straight)
        #expect(VideoPoker.evaluate(hand("Ac 2d 3s 4h 5s")) == .straight)
        #expect(VideoPoker.evaluate(hand("Qc Kd As 2h 3s")) == .nothing) // No wrapping round.
        #expect(VideoPoker.evaluate(hand("9c 9d 9s 2h 5s")) == .threeOfAKind)
        #expect(VideoPoker.evaluate(hand("9c 9d 4s 4h 5s")) == .twoPair)
        #expect(VideoPoker.evaluate(hand("Jc Jd 4s 8h 5s")) == .jacksOrBetter)
        #expect(VideoPoker.evaluate(hand("Ac 3d As 8h 5s")) == .jacksOrBetter)
        #expect(VideoPoker.evaluate(hand("Tc Td 4s 8h 5s")) == .nothing) // Tens don't pay.
        #expect(VideoPoker.evaluate(hand("2c 7d 9s Jh Ks")) == .nothing)
        #expect(VideoPoker.evaluate(hand("2c 7d 9s Jh")) == .nothing) // Not five cards.
    }

    @Test func thePayTableIsEightFive() {
        #expect(PokerHand.allCases.map(\.payout) == [0, 1, 2, 3, 4, 5, 8, 25, 50, 800])
        #expect(PokerHand.paying.first == .royalFlush)
        #expect(PokerHand.paying.count == 9)
        #expect(PokerHand.twoPair > .jacksOrBetter)
    }

    @Test func drawingKeepsHeldCardsInPlace() {
        let cards = hand("As Ks 2d 7c 9h")
        let pile = hand("Qs Js Ts 3c 4c").map { Card(id: $0.id + 10, rank: $0.rank, suit: $0.suit) }
        let drawn = VideoPoker.draw(cards, holding: [0, 1], from: pile)
        #expect(drawn.map(\.id) == [0, 1, 10, 11, 12])
        #expect(VideoPoker.evaluate(drawn) == .royalFlush)
        #expect(VideoPoker.draw(cards, holding: Set(0..<5), from: pile) == cards)
        #expect(VideoPoker.draw(cards, holding: [], from: pile).map(\.id) == [10, 11, 12, 13, 14])
    }

    @Test func dealsComeFromOneShuffledDeck() {
        var rng = SeededGenerator(seed: 9)
        for _ in 0..<200 {
            let dealt = VideoPoker.deal(using: &rng)
            let all = dealt.cards + dealt.drawPile
            #expect(dealt.cards.count == 5 && dealt.drawPile.count == 5)
            #expect(Set(all.map(\.id)).count == 10)
            #expect(Set(all.map { "\($0.rank)\($0.suit)" }).count == 10)
        }
    }

    @Test func theSuggestedHoldsFollowTheSimpleStrategy() {
        func holds(_ names: String) -> [String] {
            let cards = hand(names)
            return VideoPoker.suggestedHolds(cards).sorted().map { names.split(separator: " ").map(String.init)[$0] }
        }
        #expect(holds("As Ks Qs Js Ts") == ["As", "Ks", "Qs", "Js", "Ts"])
        #expect(holds("7s 7h 7d 7c 2s") == ["7s", "7h", "7d", "7c"])
        #expect(holds("As Ks Qs Js 3s") == ["As", "Ks", "Qs", "Js"]) // 4 to a royal beats a pat flush.
        #expect(holds("2h 9h Jh Kh 4h") == ["2h", "9h", "Jh", "Kh", "4h"])
        #expect(holds("9c 9d 9s 2h 5s") == ["9c", "9d", "9s"])
        #expect(holds("9s Ts Js Qs 2d") == ["9s", "Ts", "Js", "Qs"]) // 4 to a straight flush.
        #expect(holds("9c 9d 4s 4h Ks") == ["9c", "9d", "4s", "4h"])
        #expect(holds("Jc Jd 4s 8h 5s") == ["Jc", "Jd"])
        #expect(holds("Qh Kh Ah 3c 3d") == ["Qh", "Kh", "Ah"]) // 3 to a royal beats a low pair.
        #expect(holds("2h 6h 9h Kh 3c") == ["2h", "6h", "9h", "Kh"]) // 4 to a flush.
        #expect(holds("5c 5d 9s Qh 2s") == ["5c", "5d"])
        #expect(holds("5c 6d 7s 8h Ks") == ["5c", "6d", "7s", "8h"]) // An outside straight.
        #expect(holds("Jh Qh 4s 8c 2d") == ["Jh", "Qh"])
        #expect(holds("Jh Qs Kd 4c 2d") == ["Jh", "Qs"]) // The two lowest high cards.
        #expect(holds("Th Kh 4s 8c 2d") == ["Th", "Kh"])
        #expect(holds("Ah 3s 6c 8d 9c") == ["Ah"])
        #expect(holds("2h 4s 6c 8d 9c").isEmpty)
    }

    /// 50,000 hands played with the suggested holds return close to the table's 97%. Royal flushes
    /// are left out of the measure: one in 40,000 hands, but worth 800 times the bet, they would
    /// swing a short sample by several percent. The rest of the table returns about 95%.
    @Test func theSuggestedStrategyReturnsAboutNinetySevenPercent() {
        var rng = SeededGenerator(seed: 2_026)
        var returned = 0
        var hands: [PokerHand: Int] = [:]
        let count = 50_000
        for _ in 0..<count {
            let dealt = VideoPoker.deal(using: &rng)
            let final = VideoPoker.draw(dealt.cards, holding: VideoPoker.suggestedHolds(dealt.cards), from: dealt.drawPile)
            let made = VideoPoker.evaluate(final)
            hands[made, default: 0] += 1
            if made != .royalFlush { returned += made.payout }
        }
        let withoutRoyals = Double(returned) / Double(count)
        #expect((0.93...0.97).contains(withoutRoyals), "returned \(withoutRoyals)")
        // About one hand in five pays even money, and about one in four does better.
        let evenMoney = Double(hands[.jacksOrBetter, default: 0]) / Double(count)
        #expect((0.18...0.24).contains(evenMoney))
    }

    // MARK: Betting

    func player() -> GameState {
        var game = GameState.make(miners: [.desktop: 5]) // 10 coins a second.
        game.tokens = [.shibaInu: 100]
        return game
    }

    @Test func aHandTakesTheBetAndPaysTheTable() throws {
        var game = player()
        var rng = SeededGenerator(seed: 1)
        let result1 = game.dealPoker(.shibaInu, bet: 101, using: &rng)
        #expect(result1 == nil)
        let result2 = game.dealPoker(.shibaInu, bet: 0, using: &rng)
        #expect(result2 == nil)
        let dealing = game.dealPoker(.shibaInu, bet: 10, using: &rng)
        let dealt = try #require(dealing)
        let result3 = game.dealPoker(.shibaInu, bet: 10, using: &rng) // One hand at a time.
        #expect(result3 == nil)
        #expect(game.tokenCount(.shibaInu) == 90)
        #expect(game.stats.pokerHands == 1)
        #expect(game.stats.pokerWagered == 10_000)
        let drawing = game.drawPoker(holding: [0, 1, 2, 3, 4])
        let drawn = try #require(drawing)
        #expect(drawn.cards == dealt.cards)
        #expect(drawn.hand == VideoPoker.evaluate(dealt.cards))
        #expect(drawn.tokensWon == 10 * drawn.hand.payout)
        #expect(game.tokenCount(.shibaInu) == 90 + drawn.tokensWon)
        #expect(game.pokerRound == nil)
        let result4 = game.drawPoker(holding: [])
        #expect(result4 == nil)
    }

    @Test func goodHandsPayACoinBonus() {
        var game = player()
        game.tokens[.shibaInu] = 90
        // A full house: 8 times the bet back, and a bonus for each multiple.
        game.pokerRound = PokerRound(token: .shibaInu, bet: 10, cards: hand("7s 7h 7d 2c 2s"), drawPile: hand("3s 4s 5s 6s 8s"))
        let result = game.drawPoker(holding: [0, 1, 2, 3, 4])
        #expect(result?.hand == .fullHouse)
        #expect(result?.tokensWon == 80)
        // 10 Shiba stake 10,000 coins: 5% is 500, capped at 15 seconds of income (150) per multiple.
        #expect(result?.bonus == 1_200)
        #expect(game.coins == 1_200)
        #expect(game.stats.pokerWins == 1)
        #expect(game.stats.pokerBestHand == PokerHand.fullHouse.rawValue)
        #expect(game.stats.pokerBiggestWin == 70 * 1_000 + 1_200)
        // Jacks or better returns the bet, with no bonus.
        #expect(game.pokerBonus(bet: 10, token: .shibaInu, hand: .jacksOrBetter) == 0)
        #expect(game.pokerBonus(bet: 1, token: .shibaInu, hand: .twoPair) == 100) // 5% of 1,000, twice.
        #expect(game.pokerBetForFullBonus(.shibaInu) == 3)
    }

    @Test func aHandLeftWaitingGoesWithAPrestige() {
        var game = player()
        game.pokerRound = PokerRound(token: .shibaInu, bet: 5, cards: hand("Js Jh 4d 8c 2s"), drawPile: hand("Jd Jc 3s 6s 9h"))
        game.stats.lifetimeCoins = 1e15
        #expect(game.prestige(at: t0) > 0)
        #expect(game.pokerRound == nil) // Bet in tokens, which a prestige resets anyway.
        #expect(game.tokens.isEmpty)
    }

    @Test func aHandLeftUnfinishedIsPlayedOutWithTheSuggestedHolds() {
        var game = player()
        game.pokerRound = PokerRound(token: .shibaInu, bet: 5, cards: hand("Js Jh 4d 8c 2s"), drawPile: hand("Jd Jc 3s 6s 9h"))
        let result = game.finishPokerRound()
        #expect(result?.hand == .fourOfAKind) // Held the jacks, drew the other two.
        #expect(result?.tokensWon == 125)
        #expect(game.pokerRound == nil)
        let result5 = game.finishPokerRound()
        #expect(result5 == nil)
    }
}
