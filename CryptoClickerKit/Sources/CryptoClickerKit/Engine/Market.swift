import Foundation

/// A story that moved a token's price.
public struct MarketNews: Equatable, Sendable, Identifiable {
    public let token: TokenID
    /// When the news broke.
    public let date: Date
    /// Good news pushes the price up; bad news pulls it down.
    public let isGood: Bool
    public let headline: String

    public var id: String { "\(token.rawValue)@\(Int64(date.timeIntervalSince1970))" }
}

/// Token prices in the Shop's Tokens page. Each price follows two slow waves, some gentle noise and the
/// occasional news story, all worked out from the clock: every device sees the same market, nothing
/// needs saving, and the past can be charted. Prices stay within the token's `priceRange` of its
/// list price and move once per `Tuning.marketTick`.
public enum Market {
    /// Ticks in a day.
    public static let ticksPerDay = Int(86_400 / Tuning.marketTick)

    /// The tick that contains `date`: prices change when it does.
    public static func tick(at date: Date) -> Int64 {
        let value = (date.timeIntervalSince1970 / Tuning.marketTick).rounded(.down)
        return value.isFinite ? Int64(max(0, min(value, 1e15))) : 0 // Int64, not Int: 32 bits on the watch.
    }

    /// When `tick` starts.
    static func date(ofTick tick: Int64) -> Date {
        Date(timeIntervalSince1970: Double(tick) * Tuning.marketTick)
    }

    /// The token's price as a multiple of its list price.
    public static func priceFactor(_ token: TokenID, at date: Date) -> Double {
        factor(token, tick: tick(at: date))
    }

    /// The price of one token at `date`, in whole coins.
    public static func price(_ token: TokenID, at date: Date) -> Double {
        GameState.wholePrice(token.price * priceFactor(token, at: date))
    }

    /// How much the price moved over the last day, as a share (0.1 = up 10%).
    public static func dayChange(_ token: TokenID, at date: Date) -> Double {
        let now = tick(at: date)
        return factor(token, tick: now) / factor(token, tick: now - Int64(ticksPerDay)) - 1
    }

    /// Price factors for a chart: `points` values evenly spread over the `span` before `date`,
    /// oldest first, ending with the current price.
    public static func history(_ token: TokenID, endingAt date: Date, span: TimeInterval = 86_400,
                               points: Int = 48) -> [Double] {
        guard points > 1 else { return [priceFactor(token, at: date)] }
        let end = tick(at: date)
        let spanTicks = max(1, span / Tuning.marketTick)
        return (0..<points).map { index in
            let back = spanTicks * Double(points - 1 - index) / Double(points - 1)
            return factor(token, tick: end - Int64(back.rounded()))
        }
    }

    /// News from the `span` before `date`, newest first.
    public static func news(before date: Date, span: TimeInterval = 86_400) -> [MarketNews] {
        let end = tick(at: date)
        let count = Int64(max(1, span / Tuning.marketTick))
        var stories: [MarketNews] = []
        for back in 0..<count {
            let start = end - back
            for token in TokenID.allCases {
                guard let event = newsEvent(token, startingAt: start) else { continue }
                stories.append(MarketNews(token: token, date: Self.date(ofTick: start), isGood: event.strength > 0,
                                          headline: headline(token, isGood: event.strength > 0, hash: event.hash)))
            }
        }
        return stories
    }

    // MARK: Model

    /// The price factor at `tick`: waves and noise scaled by the token's volatility, plus news.
    static func factor(_ token: TokenID, tick: Int64) -> Double {
        let seed = StableHash.of("market-" + token.rawValue)
        let t = Double(tick)
        // A slow wave of two to six days and a faster one of eight to twenty hours, different per token.
        let slowPeriod = Double(2 * ticksPerDay) + Double(seed % UInt64(4 * ticksPerDay))
        let fastPeriod = 96 + Double((seed >> 20) % 145)
        let slowPhase = StableHash.unit(StableHash.mix(seed, 1)) * 2 * .pi
        let fastPhase = StableHash.unit(StableHash.mix(seed, 2)) * 2 * .pi
        var logFactor = 0.55 * sin(2 * .pi * t / slowPeriod + slowPhase)
            + 0.25 * sin(2 * .pi * t / fastPeriod + fastPhase)
            + 0.2 * noise(seed, at: t / 12) // New random values every hour, blended smoothly.
        if token.volatilityLevel == .volatile {
            // Volatile tokens also jump about from one ten-minute stretch to the next.
            logFactor += Tuning.volatileJitter * noise(StableHash.mix(seed, 3), at: t / 2)
        }
        logFactor *= token.volatility
        logFactor += newsEffect(token, tick: tick)
        let range = token.priceRange
        return min(max(exp(logFactor), range.lowerBound), range.upperBound)
    }

