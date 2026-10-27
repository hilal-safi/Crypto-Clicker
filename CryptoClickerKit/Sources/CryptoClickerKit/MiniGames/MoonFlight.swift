import Foundation

/// To the Moon: a bet rides a rocket whose multiplier climbs from 1.00×, doubling every few
/// seconds, until the market crashes. Cashing out before the crash pays the bet times the
/// multiplier; staying on through the crash loses the bet.
///
/// Where a flight crashes is drawn when the bet is placed. The draw is fair in a simple way: the
/// chance of a flight reaching any multiplier `m` is 97% ÷ `m`, so aiming for 1.5×, 2× or 100×
/// returns 97% of the bet on average. That leaves no strategy that beats the house, and none that
/// loses faster than another. About 4% of flights crash at 1.00×, before they can be cashed out.
public enum MoonFlight {
    /// The multiplier doubles every this many seconds.
    public static let doublingTime: TimeInterval = 5
    /// No flight goes higher.
    public static let maxMultiplier = 1_000.0
    /// What a bet returns on average, whatever the cash-out.
    public static let returnToPlayer = 0.97
    /// Automatic cash-out targets the player can pick.
    public static let autoCashOutChoices: [Double] = [1.5, 2, 3, 5, 10, 25, 100]

    /// The multiplier `seconds` after launch, in hundredths rounded down: 1.00 at launch.
    public static func multiplier(after seconds: TimeInterval) -> Double {
        guard seconds.isFinite, seconds > 0 else { return 1 }
        return hundredths(pow(2, seconds / doublingTime))
    }

    /// Seconds after launch at which the multiplier reaches `multiplier`.
    public static func time(toReach multiplier: Double) -> TimeInterval {
        guard multiplier.isFinite, multiplier > 1 else { return 0 }
        return log2(min(multiplier, maxMultiplier)) * doublingTime
    }

    /// Where a flight crashes, from a uniform roll in 0..<1.
    public static func crashPoint(roll: Double) -> Double {
        let roll = roll.isFinite ? min(max(roll, 0), 0.999_999_999) : 0
        let point = returnToPlayer / (1 - roll)
        return point < 1 ? 1 : hundredths(point)
    }

    /// The chance a flight reaches `multiplier` (in hundredths).
    public static func chance(ofReaching multiplier: Double) -> Double {
        guard multiplier > 1 else { return 1 }
        return min(1, returnToPlayer / multiplier)
    }

    /// Rounds down to hundredths, from 1.00 to `maxMultiplier`. The small nudge keeps values such as
    /// 2.0000000001 or 1.9999999999 (from `pow`) on the right side of a hundredth.
    static func hundredths(_ value: Double) -> Double {
        guard value.isFinite else { return maxMultiplier }
        return min(max((value * 100 + 1e-7).rounded(.down) / 100, 1), maxMultiplier)
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
    public let bonus: Double

    public var isWin: Bool { cashedOutAt != nil }
}
