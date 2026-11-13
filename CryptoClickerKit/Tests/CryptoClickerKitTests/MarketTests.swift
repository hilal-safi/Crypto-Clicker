import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Market")
struct MarketTests {
    /// A fixed afternoon, so tests never depend on the clock.
    let noon = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func pricesStayInRangeAndMove() {
        for token in TokenID.allCases {
            let range = token.priceRange
            var lowest = Double.infinity
            var highest = 0.0
            for tick in 0..<(10 * Market.ticksPerDay) {
                let factor = Market.priceFactor(token, at: noon.addingTimeInterval(Double(tick) * Tuning.marketTick))
                #expect(range.contains(factor))
                lowest = min(lowest, factor)
                highest = max(highest, factor)
            }
            if token == .tether {
                // A stablecoin holds its peg: within a few percent, news and all.
                #expect(highest / lowest < 1.05, "Tether swung \(highest / lowest)")
                continue
            }
            // Over ten days every other token moves, by at least a tenth, but no token runs away.
            // The volatile ones move a lot: by half or more.
            #expect(highest / lowest > (token.volatilityLevel == .volatile ? 1.5 : 1.1), "\(token) barely moved")
            #expect(highest / lowest < (token.volatilityLevel == .volatile ? 3.6 : 1.8), "\(token) swung too far")
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
        // About five stories a day across all tokens; allow plenty of luck either way.
        #expect((40...300).contains(month.count))
        #expect(month.map(\.date) == month.map(\.date).sorted(by: >)) // Newest first.
        #expect(month.contains { $0.isGood } && month.contains { !$0.isGood })
        let story = try #require(month.first)
        #expect(story.headline.contains(story.token.name))
        // The price jumps the way the news says the moment it breaks.
        let before = Market.priceFactor(story.token, at: story.date.addingTimeInterval(-1))
        let after = Market.priceFactor(story.token, at: story.date)
        let range = story.token.priceRange
        if !range.contains(before * 1.04) || !range.contains(before / 1.04) { return } // Near a limit.
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

    @Test func theLadderClimbsFromSafeMoonToBitcoin() {
        let ladder: [TokenID] = [.safeMoon, .shibaInu, .tether, .dogecoin, .xrp, .bnb, .monero, .cardano, .solana, .ethereum, .bitcoin]
        #expect(TokenID.allCases == ladder)
        #expect(zip(ladder, ladder.dropFirst()).allSatisfy { $0.price < $1.price })
        // The original seven keep their prices, so tokens already owned keep their value.
        #expect([TokenID.shibaInu, .dogecoin, .xrp, .cardano, .solana, .ethereum, .bitcoin].map(\.price)
                == [1e3, 1e5, 1e7, 1e9, 1e11, 1e13, 1e15])
        #expect(Set(TokenID.allCases.map(\.ticker)).count == ladder.count)
        #expect(Set(TokenID.allCases.map(\.imageName)).count == ladder.count)
    }

    @Test func safeMoonIsTheCheapestTokenAndSwingsTheMost() {
        #expect(TokenID.allCases.first == .safeMoon)
        #expect(TokenID.safeMoon.price == 100)
        #expect(TokenID.allCases.dropFirst().allSatisfy { $0.price > TokenID.safeMoon.price })
        #expect(TokenID.allCases.map(\.price) == TokenID.allCases.map(\.price).sorted()) // Cheapest first.
        #expect(TokenID.allCases.allSatisfy { $0 == .safeMoon || $0.volatility < TokenID.safeMoon.volatility })
        #expect(TokenID.safeMoon.ticker == "SFM")
        // The Tokens page tags each by how much it moves.
        #expect(TokenID.tether.volatilityLevel == .stable)
        #expect(TokenID.allCases.filter { $0.volatilityLevel == .volatile } == [.safeMoon, .shibaInu, .dogecoin])
        #expect([TokenID.bnb, .xrp, .monero, .cardano, .solana, .ethereum, .bitcoin].allSatisfy { $0.volatilityLevel == .moderate })
        #expect(TokenID.safeMoon.imageName == "safemoon_image")
        // Not on the slot reels: it would change what the machine pays.
        #expect(!SlotMachine.strip.contains(.safeMoon))
        #expect(SlotMachine.threeOfAKind(.safeMoon) == 0)
        // Its price stays in the volatile tokens' wider range.
        #expect(TokenID.safeMoon.priceRange == Tuning.volatilePriceRange)
        #expect(TokenID.bitcoin.priceRange == Tuning.marketPriceRange)
        for hour in stride(from: 0.0, to: 24 * 30, by: 7) {
            let date = Date(timeIntervalSince1970: 1_790_000_000 + hour * 3_600)
            #expect(Tuning.volatilePriceRange.contains(Market.priceFactor(.safeMoon, at: date)))
        }
    }

    /// Prices and news are seeded by each token's name, so adding SafeMoon (first in the list)
    /// left every other token's market exactly as it was: these are the prices from before it (but
    /// for Shiba Inu and Dogecoin, which have swung harder since, as volatile tokens).
    @Test func addingATokenLeavesTheOthersPricesAlone() {
        let early = Date(timeIntervalSince1970: 1_790_000_000), late = Date(timeIntervalSince1970: 1_800_000_000)
        let before: [TokenID: (Double, Double)] = [
            .tether: (10_011, 10_027),
            .xrp: (9_678_458, 11_461_001), .bnb: (45_559_598, 48_719_392), .monero: (199_903_496, 187_742_978),
            .cardano: (1_168_248_191, 907_347_852), .solana: (99_674_998_931, 101_609_276_832),
            .ethereum: (9_783_099_588_791, 9_123_334_646_435), .bitcoin: (1_034_124_902_388_354, 1_042_730_824_033_083),
        ]
        for (token, prices) in before {
            #expect(Market.price(token, at: early) == prices.0, "\(token)")
            #expect(Market.price(token, at: late) == prices.1, "\(token)")
        }
    }
}
