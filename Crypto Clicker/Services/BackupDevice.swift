import UIKit

/// This iPhone's id in backups, to tell a copy made here from one made on another device: the
/// vendor identifier, which a new iPhone doesn't share even when it's set up from this one's backup
/// (an id kept in the app's settings would move to it with them). Should iOS not give one, an id
/// kept for this install stands in.
@MainActor
enum BackupDevice {
    static let id: String = UIDevice.current.identifierForVendor?.uuidString ?? installID

    private static var installID: String {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: Preferences.backupDeviceKey) { return saved }
        let made = UUID().uuidString
        defaults.set(made, forKey: Preferences.backupDeviceKey)
        return made
    }
}
