import Foundation

/// A first step in the opening, with a small reward to claim on the Goals page. They give a new
/// game a few short goals to reach for before the longer ones (the next miner, the first
/// prestige). Once claimed they stay claimed, through prestiges.
public enum StarterMilestone: String, CaseIterable, Codable, Sendable, Identifiable {
    case firstChromebook, threeMiners, firstUpgrade, firstGameUnlocked, firstGamePlayed

    public var id: String { rawValue }

    /// What to do.
    public var title: String {
        switch self {
        case .firstChromebook: localized("Buy your first Chromebook")
        case .threeMiners: localized("Own three miners")
        case .firstUpgrade: localized("Buy your first upgrade")
        case .firstGameUnlocked: localized("Unlock your first mini-game")
        case .firstGamePlayed: localized("Finish your first mini-game")
        }
    }

    /// SF Symbol for the Goals page.
    public var symbol: String {
        switch self {
        case .firstChromebook: "cpu.fill"
        case .threeMiners: "square.stack.3d.up.fill"
        case .firstUpgrade: "sparkles"
        case .firstGameUnlocked: "lock.open.fill"
        case .firstGamePlayed: "gamecontroller.fill"
        }
    }

    /// What claiming it pays.
    public var reward: StarterReward {
        switch self {
        case .firstChromebook: .coins(seconds: Tuning.starterChromebookSeconds)
        case .threeMiners: .coins(seconds: Tuning.starterThreeMinersSeconds)
        case .firstUpgrade: .coins(seconds: Tuning.starterUpgradeSeconds)
        case .firstGameUnlocked: .bullRun(seconds: Tuning.starterGameBullRun)
        case .firstGamePlayed: .coins(seconds: Tuning.starterGamePlayedSeconds)
        }
    }
}

/// What a starter milestone is worth.
public enum StarterReward: Equatable, Sendable {
    /// Coins worth this many seconds of income when claimed.
    case coins(seconds: Double)
    /// A Bull Run of this many seconds.
    case bullRun(seconds: TimeInterval)
}

/// What claiming a starter milestone pays (or would pay now).
public enum StarterPayout: Equatable, Sendable {
    case coins(Double)
    case bullRun(seconds: TimeInterval)

    public var text: String {
        switch self {
        case .coins(let amount): localized("\(CoinFormat.short(amount)) coins")
        case .bullRun(let seconds):
            localized("Bull Run \(CoinFormat.multiplier(Tuning.bullRunMultiplier)) for \(CoinFormat.duration(seconds))")
        }
    }
}
