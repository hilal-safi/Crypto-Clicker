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
        if let state = try? GameCoding.decoder().decode(GameState.self, from: data) { return .loaded(state) }
        guard setsAsideUnreadable else { return .unreadable(backup: url) }
        // Not a game this version can read: set it aside, never deleted, and let the player decide.
        let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(Int(now.timeIntervalSince1970)).json")
        guard (try? FileManager.default.moveItem(at: url, to: backup)) != nil else { return .unavailable }
        return .unreadable(backup: backup)
    }

    /// Tries a set-aside save again: if it reads now, it goes back into place and is returned.
    public func restore(from backup: URL) -> GameState? {
        guard let data = try? Data(contentsOf: backup),
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