    /// Smooth noise in -1...1: random values at whole numbers, eased in between.
    static func noise(_ seed: UInt64, at x: Double) -> Double {
        let left = x.rounded(.down)
        let blend = x - left
        let eased = blend * blend * (3 - 2 * blend)
        let a = StableHash.unit(StableHash.mix(seed, UInt64(bitPattern: Int64(left)))) * 2 - 1
        let b = StableHash.unit(StableHash.mix(seed, UInt64(bitPattern: Int64(left) + 1))) * 2 - 1
        return a + (b - a) * eased
    }

    /// News that broke for `token` at `start`, if any: its strength (in log terms; positive is good
    /// news), how many ticks it lasts, and a hash for picking a headline.
    static func newsEvent(_ token: TokenID, startingAt start: Int64) -> (strength: Double, ticks: Int, hash: UInt64)? {
        let hash = StableHash.mix(StableHash.of("news-" + token.rawValue), UInt64(bitPattern: start))
        guard StableHash.unit(hash) < Tuning.marketNewsChance else { return nil }
        let detail = StableHash.mix(hash, 7)
        let sign: Double = detail & 1 == 0 ? 1 : -1
        let range = Tuning.marketNewsStrength
        let strength = sign * (range.lowerBound + (range.upperBound - range.lowerBound) * StableHash.unit(detail >> 1))
        let shortest = Tuning.marketNewsTicks / 3
        let ticks = shortest + Int(StableHash.mix(detail, 3) % UInt64(Tuning.marketNewsTicks - shortest + 1))
        return (strength, ticks, detail)
    }

    /// The combined pull of recent news at `tick`: each story moves the price at once, then fades.
    static func newsEffect(_ token: TokenID, tick: Int64) -> Double {
        var effect = 0.0
        for age in 0..<Tuning.marketNewsTicks {
            guard let event = newsEvent(token, startingAt: tick - Int64(age)), age < event.ticks else { continue }
            effect += event.strength * (1 - Double(age) / Double(event.ticks))
        }
        return effect * token.newsWeight
    }

    static func headline(_ token: TokenID, isGood: Bool, hash: UInt64) -> String {
        let name = token.name
        if token == .tether {
            let stable = isGood
                ? [localized("Tether holds its peg through a busy day"), localized("Tether reserves pass another audit"), localized("Traders park their gains in Tether")]
                : [localized("Tether wobbles off its peg for a moment"), localized("Questions about Tether's reserves resurface"), localized("Tether dips a fraction of a cent")]
            return stable[Int((hash >> 8) % UInt64(stable.count))]
        }
        let good = [
            localized("\(name) soars after a celebrity post"),
            localized("A major exchange lists \(name)"),
            localized("Whales are buying \(name)"),
            localized("\(name) network upgrade goes live"),
            localized("\(name) trends worldwide"),
        ]
        let bad = [
            localized("\(name) slips during an exchange outage"),
            localized("Regulators take a closer look at \(name)"),
            localized("Whales dump \(name)"),
            localized("\(name) network stalls for an hour"),
            localized("Rumours shake \(name) holders"),
        ]
        let headlines = isGood ? good : bad
        return headlines[Int((hash >> 8) % UInt64(headlines.count))]
    }
}

extension TokenID {
    /// How far the price swings, at most about this share either way before news: the volatile
    /// meme coins swing the most (and jump about too), Bitcoin least, and Tether, a stablecoin,
    /// hardly at all. The others drift rather than jump.
    var volatility: Double {
        switch self {
        case .safeMoon: 0.42
        case .shibaInu: 0.36
        case .tether: 0.006
        case .dogecoin: 0.33
        case .xrp: 0.20
        case .bnb: 0.17
        case .monero: 0.19
        case .cardano: 0.20
        case .solana: 0.18
        case .ethereum: 0.15
        case .bitcoin: 0.12
        }
    }

