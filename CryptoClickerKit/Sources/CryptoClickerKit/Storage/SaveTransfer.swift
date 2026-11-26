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

    /// What a copy says about itself, read without the whole game: enough to list backups, to
    /// tell one made on another device, and to tell which game it is and how far on.
    public struct Header: Equatable, Sendable {
        public let version: Int
        /// When the game it was copied from was last played.
        public let savedAt: Date
        public let lifetimeCoins: Double
        public let prestiges: Int
        /// The device that made it, when it says (`data(of:device:)`).
        public let device: String?
        /// Which game it is and how many times that game had been saved (`GameState.gameID`,
        /// `GameState.revision`): nil for a copy from before games had ids.
        public let lineage: SaveLineage?

        public init(version: Int = GameState.saveVersion, savedAt: Date, lifetimeCoins: Double, prestiges: Int,
                    device: String?, lineage: SaveLineage?) {
            self.version = version
            self.savedAt = savedAt
            self.lifetimeCoins = lifetimeCoins
            self.prestiges = prestiges
            self.device = device
            self.lineage = lineage
        }

        /// What a copy of `game` made now on `device` says.
        public init(of game: GameState, device: String?) {
            self.init(savedAt: game.lastUpdate, lifetimeCoins: game.stats.lifetimeCoins, prestiges: game.stats.prestiges,
                      device: device, lineage: game.lineage)
        }
    }

    /// Why a backup of a game must not replace the copy already where it goes.
    public enum Conflict: Equatable, Sendable {
        /// The copy there is of this game, but further on: played since on another device, or
        /// this game was carried on from an older copy of it.
        case furtherOn
        /// The copy there is of another game: one played on another device, or the game here
        /// before it was reset or replaced by a copy of another.
        case otherGame
        /// The copy there was made by a newer version of the game, which this one would lose
        /// part of.
        case newerVersion
    }

    /// Whether a backup of `game` made on `device` may replace `existing`, the copy already where
    /// it goes (a picked folder, iCloud): nil when it may, else why not. A backup only replaces an
    /// earlier copy of the same game, or the copy (or an earlier one of the same game) it was
    /// carried on from, or a game with nothing in it; anything else waits for the player, so no
    /// copy with progress is ever replaced without them choosing to.
    public static func conflict(replacing existing: Header?, with game: GameState, device: String) -> Conflict? {
        guard let existing else { return nil }
        if existing.version > GameState.saveVersion { return .newerVersion }
        if existing.lifetimeCoins <= 0 && existing.prestiges == 0 { return nil }
        guard let lineage = existing.lineage else {
            // A copy from before games had ids: what it mined is all there is to go on.
            return existing.lifetimeCoins <= game.stats.lifetimeCoins ? nil : .furtherOn
        }
        if lineage.gameID == game.gameID {
            guard lineage.revision <= game.revision else { return .furtherOn }
            // The same game saved on another device too (the iPhone itself was copied to a new
            // one): only if this one has mined as much.
            if let other = existing.device, other != device, existing.lifetimeCoins > game.stats.lifetimeCoins {
                return .furtherOn
            }
            return nil
        }
        if let origin = game.copiedFrom, origin.gameID == lineage.gameID {
            return lineage.revision <= origin.revision ? nil : .furtherOn
        }
        return .otherGame
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
            let gameID: UUID?
            let revision: Int?
        }
        guard let raw = try? GameCoding.decoder().decode(Raw.self, from: data), let savedAt = raw.lastUpdate else { return nil }
        return Header(version: raw.version ?? 1, savedAt: savedAt, lifetimeCoins: raw.stats?.lifetimeCoins ?? 0,
                      prestiges: raw.stats?.forksPerformed ?? 0, device: raw.transferDevice,
                      lineage: raw.gameID.map { SaveLineage(gameID: $0, revision: max(0, raw.revision ?? 0)) })
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
    /// Counts a save, before it's written, so every copy says how far on the game is.
    public mutating func countSave() {
        revision = revision.addingCount(1)
    }

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
    /// clock starts now, so an import never pays for time away. It goes on as a game of its own,
    /// remembering the copy it came from (`copiedFrom`), so its backups replace that copy and
    /// earlier ones of it, never a copy of the same game that went on further somewhere else.
    public func continuing(with copy: GameState, at now: Date) -> GameState {
        var game = copy
        game.gameID = UUID()
        game.copiedFrom = copy.lineage
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
