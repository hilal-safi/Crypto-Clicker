import Foundation
import CryptoClickerKit

/// Copies of the game kept as files, so progress survives a mistake, a lost phone or a reinstall
/// (iOS: GameBackups):
///
/// - On this phone, in Backups/ beside the save (which Android's backup to the player's Google
///   account includes, when that's on): the latest copy, refreshed every ten minutes or so while
///   playing and whenever the app leaves the screen, and one copy a day for the last week.
/// - Snapshots, beside them: the game as it was just before a restore or a reset replaced it, and
///   the backup folder's copy just before the player replaced it, so none of those can lose a
///   game. The latest ten are kept.
/// - Optionally, in a folder the player picks (on the phone, a memory card or a cloud drive). The
///   app holds the permission to it, so it writes the copy there: it asks for one here
///   (`folderData`), which only ever replaces an earlier copy of the same game
///   (`SaveTransfer.conflict`) unless the player chooses to.
///
/// Every copy is `SaveTransfer`'s, so Health Connect's steps never go in one.
final class SessionBackups {
    /// A backup file on this phone, with what it holds and where it is.
    struct Entry: Equatable {
        let url: URL
        let header: SaveTransfer.Header
        let place: Place
        /// Made on this phone.
        let isFromThisDevice: Bool
    }

    enum Place: Equatable {
        case latest, daily
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

    /// The file the copy in the picked folder is kept in.
    static let folderFileName = "Crypto Clicker Backup.json"
    private static let latestFileName = "Latest.json"
    private static let dailyKept = 7
    private static let snapshotsKept = 10
    private static let interval: TimeInterval = 600

    let folder: URL
    var snapshotFolder: URL { folder.appendingPathComponent("Snapshots", isDirectory: true) }
    /// This phone's id, so a copy made on another device can be told apart.
    let deviceID: String
    private var lastBackup = Date.distantPast
    private(set) var lastLocalBackup: Date?

    /// The picked folder as the app last read it: its name (nil while none is picked), and the
    /// copy in it (nil when it has none).
    private(set) var folderName: String?
    private(set) var folderCopy: Data?
    private(set) var folderStatus = FolderStatus.none
    /// The copy last handed to the app for the folder, which is the folder's once it's written.
    private var folderDataOut: Data?
    /// The backups on this phone, as last listed (the Backup page lists them when it opens and
    /// after each change, not on every redraw).
    private var listed: [Entry]?

    init(folder: URL, deviceID: String) {
        self.folder = folder
        self.deviceID = deviceID
        lastLocalBackup = Self.modified(folder.appendingPathComponent(Self.latestFileName))
    }

    // MARK: Backing up

    /// Copies `game`: at most every ten minutes, unless `force` (leaving the app, an import).
    func backUp(_ game: GameState, force: Bool = false, at now: Date) {
        guard force || now.timeIntervalSince(lastBackup) >= Self.interval,
              let data = try? SaveTransfer.data(of: game, device: deviceID) else { return }
        lastBackup = now
        writeLocal(data, at: now)
    }

