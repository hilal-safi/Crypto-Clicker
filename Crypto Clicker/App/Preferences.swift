import SwiftUI

/// Player preferences, stored in `UserDefaults` under the same keys as earlier versions.
enum Preferences {
    static let appearanceKey = "appearanceMode"
    static let hapticsKey = "enableHaptics"
    static let soundsKey = "enableSounds"
}

enum Appearance: String, CaseIterable, Identifiable {
    case auto, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .auto: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
