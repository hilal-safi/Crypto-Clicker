import SwiftUI
import CryptoClickerKit

/// Where the coins come from, right now: every miner's share, automatic taps, the multipliers on
/// production, what makes up a tap, and the other ways coins arrive. Opened from the bar at the
/// bottom of the screen. Numbers follow the short-or-full choice made by tapping the balance.
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
                }

                Section {
                    if miners.isEmpty {
                        Text("Buy a miner in the Shop and it shows up here.")
                            .foregroundStyle(.subtext)
                    }
                    ForEach(miners) { miner in
                        let minerRate = game.rate(of: miner) * (boost?.multiplier ?? 1)
                        MinerShareRow(miner: miner, owned: game.owned(miner), mkLevel: game.minerUpgradeLevel(miner),
                                      milestones: GameState.milestoneMultiplier(owned: game.owned(miner)),
                                      rate: rate(minerRate), share: idle > 0 ? minerRate / idle : 0)
                    }
                    if autoTaps > 0 {
                        LabeledContent {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(rate(autoTaps))/s").monospacedDigit()
                                Text(CoinFormat.percent(idle > 0 ? autoTaps / idle : 0))
                                    .font(.caption).foregroundStyle(.subtext)
                            }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Automatic taps")
                                    Text("\(CoinFormat.rate(game.autoTapsPerSecond)) a second, each worth \(CoinFormat.percent(game.autoTapStrength)) of a tap")
                                        .font(.caption).foregroundStyle(.subtext)
                                }
                            } icon: {
                                Image(systemName: "hand.tap.fill").foregroundStyle(Theme.accent)
                            }
                        }
                    }
                } header: {
                    Text("Earned every second")
                } footer: {
                    Text("Milestones (25, 50, 100… owned) and Mk upgrades each double a miner. Shares include any Bull Run.")
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
                    row("With a full combo", amount((game.tapValue(at: now) * game.comboMaxMultiplier).rounded()))
                    if store.comboStreak > 1 {
                        row("Combo now", "\(CoinFormat.multiplier(store.comboMultiplier)) · \(store.comboStreak) taps")
                    }
                } header: {
                    Text("What a tap earns")
                } footer: {
                    Text("Tapping upgrades add a share of a second's production to every tap. Quick taps in a row build a combo up to \(CoinFormat.multiplier(game.comboMaxMultiplier)).")
                }

                Section("Other ways coins arrive") {
                    row("While away", game.offlineCap > 0
                        ? "Up to \(CoinFormat.duration(game.offlineCap)) · \(amount(game.baseIdleIncome * game.offlineCap))"
                        : "First minute only (no Offline Mining)")
                    if game.steps.isConnected {
                        row("Each step", amount(game.stepValue))
                    }
                    row("Coin airdrop", "Up to \(amount(game.rewardIncome * Tuning.airdropIncomeSeconds))")
                    row("Whale airdrop", amount(game.rewardIncome * Tuning.whaleIncomeSeconds))
                    row("Daily quests", "\(amount(game.rewardIncome * 600 * game.dailyRewardMultiplier)) to \(amount(game.rewardIncome * 1_800 * game.dailyRewardMultiplier))")
                }
            }
            .monospacedDigit()
            .navigationTitle("Income")
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

    private func row(_ title: String, _ value: String, bold: Bool = false) -> some View {
        LabeledContent {
            Text(value)
                .fontWeight(bold ? .bold : .regular)
                .foregroundStyle(bold ? Color.primary : Theme.subtext)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(title)
                .fontWeight(bold ? .bold : .regular)
        }
    }
}

/// One miner's part of the income: how many, its boosts, its rate and share.
private struct MinerShareRow: View {
    let miner: MinerID
    let owned: Int
    let mkLevel: Int
    let milestones: Double
    let rate: String
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(miner.emoji)
                    .font(.title3)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(miner.name) ×\(CoinFormat.grouped(owned))")
                        .font(.subheadline.weight(.semibold))
                    Text(boosts)
                        .font(.caption)
                        .foregroundStyle(.subtext)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(rate)/s")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                    Text(CoinFormat.percent(share))
                        .font(.caption)
                        .foregroundStyle(.subtext)
                }
            }
            ProgressView(value: min(max(share, 0), 1))
                .tint(Theme.accent)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var boosts: String {
        var parts = ["Milestones \(CoinFormat.multiplier(milestones))"]
        if mkLevel > 0 { parts.append("Mk \(MinerID.markName(level: mkLevel - 1)) \(CoinFormat.multiplier(pow(Tuning.minerUpgradeMultiplier, Double(mkLevel))))") }
        return parts.joined(separator: " · ")
    }
}
