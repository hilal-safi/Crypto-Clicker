import Foundation
import CryptoClickerKit

/// A copy of the game in iCloud's key-value storage, so a new iPhone (or the app reinstalled) can
/// carry on. The copy is `SaveTransfer`'s: no Apple Health data goes to iCloud. Backs up at most
/// every ten minutes while saving, and whenever the app leaves the screen; only ever over an
/// earlier copy of the same game (`SaveTransfer.conflict`). A copy further on, or of another game,
/// is left for the player to restore or replace in Settings, and anything that stops a backup
/// (too big, iCloud full) is shown there too.
///
/// Needs the iCloud capability (Key-value storage) on the app, which takes a paid developer
/// account; without it, or without an iCloud account, `isAvailable` is false and nothing is backed
/// up here. The file backups (`GameBackups`) work either way.
@MainActor
final class CloudBackup {
    /// What happened to the last backup.
    enum Status: Equatable {
        case none
        case backedUp(Date)
        /// iCloud has a copy the game here mustn't replace by itself: left alone until the player
        /// restores it or chooses to replace it.
        case conflict(SaveTransfer.Conflict)
        /// The game, packed, is too big for iCloud's key-value storage (its size in bytes).
        case tooLarge(Int)
        /// iCloud's storage for the app is full, so the latest backup wasn't kept.
        case full
        case failed(String)
    }

    private static let gameKey = "backup.game"
    private static let infoKey = "backup.info"
    private static let interval: TimeInterval = 600
    /// Key-value storage keeps a value of up to 1 MB, and 1 MB for the app in all: this leaves room.
    static let sizeLimit = 900_000
    private let store = NSUbiquitousKeyValueStore.default
    private var lastBackup = Date.distantPast
    /// This iPhone's id, so a backup made on another device can be told apart.
    let deviceID = BackupDevice.id
    /// Whether iCloud's key-value storage works for this build and an iCloud account is signed in.
    private(set) var isAvailable = false
    private(set) var status = Status.none
    private var observer: NSObjectProtocol?

    init() {
        refreshAvailability()
        // iCloud says when the storage is full, or the account changes.
        observer = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                          object: store, queue: .main) { [weak self] note in
            let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            MainActor.assumeIsolated { self?.changedExternally(reason: reason) }
        }
    }

    private func changedExternally(reason: Int?) {
        guard let reason else { return }
        switch reason {
        case NSUbiquitousKeyValueStoreQuotaViolationChange: status = .full
        case NSUbiquitousKeyValueStoreAccountChange: refreshAvailability()
        default: break
        }
    }

    /// Checks again whether iCloud can be used (an account may have been signed in since).
    func refreshAvailability() {
        isAvailable = FileManager.default.ubiquityIdentityToken != nil && store.synchronize()
    }

    /// The player's choice in Settings (on unless turned off).
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Preferences.iCloudBackupKey) as? Bool ?? true
    }

    /// What the backup in iCloud says about itself, if there is one.
    var latest: SaveTransfer.Header? {
        guard let info = store.dictionary(forKey: Self.infoKey),
              let savedAt = info["savedAt"] as? Double,
              let coins = info["lifetimeCoins"] as? Double,
              let prestiges = info["prestiges"] as? Int,
              let device = info["device"] as? String else { return nil }
        let lineage = (info["gameID"] as? String).flatMap(UUID.init(uuidString:))
            .map { SaveLineage(gameID: $0, revision: info["revision"] as? Int ?? 0) }
        return SaveTransfer.Header(version: info["version"] as? Int ?? 1, savedAt: Date(timeIntervalSince1970: savedAt),
                                   lifetimeCoins: coins, prestiges: prestiges, device: device, lineage: lineage)
    }

    /// Why the backup in iCloud mustn't be replaced by `game` by itself, or nil if it may.
    func conflict(with game: GameState) -> SaveTransfer.Conflict? {
        SaveTransfer.conflict(replacing: latest, with: game, device: deviceID)
    }

    /// Backs `game` up: at most every ten minutes, unless `force`. `replacing` writes over the
    /// copy there whatever it holds (the player chose to; `replace(with:)` keeps it first).
    func backUp(_ game: GameState, force: Bool = false, replacing: Bool = false) {
        let now = Date.now
        guard isEnabled, isAvailable, force || now.timeIntervalSince(lastBackup) >= Self.interval else { return }
        lastBackup = now
        if !replacing, let conflict = conflict(with: game) {
            status = .conflict(conflict)
            return
        }
        guard let json = try? SaveTransfer.data(of: game),
              let data = try? (json as NSData).compressed(using: .lzfse) as Data else {
            status = .failed(String(localized: "The game couldn't be packed for iCloud."))
            return
        }
        guard data.count < Self.sizeLimit else {
            status = .tooLarge(data.count)
            return
        }
        store.set(data, forKey: Self.gameKey)
        store.set(["savedAt": now.timeIntervalSince1970, "lifetimeCoins": game.stats.lifetimeCoins,
                   "prestiges": game.stats.prestiges, "device": deviceID, "version": GameState.saveVersion,
                   "gameID": game.gameID.uuidString, "revision": game.revision] as [String: Any],
                  forKey: Self.infoKey)
        status = store.synchronize() ? .backedUp(now) : .failed(String(localized: "iCloud didn't take the backup. It's tried again next time."))
    }

    /// Replaces the backup in iCloud with `game`, as the player chose, after keeping the copy
    /// there as a snapshot in `backups`. Leaves it if that can't be done.
    func replace(with game: GameState, keepingCopyIn backups: GameBackups) {
        if let data = store.data(forKey: Self.gameKey) {
            guard let json = try? (data as NSData).decompressed(using: .lzfse) as Data,
                  backups.keep(json, before: .iCloudCopy) else {
                status = .failed(String(localized: "The copy in iCloud couldn't be kept first, so it wasn't replaced."))
                return
            }
        }
        backUp(game, force: true, replacing: true)
    }

    /// The game in the backup.
    func restore() throws -> GameState {
        guard let data = store.data(forKey: Self.gameKey),
              let json = try? (data as NSData).decompressed(using: .lzfse) as Data else {
            throw SaveTransfer.ReadError.unreadable
        }
        return try SaveTransfer.game(from: json)
    }
}
