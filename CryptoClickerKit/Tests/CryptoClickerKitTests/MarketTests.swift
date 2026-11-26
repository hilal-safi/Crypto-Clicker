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

    /// A time when `token` costs at least 20% more than at `noon`, within a week of it.
    func rise(_ token: TokenID) -> Date? {
        let start = Market.price(token, at: noon)
        return (1...2_016).lazy.map { self.noon.addingTimeInterval(Double($0) * 300) }
            .first { Market.price(token, at: $0) >= start * 1.2 }
    }

    @Test func aSaleIsPreviewedInFullAndComparedWithThePricePaid() throws {
        let token = TokenID.dogecoin
        let later = try #require(rise(token))
        let bought = Market.price(token, at: noon)
        var game = GameState.make(coins: bought * 10)
        #expect(game.buyTokens(token, quantity: 10, at: noon) == true)
        // Before selling: the tokens' worth, the fee and what's left, against what they cost.
        let preview = game.salePreview(of: token, quantity: 4, at: later)
        let worth = (Market.price(token, at: later) * 4).rounded()
        #expect(preview.worth == worth)
        #expect(preview.net == game.saleValue(of: token, quantity: 4, at: later))
        #expect(preview.fee == worth - preview.net && preview.fee > 0)
        #expect(preview.paid == bought * 4)
        #expect(preview.profit == preview.net - bought * 4)
        // The sale itself: a profit, counted once, in the history.
        let sale = game.sellTokens(token, quantity: 4, at: later)
        let paid = try #require(sale)
        #expect(paid == preview.net)
        #expect(game.stats.profitableSales == 1)
        #expect(game.stats.tradingProfit == paid - bought * 4 && game.stats.bestSaleProfit == game.stats.tradingProfit)
        #expect(game.recentTrades.map(\.quantity) == [10, -4])
        #expect(game.recentTrades.last?.profit == paid - bought * 4 && game.recentTrades.last?.isSale == true)
        #expect(game.recentTrades.first?.coins == bought * 10 && game.recentTrades.first?.profit == nil)
        #expect(game.tiersEarned(AchievementCatalog.all.first { $0.id == "buy-low" }!) == 0)
        game.refreshAchievements()
        #expect(game.tiersEarned(AchievementCatalog.all.first { $0.id == "buy-low" }!) == 1)
        // Selling at a loss counts against the total, not as a profitable sale.
        let low = try #require((1...2_016).lazy.map { later.addingTimeInterval(Double($0) * 300) }
            .first { Market.price(token, at: $0) * 0.9 < bought })
        let lossSale = game.sellTokens(token, quantity: 2, at: low)
        let loss = try #require(lossSale)
        #expect(game.stats.profitableSales == 1)
        #expect(abs(game.stats.tradingProfit - (paid - bought * 4 + loss - bought * 2)) < 1e-6)
    }

    @Test func tokensNeverBoughtHaveNoPricePaid() {
        var game = GameState.make()
        game.tokens = [.bitcoin: 3] // Won at the casino, say.
        let preview = game.salePreview(of: .bitcoin, quantity: 3, at: noon)
        #expect(preview.paid == nil && preview.profit == nil)
        game.sellTokens(.bitcoin, quantity: 3, at: noon)
        #expect(game.stats.profitableSales == 0 && game.stats.tradingProfit == 0)
        #expect(game.recentTrades.last?.profit == nil)
        #expect(game.portfolio(at: noon) == Portfolio(worth: 0, paid: 0, worthOfPaid: 0))
    }

    @Test func thePortfolioComparesWhatWasPaidWithWhatItsWorth() throws {
        let later = try #require(rise(.dogecoin))
        var game = GameState.make(coins: 1e9)
        game.buyTokens(.dogecoin, quantity: 5, at: noon)
        game.tokens[.bitcoin] = 2 // Never bought: worth something, paid nothing.
        let portfolio = game.portfolio(at: later)
        let dogecoin = Market.price(.dogecoin, at: later) * 5
        #expect(portfolio.paid == Market.price(.dogecoin, at: noon) * 5)
        #expect(portfolio.worthOfPaid == dogecoin)
        #expect(portfolio.worth == dogecoin + Market.price(.bitcoin, at: later) * 2)
        #expect(portfolio.change > 0 && (portfolio.changeShare ?? 0) >= 0.2 - 1e-9)
    }

    // MARK: What the tokens held cost

    /// Stakes `bet` tokens on a hand of 21 Million that pays `payout` tokens back.
    func playHand(_ game: inout GameState, _ token: TokenID, bet: Int, payout: Int) {
        #expect(game.placeBlackjackBet(token, amount: bet) == true)
        let outcome: BlackjackOutcome = payout > bet ? .win : payout == bet ? .push : .lose
        game.settleBlackjack([BlackjackResult(outcome: outcome, bet: bet, payout: payout)], token: token)
    }

    @Test func sellingEverythingLeavesNothingPaid() throws {
        let price = Market.price(.dogecoin, at: noon)
        var game = GameState.make(coins: price * 10)
        #expect(game.buyTokens(.dogecoin, quantity: 10, at: noon) == true)
        #expect(game.boughtTokens[.dogecoin] == TokenLot(count: 10, cost: price * 10))
        #expect(game.averageCost(of: .dogecoin) == price)
        let sale = game.sellTokens(.dogecoin, quantity: 10, at: noon)
        let net = try #require(sale)
        // The same price both ways: the fee is all that was lost.
        #expect(game.recentTrades.last?.profit == net - price * 10)
        #expect(game.stats.tradingProfit == net - price * 10 && game.stats.profitableSales == 0)
        #expect(game.boughtTokens.isEmpty && game.averageCost(of: .dogecoin) == nil)
        #expect(game.portfolio(at: noon) == Portfolio(worth: 0, paid: 0, worthOfPaid: 0))
    }

    /// The reviewer's case: buy 10 at one price and sell them all, buy 10 at a higher price and sell
    /// them at that price. The second sale lost the fee; the lifetime average (between the two
    /// prices) would have called it a profit.
    @Test func buyingAgainAtAnotherPriceStartsAfresh() throws {
        let later = try #require(rise(.dogecoin))
        let first = Market.price(.dogecoin, at: noon)
        let second = Market.price(.dogecoin, at: later)
        var game = GameState.make(coins: (first + second) * 10)
        game.buyTokens(.dogecoin, quantity: 10, at: noon)
        game.sellTokens(.dogecoin, quantity: 10, at: noon)
        game.buyTokens(.dogecoin, quantity: 10, at: later)
        #expect(game.averageCost(of: .dogecoin) == second)
        let preview = game.salePreview(of: .dogecoin, quantity: 10, at: later)
        #expect(preview.paid == second * 10 && preview.profit == preview.net - second * 10)
        #expect(try #require(preview.profit) < 0)
        // The lifetime figures still count both purchases.
        #expect(game.stats.averagePricePaid(.dogecoin) == (first + second) / 2)
        #expect(game.stats.tokensBought[.dogecoin] == 20)
        let sale = game.sellTokens(.dogecoin, quantity: 10, at: later)
        let net = try #require(sale)
        #expect(game.recentTrades.last?.profit == net - second * 10)
        #expect(game.stats.profitableSales == 0)
    }

    @Test func purchasesAtTwoPricesAverageAndASaleTakesItsShare() throws {
        let later = try #require(rise(.dogecoin))
        let first = Market.price(.dogecoin, at: noon)
        let second = Market.price(.dogecoin, at: later)
        var game = GameState.make(coins: (first + second) * 10)
        game.buyTokens(.dogecoin, quantity: 10, at: noon)
        game.buyTokens(.dogecoin, quantity: 10, at: later)
        #expect(game.averageCost(of: .dogecoin) == (first + second) / 2)
        let preview = game.salePreview(of: .dogecoin, quantity: 5, at: later)
        #expect(preview.bought == 5 && preview.paid == (first + second) / 2 * 5)
        game.sellTokens(.dogecoin, quantity: 5, at: later)
        let lot = try #require(game.boughtTokens[.dogecoin])
        #expect(lot.count == 15 && approx(lot.cost, (first + second) * 10 * 15 / 20))
        #expect(game.averageCost(of: .dogecoin) == lot.averageCost)
    }

    @Test func aPrestigeClearsWhatTheTokensCost() throws {
        let later = try #require(rise(.dogecoin))
        var game = GameState.make(coins: 1e9)
        game.buyTokens(.dogecoin, quantity: 10, at: noon)
        game.stats.lifetimeCoins = 1e11
        #expect(game.prestige(at: noon) > 0)
        #expect(game.tokens.isEmpty && game.boughtTokens.isEmpty)
        // Tokens won after it cost nothing: selling them is no profit and no loss...
        game.giveTokens(.dogecoin, amount: 4)
        #expect(game.salePreview(of: .dogecoin, quantity: 4, at: later).profit == nil)
        game.sellTokens(.dogecoin, quantity: 4, at: later)
        #expect(game.recentTrades.last?.profit == nil)
        // ...and new purchases are measured against what they cost, not the last run's price.
        let price = Market.price(.dogecoin, at: later)
        game.coins = price * 5
        game.buyTokens(.dogecoin, quantity: 5, at: later)
        #expect(game.averageCost(of: .dogecoin) == price)
        #expect(game.portfolio(at: later).paid == price * 5)
        #expect(game.stats.tokensBought[.dogecoin] == 15) // Lifetime figures carry over.
    }

    @Test func wonTokensCostNothingAndBoughtOnesAreSoldFirst() throws {
        let later = try #require(rise(.dogecoin))
        let price = Market.price(.dogecoin, at: noon)
        var game = GameState.make(coins: price * 10)
        game.buyTokens(.dogecoin, quantity: 10, at: noon)
        playHand(&game, .dogecoin, bet: 10, payout: 20) // A win: the stake back and 10 more.
        #expect(game.tokenCount(.dogecoin) == 20 && game.boughtCount(.dogecoin) == 10)
        #expect(game.boughtTokens[.dogecoin] == TokenLot(count: 10, cost: price * 10))
        // The wallet compares only the bought ones with what they cost.
        let portfolio = game.portfolio(at: later)
        #expect(portfolio.paid == price * 10)
        #expect(portfolio.worthOfPaid == Market.price(.dogecoin, at: later) * 10)
        #expect(portfolio.worth == Market.price(.dogecoin, at: later) * 20)
        // Selling 15: the 10 bought go first, and only their share of the coins counts.
        let preview = game.salePreview(of: .dogecoin, quantity: 15, at: later)
        #expect(preview.count == 15 && preview.bought == 10 && preview.paid == price * 10)
        let profit = try #require(preview.profit)
        #expect(approx(profit, preview.net * 10 / 15 - price * 10))
        game.sellTokens(.dogecoin, quantity: 15, at: later)
        #expect(game.recentTrades.last?.profit == profit)
        #expect(game.boughtTokens.isEmpty && game.tokenCount(.dogecoin) == 5)
        // The 5 left were won.
        let rest = game.salePreview(of: .dogecoin, quantity: 5, at: later)
        #expect(rest.bought == 0 && rest.paid == nil && rest.profit == nil)
    }

    @Test func casinoLossesComeOutOfWonTokensFirst() throws {
        let price = Market.price(.dogecoin, at: noon)
        var game = GameState.make(coins: price * 10)
        game.buyTokens(.dogecoin, quantity: 10, at: noon)
        playHand(&game, .dogecoin, bet: 10, payout: 20) // Won 10.
        playHand(&game, .dogecoin, bet: 10, payout: 0)  // Lost 10: the ones won.
        #expect(game.boughtTokens[.dogecoin] == TokenLot(count: 10, cost: price * 10))
        playHand(&game, .dogecoin, bet: 4, payout: 0)   // Lost 4 of the bought ones.
        #expect(game.boughtTokens[.dogecoin] == TokenLot(count: 6, cost: price * 6))
        #expect(game.averageCost(of: .dogecoin) == price) // The loss isn't a dearer price.
        // Selling the rest at the price paid loses only the fee: the casino's losses aren't trading's.
        let sale = game.sellTokens(.dogecoin, quantity: 6, at: noon)
        let net = try #require(sale)
        #expect(game.recentTrades.last?.profit == net - price * 6)
        #expect(game.boughtTokens.isEmpty)
    }

    @Test func aStakeThatComesBackIsStillBought() {
        let price = Market.price(.dogecoin, at: noon)
        var game = GameState.make(coins: price * 10)
        game.buyTokens(.dogecoin, quantity: 10, at: noon)
        playHand(&game, .dogecoin, bet: 10, payout: 10) // A push.
        #expect(game.boughtTokens[.dogecoin] == TokenLot(count: 10, cost: price * 10))
        // A round cut short by the app closing is refunded the same way.
        #expect(game.placeBlackjackBet(.dogecoin, amount: 6) == true)
        #expect(game.tokenCount(.dogecoin) == 4 && game.boughtTokens[.dogecoin]?.count == 10)
        game.refundBlackjackStake()
        #expect(game.boughtTokens[.dogecoin] == TokenLot(count: 10, cost: price * 10))
        // Slots, which bet and pay in one go, settle at once.
        // Slots, which bet and pay in one go, settle at once: a spin's losses come out of what
        // was won first, so the bought ones only ever fall to what's held.
        var rng = SystemRandomNumberGenerator()
        var bought = 10
        for _ in 0..<300 where game.tokenCount(.dogecoin) > 0 {
            guard game.spinSlots(.dogecoin, bet: 1, using: &rng) != nil else { break }
            bought = min(bought, game.tokenCount(.dogecoin))
            #expect((game.boughtTokens[.dogecoin]?.count ?? 0) == bought)
            #expect(game.averageCost(of: .dogecoin) == (bought > 0 ? price : nil))
        }
    }

    @Test func boughtTokensWaitForARoundStillInTheAir() throws {
        let price = Market.price(.dogecoin, at: noon)
        var game = GameState.make(coins: price * 10)
        game.buyTokens(.dogecoin, quantity: 10, at: noon)
        var rng = SystemRandomNumberGenerator()
        #expect(game.launchMoon(.dogecoin, bet: 5, autoCashOut: nil, using: &rng) == true)
        playHand(&game, .dogecoin, bet: 5, payout: 0) // Another game loses the other 5 meanwhile.
        #expect(game.tokenCount(.dogecoin) == 0 && game.boughtTokens[.dogecoin]?.count == 10)
        // Saved and loaded mid-flight, the 5 in the air are still bought.
        let loaded = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(loaded.boughtTokens[.dogecoin] == TokenLot(count: 5, cost: price * 5))
        game.refundMoonRound()
        #expect(game.boughtTokens[.dogecoin] == TokenLot(count: 5, cost: price * 5))
        // A flight that crashes takes them.
        #expect(game.launchMoon(.dogecoin, bet: 5, autoCashOut: nil, using: &rng) == true)
        game.settleMoon(after: 1e6)
        #expect(game.tokenCount(.dogecoin) == 0 && game.boughtTokens.isEmpty)
    }

    @Test func whatTokensCostIsSavedAndOlderSavesCountTheirsAsWon() throws {
        let price = Market.price(.dogecoin, at: noon)
        var game = GameState.make(coins: price * 10)
        game.buyTokens(.dogecoin, quantity: 10, at: noon)
        game.giveTokens(.bitcoin, amount: 2)
        let data = try GameCoding.encoder().encode(game)
        let loaded = try GameCoding.decoder().decode(GameState.self, from: data)
        #expect(loaded.boughtTokens == game.boughtTokens)
        // An older save, or a broken or impossible entry, has none: nothing is guessed.
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["boughtTokens"] = nil
        let old = try GameCoding.decoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.boughtTokens.isEmpty && old.tokenCount(.dogecoin) == 10)
        #expect(old.salePreview(of: .dogecoin, quantity: 10, at: noon).profit == nil)
        json["boughtTokens"] = ["dogecoin": ["count": 40, "cost": price * 40], "bitcoin": ["count": 2, "cost": -5],
                                "monero": ["count": 3, "cost": 100]]
        let odd = try GameCoding.decoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(odd.boughtTokens == [.dogecoin: TokenLot(count: 10, cost: price * 10)])
    }

    @Test func theTradeHistoryKeepsTheLatestFiftyAndIsSaved() throws {
        var game = GameState.make(coins: 1e15)
        for index in 0..<60 {
            game.buyTokens(.shibaInu, quantity: index + 1, at: noon.addingTimeInterval(Double(index)))
        }
        #expect(game.recentTrades.count == Tuning.tradeHistoryLimit)
        #expect(game.recentTrades.first?.quantity == 11 && game.recentTrades.last?.quantity == 60)
        let loaded = try GameCoding.decoder().decode(GameState.self, from: GameCoding.encoder().encode(game))
        #expect(loaded.recentTrades == game.recentTrades)
        // An older save has none.
        var json = try JSONSerialization.jsonObject(with: GameCoding.encoder().encode(game)) as! [String: Any]
        json["recentTrades"] = nil
        let old = try GameCoding.decoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.recentTrades.isEmpty)
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
        #expect(TokenID.tether.priceRange == Tuning.stablePriceRange) // Not the moderate tokens' range.
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
