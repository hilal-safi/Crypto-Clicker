import Foundation

/// An airdrop on screen: what it is, and how long it stays.
public struct AirdropDrop: Equatable, Sendable, Identifiable {
    public let id: UUID
    /// Decided when it appears, so a whale looks different from the start.
    public let kind: AirdropKind
    public let expiresAt: Date
    /// How long it stays in all, for the countdown ring.
    public let lifetime: TimeInterval

    public init(id: UUID = UUID(), kind: AirdropKind, expiresAt: Date, lifetime: TimeInterval) {
        self.id = id
        self.kind = kind
        self.expiresAt = expiresAt
        self.lifetime = lifetime
    }
}

/// When airdrops fall. Each waits a few minutes after the last (less with Airdrop Radar), falls
/// once 50,000 coins have been mined, a miner is owned and no game is on screen, and stays a short
/// while. One that runs out is missed, unless a game came on screen meanwhile: games hold airdrops
/// back, so it never had its chance. The clock lives with the app session; nothing here is saved.
public struct AirdropSchedule: Equatable, Sendable {
    /// The airdrop on screen, if there is one.
    public private(set) var drop: AirdropDrop?
    /// When the next one falls (`distantFuture` until it's scheduled).
    public private(set) var nextAt: Date

    public enum Event: Equatable, Sendable {
        case appeared(AirdropDrop)
        /// It ran out; `missed` is false when a game on screen held it back.
        case expired(AirdropDrop, missed: Bool)
    }

    public init(nextAt: Date = .distantFuture) {
        self.nextAt = nextAt
    }

    /// The next one hasn't been scheduled, or its time came while the app was away.
    public func isDue(at now: Date) -> Bool {
        nextAt == .distantFuture || nextAt <= now
    }

    /// Schedules the next airdrop `roll` (0 to 1) of the way through the game's airdrop interval
    /// from `now`.
    public mutating func schedule(from now: Date, game: GameState, roll: Double) {
        let interval = game.airdropInterval
        let share = min(max(roll, 0), 1)
        nextAt = now.addingTimeInterval(interval.lowerBound + share * (interval.upperBound - interval.lowerBound))
    }

    /// Moves the clock to `now`: the airdrop on screen runs out, or the next one falls (its kind
    /// picked by `kindRoll`). When one runs out, the next is scheduled by `delayRoll`.
    public mutating func update(at now: Date, game: GameState, isInGame: Bool, kindRoll: Double, delayRoll: Double) -> Event? {
        if let drop {
            guard now >= drop.expiresAt else { return nil }
            self.drop = nil
            schedule(from: now, game: game, roll: delayRoll)
            return .expired(drop, missed: !isInGame)
        }
        guard now >= nextAt, game.areAirdropsUnlocked, !isInGame else { return nil }
        let drop = spawn(game.airdropKind(roll: kindRoll), at: now, game: game)
        return .appeared(drop)
    }

    /// Catches the airdrop on screen and schedules the next. Returns what was caught. A tap in the
    /// moment between running out and the next clock tick still counts.
    public mutating func catchDrop(at now: Date, game: GameState, roll: Double) -> AirdropDrop? {
        guard let drop else { return nil }
        self.drop = nil
        schedule(from: now, game: game, roll: roll)
        return drop
    }

    /// Takes the airdrop off screen without counting a miss (the app going to the background, a
    /// prestige or a reset).
    public mutating func clear() {
        drop = nil
    }

    /// Puts an airdrop of `kind` on screen now (the testing tools use it too).
    @discardableResult
    public mutating func spawn(_ kind: AirdropKind, at now: Date, game: GameState) -> AirdropDrop {
        let lifetime = game.airdropLifetime
        let drop = AirdropDrop(kind: kind, expiresAt: now.addingTimeInterval(lifetime), lifetime: lifetime)
        self.drop = drop
        return drop
    }
}

/// How the game greets a player coming back with coins earned while away.
public enum ReturnGreeting: Equatable, Sendable {
    /// Nothing earned worth mentioning.
    case none
    /// A short note at the top of the screen.
    case toast
    /// The welcome-back screen, with what the time away unlocked. `marksDay` says to remember
    /// today, because without Offline Mining it shows once a day.
    case welcomeBack(marksDay: Bool)

    /// Absences shorter than this get a toast instead of the welcome-back screen.
    public static let welcomeBackThreshold: TimeInterval = 5 * 60

    /// With Offline Mining every long absence gets the welcome-back screen. Without it the miners
    /// earned only a minute, so the screen (with its Offline Mining tip) shows once a day and a
    /// toast covers the other returns.
    public static func choose(for report: OfflineReport, lastWelcomeDay: String?, today: String) -> ReturnGreeting {
        guard report.earned >= 1 else { return .none }
        guard report.elapsed >= welcomeBackThreshold else { return .toast }
        if report.offlineCap > 0 { return .welcomeBack(marksDay: false) }
        return lastWelcomeDay == today ? .toast : .welcomeBack(marksDay: true)
    }
}
