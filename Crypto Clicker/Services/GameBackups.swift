import Foundation
import CryptoClickerKit

/// Copies of the game kept as files, so progress survives a lost iPhone, a reinstall or a mistake,
/// without needing iCloud in the app:
///
/// - On this iPhone, in the app's own folder (On My iPhone › Crypto Clicker › Backups in the Files
///   app): the latest copy, refreshed every ten minutes or so while playing and whenever the app
///   leaves the screen, and one copy a day for the last week. The iPhone's own backup (iCloud or a
///   computer) includes them.
/// - Optionally, in a folder the player picks in Files (iCloud Drive, another app's storage, a
///   drive), kept up to date the same way. The player grants that folder once; the app keeps a
///   bookmark to it.
///
/// Every copy is `SaveTransfer`'s, so Apple Health's data never goes in one, and an automatic copy
/// never replaces one in the picked folder that another device made further on.
@MainActor
final class GameBackups {
    /// A backup file, with what it holds.
    struct Entry: Identifiable, Equatable {
        let url: URL
        let header: SaveTransfer.Header
        /// Made on this iPhone (this install).
        let isFromThisDevice: Bool
        var id: URL { url }
    }

    /// What happened to the last copy for the picked folder.
    enum FolderStatus: Equatable {
        case none
        case backedUp(Date)
        /// The folder has a copy from another device that's further on: left alone.
        case newerElsewhere
        /// The folder couldn't be reached or written (moved, deleted, or offline).
        case failed(String)
    }

    static let folderFileName = "Crypto Clicker Backup.json"
    private static let latestFileName = "Latest.json"
    private static let dailyKept = 7
    private static let interval: TimeInterval = 600

    /// This install's id, so a copy made on another device can be told apart.
    let deviceID: String
    private var lastBackup = Date.distantPast
    private(set) var folderStatus = FolderStatus.none
    private(set) var lastLocalBackup: Date?

    init() {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: Preferences.backupDeviceKey) {
            deviceID = saved
        } else {
            deviceID = UUID().uuidString
            defaults.set(deviceID, forKey: Preferences.backupDeviceKey)
        }
        lastLocalBackup = Self.modified(localFolder.appending(path: Self.latestFileName))
    }

    /// Backups/ in the app's Documents folder, which the Files app shows.
    var localFolder: URL {
        URL.documentsDirectory.appending(path: "Backups", directoryHint: .isDirectory)
    }

    // MARK: Backing up

    /// Copies `game`: at most every ten minutes, unless `force` (leaving the app, an import).
    func backUp(_ game: GameState, force: Bool = false) {
        let now = Date.now
        guard force || now.timeIntervalSince(lastBackup) >= Self.interval,
              let data = try? SaveTransfer.data(of: game, device: deviceID) else { return }
        lastBackup = now
        writeLocal(data, at: now)
        writeToFolder(data, game: game, at: now)
    }

    /// The latest copy, and the day's own copy the first time the day backs up; then only the
    /// latest week of daily copies is kept.
    private func writeLocal(_ data: Data, at now: Date) {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: localFolder, withIntermediateDirectories: true)
            try data.write(to: localFolder.appending(path: Self.latestFileName), options: .atomic)
            let daily = localFolder.appending(path: "\(StepDay.key(for: now)).json")
            if !manager.fileExists(atPath: daily.path(percentEncoded: false)) {
                try data.write(to: daily, options: .atomic)
            }
            let days = try manager.contentsOfDirectory(at: localFolder, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent != Self.latestFileName && $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in days.dropFirst(Self.dailyKept) { try? manager.removeItem(at: old) }
            lastLocalBackup = now
        } catch {
            // Nothing to do but try again next time: the game's own save is untouched.
        }
    }

    // MARK: The picked folder

    /// The folder the player picked for backups, if they did and it can still be found.
    var pickedFolder: URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: Preferences.backupFolderKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale { remember(url) }
        return url
    }

    /// Where the picked folder is, for Settings: "iCloud Drive › Games".
    var pickedFolderName: String? {
        pickedFolder.map { $0.lastPathComponent }
    }

    /// Keeps `folder` (picked in Files) for backups, and backs up there now.
    func useFolder(_ folder: URL, for game: GameState) {
        remember(folder)
        backUp(game, force: true)
    }

    /// Stops backing up to the picked folder (the copies already there stay).
    func forgetFolder() {
        UserDefaults.standard.removeObject(forKey: Preferences.backupFolderKey)
        folderStatus = .none
    }

    private func remember(_ folder: URL) {
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        if let bookmark = try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: Preferences.backupFolderKey)
        }
    }

    private func writeToFolder(_ data: Data, game: GameState, at now: Date) {
        guard let folder = pickedFolder else { return }
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        let file = folder.appending(path: Self.folderFileName)
        // Never over a copy another device made further on.
        if let existing = Self.read(file), existing.device != nil, existing.device != deviceID,
           existing.lifetimeCoins > game.stats.lifetimeCoins {
            folderStatus = .newerElsewhere
            return
        }
        var problem: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &coordinationError) { url in
            do { try data.write(to: url, options: .atomic) } catch { problem = error }
        }
        if let failure = problem ?? coordinationError {
            folderStatus = .failed(failure.localizedDescription)
        } else {
            folderStatus = .backedUp(now)
        }
    }

    // MARK: Reading backups

    /// Every backup, newest first: the picked folder's, then this iPhone's latest and daily copies.
    func entries() -> [Entry] {
        var urls: [URL] = []
        if let folder = pickedFolder {
            urls.append(folder.appending(path: Self.folderFileName))
        }
        let local = (try? FileManager.default.contentsOfDirectory(at: localFolder, includingPropertiesForKeys: nil)) ?? []
        urls += local.filter { $0.pathExtension == "json" }
        let folder = pickedFolder
        let isScoped = folder?.startAccessingSecurityScopedResource() ?? false
        defer { if isScoped { folder?.stopAccessingSecurityScopedResource() } }
        return urls.compactMap { url in
            Self.read(url).map { Entry(url: url, header: $0, isFromThisDevice: $0.device == deviceID) }
        }
        .sorted { $0.header.savedAt > $1.header.savedAt }
    }

    /// The game in a backup.
    func game(in entry: Entry) throws -> GameState {
        let folder = pickedFolder
        let isScoped = folder?.startAccessingSecurityScopedResource() ?? false
        defer { if isScoped { folder?.stopAccessingSecurityScopedResource() } }
        return try SaveTransfer.game(from: Data(contentsOf: entry.url))
    }

    private static func read(_ url: URL) -> SaveTransfer.Header? {
        var data: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            data = try? Data(contentsOf: url)
        }
        return data.flatMap(SaveTransfer.header(of:))
    }

    private static func modified(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
