import Foundation

/// To the Moon: a bet rides a rocket whose multiplier climbs from 1.00×, doubling every few
/// seconds (or growing fivefold on the 5× rocket), until the market crashes. Cashing out before
/// the crash pays the bet times the multiplier; staying on through the crash loses the bet.
///
/// Where a flight crashes is drawn when the bet is placed. The draw is fair in a simple way: the
/// chance of a flight reaching any multiplier `m` is 97% ÷ `m` (95% ÷ `m` on the 5× rocket), so
/// aiming for 1.5×, 2× or 100× returns 97% of the bet on average. That leaves no strategy that
/// beats the house, and none that loses faster than another. About 4% of flights crash at 1.00×
/// before they can be cashed out (about 6% on the 5× rocket).
public enum MoonFlight {
    /// The multiplier grows by the rocket's factor every this many seconds.
    public static let doublingTime: TimeInterval = 5
    /// No flight goes higher.
    public static let maxMultiplier = 1_000.0
    /// What a bet returns on average on the 2× rocket, whatever the cash-out.
    public static let returnToPlayer = MoonRocket.doubling.returnToPlayer
    /// Automatic cash-out targets the player can pick.
    public static let autoCashOutChoices: [Double] = [1.5, 2, 3, 5, 10, 25, 100]

    /// The multiplier `seconds` after launch, in hundredths rounded down: 1.00 at launch.
    public static func multiplier(after seconds: TimeInterval, rocket: MoonRocket = .doubling) -> Double {
        guard seconds.isFinite, seconds > 0 else { return 1 }
        return hundredths(pow(rocket.growth, seconds / doublingTime))
    }

    /// Seconds after launch at which the multiplier reaches `multiplier`.
    public static func time(toReach multiplier: Double, rocket: MoonRocket = .doubling) -> TimeInterval {
        guard multiplier.isFinite, multiplier > 1 else { return 0 }
        return log(min(multiplier, maxMultiplier)) / log(rocket.growth) * doublingTime
    }

    /// Where a flight crashes, from a uniform roll in 0..<1.
    public static func crashPoint(roll: Double, rocket: MoonRocket = .doubling) -> Double {
        let roll = roll.isFinite ? min(max(roll, 0), 0.999_999_999) : 0
        let point = rocket.returnToPlayer / (1 - roll)
        return point < 1 ? 1 : hundredths(point)
    }

    /// The chance a flight reaches `multiplier` (in hundredths).
    public static func chance(ofReaching multiplier: Double, rocket: MoonRocket = .doubling) -> Double {
        guard multiplier > 1 else { return 1 }
        return min(1, rocket.returnToPlayer / multiplier)
    }

    /// Rounds down to hundredths, from 1.00 to `maxMultiplier`. The small nudge keeps values such as
    /// 2.0000000001 or 1.9999999999 (from `pow`) on the right side of a hundredth.
    static func hundredths(_ value: Double) -> Double {
        guard value.isFinite else { return maxMultiplier }
        return min(max((value * 100 + 1e-7).rounded(.down) / 100, 1), maxMultiplier)
    }
}

/// The rocket a flight rides. The 5× rocket climbs much faster and crashes a little more often
/// (it returns 95% of the tokens bet, not 97%), and its cash-outs pay a bigger coin bonus.
public enum MoonRocket: String, Codable, CaseIterable, Sendable, Identifiable {
    case doubling, fivefold

    public var id: String { rawValue }

    /// The multiplier grows by this factor every `MoonFlight.doublingTime` seconds.
    public var growth: Double {
        switch self {
        case .doubling: 2
        case .fivefold: 5
        }
    }

    /// What a bet returns on average, whatever the cash-out.
    public var returnToPlayer: Double {
        switch self {
        case .doubling: 0.97
        case .fivefold: 0.95
        }
    }

    /// The coin bonus of a cash-out, relative to the 2× rocket's.
    public var bonusFactor: Double {
        switch self {
        case .doubling: 1
        case .fivefold: Tuning.moonFivefoldBonus
        }
    }

    public var name: String {
        switch self {
        case .doubling: localized("2× Rocket")
        case .fivefold: localized("5× Rocket")
        }
    }

    /// The picker's short label.
    public var shortName: String {
        switch self {
        case .doubling: "2×"
        case .fivefold: "5×"
        }
    }
}