    /// The latest copy, and the day's own copy the first time the day backs up; then only the
    /// latest week of daily copies is kept.
    private func writeLocal(_ data: Data, at now: Date) {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent(Self.latestFileName), options: .atomic)
            let daily = folder.appendingPathComponent("\(StepDay.key(for: now)).json")
            if !manager.fileExists(atPath: daily.path) {
                try data.write(to: daily, options: .atomic)
            }
            // Only the dated copies: Latest.json stays, and the snapshots are in their own folder.
            let days = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent != Self.latestFileName && $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in days.dropFirst(Self.dailyKept) { try? manager.removeItem(at: old) }
            lastLocalBackup = now
            listed = nil
        } catch {
            // Nothing to do but try again next time: the game's own save is untouched.
        }
    }

    // MARK: Snapshots

    /// Keeps `game` as it is now, before a restore or a reset replaces it. A game with nothing in
    /// it yet isn't worth one.
    func snapshot(_ game: GameState, before reason: SnapshotReason, at now: Date) {
        guard game.stats.lifetimeCoins > 0 || game.stats.prestiges > 0,
              let data = try? SaveTransfer.data(of: game, device: deviceID) else { return }
        keep(data, before: reason, at: now)
    }

    /// Keeps a copy (as `SaveTransfer` wrote it) in the snapshots; only the latest ten stay.
    @discardableResult
    func keep(_ data: Data, before reason: SnapshotReason, at now: Date) -> Bool {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: snapshotFolder, withIntermediateDirectories: true)
            let file = snapshotFolder.appendingPathComponent("\(Self.stamp(now)) before \(reason.rawValue).json")
            try data.write(to: file, options: .atomic)
            let snapshots = try manager.contentsOfDirectory(at: snapshotFolder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in snapshots.dropFirst(Self.snapshotsKept) { try? manager.removeItem(at: old) }
            listed = nil
            return true
        } catch {
            return false
        }
    }

    /// "2026-11-26 14.03.22": sorts by time, and reads well in a file list.
    private static func stamp(_ date: Date) -> String {
        let parts = StepDay.calendar().dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func padded(_ value: Int?, _ width: Int = 2) -> String {
            let text = String(max(0, value ?? 0))
            return String(repeating: "0", count: max(0, width - text.count)) + text
        }
        return "\(padded(parts.year, 4))-\(padded(parts.month))-\(padded(parts.day)) "
            + "\(padded(parts.hour)).\(padded(parts.minute)).\(padded(parts.second))"
    }

    // MARK: The picked folder

    /// What the app found in the picked folder: its name, and the copy there (nil for none).
    /// Without a name, no folder is picked.
    func useFolder(named name: String?, copy: Data?) {
        if name == nil || name != folderName { folderStatus = .none }
        folderName = name
        folderCopy = name == nil ? nil : copy
    }

    /// The copy to write to the picked folder, which holds `existing` now (nil for none), for
    /// `game`. Nil when the copy there mustn't be replaced by itself (the status says why), or the
    /// player chose to replace it (`replacing`) and it couldn't be kept as a snapshot first.
    func folderData(for game: GameState, existing: Data?, replacing: Bool, at now: Date) -> Data? {
        folderCopy = existing
        if replacing, let existing, !keep(existing, before: .folderCopy, at: now) {
            folderStatus = .failed("The copy there couldn't be kept first, so it wasn't replaced.")
            return nil
        }
        // Only over an earlier copy of this game, unless the player chose to replace it.
        if !replacing, let existing, let header = SaveTransfer.header(of: existing),
           let conflict = SaveTransfer.conflict(replacing: header, with: game, device: deviceID) {
            folderStatus = .conflict(conflict, header)
            return nil
        }
        let data = try? SaveTransfer.data(of: game, device: deviceID)
        folderDataOut = data
        return data
    }

    /// What became of the copy the app was given for the folder.
    func folderWritten(_ written: Bool, problem: String?, at now: Date) {
        if written {
            folderStatus = .backedUp(now)
            if let data = folderDataOut { folderCopy = data }
        } else {
            folderStatus = .failed(problem ?? "The folder couldn't be reached.")
        }
        folderDataOut = nil
    }

    /// The copy in the picked folder, as an entry to restore, when there's a readable one.
    var folderEntry: SaveTransfer.Header? {
        folderCopy.flatMap(SaveTransfer.header(of:))
    }

    /// Why the folder's copy mustn't be replaced by `game` by itself; nil if it may be (or there's none).
    func folderConflict(with game: GameState) -> SaveTransfer.Conflict? {
        guard folderName != nil, let header = folderEntry else { return nil }
        return SaveTransfer.conflict(replacing: header, with: game, device: deviceID)
    }

    // MARK: Reading backups

    /// Every backup on this phone, newest first: the latest and daily copies, and the snapshots.
    func entries() -> [Entry] {
        if let listed { return listed }
        var urls: [(URL, Place)] = []
        let manager = FileManager.default
        let local = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        urls += local.filter { $0.pathExtension == "json" }
            .map { ($0, $0.lastPathComponent == Self.latestFileName ? Place.latest : Place.daily) }
        let snapshots = (try? manager.contentsOfDirectory(at: snapshotFolder, includingPropertiesForKeys: nil)) ?? []
        for url in snapshots where url.pathExtension == "json" {
            let name = url.deletingPathExtension().lastPathComponent
            let reason = SnapshotReason.allCases.first { name.hasSuffix("before \($0.rawValue)") } ?? .restore
            urls.append((url, .snapshot(reason)))
        }
        var found: [Entry] = []
        for (url, place) in urls {
            guard let header = Self.read(url) else { continue }
            found.append(Entry(url: url, header: header, place: place, isFromThisDevice: header.device == deviceID))
        }
        found.sort { $0.header.savedAt > $1.header.savedAt }
        listed = found
        return found
    }

    /// Lists the backups again when next asked.
    func relist() {
        listed = nil
    }

    /// The game in a backup on this phone.
    func game(in entry: Entry) throws -> GameState {
        guard let data = try? Data(contentsOf: entry.url) else { throw SaveTransfer.ReadError.unreadable }
        return try SaveTransfer.game(from: data)
    }

    /// An entry's id for the app: its folder and file name.
    static func id(of entry: Entry) -> String {
        switch entry.place {
        case .snapshot: "snapshot/\(entry.url.lastPathComponent)"
        case .latest, .daily: "local/\(entry.url.lastPathComponent)"
        }
    }

    private static func read(_ url: URL) -> SaveTransfer.Header? {
        (try? Data(contentsOf: url)).flatMap(SaveTransfer.header(of:))
    }

    private static func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}

