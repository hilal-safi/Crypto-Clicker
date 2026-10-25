import SwiftUI
import CryptoClickerKit

/// Lifetime statistics, grouped the way the game earns.
struct StatsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let game = store.game
        let stats = game.stats
        let now = Date.now
        NavigationStack {
            List {
                Section("Right now") {
                    row("Balance", CoinFormat.short(game.coins))
                    row("Income", "\(CoinFormat.short(game.idleIncome(at: now))) per second")
                    row("Per tap", CoinFormat.short(game.tapValue(at: now)))
                    row("Production multiplier", CoinFormat.multiplier(game.globalMultiplier))
                    row("Offline earnings limit", CoinFormat.duration(game.offlineCap))
                    row("Difficulty", game.difficulty.name)
                }
                Section("All time") {
                    row("Coins mined", CoinFormat.short(stats.lifetimeCoins))
                    row("Coins this run", CoinFormat.short(stats.runCoins))
                    row("Coins spent", CoinFormat.short(stats.spent))
                    row("Best income", "\(CoinFormat.short(stats.peakIncome)) per second")
                    row("Hard Forks", CoinFormat.grouped(stats.forksPerformed))
                    row("Airdrops caught", CoinFormat.grouped(stats.airdrops))
                }
                Section("Where coins came from") {
                    row("Tapping", CoinFormat.short(stats.earnedFromTaps))
                    row("Miners", CoinFormat.short(stats.earnedFromIdle))
                    row("While away", CoinFormat.short(stats.earnedOffline))
                    row("Steps", CoinFormat.short(stats.earnedFromSteps))
                    row("Mini-games", CoinFormat.short(stats.earnedFromGames))
                    row("Airdrops", CoinFormat.short(stats.earnedFromAirdrops))
                }
                Section("Activity") {
                    row("Taps", CoinFormat.grouped(stats.taps))
                    row("Best tap", CoinFormat.short(stats.bestTap))
                    row("Steps rewarded", CoinFormat.grouped(stats.lifetimeSteps))
                    row("Best day", "\(CoinFormat.grouped(stats.bestDaySteps)) steps")
                    row("Most miners at once", CoinFormat.grouped(stats.maxTotalMiners))
                    row("Tokens bought", CoinFormat.grouped(stats.totalTokensBought))
                }
                Section("Mini-games") {
                    row("Blackjack hands", CoinFormat.grouped(stats.blackjackHands))
                    row("Blackjack wins", CoinFormat.grouped(stats.blackjackWins))
                    row("Naturals", CoinFormat.grouped(stats.blackjackNaturals))
                    row("Tetris games", CoinFormat.grouped(stats.tetrisGames))
                    row("Tetris lines", CoinFormat.grouped(stats.tetrisLines))
                    row("Tetris best", CoinFormat.grouped(stats.tetrisBestScore))
                }
            }
            .monospacedDigit()
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }
}
