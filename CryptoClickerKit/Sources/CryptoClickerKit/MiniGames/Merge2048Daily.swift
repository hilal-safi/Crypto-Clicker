import Foundation

extension Merge2048Game {
    /// Scores that earn the daily puzzle's stars, in `dailyMoves` moves.
    public static let dailyStarScores = [1_400, 1_700, 2_000]

    /// Stars a daily puzzle score earns (0 to 3).
    public static func dailyStars(score: Int) -> Int {
        dailyStarScores.filter { score >= $0 }.count
    }

    /// The day this game's puzzle belongs to, for a daily game.
    public var day: String? {
        if case .daily(let day) = mode { day } else { nil }
    }
}

/// The day's 2048 puzzle: the best result today and the stars already paid for it, saved with
/// the game. Kept through prestiges.
public struct Merge2048DailyProgress: Codable, Equatable, Sendable {
    /// The day the best score and stars belong to.
    public internal(set) var day: String?
    public internal(set) var bestScore = 0
    public internal(set) var stars = 0
    /// Days with at least one star, and every star earned.
    public internal(set) var wins = 0
    public internal(set) var totalStars = 0

    public init() {}

    public func stars(on day: String) -> Int { self.day == day ? stars : 0 }

    public func bestScore(on day: String) -> Int { self.day == day ? bestScore : 0 }

    /// Records a finished puzzle; returns the stars earned for the first time today.
    mutating func record(day: String, score: Int, stars earned: Int) -> Int {
        if self.day != day {
            self.day = day
            bestScore = 0
            stars = 0
        }
        let before = stars
        bestScore = max(bestScore, score)
        stars = max(stars, min(3, max(0, earned)))
        if before == 0 && stars > 0 { wins += 1 }
        totalStars += stars - before
        return stars - before
    }

    private enum CodingKeys: String, CodingKey { case day, bestScore, stars, wins, totalStars }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = c.value(.day, default: nil)
        bestScore = max(0, c.value(.bestScore, default: 0))
        stars = min(3, max(0, c.value(.stars, default: 0)))
        wins = max(0, c.value(.wins, default: 0))
        totalStars = max(0, c.value(.totalStars, default: 0))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(day, forKey: .day)
        try c.encode(bestScore, forKey: .bestScore)
        try c.encode(stars, forKey: .stars)
        try c.encode(wins, forKey: .wins)
        try c.encode(totalStars, forKey: .totalStars)
    }
}

/// What a finished daily 2048 puzzle earned.
public struct Merge2048DailyPayout: Equatable, Sendable {
    /// Stars this game earned, and how many were new today (and paid).
    public let stars: Int
    public let newStars: Int
    /// Coins for the new stars, included in `payout.coins`.
    public let starCoins: Double
    public let payout: ArcadePayout
}
