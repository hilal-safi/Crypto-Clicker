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

/// Token prices on the Coin Exchange. Each price follows two slow waves, some gentle noise and the
/// occasional news story, all worked out from the clock: every device sees the same market, nothing
/// needs saving, and the past can be charted. Prices stay within `Tuning.marketPriceRange` of the
/// token's list price and move once per `Tuning.marketTick`.
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
        logFactor *= token.volatility
        logFactor += newsEffect(token, tick: tick)
        let range = Tuning.marketPriceRange
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
        let strength = sign * (0.25 + 0.35 * StableHash.unit(detail >> 1))
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
        return effect
    }

    static func headline(_ token: TokenID, isGood: Bool, hash: UInt64) -> String {
        let name = token.name
        let good = [
            "\(name) soars after a celebrity post",
            "A major exchange lists \(name)",
            "Whales are buying \(name)",
            "\(name) network upgrade goes live",
            "\(name) trends worldwide",
        ]
        let bad = [
            "\(name) slips during an exchange outage",
            "Regulators take a closer look at \(name)",
            "Whales dump \(name)",
            "\(name) network stalls for an hour",
            "Rumours shake \(name) holders",
        ]
        let headlines = isGood ? good : bad
        return headlines[Int((hash >> 8) % UInt64(headlines.count))]
    }
}

extension TokenID {
    /// How far the price swings: meme coins swing most, Bitcoin least.
    var volatility: Double {
        switch self {
        case .shibaInu: 1.0
        case .dogecoin: 0.9
        case .xrp: 0.75
        case .cardano: 0.7
        case .solana: 0.8
        case .ethereum: 0.6
        case .bitcoin: 0.5
        }
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
        tokens[token, default: 0] += quantity
        stats.tokensBought[token, default: 0] += quantity
        return true
    }

    /// Sells tokens at the market price, less the fee. The coins go back into the balance without
    /// counting as mined, so trading can't inflate prestige. Returns the coins received.
    @discardableResult
    public mutating func sellTokens(_ token: TokenID, quantity: Int, at date: Date) -> Double? {
        guard quantity > 0, tokenCount(token) >= quantity else { return nil }
        let value = saleValue(of: token, quantity: quantity, at: date)
        tokens[token] = tokenCount(token) - quantity
        coins += value
        stats.tokensSold += quantity
        stats.coinsFromSales += value
        return value
    }
}
