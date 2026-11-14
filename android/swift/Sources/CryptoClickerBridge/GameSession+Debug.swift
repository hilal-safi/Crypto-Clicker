import Foundation
import CryptoClickerKit

#if DEBUG
/// Shortcuts behind the Testing Tools (iOS: GameStore+Debug). Like the iOS screen, they exist only
/// in debug builds (the ones Android Studio installs) and are left out of Google Play builds.
extension GameSession {
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

    func debugAddOfflineMining(hours: Double) {
        debugChange { game, _ in game.debugAddOfflineMining(hours: hours) }
    }

    func debugMaxPowerUps() {
        debugChange { game, _ in game.debugMaxPowerUps() }
    }

    func debugUnlockAllGames() {
        debugChange { game, _ in game.debugUnlockAllGames() }
    }

    func debugReachArcadeRank(_ rank: Int) {
        debugChange { game, _ in game.debugReachArcadeRank(rank) }
    }

    func debugEarnAllAchievements() {
        debugChange { game, _ in game.debugEarnAllAchievements() }
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
        refreshDaily(at: now, force: true)
    }

    /// Shows an airdrop now instead of in a few minutes.
    func debugDropAirdrop(_ kind: AirdropKind = .coins) {
        spawnAirdrop(kind, at: now)
    }

    /// Acts as if the app had been closed for `seconds`: the next tick pays the time away (up to
    /// the Offline Mining limit) and shows the welcome-back screen, even if it showed today.
    func debugPretendAway(_ seconds: TimeInterval) {
        prefs.lastShortWelcomeDay = nil
        prefs.save(to: prefsURL)
        debugChange { game, _ in game.debugRewind(seconds) }
    }

    func debugChange(_ change: (inout GameState, Date) -> Void) {
        perform(change)
        save()
    }
}
#endif
