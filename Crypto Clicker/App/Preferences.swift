import SwiftUI

/// Player preferences, stored in `UserDefaults` under the same keys as earlier versions.
enum Preferences {
    static let appearanceKey = "appearanceMode"
    static let hapticsKey = "enableHaptics"
    static let soundsKey = "enableSounds"
    /// The player closed the home screen's invitation to earn coins from steps.
    static let stepsInviteDismissedKey = "stepsInviteDismissed"
    /// Show the balance and tap values with every digit (`12,345,678`) instead of the short form
    /// (`12.3M`). Switched by tapping the balance.
    static let exactNumbersKey = "showsExactNumbers"
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