    /// How much the price moves, in a word for the Tokens page: Tether is stable, the meme coins
    /// (SafeMoon, Shiba Inu, Dogecoin) volatile, and the rest in between.
    public var volatilityLevel: TokenVolatility {
        switch volatility {
        case ..<0.05: .stable
        case ..<0.21: .moderate
        default: .volatile
        }
    }

    /// Where the price stays, as a share of the list price: wider for volatile tokens, and within a
    /// couple of percent for a stablecoin.
    public var priceRange: ClosedRange<Double> {
        switch volatilityLevel {
        case .stable: Tuning.stablePriceRange
        case .moderate: Tuning.marketPriceRange
        case .volatile: Tuning.volatilePriceRange
        }
    }

    /// How hard news moves the price: a stablecoin holds its peg through almost anything.
    var newsWeight: Double {
        self == .tether ? 0.05 : 1
    }
}

extension GameState {
    // MARK: Trading

    /// Coins `quantity` tokens cost at the market price at `date`.
    public func price(of token: TokenID, quantity: Int, at date: Date) -> Double {
        Market.price(token, at: date) * Double(max(0, quantity))
    }

    /// Coins selling `quantity` tokens at `date` would pay, after the market's fee.
    public func saleValue(of token: TokenID, quantity: Int, at date: Date) -> Double {
        Self.wholeCoins(price(of: token, quantity: quantity, at: date) * marketSellRate)
    }

    /// How many tokens the balance can buy at `date`.
    public func maxAffordableTokens(_ token: TokenID, at date: Date) -> Int {
        let unit = Market.price(token, at: date)
        guard unit > 0, coins.isFinite else { return 0 }
        return Int(min((coins / unit).rounded(.down), 1e9)) // Fits a 32-bit Int on Apple Watch.
    }

    @discardableResult
    public mutating func buyTokens(_ token: TokenID, quantity: Int, at date: Date) -> Bool {
        let cost = price(of: token, quantity: quantity, at: date)
        guard quantity > 0, cost.isFinite, cost <= coins else { return false }
        spend(cost)
        giveTokens(token, amount: quantity)
        let lot = boughtTokens[token] ?? TokenLot(count: 0, cost: 0)
        boughtTokens[token] = TokenLot(count: lot.count.addingCount(quantity), cost: Self.finite(lot.cost + cost))
        stats.tokensBought[token] = stats.tokensBought[token, default: 0].addingCount(quantity)
        stats.tokensBoughtWithPrice[token] = stats.tokensBoughtWithPrice[token, default: 0].addingCount(quantity)
        stats.coinsSpentOnTokens[token] = Self.finite(stats.coinsSpentOnTokens[token, default: 0] + cost)
        record(TokenTrade(date: date, token: token, quantity: quantity, coins: cost))
        return true
    }

    /// Sells tokens at the market price, less the fee. The coins go back into the balance without
    /// counting as mined, so trading can't inflate prestige. Bought tokens are sold first, each
    /// with its share of what they cost (`boughtTokens`), which is what the sale is measured
    /// against. Returns the coins received.
    @discardableResult
    public mutating func sellTokens(_ token: TokenID, quantity: Int, at date: Date) -> Double? {
        guard quantity > 0, tokenCount(token) >= quantity else { return nil }
        let preview = salePreview(of: token, quantity: quantity, at: date)
        let value = preview.net
        if let lot = boughtTokens[token] { boughtTokens[token] = lot.removing(preview.bought) }
        tokens[token] = tokenCount(token) - quantity
        settleBoughtTokens(token)
        coins += value
        stats.tokensSold += quantity
        stats.coinsFromSales += value
        if let profit = preview.profit {
            stats.tradingProfit = Self.finite(stats.tradingProfit + profit)
            if profit > 0 {
                stats.profitableSales += 1
                stats.bestSaleProfit = Self.finite(max(stats.bestSaleProfit, profit))
            }
        }
        record(TokenTrade(date: date, token: token, quantity: -quantity, coins: value, profit: preview.profit))
        return value
    }

    /// What selling `quantity` tokens at `date` comes to, before it's done: their worth at the
    /// market price, the fee, what's left, and how many of them were bought (sold first) and what
    /// those cost.
    public func salePreview(of token: TokenID, quantity: Int, at date: Date) -> SalePreview {
        let count = max(0, min(quantity, tokenCount(token)))
        let worth = Self.wholeCoins(price(of: token, quantity: count, at: date))
        let net = saleValue(of: token, quantity: count, at: date)
        let bought = min(count, boughtCount(token))
        let paid = averageCost(of: token).map { $0 * Double(bought) }
        return SalePreview(worth: worth, fee: max(0, worth - net), net: net, count: count, bought: bought, paid: paid)
    }