/// A copy of a game waiting to replace the one here, and where it's from: "this backup", "this
/// save file", "the backup folder's copy".
struct PendingCopy {
    let game: GameState
    let source: String
}

// MARK: - The Backup page

/// Settings › Backup and Save Files (view "backup"; iOS: BackupView).
struct BackupPageView: Encodable {
    /// When the latest copy on this phone was made (seconds since 1970), or nil before the first.
    let lastBackup: Double?
    /// The backups to restore, newest first: the folder's copy, then this phone's.
    let entries: [BackupEntryView]
    /// The picked folder, when there is one.
    let folder: BackupFolderView?
    /// A copy waiting for the player to confirm it replaces the game here.
    let pending: PendingCopyView?
    /// Why a save file or a backup couldn't be opened.
    let problem: String?
}

struct BackupEntryView: Encodable {
    /// What restores it (`backup.restore`).
    let id: String
    /// When the game in it was last played (seconds since 1970).
    let savedAt: Double
    /// "Latest on this phone", "Daily copy", "Before a reset"…
    let place: String
    /// "12.3M coins mined · 2 prestiges"
    let holds: String
    let fromAnotherDevice: Bool
}

struct BackupFolderView: Encodable {
    let name: String
    /// When the app last wrote the copy there (seconds since 1970).
    let backedUpAt: Double?
    /// Why the last copy couldn't be written.
    let failure: String?
    /// Why the copy there isn't replaced by the game here by itself, when it isn't.
    let conflict: BackupConflictView?
}

/// Why a backup isn't replaced (iOS: ConflictNote): "furtherOn", "otherGame" or "newerVersion",
/// with what the copy holds and when it was made.
struct BackupConflictView: Encodable {
    let kind: String
    /// "12.3M coins mined, 2 prestiges"
    let holds: String
    let savedAt: Double
}

/// A copy waiting to replace the game here (iOS: PendingCopy).
struct PendingCopyView: Encodable {
    /// "this backup", "this save file"
    let source: String
    /// When the game in it was last played (seconds since 1970).
    let savedAt: Double
    /// "12.3M coins mined, 2 prestiges"
    let holds: String
}

extension GameSession {
    var backupPageView: BackupPageView {
        let game = state
        var entries: [BackupEntryView] = []
        if backups.folderName != nil, let header = backups.folderEntry {
            entries.append(BackupEntryView(id: "folder", savedAt: header.savedAt.timeIntervalSince1970, place: "Backup folder",
                                           holds: holdsLine(header, separator: " · "),
                                           fromAnotherDevice: header.device != nil && header.device != backups.deviceID))
        }
        entries += backups.entries().map { entry in
            BackupEntryView(id: SessionBackups.id(of: entry), savedAt: entry.header.savedAt.timeIntervalSince1970,
                            place: placeName(entry.place), holds: holdsLine(entry.header, separator: " · "),
                            fromAnotherDevice: !entry.isFromThisDevice && entry.header.device != nil)
        }
        var folder: BackupFolderView?
        if let name = backups.folderName {
            var backedUpAt: Double?
            var failure: String?
            var conflict = backups.folderConflict(with: game).flatMap { kind in
                backups.folderEntry.map { conflictView(kind, $0) }
            }
            switch backups.folderStatus {
            case .backedUp(let date): backedUpAt = date.timeIntervalSince1970
            case .failed(let reason): failure = reason
            case .conflict(let kind, let header): conflict = conflict ?? conflictView(kind, header)
            case .none: break
            }
            folder = BackupFolderView(name: name, backedUpAt: conflict == nil ? backedUpAt : nil, failure: failure,
                                      conflict: conflict)
        }
        return BackupPageView(
            lastBackup: backups.lastLocalBackup?.timeIntervalSince1970, entries: entries, folder: folder,
            pending: pendingCopy.map { copy -> PendingCopyView in
                let summary = SaveTransfer.Summary(of: copy.game)
                return PendingCopyView(source: copy.source, savedAt: summary.savedAt.timeIntervalSince1970,
                                       holds: "\(CoinFormat.short(summary.lifetimeCoins)) coins mined, \(prestigesText(summary.prestiges))")
            },
            problem: backupProblem)
    }

