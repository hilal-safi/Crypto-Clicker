import Foundation

/// Reads and writes the game as one small JSON file. Writes are atomic, so a crash mid-save can
/// never leave a half-written file. The app keeps it in Application Support; tests use a folder of
/// their own.
public struct SaveStore: Sendable {
    public enum LoadResult: Equatable, Sendable {
        case loaded(GameState)
        /// First launch: there is no save yet.
        case missing
        /// A save exists but can't be read yet, because iOS launched the app in the background
        /// before the device was first unlocked. It must not be overwritten.
        case unavailable
        /// A save exists but isn't a game this version can read (it's damaged). It has been moved
        /// aside to `backup`, untouched, so the player can be told and it can be tried again.
        case unreadable(backup: URL)
        /// A save exists but a newer version of the game made it (`version`, its save version).
        /// It's left exactly where it is, unread: this version would drop what it doesn't know
        /// the next time it saved.
        case newerVersion(Int)
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Reads the save. A damaged one is moved aside (never deleted) unless `setsAsideUnreadable` is
    /// false, for a quick look from outside the app (Siri) that must change nothing.
    public func load(setsAsideUnreadable: Bool = true, now: Date = .now) -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return .missing }
        guard let data = try? Data(contentsOf: url) else { return .unavailable }
        if let version = Self.newerVersion(of: data) { return .newerVersion(version) }
        if let state = try? GameCoding.decoder().decode(GameState.self, from: data) { return .loaded(state) }
        guard setsAsideUnreadable else { return .unreadable(backup: url) }
        // Not a game this version can read: set it aside, never deleted, and let the player decide.
        let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(Int(now.timeIntervalSince1970)).json")
        guard (try? FileManager.default.moveItem(at: url, to: backup)) != nil else { return .unavailable }
        return .unreadable(backup: backup)
    }

    /// The save version of a save made by a newer version of the game than this one, or nil.
    static func newerVersion(of data: Data) -> Int? {
        struct Header: Decodable { let version: Int? }
        guard let version = (try? GameCoding.decoder().decode(Header.self, from: data))?.version,
              version > GameState.saveVersion else { return nil }
        return version
    }

    /// Moves a save from a newer version of the game aside (never deleted, under a name that says
    /// so), so a new game can start without saving over it. Returns where it went.
    public func setAsideNewerSave(now: Date = .now) -> URL? {
        guard let data = try? Data(contentsOf: url), let version = Self.newerVersion(of: data) else { return nil }
        let aside = url.deletingPathExtension()
            .appendingPathExtension("version-\(version)-\(Int(now.timeIntervalSince1970)).json")
        guard (try? FileManager.default.moveItem(at: url, to: aside)) != nil else { return nil }
        return aside
    }

    /// Tries a set-aside save again: if it reads now, it goes back into place and is returned.
    /// One from a newer version of the game stays where it is.
    public func restore(from backup: URL) -> GameState? {
        guard let data = try? Data(contentsOf: backup), Self.newerVersion(of: data) == nil,
              let state = try? GameCoding.decoder().decode(GameState.self, from: data) else { return nil }
        try? FileManager.default.removeItem(at: url)
        guard (try? FileManager.default.moveItem(at: backup, to: url)) != nil else { return nil }
        return state
    }

    public func save(_ state: GameState) throws {
        let data = try GameCoding.encoder().encode(state)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
