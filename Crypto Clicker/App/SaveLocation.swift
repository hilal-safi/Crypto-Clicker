import Foundation
import CryptoClickerKit

extension SaveStore {
    /// The game's save: one JSON file in Application Support.
    init() {
        let folder = URL.applicationSupportDirectory.appending(path: "CryptoClicker", directoryHint: .isDirectory)
        self.init(url: folder.appending(path: "game.json", directoryHint: .notDirectory))
    }
}
