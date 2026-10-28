import SwiftUI
import CryptoClickerKit

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
    /// How hard the coin taps back when tapped.
    static let tapHapticStrengthKey = "tapHapticStrength"
    /// The coin's finish on the Mine tab (a `CoinFinish` raw value).
    static let coinFinishKey = "coinFinish"
    /// Reminders the player turned on.
    static let notifyMinersKey = "notifyMinersStopped"
    static let notifyDailyKey = "notifyDailyReward"
    /// The day the welcome-back screen last showed without Offline Mining (it shows once a day).
    static let lastShortWelcomeDayKey = "lastShortWelcomeDay"
    /// First-run tips the player has closed, comma-separated.
    static let dismissedTipsKey = "dismissedTips"

    /// The player has seen a mini-game's How to Play (it opens by itself the first time).
    static func helpSeenKey(_ game: MiniGame) -> String { "helpSeen.\(game.rawValue)" }
}

/// The haptic each tap on the coin plays.
enum TapHapticStrength: String, CaseIterable, Identifiable {
    case light, medium, strong

    var id: Self { self }

    var title: String {
        switch self {
        case .light: "Light"
        case .medium: "Medium"
        case .strong: "Strong"
        }
    }

    var feedback: SensoryFeedback {
        switch self {
        case .light: .impact(weight: .light, intensity: 0.8)
        case .medium: .impact(weight: .medium, intensity: 1)
        case .strong: .impact(weight: .heavy, intensity: 1)
        }
    }
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
