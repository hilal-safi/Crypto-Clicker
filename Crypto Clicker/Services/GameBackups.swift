import Foundation
import CryptoClickerKit

/// Copies of the game kept as files, so progress survives a lost iPhone, a reinstall or a mistake,
/// without needing iCloud in the app:
///
/// - On this iPhone, in the app's own folder (On My iPhone › Crypto Clicker › Backups in the Files
///   app): the latest copy, refreshed every ten minutes or so while playing and whenever the app
///   leaves the screen, and one copy a day for the last week. The iPhone's own backup (iCloud or a
///   computer) includes them.
/// - Snapshots, beside them: the game as it was just before a restore or a reset replaced it, and
///   any copy in the picked folder or iCloud just before the player replaced it, so none of those
///   can lose a game. The latest ten are kept.
/// - Optionally, in a folder the player picks in Files (iCloud Drive, another app's storage, a
///   drive), kept up to date the same way. The player grants that folder once; the app keeps a
///   bookmark to it.
///
/// Every copy is `SaveTransfer`'s, so Apple Health's data never goes in one, and an automatic copy
/// only ever replaces an earlier copy of the same game in the picked folder
/// (`SaveTransfer.conflict`): a copy further on, or of another game, waits for the player.
@MainActor
final class GameBackups {
    /// A backup file, with what it holds and where it is.
    struct Entry: Identifiable, Equatable {
        let url: URL
        let header: SaveTransfer.Header
        let place: Place
        /// Made on this iPhone.
        let isFromThisDevice: Bool
        var id: URL { url }
    }

    /// Where a backup is.
    enum Place: Equatable {
        case folder, latest, daily
        /// A snapshot, and what it was taken before.
        case snapshot(SnapshotReason)
    }

    /// What a snapshot was taken before.
    enum SnapshotReason: String, CaseIterable {
        /// The game here, before a restore or an imported save replaced it.
        case restore
        /// The game here, before a reset.
        case reset
        /// The copy in the picked folder, before the game here replaced it.
        case folderCopy = "folder copy"
        /// The copy in iCloud, before the game here replaced it.
        case iCloudCopy = "iCloud copy"
    }

    /// What happened to the last copy for the picked folder.
    enum FolderStatus: Equatable {
        case none
        case backedUp(Date)
        /// The folder has a copy the game here mustn't replace by itself: left alone until the
        /// player restores it or chooses to replace it.
        case conflict(SaveTransfer.Conflict, SaveTransfer.Header)
        /// The folder couldn't be reached or written (moved, deleted, or offline).
        case failed(String)
    }

    static let folderFileName = "Crypto Clicker Backup.json"
    private static let latestFileName = "Latest.json"
    private static let dailyKept = 7
    private static let snapshotsKept = 10
    private static let interval: TimeInterval = 600

    /// This iPhone's id, so a copy made on another device can be told apart.
    let deviceID = BackupDevice.id
    private var lastBackup = Date.distantPast
    private(set) var folderStatus = FolderStatus.none
    private(set) var lastLocalBackup: Date?

    init() {
        lastLocalBackup = Self.modified(localFolder.appending(path: Self.latestFileName))
    }

    /// Backups/ in the app's Documents folder, which the Files app shows.
    var localFolder: URL {
        URL.documentsDirectory.appending(path: "Backups", directoryHint: .isDirectory)
    }

    /// Backups/Snapshots/.
    var snapshotFolder: URL {
        localFolder.appending(path: "Snapshots", directoryHint: .isDirectory)
    }

    // MARK: Backing up

    /// Copies `game`: at most every ten minutes, unless `force` (leaving the app, an import).
    /// `replacingFolderCopy` writes over the picked folder's copy whatever it holds (the player
    /// chose to, and it was kept as a snapshot first).
    func backUp(_ game: GameState, force: Bool = false, replacingFolderCopy: Bool = false) {
        let now = Date.now
        guard force || now.timeIntervalSince(lastBackup) >= Self.interval,
              let data = try? SaveTransfer.data(of: game, device: deviceID) else { return }
        lastBackup = now
        writeLocal(data, at: now)
        writeToFolder(data, game: game, replacing: replacingFolderCopy, at: now)
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
            // Only the dated copies: Latest.json stays, and the snapshots are in their own folder.
            let days = try manager.contentsOfDirectory(at: localFolder, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent != Self.latestFileName && $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in days.dropFirst(Self.dailyKept) { try? manager.removeItem(at: old) }
            lastLocalBackup = now
        } catch {
            // Nothing to do but try again next time: the game's own save is untouched.
        }
    }

    // MARK: Snapshots

    /// Keeps `game` as it is now, before a restore or a reset replaces it. A game with nothing in
    /// it yet isn't worth one.
    func snapshot(_ game: GameState, before reason: SnapshotReason) {
        guard game.stats.lifetimeCoins > 0 || game.stats.prestiges > 0,
              let data = try? SaveTransfer.data(of: game, device: deviceID) else { return }
        keep(data, before: reason)
    }

