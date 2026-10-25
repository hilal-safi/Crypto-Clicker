import Foundation
import CryptoClickerKit

/// Reads and writes the game as one small JSON file in Application Support.
/// Writes are atomic, so a crash mid-save can never leave a half-written file.
struct SaveStore {
    enum LoadResult {
        case loaded(GameState)
        /// First launch: there is no save yet.
        case missing
        /// A save exists but can't be read yet, because iOS launched the app in the background
        /// before the device was first unlocked. It must not be overwritten.
        case unavailable
    }

    let url: URL

    init() {
        let base = URL.applicationSupportDirectory.appending(path: "CryptoClicker", directoryHint: .isDirectory)
        url = base.appending(path: "game.json", directoryHint: .notDirectory)
    }

    func load() -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return .missing }
        guard let data = try? Data(contentsOf: url) else { return .unavailable }
        if let state = try? GameCoding.decoder().decode(GameState.self, from: data) { return .loaded(state) }
        // Not a game at all: set it aside (so it can still be recovered by hand) and start over.
        let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: backup)
        return .missing
    }

    func save(_ state: GameState) throws {
        let data = try GameCoding.encoder().encode(state)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
