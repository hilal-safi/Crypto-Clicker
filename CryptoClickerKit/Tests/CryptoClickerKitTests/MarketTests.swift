import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Market")
struct MarketTests {
    /// A fixed afternoon, so tests never depend on the clock.
    let noon = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func pricesStayInRangeAndMove() {
        let range = Tuning.marketPriceRange
        for token in TokenID.allCases {
            var lowest = Double.infinity
            var highest = 0.0
            for tick in 0..<(10 * Market.ticksPerDay) {
                let factor = Market.priceFactor(token, at: noon.addingTimeInterval(Double(tick) * Tuning.marketTick))
                #expect(range.contains(factor))
                lowest = min(lowest, factor)
                highest = max(highest, factor)
            }
            // Over ten days every token swings by at least half its low.
            #expect(highest / lowest > 1.5, "\(token) barely moved")
        }
    }

    @Test func pricesHoldStillWithinATickAndAreTheSameEverywhere() {
        let start = Market.date(ofTick: Market.tick(at: noon))
        for token in TokenID.allCases {
            let price = Market.price(token, at: start)
            #expect(Market.price(token, at: start.addingTimeInterval(Tuning.marketTick - 1)) == price)
            #expect(price == price.rounded()) // Whole coins.
            #expect(price >= 1)
        }
    }

    @Test func memeCoinsSwingMoreThanBitcoin() {
        func spread(_ token: TokenID) -> Double {
            let values = Market.history(token, endingAt: noon, span: 30 * 86_400, points: 2_000)
            let logs = values.map(log)
            let mean = logs.reduce(0, +) / Double(logs.count)
            return logs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(logs.count)
        }
        #expect(spread(.shibaInu) > spread(.bitcoin))
    }

    @Test func historyEndsWithTheCurrentPrice() {
        let history = Market.history(.dogecoin, endingAt: noon, points: 48)
        #expect(history.count == 48)
        #expect(history.last == Market.priceFactor(.dogecoin, at: noon))
        #expect(history.first == Market.priceFactor(.dogecoin, at: noon.addingTimeInterval(-86_400)))
        #expect(approx(Market.dayChange(.dogecoin, at: noon), history.last! / history.first! - 1))
    }

    @Test func newsBreaksAFewTimesADayAndMovesThePrice() throws {
        let month = Market.news(before: noon, span: 30 * 86_400)
        // About one story per token per day; allow plenty of luck either way.
        #expect((60...400).contains(month.count))
        #expect(month.map(\.date) == month.map(\.date).sorted(by: >)) // Newest first.
        #expect(month.contains { $0.isGood } && month.contains { !$0.isGood })
        let story = try #require(month.first)
        #expect(story.headline.contains(story.token.name))
        // The price jumps the way the news says the moment it breaks.
        let before = Market.priceFactor(story.token, at: story.date.addingTimeInterval(-1))
        let after = Market.priceFactor(story.token, at: story.date)
        let range = Tuning.marketPriceRange
        if !range.contains(before * 1.2) || !range.contains(after / 1.2) { return } // Pinned at a limit.
        #expect(story.isGood ? after > before : after < before)
    }

    @Test func buyingUsesTheMarketPrice() {
        let price = Market.price(.shibaInu, at: noon)
        var game = GameState.make(coins: price * 5 + 7)
        #expect(game.maxAffordableTokens(.shibaInu, at: noon) == 5)
        #expect(game.buyTokens(.shibaInu, quantity: 5, at: noon) == true)
        #expect(game.coins == 7)
        #expect(game.tokenCount(.shibaInu) == 5)
        #expect(game.stats.tokensBought[.shibaInu] == 5)
        #expect(game.stats.spent == price * 5)
        #expect(game.buyTokens(.shibaInu, quantity: 1, at: noon) == false)
        #expect(game.buyTokens(.shibaInu, quantity: 0, at: noon) == false)
        #expect(game.buyTokens(.shibaInu, quantity: -2, at: noon) == false)
        #expect(game.coins == 7)
    }

    @Test func sellingPaysThePriceLessTheFeeWithoutCountingAsMined() {
        let price = Market.price(.dogecoin, at: noon)
        var game = GameState.make()
        game.tokens = [.dogecoin: 10]
        #expect(game.saleValue(of: .dogecoin, quantity: 4, at: noon) == (price * 4 * 0.9).rounded())
        let paid = game.sellTokens(.dogecoin, quantity: 4, at: noon)
        #expect(paid == (price * 4 * 0.9).rounded())
        #expect(game.coins == paid)
        #expect(game.tokenCount(.dogecoin) == 6)
        #expect(game.stats.tokensSold == 4)
        #expect(game.stats.coinsFromSales == paid)
        #expect(game.stats.lifetimeCoins == 0) // Trading never adds prestige potential.
        #expect(game.sellTokens(.dogecoin, quantity: 7, at: noon) == nil)
        #expect(game.sellTokens(.dogecoin, quantity: 0, at: noon) == nil)
        #expect(game.tokenCount(.dogecoin) == 6)
        game.perks = [.marketInsider]
        #expect(game.sellTokens(.dogecoin, quantity: 6, at: noon) == price * 6)
        #expect(game.tokenCount(.dogecoin) == 0)
    }
}