    /// Keeps a copy (as `SaveTransfer` wrote it) in the snapshots; only the latest ten stay.
    @discardableResult
    func keep(_ data: Data, before reason: SnapshotReason) -> Bool {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: snapshotFolder, withIntermediateDirectories: true)
            let file = snapshotFolder.appending(path: "\(Self.stamp(.now)) before \(reason.rawValue).json")
            try data.write(to: file, options: .atomic)
            let snapshots = try manager.contentsOfDirectory(at: snapshotFolder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in snapshots.dropFirst(Self.snapshotsKept) { try? manager.removeItem(at: old) }
            return true
        } catch {
            return false
        }
    }

    /// "2026-11-26 14.03.22": sorts by time, and reads well in Files.
    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: date)
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

    /// Keeps `folder` (picked in Files) for backups, and backs up there now (unless it already
    /// has a copy the game here mustn't replace by itself).
    func useFolder(_ folder: URL, for game: GameState) {
        remember(folder)
        backUp(game, force: true)
    }

    /// Stops backing up to the picked folder (the copies already there stay).
    func forgetFolder() {
        UserDefaults.standard.removeObject(forKey: Preferences.backupFolderKey)
        folderStatus = .none
    }

    /// Replaces the picked folder's copy with `game`, as the player chose, after keeping that copy
    /// as a snapshot. Leaves it if the snapshot can't be made.
    func replaceFolderCopy(with game: GameState) {
        if let folder = pickedFolder {
            let isScoped = folder.startAccessingSecurityScopedResource()
            defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
            if let data = Self.contents(of: folder.appending(path: Self.folderFileName)),
               !keep(data, before: .folderCopy) {
                folderStatus = .failed(String(localized: "The copy there couldn't be kept first, so it wasn't replaced."))
                return
            }
        }
        backUp(game, force: true, replacingFolderCopy: true)
    }

    /// The picked folder's copy, to restore it.
    var folderEntry: Entry? {
        guard let folder = pickedFolder else { return nil }
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        let file = folder.appending(path: Self.folderFileName)
        return Self.read(file).map { Entry(url: file, header: $0, place: .folder, isFromThisDevice: $0.device == deviceID) }
    }

    /// Why the picked folder's copy mustn't be replaced by `game` by itself, with the copy; nil if
    /// it may be (or there's none).
    func folderConflict(with game: GameState) -> FolderConflict? {
        guard let entry = folderEntry,
              let conflict = SaveTransfer.conflict(replacing: entry.header, with: game, device: deviceID) else { return nil }
        return FolderConflict(conflict: conflict, entry: entry)
    }

    /// The picked folder's copy, and why the game here doesn't replace it by itself.
    struct FolderConflict: Equatable {
        let conflict: SaveTransfer.Conflict
        let entry: Entry
    }

    private func remember(_ folder: URL) {
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        if let bookmark = try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: Preferences.backupFolderKey)
        }
    }

    private func writeToFolder(_ data: Data, game: GameState, replacing: Bool, at now: Date) {
        guard let folder = pickedFolder else { return }
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        let file = folder.appending(path: Self.folderFileName)
        // Only over an earlier copy of this game, unless the player chose to replace it.
        if !replacing, let existing = Self.read(file),
           let conflict = SaveTransfer.conflict(replacing: existing, with: game, device: deviceID) {
            folderStatus = .conflict(conflict, existing)
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

    /// Every backup, newest first: the picked folder's, this iPhone's latest and daily copies, and
    /// the snapshots.
    func entries() -> [Entry] {
        var urls: [(URL, Place)] = []
        if let folder = pickedFolder {
            urls.append((folder.appending(path: Self.folderFileName), .folder))
        }
        let manager = FileManager.default
        let local = (try? manager.contentsOfDirectory(at: localFolder, includingPropertiesForKeys: nil)) ?? []
        urls += local.filter { $0.pathExtension == "json" }
            .map { ($0, $0.lastPathComponent == Self.latestFileName ? .latest : .daily) }
        let snapshots = (try? manager.contentsOfDirectory(at: snapshotFolder, includingPropertiesForKeys: nil)) ?? []
        urls += snapshots.filter { $0.pathExtension == "json" }.map { url in
            let name = url.deletingPathExtension().lastPathComponent
            let reason = SnapshotReason.allCases.first { name.hasSuffix("before \($0.rawValue)") } ?? .restore
            return (url, .snapshot(reason))
        }
        let folder = pickedFolder
        let isScoped = folder?.startAccessingSecurityScopedResource() ?? false
        defer { if isScoped { folder?.stopAccessingSecurityScopedResource() } }
        return urls.compactMap { url, place in
            Self.read(url).map { Entry(url: url, header: $0, place: place, isFromThisDevice: $0.device == deviceID) }
        }
        .sorted { $0.header.savedAt > $1.header.savedAt }
    }

    /// The game in a backup.
    func game(in entry: Entry) throws -> GameState {
        let folder = pickedFolder
        let isScoped = folder?.startAccessingSecurityScopedResource() ?? false
        defer { if isScoped { folder?.stopAccessingSecurityScopedResource() } }
        guard let data = Self.contents(of: entry.url) else { throw SaveTransfer.ReadError.unreadable }
        return try SaveTransfer.game(from: data)
    }

    private static func read(_ url: URL) -> SaveTransfer.Header? {
        contents(of: url).flatMap(SaveTransfer.header(of:))
    }

    /// A file's contents, read in turn with anything else using it (iCloud Drive, say).
    private static func contents(of url: URL) -> Data? {
        var data: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            data = try? Data(contentsOf: url)
        }
        return data
    }

    private static func modified(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
