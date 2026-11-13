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
    /// The coin's rim (a `CoinRim` raw value) and what a tap sets off (a `CoinTapEffect` raw value).
    static let coinRimKey = "coinRim"
    static let coinTapEffectKey = "coinTapEffect"
    /// Reminders the player turned on.
    static let notifyMinersKey = "notifyMinersStopped"
    static let notifyDailyKey = "notifyDailyReward"
    /// The day the welcome-back screen last showed without Offline Mining (it shows once a day).
    static let lastShortWelcomeDayKey = "lastShortWelcomeDay"
    /// First-run tips the player has closed, comma-separated.
    static let dismissedTipsKey = "dismissedTips"
    /// Each action game's Speed option.
    static let brickBreakerSpeedKey = "speed.brickBreaker"
    static let snakeSpeedKey = "speed.snake"
    /// Snake's arena for Classic games (a `SnakeGame.Arena` raw value).
    static let snakeArenaKey = "snakeArena"
    static let tetrisSpeedKey = "speed.tetris"
    static let invadersSpeedKey = "speed.invaders"
    /// Scam Invaders' difficulty: hits a ship takes, and the speed.
    static let invadersDifficultyKey = "difficulty.invaders"
    /// The level Hash Smash's Levels and the wave Scam Invaders' Waves start at, picked on their
    /// start screens from those reached.
    static let brickBreakerStartKey = "start.brickBreaker"
    static let invadersStartKey = "start.invaders"
    static let pumpDumpSpeedKey = "speed.pumpDump"
    /// How fast Bubble Market's shots fly (a `GameSpeed` raw value), and how much of the path its
    /// aiming guide shows (a `BubbleAimGuide` raw value).
    static let bubbleSpeedKey = "speed.bubbleBlaster"
    static let bubbleAimKey = "bubbleBlaster.aimGuide"
    /// Pump and Dump's board (a `PumpDumpGame.Board` raw value: its side).
    static let pumpDumpBoardKey = "pumpDump.board"
    /// The difficulty last picked for a random Token Swap level.
    static let tokenSwapRandomDifficultyKey = "tokenSwapRandomDifficulty"
    /// The player has opened How to Play (in Settings), so the tip pointing there is done.
    static let howToPlaySeenKey = "howToPlaySeen"
    /// The income chart's range in Statistics (an `IncomeRange` raw value).
    static let incomeChartRangeKey = "incomeChartRange"
    /// The balance shows as a Live Activity on the Lock Screen and in the Dynamic Island.
    static let liveActivityKey = "showsLiveActivity"
    /// Merge Mining shows each miner's number under its picture.
    static let mergeValuesKey = "merge2048.showsValues"
    /// How quickly 2048's tiles slide (a `GameSpeed` raw value).
    static let mergeSlideSpeedKey = "speed.merge2048"

    /// Whether the Live Activity is on (it is unless the player turned it off).
    static var showsLiveActivity: Bool {
        UserDefaults.standard.object(forKey: liveActivityKey) as? Bool ?? true
    }

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
