import SwiftUI
import CryptoClickerKit

#if DEBUG
/// Shortcuts behind the Testing Tools screen. Like that screen, they exist only in builds run
/// from Xcode (the Debug configuration) and are left out of App Store builds.
extension GameStore {
    /// Adds coins that count as mined, so upgrades, achievements and prestige unlock as in play.
    func debugAddCoins(_ amount: Double) {
        debugChange { game, _ in game.debugAddCoins(amount) }
    }

    /// Adds what the miners would earn in `seconds` at the current rate.
    func debugAddIncome(seconds: TimeInterval) {
        debugChange { game, now in game.debugAddCoins((game.idleIncome(at: now) * seconds).rounded()) }
    }

    func debugAddTokens(_ amount: Int) {
        debugChange { game, _ in game.debugAddTokens(amount) }
    }

    func debugAddMiners(_ count: Int) {
        debugChange { game, _ in game.debugAddMiners(count) }
    }

    func debugGiveAllUpgrades() {
        debugChange { game, _ in game.debugGiveAllUpgrades() }
    }

    func debugAddOfflineMining(levels: Int) {
        debugChange { game, _ in game.debugAddOfflineMining(levels: levels) }
    }

    func debugMaxPowerUps() {
        debugChange { game, _ in game.debugMaxPowerUps() }
    }

    func debugUnlockAllGames() {
        debugChange { game, _ in game.debugUnlockAllGames() }
    }

    func debugUnlockSteps() {
        debugChange { game, _ in game.debugUnlockSteps() }
    }

    func debugStartBullRun() {
        debugChange { game, now in game.debugStartBullRun(at: now) }
    }

    func debugAddPrestigePoints(_ points: Int) {
        debugChange { game, _ in game.debugAddPrestigePoints(points) }
    }

    func debugCompleteQuests() {
        debugChange { game, _ in game.debugCompleteQuests() }
    }

    /// Makes today's reward, quests and a fresh challenge available again (the streak carries on).
    func debugResetDaily() {
        let yesterday = yesterday
        debugChange { game, _ in game.debugResetDaily(yesterday: yesterday) }
        refreshDaily(at: .now, force: true)
    }

    /// Shows an airdrop now instead of in a few minutes.
    func debugDropAirdrop(_ kind: AirdropKind = .coins) {
        spawnAirdrop(kind, at: .now)
    }

    /// Acts as if the app had been closed for `seconds`: the next tick pays the time away
    /// (up to the offline limit) and shows the welcome-back screen.
    func debugPretendAway(_ seconds: TimeInterval) {
        UserDefaults.standard.removeObject(forKey: Preferences.lastShortWelcomeDayKey)
        debugChange { game, _ in game.debugRewind(seconds) }
    }

    func debugChange(_ change: (inout GameState, Date) -> Void) {
        perform(change)
        save()
        pushToWatch(force: true)
    }
}
#endif
