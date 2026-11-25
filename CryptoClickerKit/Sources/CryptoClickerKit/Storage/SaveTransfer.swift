import Foundation

/// A copy of a game for keeping it safe or moving it between devices: the automatic backups, and
/// the file the player exports and imports in Settings. Apple Health's data stays behind (the step
/// ledger and the step counts in the statistics: Health data mustn't leave the device in a file
/// that could end up in iCloud Drive), as do the numbers that pair the game with one watch.
public enum SaveTransfer {
    public enum ReadError: Error, Equatable {
        /// Not a Crypto Clicker save, or a damaged one.
        case unreadable
        /// Saved by a newer version of the game, which this one could read only in part.
        case newerVersion
    }

    /// What a copy holds, to show before it replaces the game on this device.
    public struct Summary: Equatable, Sendable {
        /// When the game it was copied from was last played.
        public let savedAt: Date
        public let lifetimeCoins: Double
        public let prestiges: Int
        public let prestigePoints: Int
        public let totalMiners: Int

        public init(of game: GameState) {
            savedAt = game.lastUpdate
            lifetimeCoins = game.stats.lifetimeCoins
            prestiges = game.stats.prestiges
            prestigePoints = game.prestigePoints
            totalMiners = game.totalMiners
        }
    }

    /// What a copy says about itself, read without the whole game: enough to list backups and to
    /// tell one made on another device.
    public struct Header: Equatable, Sendable {
        public let version: Int
        /// When the game it was copied from was last played.
        public let savedAt: Date
        public let lifetimeCoins: Double
        public let prestiges: Int
        /// The device that made it, when it says (`data(of:device:)`).
        public let device: String?
    }

    /// `game` without its Health and watch data, as JSON, marked with the device that made it
    /// when `device` is given (a key the game itself ignores).
    public static func data(of game: GameState, device: String? = nil) throws -> Data {
        let json = try GameCoding.encoder().encode(game.withoutDeviceData)
        guard let device, json.count > 2, json.first == UInt8(ascii: "{"),
              let mark = try? GameCoding.encoder().encode([deviceKey: device]) else { return json }
        // {"transferDevice":"…"} and the game's own keys, in one object.
        return mark.dropLast() + Data(",".utf8) + json.dropFirst()
    }

    /// The key a copy's device is kept under.
    static let deviceKey = "transferDevice"

    /// What a copy says about itself, or nil for anything that isn't a readable save.
    public static func header(of data: Data) -> Header? {
        struct Stats: Decodable {
            let lifetimeCoins: Double?
            let forksPerformed: Int?
        }
        struct Raw: Decodable {
            let version: Int?
            let lastUpdate: Date?
            let stats: Stats?
            let transferDevice: String?
        }
        guard let raw = try? GameCoding.decoder().decode(Raw.self, from: data), let savedAt = raw.lastUpdate else { return nil }
        return Header(version: raw.version ?? 1, savedAt: savedAt, lifetimeCoins: raw.stats?.lifetimeCoins ?? 0,
                      prestiges: raw.stats?.forksPerformed ?? 0, device: raw.transferDevice)
    }

    /// The game in a copy. Throws `ReadError.newerVersion` for a copy from a newer version of the
    /// game, and `ReadError.unreadable` for anything that isn't a readable save.
    public static func game(from data: Data) throws -> GameState {
        struct Header: Decodable {
            let version: Int?
            let lastUpdate: Date?
        }
        // Every save has its version and the time it was last played; anything else isn't one.
        guard let header = try? GameCoding.decoder().decode(Header.self, from: data), header.lastUpdate != nil else {
            throw ReadError.unreadable
        }
        if (header.version ?? 1) > GameState.saveVersion { throw ReadError.newerVersion }
        guard let game = try? GameCoding.decoder().decode(GameState.self, from: data) else { throw ReadError.unreadable }
        return game
    }
}

extension GameState {
    /// This game without what belongs to the device it's on: Apple Health's steps (the ledger and
    /// the step counts in the statistics) and the watch's tap batch numbers.
    var withoutDeviceData: GameState {
        var copy = self
        copy.steps = StepLedger()
        copy.stats.lifetimeSteps = 0
        copy.stats.bestDaySteps = 0
        copy.stats.bestWeekSteps = 0
        copy.recentWatchBatches = []
        copy.watchSequences = [:]
        return copy
    }

    /// `copy` (from `SaveTransfer`) carried on in place of this game. This device keeps its Apple
    /// Health ledger, so no day's steps are paid twice, and its step counts and watch pairing; the
    /// clock starts now, so an import never pays for time away.
    public func continuing(with copy: GameState, at now: Date) -> GameState {
        var game = copy
        game.steps = steps
        game.stats.lifetimeSteps = max(stats.lifetimeSteps, copy.stats.lifetimeSteps)
        game.stats.bestDaySteps = max(stats.bestDaySteps, copy.stats.bestDaySteps)
        game.stats.bestWeekSteps = max(stats.bestWeekSteps, copy.stats.bestWeekSteps)
        game.recentWatchBatches = recentWatchBatches
        game.watchSequences = watchSequences
        game.lastUpdate = now
        return game
    }
}