    private func conflictView(_ conflict: SaveTransfer.Conflict, _ header: SaveTransfer.Header) -> BackupConflictView {
        let kind = switch conflict {
        case .furtherOn: "furtherOn"
        case .otherGame: "otherGame"
        case .newerVersion: "newerVersion"
        }
        return BackupConflictView(kind: kind, holds: holdsLine(header, separator: ", "), savedAt: header.savedAt.timeIntervalSince1970)
    }

    private func holdsLine(_ header: SaveTransfer.Header, separator: String) -> String {
        "\(CoinFormat.short(header.lifetimeCoins)) coins mined\(separator)\(prestigesText(header.prestiges))"
    }

    private func prestigesText(_ count: Int) -> String {
        count == 1 ? "1 prestige" : "\(CoinFormat.grouped(count)) prestiges"
    }

    private func placeName(_ place: SessionBackups.Place) -> String {
        switch place {
        case .latest: "Latest on this phone"
        case .daily: "Daily copy"
        case .snapshot(.restore): "Before a restore"
        case .snapshot(.reset): "Before a reset"
        case .snapshot(.folderCopy): "Folder copy, replaced"
        }
    }

    // MARK: Actions

    /// Backs up now (Back Up Now), and lists the backups again.
    func backUpNow() {
        backups.backUp(state, force: true, at: now)
        backups.relist()
        publish()
    }

    /// The game as a save file to export: JSON, without Health Connect's data.
    func saveFileData() -> String? {
        (try? SaveTransfer.data(of: state)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// A save file the player picked to import: waits for them to confirm it replaces the game.
    func readSaveFile(_ text: String) {
        openCopy(source: "this save file") { try SaveTransfer.game(from: Data(text.utf8)) }
    }

    /// A backup the player picked to restore: waits for them to confirm it replaces the game.
    func restoreBackup(_ id: String) {
        if id == "folder" {
            openCopy(source: "the backup folder's copy") {
                guard let data = backups.folderCopy else { throw SaveTransfer.ReadError.unreadable }
                return try SaveTransfer.game(from: data)
            }
            return
        }
        guard let entry = backups.entries().first(where: { SessionBackups.id(of: $0) == id }) else {
            backupProblem = "That backup is no longer there."
            publish()
            return
        }
        openCopy(source: "this backup") { try backups.game(in: entry) }
    }

    private func openCopy(source: String, read: () throws -> GameState) {
        do {
            pendingCopy = PendingCopy(game: try read(), source: source)
            backupProblem = nil
        } catch {
            pendingCopy = nil
            backupProblem = Self.explanation(of: error)
        }
        publish()
    }

    /// The player confirmed: the copy waiting replaces the game here.
    func confirmPendingCopy() {
        guard let copy = pendingCopy else { return }
        pendingCopy = nil
        importGame(copy.game)
        backups.relist()
        publish()
    }

    /// Puts away the copy waiting, or the problem shown.
    func dismissPendingCopy() {
        guard pendingCopy != nil || backupProblem != nil else { return }
        pendingCopy = nil
        backupProblem = nil
        publish()
    }

    /// What the app read from the picked folder (when the Backup page opens, or a folder is
    /// picked): its name, or nil when none is picked, and the copy in it.
    func inspectBackupFolder(name: String?, copy: String?) {
        backups.useFolder(named: name, copy: copy.map { Data($0.utf8) })
        backups.relist()
        publish()
    }

    /// The copy to write to the picked folder (`name`), which holds `existing` now. `replacing`:
    /// the player chose to replace a copy there that isn't an earlier one of this game.
    func backupFolderData(name: String?, existing: String?, replacing: Bool) -> String? {
        let copy = existing.map { Data($0.utf8) }
        backups.useFolder(named: name, copy: copy)
        let data = backups.folderData(for: state, existing: copy, replacing: replacing, at: now)
        publish()
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    /// What became of the copy written to the folder.
    func backupFolderWritten(_ written: Bool, problem: String?) {
        backups.folderWritten(written, problem: problem, at: now)
        backups.relist()
        publish()
    }

    static func explanation(of error: Error) -> String {
        switch error as? SaveTransfer.ReadError {
        case .newerVersion: "It was saved by a newer version of Crypto Clicker. Update the app, then try again."
        case .unreadable: "It isn't a Crypto Clicker save, or it's damaged."
        case nil: error.localizedDescription
        }
    }
}