/// A To the Moon bet in flight. The bet is taken at launch and the flight is saved with the game,
/// so a flight cut short by the app closing is refunded on the next launch.
public struct MoonRound: Codable, Equatable, Sendable {
    public let token: TokenID
    public let bet: Int
    /// The multiplier at which this flight crashes (1.00 crashes at once).
    public let crashPoint: Double
    /// Cash out automatically on reaching this multiplier, if it gets there.
    public let autoCashOut: Double?
    /// The rocket it rides (flights saved before the 5× rocket rode the 2× one).
    public let rocket: MoonRocket

    public init(token: TokenID, bet: Int, crashPoint: Double, autoCashOut: Double?, rocket: MoonRocket = .doubling) {
        self.token = token
        self.bet = bet
        self.crashPoint = crashPoint
        self.autoCashOut = autoCashOut
        self.rocket = rocket
    }

    private enum CodingKeys: String, CodingKey {
        case token, bet, crashPoint, autoCashOut, rocket
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decode(TokenID.self, forKey: .token)
        bet = try c.decode(Int.self, forKey: .bet)
        crashPoint = try c.decode(Double.self, forKey: .crashPoint)
        autoCashOut = try c.decodeIfPresent(Double.self, forKey: .autoCashOut)
        rocket = c.value(.rocket, default: .doubling)
    }

    /// The multiplier `seconds` after launch on this flight's rocket.
    public func multiplier(after seconds: TimeInterval) -> Double {
        MoonFlight.multiplier(after: seconds, rocket: rocket)
    }

    /// Seconds after launch at which this flight's rocket reaches `multiplier`.
    public func time(toReach multiplier: Double) -> TimeInterval {
        MoonFlight.time(toReach: multiplier, rocket: rocket)
    }

    /// Where the flight stands `seconds` after launch. The automatic cash-out is checked first, so
    /// a target equal to the crash point still pays.
    public func state(after seconds: TimeInterval) -> MoonState {
        let multiplier = multiplier(after: seconds)
        if let target = autoCashOut, target <= crashPoint, multiplier >= target {
            return .autoCashedOut(multiplier: target)
        }
        if multiplier >= crashPoint { return .crashed(at: crashPoint) }
        return .flying(multiplier: multiplier)
    }

    /// How the flight ends if it's ended `seconds` after launch, without the wallet: a cash-out at
    /// the moment's multiplier while it's flying, the automatic cash-out, or the crash; no coin
    /// bonus. Practice flights end this way; `GameState.settleMoon` pays the same ending.
    public func outcome(after seconds: TimeInterval) -> MoonResult {
        switch state(after: seconds) {
        case .flying(let multiplier), .autoCashedOut(let multiplier):
            MoonResult(token: token, bet: bet, cashedOutAt: multiplier, crashPoint: crashPoint,
                       tokensWon: tokensWon(at: multiplier), bonus: 0, rocket: rocket)
        case .crashed:
            MoonResult(token: token, bet: bet, cashedOutAt: nil, crashPoint: crashPoint, tokensWon: 0, bonus: 0, rocket: rocket)
        }
    }

    /// Tokens a cash-out at `multiplier` pays: the bet times the multiplier, rounded down to whole
    /// tokens and kept within a 32-bit count.
    public func tokensWon(at multiplier: Double) -> Int {
        guard multiplier.isFinite, multiplier > 0 else { return 0 }
        return Int(min((Double(bet) * multiplier).rounded(.down), Double(Int32.max)))
    }
}

/// Where a flight stands at a moment.
public enum MoonState: Equatable, Sendable {
    case flying(multiplier: Double)
    /// Reached the automatic cash-out.
    case autoCashedOut(multiplier: Double)
    case crashed(at: Double)
}

/// How a To the Moon flight ended.
public struct MoonResult: Equatable, Sendable {
    public let token: TokenID
    public let bet: Int
    /// The multiplier cashed out at, or `nil` after a crash.
    public let cashedOutAt: Double?
    public let crashPoint: Double
    /// Tokens paid back: the bet times the multiplier, in whole tokens.
    public let tokensWon: Int
    /// Coins paid on top of a win.
    public internal(set) var bonus: Double
    public var rocket = MoonRocket.doubling

    public var isWin: Bool { cashedOutAt != nil }
}
