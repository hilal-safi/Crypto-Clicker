import SwiftUI
import CryptoClickerKit

/// Lifetime statistics, grouped the way the game earns, under a chart of income over time. Opened
/// from Settings. Coin amounts follow the short-or-full choice made by tapping the balance (or the
/// button here).
struct StatsPage: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false

    var body: some View {
        let game = store.game
        let now = Date.now
        List {
            nowSections(game, now: now)
            progressSections(game)
            marketSection(game)
            casinoSection(game)
            arcadeSection(game)
        }
        .monospacedDigit()
        .scrollContentBackground(.hidden)
        .background { AppBackground(tint: Theme.settings) }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(exactNumbers ? "Short" : "Full") {
                    withAnimation(.snappy) { exactNumbers.toggle() }
                }
                .accessibilityHint(exactNumbers ? "Shows numbers in short form" : "Shows every digit")
            }
        }
    }

    /// The income chart, what's happening right now, this run and the miners.
    @ViewBuilder
    private func nowSections(_ game: GameState, now: Date) -> some View {
        let stats = game.stats
        let owned = MinerID.allCases.filter { game.owned($0) > 0 }
        Section {
            IncomeChartCard(samples: game.incomeHistory, current: IncomeSample(date: now, income: game.baseIdleIncome))
        } header: {
            Text("Income")
        } footer: {
            SettingsNote("Coins per second from your miners, saved every minute while the game is open. Older points keep the best of each stretch of time, and dips are prestiges.")
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
            let total = owned.reduce(0) { $0 + game.rate(of: $1) }
            Section {
                ForEach(owned) { miner in
                    MinerStatRow(miner: miner, owned: game.owned(miner), mostEver: stats.maxOwned[miner, default: 0],
                                 mkLevel: game.minerUpgradeLevel(miner), rate: rate(game.rate(of: miner)),
                                 share: total > 0 ? game.rate(of: miner) / total : 0)
                }
            } header: {
                Text("Miners")
            } footer: {
                SettingsNote("What each tier mines a second, and its share of what all your miners mine.")
            }
        }
    }

    /// Prestige, all-time records, where coins came from, tapping, daily play and steps.
    @ViewBuilder
    private func progressSections(_ game: GameState) -> some View {
        let stats = game.stats
        let today = store.today
        Section("Prestige") {
            row("Prestiges", CoinFormat.grouped(stats.prestiges))
            row("Points earned", "\(CoinFormat.grouped(game.prestigePoints)) · +\(CoinFormat.percent(game.prestigeGain(game.prestigePoints)))")
            row("Points to spend", CoinFormat.grouped(game.availablePrestigePoints))
            row("Perks", "\(game.perks.count) of \(PerkID.allCases.count)")
            row("Difficulty multiplier this run", CoinFormat.multiplier(game.runPrestigeMultiplier))
        }

        Section("All time") {
            NavigationLink {
                JourneyView()
            } label: {
                Label("Your Journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
            }
            row("Playing since", game.created.formatted(date: .abbreviated, time: .omitted))
            row("Coins mined", amount(stats.lifetimeCoins))
            row("Coins spent", amount(stats.spent))
            row("Best income", "\(rate(stats.peakIncome)) per second")
            row("Achievement stars", "\(game.earnedAchievementTiers) of \(AchievementCatalog.tierCount) · +\(CoinFormat.percent(game.achievementBonus - 1))")
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
            row("Combo speed", "\(CoinFormat.compact(game.comboSpeed))× · +0.1 every \(CoinFormat.compact(game.comboTapsPerStep)) taps")
            row("Power-up levels bought", CoinFormat.grouped(stats.powerUpLevelsBought))
            row("Automatic taps", "\(CoinFormat.rate(game.autoTapsPerSecond)) a second · \(CoinFormat.percent(game.autoTapStrength)) of a tap")
        }

        airdropSection(game)

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
            row("Each step pays", game.stepsPaidNextDay(today: today) ? "\(amount(game.stepValue)) tomorrow" : amount(game.stepValue))
            row("Steps walked", CoinFormat.grouped(stats.lifetimeSteps))
            row("Steps paid for", CoinFormat.grouped(stats.stepsPaid))
            row("Best day", "\(CoinFormat.grouped(stats.bestDaySteps)) steps")
        }
    }

    /// Airdrops caught and missed, what they paid, and the latest few.
    @ViewBuilder
    private func airdropSection(_ game: GameState) -> some View {
        let stats = game.stats
        Section {
            AirdropSummary(caught: stats.airdrops, missed: stats.airdropsMissed, earned: amount(stats.earnedFromAirdrops),
                           items: [StatItem("Whales", CoinFormat.grouped(stats.whaleAirdrops)),
                                   StatItem("Bull Runs", CoinFormat.grouped(stats.bullRuns)),
                                   StatItem("Best catch", stats.bestAirdrop > 0 ? amount(stats.bestAirdrop) : "–")])
            ForEach(Array(game.recentAirdrops.reversed().enumerated()), id: \.offset) { _, log in
                AirdropLogRow(log: log, coins: amount(log.coins))
            }
        } header: {
            Text("Airdrops")
        } footer: {
            if !game.recentAirdrops.isEmpty {
                SettingsNote("The latest airdrops, newest first.")
            }
        }
    }

    @ViewBuilder
    private func marketSection(_ game: GameState) -> some View {
        let stats = game.stats
        let market = store.market
        let tokens = TokenID.allCases.filter { game.tokenCount($0) > 0 || stats.tokensBought[$0, default: 0] > 0 }
        let walletValue = TokenID.allCases.reduce(0.0) { $0 + market.quote($1).price * Double(game.tokenCount($1)) }
        let held = TokenID.allCases.reduce(0) { $0 + game.tokenCount($1) }
        Section("Market") {
            WalletCard(value: amount(walletValue),
                       detail: stats.totalTokensBought > 0
                           ? "\(counted(held, "token")) held, at today's prices"
                           : "Buy tokens in the Shop's Tokens page",
                       items: [StatItem("Bought", CoinFormat.grouped(stats.totalTokensBought)),
                               StatItem("Sold", CoinFormat.grouped(stats.tokensSold)),
                               StatItem("From sales", amount(stats.coinsFromSales))])
            ForEach(tokens) { token in
                let price = market.quote(token).price
                TokenStatRow(token: token, held: game.tokenCount(token), bought: stats.tokensBought[token, default: 0],
                             worth: amount(price * Double(game.tokenCount(token))), price: amount(price))
            }
        }
    }

    @ViewBuilder
    private func casinoSection(_ game: GameState) -> some View {
        let games = MiniGame.byPrice.filter(\.isCasino)
        let played = games.filter { hasRecords($0, in: game) }
        let unplayed = games.filter { !played.contains($0) }
        Section {
            ForEach(played) { miniGame in
                card(for: miniGame, in: game)
            }
            if !unplayed.isEmpty {
                UnplayedGamesRow(games: unplayed)
            }
        } header: {
            Text("Casino")
        } footer: {
            if !played.isEmpty {
                SettingsNote("Bets and payouts count tokens at their list price.")
            }
        }
    }

    @ViewBuilder
    private func arcadeSection(_ game: GameState) -> some View {
        let games = MiniGame.byPrice.filter { !$0.isCasino }
        let played = games.filter { hasRecords($0, in: game) }
        let unplayed = games.filter { !played.contains($0) }
        Section("Arcade") {
            ArcadeRankStats(rank: game.arcadeRank, title: game.arcadeTitle, progress: game.arcadeRankProgress,
                            items: [StatItem("Games played", CoinFormat.grouped(game.arcadeGamesPlayed)),
                                    StatItem("XP earned", CoinFormat.grouped(game.arcade.xp)),
                                    StatItem("Weekly goals", CoinFormat.grouped(game.arcade.weeklyGoals))])
            ForEach(played) { miniGame in
                card(for: miniGame, in: game)
            }
            if !unplayed.isEmpty {
                UnplayedGamesRow(games: unplayed)
            }
        }
    }

    /// Whether a game has anything to show yet: a game played, a record or a daily win.
    private func hasRecords(_ miniGame: MiniGame, in game: GameState) -> Bool {
        game.timesPlayed(miniGame) > 0 || game.bestScore(miniGame) > 0
            || (miniGame == .merge2048 && game.merge2048Daily.wins > 0)
            || (miniGame == .tokenSwap && (game.tokenSwap.levelsWon > 0 || game.tokenSwap.dailyWins > 0))
    }

    private func card(for miniGame: MiniGame, in game: GameState) -> GameStatsCard {
        GameStatsCard(miniGame, in: game, exactNumbers: exactNumbers)
    }

    private func amount(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exact(value) : CoinFormat.short(value)
    }

    private func rate(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exactRate(value) : CoinFormat.rate(value)
    }

    /// "1 hand", "1,204 hands".
    private func counted(_ count: Int, _ noun: String) -> String {
        "\(CoinFormat.grouped(count)) \(noun)\(count == 1 ? "" : "s")"
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
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.subtext)
        }
    }
}