    /// What each bought token of a kind held cost on average (`boughtTokens`). Nil when none held
    /// was bought.
    public func averageCost(of token: TokenID) -> Double? {
        guard boughtCount(token) > 0, let lot = boughtTokens[token], lot.cost > 0, lot.cost.isFinite else { return nil }
        return lot.averageCost
    }

    /// The wallet against what was paid for it, at `date`: every token held at the market price,
    /// and the bought ones against what they cost.
    public func portfolio(at date: Date) -> Portfolio {
        var worth = 0.0, paid = 0.0, worthOfPaid = 0.0
        for token in TokenID.allCases {
            let count = tokenCount(token)
            guard count > 0 else { continue }
            worth += price(of: token, quantity: count, at: date)
            if let average = averageCost(of: token) {
                let bought = boughtCount(token)
                paid += average * Double(bought)
                worthOfPaid += price(of: token, quantity: bought, at: date)
            }
        }
        return Portfolio(worth: Self.finite(worth), paid: Self.finite(paid), worthOfPaid: Self.finite(worthOfPaid))
    }

    /// Adds a trade to the history, dropping the oldest past `Tuning.tradeHistoryLimit`.
    private mutating func record(_ trade: TokenTrade) {
        recentTrades.append(trade)
        if recentTrades.count > Tuning.tradeHistoryLimit {
            recentTrades.removeFirst(recentTrades.count - Tuning.tradeHistoryLimit)
        }
    }
}

/// A trade on the market, for the Tokens page's history.
public struct TokenTrade: Codable, Hashable, Sendable, Identifiable {
    public let date: Date
    public let token: TokenID
    /// Tokens bought, or (below zero) sold.
    public let quantity: Int
    /// Coins paid for a purchase, or received for a sale after the fee.
    public let coins: Double
    /// For a sale: what the bought tokens in it made (or lost) against what they cost, when any
    /// was bought.
    public let profit: Double?

    public var isSale: Bool { quantity < 0 }
    public var id: String { "\(date.timeIntervalSinceReferenceDate)|\(token.rawValue)|\(quantity)" }

    public init(date: Date, token: TokenID, quantity: Int, coins: Double, profit: Double? = nil) {
        self.date = date
        self.token = token
        self.quantity = quantity
        self.coins = coins
        self.profit = profit
    }
}

/// What a sale comes to before it's made: the tokens' worth at the market price, the fee taken
/// from it, the coins left, and how the bought ones among them (sold first) compare with what
/// they cost.
public struct SalePreview: Equatable, Sendable {
    public let worth: Double
    public let fee: Double
    public let net: Double
    /// The tokens sold, and how many of them were bought for coins (the rest were won or given).
    public let count: Int
    public let bought: Int
    /// What the bought ones cost: nil when none was bought.
    public let paid: Double?

    /// The coins the bought ones bring in (their share of the sale) against what they cost; nil
    /// when none was bought. Won tokens cost nothing, so they make no profit or loss.
    public var profit: Double? {
        guard let paid, bought > 0, count > 0 else { return nil }
        let share = bought >= count ? net : net * Double(bought) / Double(count)
        return share - paid
    }
}

/// What the wallet's tokens are worth, and how the ones bought for coins have done: what they
/// cost, and what they're worth now.
public struct Portfolio: Equatable, Sendable {
    /// Every token held, at the market price.
    public let worth: Double
    /// What the tokens held that were bought for coins cost (`GameState.boughtTokens`)...
    public let paid: Double
    /// ...and at the market price.
    public let worthOfPaid: Double

    /// What those tokens have gained (or lost) since they were bought.
    public var change: Double { worthOfPaid - paid }
    /// The same as a share of what was paid, or nil with nothing paid.
    public var changeShare: Double? { paid > 0 ? change / paid : nil }
}

/// How much a token's price moves, for the Tokens page.
public enum TokenVolatility: String, CaseIterable, Sendable {
    case stable, moderate, volatile

    public var name: String {
        switch self {
        case .stable: localized("Stable")
        case .moderate: localized("Moderate")
        case .volatile: localized("Volatile")
        }
    }
}
