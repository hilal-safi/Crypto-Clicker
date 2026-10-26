import SwiftUI
import Charts
import CryptoClickerKit

/// Lifetime statistics, grouped the way the game earns, with a chart of income over the week.
struct StatsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let game = store.game
        let stats = game.stats
        let now = Date.now
        NavigationStack {
            List {
                Section {
                    IncomeChart(samples: game.incomeHistory, current: IncomeSample(date: now, income: game.baseIdleIncome))
                        .frame(height: 180)
                        .padding(.vertical, 6)
                } header: {
                    Text("Income this week")
                } footer: {
                    Text("Coins per second, sampled every half hour while the game is open. The scale is logarithmic: each line is ten times the one below. Drops are prestiges.")
                }
                Section("Right now") {
                    row("Balance", CoinFormat.short(game.coins))
                    row("Income", "\(CoinFormat.rate(game.idleIncome(at: now))) per second")
                    row("Per tap", CoinFormat.short(game.tapValue(at: now)))
                    row("Production multiplier", CoinFormat.multiplier(game.globalMultiplier))
                    row("Offline Mining", game.offlineCap > 0
                        ? "Level \(game.offlineMiningLevel) · \(CoinFormat.duration(game.offlineCap))" : "Off")
                    row("Difficulty", game.difficulty.name)
                }
                Section("Prestige") {
                    row("Prestiges", CoinFormat.grouped(stats.prestiges))
                    row("Points earned", "\(CoinFormat.grouped(game.prestigePoints)) · +\(CoinFormat.percent(game.prestigeGain(game.prestigePoints)))")
                    row("Points to spend", CoinFormat.grouped(game.availablePrestigePoints))
                    row("Perks", "\(game.perks.count) of \(PerkID.allCases.count)")
                }
                Section("All time") {
                    row("Coins mined", CoinFormat.short(stats.lifetimeCoins))
                    row("Coins this run", CoinFormat.short(stats.runCoins))
                    row("Coins spent", CoinFormat.short(stats.spent))
                    row("Best income", "\(CoinFormat.rate(stats.peakIncome)) per second")
                    row("Airdrops caught", CoinFormat.grouped(stats.airdrops))
                    row("Whale airdrops", CoinFormat.grouped(stats.whaleAirdrops))
                }
                Section("Where coins came from") {
                    row("Tapping", CoinFormat.short(stats.earnedFromTaps))
                    row("Miners", CoinFormat.short(stats.earnedFromIdle))
                    row("While away", CoinFormat.short(stats.earnedOffline))
                    row("Steps", CoinFormat.short(stats.earnedFromSteps))
                    row("Mini-games", CoinFormat.short(stats.earnedFromGames))
                    row("Airdrops", CoinFormat.short(stats.earnedFromAirdrops))
                    row("Daily rewards", CoinFormat.short(stats.earnedFromDaily))
                }
                Section("Activity") {
                    row("Taps", CoinFormat.grouped(stats.taps))
                    row("Best tap", CoinFormat.short(stats.bestTap))
                    row("Longest combo", "\(CoinFormat.grouped(stats.bestCombo)) taps")
                    row("Steps rewarded", CoinFormat.grouped(stats.lifetimeSteps))
                    row("Best day", "\(CoinFormat.grouped(stats.bestDaySteps)) steps")
                    row("Miners bought", CoinFormat.grouped(stats.minersBought))
                    row("Most miners at once", CoinFormat.grouped(stats.maxTotalMiners))
                    row("Mk upgrades bought", CoinFormat.grouped(stats.minerUpgradesBought))
                    row("Quests completed", CoinFormat.grouped(stats.questsCompleted))
                    row("Longest daily streak", "\(CoinFormat.grouped(stats.longestStreak)) days")
                }
                Section("Market") {
                    row("Tokens bought", CoinFormat.grouped(stats.totalTokensBought))
                    row("Tokens sold", CoinFormat.grouped(stats.tokensSold))
                    row("Coins from sales", CoinFormat.short(stats.coinsFromSales))
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

/// Income over the last week, on a log scale so early and late numbers both show.
private struct IncomeChart: View {
    let samples: [IncomeSample]
    /// Right now, so the line always reaches the present.
    let current: IncomeSample

    var body: some View {
        let weekAgo = current.date.addingTimeInterval(-7 * 86_400)
        let points = (samples + [current]).filter { $0.date >= weekAgo && $0.income >= 1 }
        if points.count < 2 {
            Text("Keep playing: your income chart fills in as the game runs.")
                .font(.subheadline)
                .foregroundStyle(.subtext)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(points, id: \.date) { sample in
                // A line only: an area would fill down to zero, which a log scale can't show.
                LineMark(x: .value("Time", sample.date), y: .value("Coins per second", sample.income))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(Theme.accent)
            }
            .chartYScale(type: .log)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let income = value.as(Double.self) { Text(CoinFormat.rate(income)) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .accessibilityLabel("Income chart")
            .accessibilityValue("From \(CoinFormat.rate(points.first?.income ?? 0)) to \(CoinFormat.rate(current.income)) coins per second")
        }
    }
}
