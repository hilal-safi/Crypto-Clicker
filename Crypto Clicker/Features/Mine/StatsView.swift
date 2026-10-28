import SwiftUI
import Charts
import CryptoClickerKit

/// Lifetime statistics, grouped the way the game earns, with a chart of income over the week.
/// Coin amounts follow the short-or-full choice made by tapping the balance (or the button here).
struct StatsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false

    var body: some View {
        let game = store.game
        let stats = game.stats
        let now = Date.now
        let market = store.market
        let owned = MinerID.allCases.filter { game.owned($0) > 0 }
        let held = TokenID.allCases.filter { game.tokenCount($0) > 0 || stats.tokensBought[$0, default: 0] > 0 }
        let walletValue = TokenID.allCases.reduce(0.0) { $0 + market.quote($1).price * Double(game.tokenCount($1)) }
        let today = store.today
        let gamesPlayed = game.arcadeGamesPlayed
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
                    row("Balance", amount(game.coins))
                    row("Income", "\(rate(game.idleIncome(at: now))) per second")
                    row("Per hour", amount(game.idleIncome(at: now) * 3_600))
                    row("Per tap", amount(game.tapValue(at: now)))
                    row("Production multiplier", CoinFormat.multiplier(game.globalMultiplier))
                    row("Offline Mining", game.offlineCap > 0
                        ? "Level \(game.offlineMiningLevel) · \(CoinFormat.duration(game.offlineCap))" : "Off")
                    row("Difficulty", game.difficulty.name)
                    if let boost = game.activeBoost(at: now) {
                        row("Bull Run", "\(CoinFormat.multiplier(boost.multiplier)) · \(CoinFormat.duration(boost.endsAt.timeIntervalSince(now))) left")
                    }
                }

                Section("This run") {
                    row("Started", "\(game.runStart.formatted(date: .abbreviated, time: .shortened))")
                    row("Running for", CoinFormat.duration(now.timeIntervalSince(game.runStart)))
                    row("Coins this run", amount(stats.runCoins))
                    row("Miners owned", CoinFormat.grouped(game.totalMiners))
                    row("Upgrades owned", "\(game.upgrades.count) of \(UpgradeID.allCases.count)")
                    row("Mk upgrades", CoinFormat.grouped(game.minerUpgrades.values.reduce(0, +)))
                    row("Prestige points waiting", CoinFormat.grouped(game.claimablePrestigePoints))
                    row("Next prestige point at", "\(amount(game.nextPrestigePointAt)) mined in all")
                }

                if !owned.isEmpty {
                    Section("Miners") {
                        ForEach(owned) { miner in
                            minerRow(miner, in: game)
                        }
                    }
                }

                Section("Prestige") {
                    row("Prestiges", CoinFormat.grouped(stats.prestiges))
                    row("Points earned", "\(CoinFormat.grouped(game.prestigePoints)) · +\(CoinFormat.percent(game.prestigeGain(game.prestigePoints)))")
                    row("Points to spend", CoinFormat.grouped(game.availablePrestigePoints))
                    row("Perks", "\(game.perks.count) of \(PerkID.allCases.count)")
                    row("Difficulty multiplier this run", CoinFormat.multiplier(game.runPrestigeMultiplier))
                }

                Section("All time") {
                    row("Playing since", game.created.formatted(date: .abbreviated, time: .omitted))
                    row("Coins mined", amount(stats.lifetimeCoins))
                    row("Coins spent", amount(stats.spent))
                    row("Best income", "\(rate(stats.peakIncome)) per second")
                    row("Achievement stars", "\(game.earnedAchievementTiers) of \(AchievementCatalog.tierCount) · +\(CoinFormat.percent(game.achievementBonus - 1))")
                    row("Airdrops caught", CoinFormat.grouped(stats.airdrops))
                    row("Whale airdrops", CoinFormat.grouped(stats.whaleAirdrops))
                }

                Section("Where coins came from") {
                    let total = max(stats.lifetimeCoins, 1)
                    sourceRow("Tapping", stats.earnedFromTaps, of: total)
                    sourceRow("Miners", stats.earnedFromIdle, of: total)
                    sourceRow("While away", stats.earnedOffline, of: total)
                    sourceRow("Steps", stats.earnedFromSteps, of: total)
                    sourceRow("Mini-games", stats.earnedFromGames, of: total)
                    sourceRow("Airdrops", stats.earnedFromAirdrops, of: total)
                    sourceRow("Daily rewards", stats.earnedFromDaily, of: total)
                }

                Section("Tapping") {
                    row("Taps", CoinFormat.grouped(stats.taps))
                    row("Best tap", amount(stats.bestTap))
                    row("Longest combo", "\(CoinFormat.grouped(stats.bestCombo)) taps")
                    row("Biggest combo", CoinFormat.multiplier(game.comboMaxMultiplier))
                    row("Automatic taps", "\(CoinFormat.rate(game.autoTapsPerSecond)) a second · \(CoinFormat.percent(game.autoTapStrength)) of a tap")
                }

                Section("Daily") {
                    row("Streak", "\(game.currentStreak(today: today, yesterday: store.yesterday)) days")
                    row("Longest streak", "\(CoinFormat.grouped(stats.longestStreak)) days")
                    row("Quests today", "\(game.daily.quests.filter(\.isClaimed).count) of \(game.daily.quests.count) claimed")
                    row("Quests completed", CoinFormat.grouped(stats.questsCompleted))
                    if let challenge = game.dailyChallenge(today: today) {
                        row("Today's challenge", challenge.isComplete ? "Done · \(challenge.goal)" : challenge.goal)
                    }
                    row("Challenges this week", "\(game.challengesCompleted(inWeekOf: today)) of \(Tuning.weeklyChallengeGoal)")
                    row("Challenges completed", CoinFormat.grouped(stats.challengesCompleted))
                }

                Section("Steps") {
                    row("Status", game.steps.isConnected ? "Connected" : (game.areStepsUnlocked ? "Not connected" : "Unlocks after \(CoinFormat.grouped(Tuning.stepsUnlockTaps)) taps"))
                    row("Each step earns", amount(game.stepValue))
                    row("Steps rewarded", CoinFormat.grouped(stats.lifetimeSteps))
                    row("Best day", "\(CoinFormat.grouped(stats.bestDaySteps)) steps")
                }

                Section("Market") {
                    row("Wallet value", amount(walletValue))
                    ForEach(held) { token in
                        let quote = market.quote(token)
                        row("\(token.name)", "\(CoinFormat.grouped(game.tokenCount(token))) held · \(amount(quote.price)) each · \(CoinFormat.grouped(stats.tokensBought[token, default: 0])) bought")
                    }
                    row("Tokens bought", CoinFormat.grouped(stats.totalTokensBought))
                    row("Tokens sold", CoinFormat.grouped(stats.tokensSold))
                    row("Coins from sales", amount(stats.coinsFromSales))
                }

                Section("Casino") {
                    row("Blackjack hands", CoinFormat.grouped(stats.blackjackHands))
                    row("Blackjack wins", "\(CoinFormat.grouped(stats.blackjackWins))\(winRate(stats.blackjackWins, of: stats.blackjackHands))")
                    row("Naturals", CoinFormat.grouped(stats.blackjackNaturals))
                    row("Win streak", "\(CoinFormat.grouped(stats.blackjackStreak)) now · best \(CoinFormat.grouped(stats.blackjackBestStreak))")
                    row("Biggest Blackjack win", amount(stats.blackjackBiggestWin))
                    row("Slot spins", CoinFormat.grouped(stats.slotsSpins))
                    row("Slot wins", "\(CoinFormat.grouped(stats.slotsWins))\(winRate(stats.slotsWins, of: stats.slotsSpins))")
                    row("Jackpots", CoinFormat.grouped(stats.slotsJackpots))
                    row("Best spin", stats.slotsBestMultiple >= 2 ? "×\(CoinFormat.grouped(stats.slotsBestMultiple)) the bet" : "No wins yet")
                    row("Biggest slots win", amount(stats.slotsBiggestWin))
                    row("Free spins", "\(CoinFormat.grouped(stats.slotsFreeSpinRounds)) won · \(CoinFormat.grouped(stats.slotsFreeSpinsPlayed)) played")
                    row("Bitcoins collected", "\(CoinFormat.grouped(stats.slotsBitcoins)) · \(CoinFormat.grouped(stats.slotsBitcoins / SlotMachine.bitcoinsPerPrize)) prizes")
                    row("Slots bet · paid", "\(amount(stats.slotsWagered)) · \(amount(stats.slotsPaidOut))\(returnRate(stats.slotsPaidOut, of: stats.slotsWagered))")
                    row("Moon flights", CoinFormat.grouped(stats.moonFlights))
                    row("Cash-outs", "\(CoinFormat.grouped(stats.moonCashOuts))\(winRate(stats.moonCashOuts, of: stats.moonFlights))")
                    row("Best cash-out", stats.moonCashOuts > 0 ? CoinFormat.flight(stats.moonBestMultiplier) : "None yet")
                    row("Biggest Moon win", amount(stats.moonBiggestWin))
                    row("Moon bet · paid", "\(amount(stats.moonWagered)) · \(amount(stats.moonPaidOut))\(returnRate(stats.moonPaidOut, of: stats.moonWagered))")
                    row("Video Poker hands", "\(CoinFormat.grouped(stats.pokerHands)) · \(CoinFormat.grouped(stats.pokerWins)) won\(winRate(stats.pokerWins, of: stats.pokerHands))")
                    row("Best poker hand", stats.pokerHands > 0 ? (PokerHand(rawValue: stats.pokerBestHand) ?? .nothing).name : "None yet")
                    row("Royal flushes", CoinFormat.grouped(stats.pokerRoyals))
                    row("Biggest poker win", amount(stats.pokerBiggestWin))
                    row("Poker bet · paid", "\(amount(stats.pokerWagered)) · \(amount(stats.pokerPaidOut))\(returnRate(stats.pokerPaidOut, of: stats.pokerWagered))")
                    Text("Bets and payouts count tokens at their list price.")
                        .font(.footnote)
                        .foregroundStyle(.subtext)
                }

                Section("Arcade") {
                    row("Tetris", "Best \(CoinFormat.grouped(stats.tetrisBestScore)) · level \(stats.tetrisBestLevel) · combo \(stats.tetrisBestCombo) · \(CoinFormat.grouped(stats.tetrisTetrises)) Tetrises · \(CoinFormat.grouped(stats.tetrisLines)) lines · \(CoinFormat.grouped(stats.tetrisGames)) games" + (stats.tetrisBestSprint > 0 ? " · Sprint \(CoinFormat.stopwatch(stats.tetrisBestSprint))" : ""))
                    row("2048", "Best \(CoinFormat.grouped(stats.merge2048BestScore)) · top tile \(stats.merge2048BestTile) · \(CoinFormat.grouped(stats.merge2048Games)) games · \(CoinFormat.grouped(game.merge2048Daily.wins)) daily puzzles · \(CoinFormat.grouped(game.merge2048Daily.totalStars)) stars")
                    row("Snake", "Best \(CoinFormat.grouped(stats.snakeBestScore)) · Coin Rush \(CoinFormat.grouped(stats.snakeRushBestScore)) · longest \(CoinFormat.grouped(stats.snakeLongest)) · most coins \(CoinFormat.grouped(stats.snakeBestCoins)) · longest game \(CoinFormat.stopwatch(stats.snakeLongestTime)) · \(CoinFormat.grouped(stats.snakePowerUps)) power-ups · \(CoinFormat.grouped(stats.snakeGames)) games")
                    row("Brick Breaker", "Best \(CoinFormat.grouped(stats.brickBreakerBestScore)) · level \(CoinFormat.grouped(stats.brickBreakerBestLevel)) · \(CoinFormat.grouped(stats.brickBreakerLevelsCleared)) levels cleared · best streak \(stats.brickBreakerBestStreak) · \(CoinFormat.grouped(stats.brickBreakerBosses)) bosses · \(CoinFormat.grouped(stats.brickBreakerPowerUps)) power-ups · \(CoinFormat.grouped(stats.bricksBroken)) bricks · \(CoinFormat.grouped(stats.brickBreakerGames)) games")
                    row("Bubble Blaster", "Best \(CoinFormat.grouped(stats.bubbleBestScore)) · wave \(CoinFormat.grouped(stats.bubbleBestWave)) · best shot \(CoinFormat.grouped(stats.bubbleBestShot)) · streak \(CoinFormat.grouped(stats.bubbleBestStreak)) · \(CoinFormat.grouped(stats.bubblesPopped)) popped · \(CoinFormat.grouped(stats.bubbleBonuses)) gold · \(CoinFormat.grouped(stats.bubbleGames)) games")
                    row("Pump and Dump", "Best \(CoinFormat.grouped(stats.pumpDumpBestScore)) · round \(stats.pumpDumpBestRound) · combo \(CoinFormat.grouped(stats.pumpDumpBestCombo)) · \(CoinFormat.grouped(stats.pumpDumpCoinsHit)) coins hit · \(CoinFormat.grouped(stats.pumpDumpScamsHit)) scams · \(CoinFormat.grouped(stats.pumpDumpGames)) runs")
                    row("Token Swap", "\(game.tokenSwap.levelsWon) levels won · \(game.tokenSwap.totalStars) stars · \(game.tokenSwap.dailyWins) daily puzzles · Classic best \(CoinFormat.grouped(stats.tokenSwapBestScore)) · chain of \(CoinFormat.grouped(stats.tokenSwapBestChain)) · \(CoinFormat.grouped(stats.tokenSwapTokens)) tokens · \(CoinFormat.grouped(stats.tokenSwapBlasts)) specials")
                    row("Games played", CoinFormat.grouped(gamesPlayed))
                }
            }
            .monospacedDigit()
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(exactNumbers ? "Short" : "Full") {
                        withAnimation(.snappy) { exactNumbers.toggle() }
                    }
                    .accessibilityHint(exactNumbers ? "Shows numbers in short form" : "Shows every digit")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    private func amount(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exact(value) : CoinFormat.short(value)
    }

    private func rate(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exactRate(value) : CoinFormat.rate(value)
    }

    private func winRate(_ wins: Int, of total: Int) -> String {
        total > 0 ? " · \(CoinFormat.percent(Double(wins) / Double(total)))" : ""
    }

    /// What came back for what went in: " · 95% back".
    private func returnRate(_ paid: Double, of bet: Double) -> String {
        bet > 0 ? " · \(CoinFormat.percent(paid / bet)) back" : ""
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .foregroundStyle(.subtext)
                .multilineTextAlignment(.trailing)
        }
    }

    private func sourceRow(_ title: String, _ value: Double, of total: Double) -> some View {
        LabeledContent(title) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(amount(value))
                    .multilineTextAlignment(.trailing)
                Text(CoinFormat.percent(value / total))
                    .font(.caption)
            }
            .foregroundStyle(.subtext)
        }
    }

    private func minerRow(_ miner: MinerID, in game: GameState) -> some View {
        let level = game.minerUpgradeLevel(miner)
        let mark = level > 0 ? " · Mk \(MinerID.markName(level: level - 1))" : ""
        return LabeledContent {
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(rate(game.rate(of: miner)))/s")
                    .multilineTextAlignment(.trailing)
                Text("Most ever \(CoinFormat.grouped(game.stats.maxOwned[miner, default: 0]))")
                    .font(.caption)
            }
            .foregroundStyle(.subtext)
        } label: {
            Text("\(miner.emoji) \(miner.name) ×\(CoinFormat.grouped(game.owned(miner)))\(mark)")
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
