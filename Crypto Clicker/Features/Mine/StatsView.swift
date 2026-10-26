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
                    row("Income", "\(CoinFormat.rate(game.idleIncome(at: now))) per second")
                    row("Per tap", CoinFormat.short(game.tapValue(at: now)))
                    row("Production multiplier", CoinFormat.multiplier(game.globalMultiplier))
                    row("Offline Mining", game.offlineCap > 0
                        ? "Level \(game.offlineMiningLevel) · \(CoinFormat.duration(game.offlineCap))" : "Off")
                    row("Difficulty", game.difficulty.name)
                }
                Section("All time") {
                    row("Coins mined", CoinFormat.short(stats.lifetimeCoins))
                    row("Coins this run", CoinFormat.short(stats.runCoins))
                    row("Coins spent", CoinFormat.short(stats.spent))
                    row("Best income", "\(CoinFormat.rate(stats.peakIncome)) per second")
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
                Section("Casino") {
                    row("Blackjack hands", CoinFormat.grouped(stats.blackjackHands))
                    row("Blackjack wins", CoinFormat.grouped(stats.blackjackWins))
                    row("Naturals", CoinFormat.grouped(stats.blackjackNaturals))
                    row("Slot spins", CoinFormat.grouped(stats.slotsSpins))
                    row("Slot wins", CoinFormat.grouped(stats.slotsWins))
                    row("Jackpots", CoinFormat.grouped(stats.slotsJackpots))
                }
                Section("Arcade") {
                    row("Tetris best", "\(CoinFormat.grouped(stats.tetrisBestScore)) · \(CoinFormat.grouped(stats.tetrisLines)) lines")
                    row("Snake best", CoinFormat.grouped(stats.snakeBestScore))
                    row("Brick Breaker best", "\(CoinFormat.grouped(stats.brickBreakerBestScore)) · \(CoinFormat.grouped(stats.bricksBroken)) bricks")
                    row("Bubble Blaster best", "\(CoinFormat.grouped(stats.bubbleBestScore)) · \(CoinFormat.grouped(stats.bubblesPopped)) popped")
                    row("Games played", CoinFormat.grouped(stats.tetrisGames + stats.snakeGames + stats.brickBreakerGames + stats.bubbleGames))
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
        LabeledContent(title) {
            Text(value)
                .foregroundStyle(.subtext)
        }
    }
}
