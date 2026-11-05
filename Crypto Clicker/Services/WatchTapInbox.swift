import Foundation
import CryptoClickerKit

/// Watch tap batches that have arrived but are not in the saved game yet.
///
/// WatchConnectivity treats a transfer as delivered as soon as the delegate callback returns,
/// so each batch is written to disk inside that callback. It is removed only after the game
/// that includes it has been saved; batch ids make applying one twice harmless.
final class WatchTapInbox: @unchecked Sendable {
    private let url = URL.applicationSupportDirectory
        .appending(path: "CryptoClicker", directoryHint: .isDirectory)
        .appending(path: "watch-inbox.json", directoryHint: .notDirectory)
    private let lock = NSLock()

    func append(_ batch: WatchTapBatch) {
        lock.withLock {
            var batches = read()
            guard !batches.contains(where: { $0.id == batch.id }) else { return }
            batches.append(batch)
            write(batches)
        }
    }

    func pending() -> [WatchTapBatch] {
        lock.withLock { read() }
    }

    func remove(_ ids: Set<UUID>) {
        lock.withLock { write(read().filter { !ids.contains($0.id) }) }
    }

    private func read() -> [WatchTapBatch] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? GameCoding.decoder().decode([WatchTapBatch].self, from: data)) ?? []
    }

    private func write(_ batches: [WatchTapBatch]) {
        guard !batches.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        guard let data = try? GameCoding.encoder().encode(batches) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // No file protection: batches must be writable even before the first unlock after a restart.
        try? data.write(to: url, options: [.atomic, .noFileProtection])
    }
}
