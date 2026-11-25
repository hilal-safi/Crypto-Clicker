import Foundation
import CryptoClickerKit

/// A copy of the game in iCloud's key-value storage, so a new iPhone (or the app reinstalled) can
/// carry on. The copy is `SaveTransfer`'s: no Apple Health data goes to iCloud. Backs up at most
/// every ten minutes while saving, and whenever the app leaves the screen; never over a copy from
/// another device with more progress, which Settings offers to restore instead.
///
/// Needs the iCloud capability (Key-value storage) on the app; without it, or without an iCloud
/// account, `isAvailable` is false and nothing is backed up.
@MainActor
final class CloudBackup {
    /// What the backup in iCloud holds, for Settings.
    struct Info: Equatable {
        let savedAt: Date
        let lifetimeCoins: Double
        let prestiges: Int
        /// The device that made it (an id of this install's own, not the device's).
        let device: String
    }

    private static let gameKey = "backup.game"
    private static let infoKey = "backup.info"
    private static let interval: TimeInterval = 600
    private let store = NSUbiquitousKeyValueStore.default
    private var lastBackup = Date.distantPast
    /// This install's id, so a backup made on another device can be told apart.
    let deviceID: String
    /// Whether iCloud's key-value storage works for this build and an iCloud account is signed in.
    private(set) var isAvailable = false

    init() {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: Preferences.backupDeviceKey) {
            deviceID = saved
        } else {
            deviceID = UUID().uuidString
            defaults.set(deviceID, forKey: Preferences.backupDeviceKey)
        }
        refreshAvailability()
    }

    /// Checks again whether iCloud can be used (an account may have been signed in since).
    func refreshAvailability() {
        isAvailable = FileManager.default.ubiquityIdentityToken != nil && store.synchronize()
    }

    /// The player's choice in Settings (on unless turned off).
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Preferences.iCloudBackupKey) as? Bool ?? true
    }

    /// The backup in iCloud, if there is one.
    var latest: Info? {
        guard let info = store.dictionary(forKey: Self.infoKey),
              let savedAt = info["savedAt"] as? Double,
              let coins = info["lifetimeCoins"] as? Double,
              let prestiges = info["prestiges"] as? Int,
              let device = info["device"] as? String else { return nil }
        return Info(savedAt: Date(timeIntervalSince1970: savedAt), lifetimeCoins: coins, prestiges: prestiges, device: device)
    }

    /// Whether the backup in iCloud came from another device and is further on than `game`: it's
    /// left alone, and offered in Settings.
    func hasMoreProgressElsewhere(than game: GameState) -> Bool {
        guard let latest else { return false }
        return latest.device != deviceID && latest.lifetimeCoins > game.stats.lifetimeCoins
    }

    /// Backs `game` up: at most every ten minutes, unless `force`.
    func backUp(_ game: GameState, force: Bool = false) {
        let now = Date.now
        guard isEnabled, isAvailable, force || now.timeIntervalSince(lastBackup) >= Self.interval,
              !hasMoreProgressElsewhere(than: game),
              let json = try? SaveTransfer.data(of: game),
              let data = try? (json as NSData).compressed(using: .lzfse) as Data,
              data.count < 900_000 else { return }
        store.set(data, forKey: Self.gameKey)
        store.set(["savedAt": now.timeIntervalSince1970, "lifetimeCoins": game.stats.lifetimeCoins,
                   "prestiges": game.stats.prestiges, "device": deviceID] as [String: Any], forKey: Self.infoKey)
        store.synchronize()
        lastBackup = now
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
