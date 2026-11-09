import SwiftUI
import CryptoClickerKit

/// Where the coins come from, right now: every miner's share, automatic taps, the multipliers on
/// production, what makes up a tap, and the other ways coins arrive. Opened from the balance bar at
/// the bottom of the screen and the rates on Mine. Its Numbers switch (short or every digit) is the
/// same one as Settings' and tapping the balance on Mine.
struct IncomeBreakdownView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false

    var body: some View {
        // Redrawn every second, so the figures stay live while the sheet is open.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(game: store.game, now: context.date)
        }
    }

    private func content(game: GameState, now: Date) -> some View {
        let production = game.production(at: now)
        let idle = game.idleIncome(at: now)
        let autoTaps = max(0, idle - production)
        let boost = game.activeBoost(at: now)
        let miners = MinerID.allCases
            .filter { game.owned($0) > 0 }
            .sorted { game.rate(of: $0) > game.rate(of: $1) }
        return NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(rate(idle)) coins per second")
                            .font(.title2.bold())
                            .monospacedDigit()
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                        Text("\(amount(game.tapValue(at: now))) per tap · \(amount(idle * 3_600)) an hour · \(amount(idle * 86_400)) a day")
                            .font(.subheadline)
                            .foregroundStyle(.subtext)
                            .monospacedDigit()
                        if let boost {
                            Label("Bull Run \(CoinFormat.multiplier(boost.multiplier)) for \(CoinFormat.duration(boost.endsAt.timeIntervalSince(now)))",
                                  systemImage: "flame.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                    NumberFormatPicker(isSegmented: true)
                        .padding(.vertical, 2)
                }

                Section {
                    if miners.isEmpty {
                        Text("Buy a miner in the Shop and it shows up here.")
                            .foregroundStyle(.subtext)
                    }
                    ForEach(miners) { miner in
                        let minerRate = game.rate(of: miner) * (boost?.multiplier ?? 1)
                        ShareRow(title: "\(miner.name) ×\(CoinFormat.grouped(game.owned(miner)))",
                                 detail: boosts(of: miner, in: game), rate: rate(minerRate),
                                 share: idle > 0 ? minerRate / idle : 0) {
                            Text(miner.emoji)
                                .font(.title3)
                        }
                    }
                    if autoTaps > 0 {
                        // Laid out like a miner: what it is, its rate and its share.
                        ShareRow(title: String(localized: "Automatic taps"),
                                 detail: String(localized: "\(CoinFormat.rate(game.autoTapsPerSecond)) a second, each worth \(CoinFormat.percent(game.autoTapStrength)) of a tap"),
                                 rate: rate(autoTaps), share: idle > 0 ? autoTaps / idle : 0) {
                            Image(systemName: "hand.tap.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                } header: {
                    Text("Earned every second")
                } footer: {
                    SettingsNote("Milestones (25, 50, 100… owned) and Mk upgrades each double a miner; late in the game Legacy lifts the oldest. Shares include any Bull Run.")
                }

                Section("Production multipliers") {
                    row("Upgrades", CoinFormat.multiplier(game.upgradeProductionMultiplier))
                    row("Prestige (\(CoinFormat.grouped(game.prestigePoints)) points)", CoinFormat.multiplier(game.prestigeBonus))
                    row("Achievements (\(game.earnedAchievementTiers) stars)", CoinFormat.multiplier(game.achievementBonus))
                    row("Difficulty (\(game.difficulty.name))", CoinFormat.multiplier(game.difficulty.productionMultiplier))
                    if let boost {
                        row("Bull Run", CoinFormat.multiplier(boost.multiplier))
                    }
                    row("All together", CoinFormat.multiplier(game.globalMultiplier * (boost?.multiplier ?? 1)), bold: true)
                }

                Section {
                    row("Flat part", amount(game.tapBase))
                    row("\(CoinFormat.percent(game.tapShare)) of production", amount(game.tapShare * production))
                    if game.tapPerkMultiplier != 1 {
                        row("Strong Fingers", CoinFormat.multiplier(game.tapPerkMultiplier))
                    }
                    row("Each tap", amount(game.tapValue(at: now)), bold: true)
                    row("With the biggest combo (\(CoinFormat.multiplier(game.comboMaxMultiplier)))",
                        amount((game.tapValue(at: now) * game.comboMaxMultiplier).rounded()))
                    row("Combo pace", "+0.1 every \(CoinFormat.compact(game.comboTapsPerStep)) quick taps")
                    if store.comboStreak > 1 {
                        row("Combo now", "\(CoinFormat.multiplier(store.comboMultiplier)) · \(store.comboStreak) taps")
                    }
                } header: {
                    Text("What a tap earns")
                } footer: {
                    SettingsNote("Tapping upgrades add a share of a second's production to every tap. Quick taps in a row build a combo, and the combo power-ups in the Shop raise how big it gets and how fast it builds.")
                }

                Section("Other ways coins arrive") {
                    row("While away", game.offlineCap > 0
                        ? "Up to \(CoinFormat.duration(game.offlineCap)) · \(amount(game.baseIdleIncome * game.offlineCap))"
                        : "First minute only (no Offline Mining)")
                    if game.steps.isConnected {
                        row("Each step", game.stepsPaidNextDay(today: StepDay.key(for: now))
                            ? "\(amount(game.stepValue)), paid tomorrow" : "\(amount(game.stepValue)), paid as you walk")
                    }
                    row("Coin airdrop", "Up to \(amount(game.rewardIncome * Tuning.airdropIncomeSeconds))")
                    row("Whale airdrop", amount(game.whaleAmount))
                    let questIncome = game.challengeRewardIncome * game.dailyRewardMultiplier
                    row("Daily quests", "\(amount(questIncome * 600)) to \(amount(questIncome * 1_800))")
                }
            }
            .monospacedDigit()
            .navigationTitle("Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

    private func row(_ title: String, _ value: String, bold: Bool = false) -> some View {
        ValueRow(title: title, value: value, bold: bold)
    }

    /// What multiplies a miner: its milestones, Mk upgrades and Legacy.
    private func boosts(of miner: MinerID, in game: GameState) -> String {
        var parts = ["Milestones \(CoinFormat.multiplier(GameState.milestoneMultiplier(owned: game.owned(miner))))"]
        let mkLevel = game.minerUpgradeLevel(miner)
        if mkLevel > 0 {
            parts.append("Mk \(MinerID.markName(level: mkLevel - 1)) \(CoinFormat.multiplier(pow(Tuning.minerUpgradeMultiplier, Double(mkLevel))))")
        }
        let legacy = game.legacyMultiplier(miner)
        if legacy > 1 { parts.append("Legacy \(CoinFormat.multiplier(legacy))") }
        return parts.joined(separator: " · ")
    }
}
