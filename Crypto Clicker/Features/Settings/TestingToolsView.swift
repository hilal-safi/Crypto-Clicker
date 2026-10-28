#if DEBUG
import SwiftUI
import CryptoClickerKit

/// Shortcuts for testing the economy, the mini-games and the rest of the game without hours of
/// play. Only in builds run from Xcode (the Debug configuration): App Store builds leave this
/// screen and its buttons out entirely. Open it from Settings.
struct TestingToolsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.stepsInviteDismissedKey) private var stepsInviteDismissed = false

    private static let coinAmounts: [Double] = [1e6, 1e9, 1e12, 1e15, 1e18, 1e21]

    var body: some View {
        let game = store.game
        let now = Date.now
        let income = game.idleIncome(at: now)
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Balance") {
                        CoinAmount(amount: game.coins, font: .body.weight(.semibold))
                    }
                    LabeledContent("Income", value: "\(CoinFormat.rate(income)) per second")
                    LabeledContent("Each tap", value: CoinFormat.short(game.tapValue(at: now)))
                    LabeledContent("Lifetime coins", value: CoinFormat.short(game.stats.lifetimeCoins))
                    LabeledContent("Prestige", value: game.claimablePrestigePoints > 0
                                   ? "+\(CoinFormat.grouped(game.claimablePrestigePoints)) points ready" : "Not yet")
                } header: {
                    Text("Right now")
                } footer: {
                    Text("These tools are only in builds you run from Xcode. App Store builds don't include them.")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                        ForEach(Self.coinAmounts, id: \.self) { amount in
                            Button("+\(CoinFormat.short(amount))") { store.debugAddCoins(amount) }
                                .accessibilityLabel("Add \(CoinFormat.short(amount)) coins")
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .padding(.vertical, 4)
                    Button("Add 1 Hour of Income (+\(CoinFormat.short(income * 3_600)))") {
                        store.debugAddIncome(seconds: 3_600)
                    }
                    .disabled(income <= 0)
                    Button("Add 1 Day of Income (+\(CoinFormat.short(income * 86_400)))") {
                        store.debugAddIncome(seconds: 86_400)
                    }
                    .disabled(income <= 0)
                } header: {
                    Text("Coins")
                } footer: {
                    Text("Added coins count as mined, so upgrades appear, achievements unlock and prestige points build up just as they would in play.")
                }

                Section {
                    Button("Add 10 of Every Miner") { store.debugAddMiners(10) }
                    Button("Add 100 of Every Miner") { store.debugAddMiners(100) }
                    Button("Give Every Upgrade") { store.debugGiveAllUpgrades() }
                        .disabled(game.upgrades.count == UpgradeID.allCases.count)
                } header: {
                    Text("Shop")
                } footer: {
                    Text("Added miners include the three that normally wait for the first prestige. Mk upgrades appear at 25, 50, 100, 200 and 400 of a miner.")
                }

                Section {
                    LabeledContent("Points", value: "\(CoinFormat.grouped(game.availablePrestigePoints)) to spend · \(CoinFormat.grouped(game.prestigePoints)) earned")
                    Button("Add 10 Prestige Points") { store.debugAddPrestigePoints(10) }
                    Button("Add 1,000 Prestige Points") { store.debugAddPrestigePoints(1_000) }
                    Button("Add 10,000 Prestige Points") { store.debugAddPrestigePoints(10_000) }
                } header: {
                    Text("Prestige")
                } footer: {
                    Text("Points added here raise production and can be spent on perks, without starting over.")
                }

                Section {
                    Button("Complete Today's Quests") { store.debugCompleteQuests() }
                        .disabled(game.daily.quests.allSatisfy { $0.isClaimed || game.isComplete($0) })
                    Button("New Day: Reward, Quests and Challenge") { store.debugResetDaily() }
                } header: {
                    Text("Daily")
                } footer: {
                    Text("A new day makes the daily reward, fresh quests and a new daily challenge available again, and keeps the streak going.")
                }

                Section {
                    LabeledContent("Level \(game.offlineMiningLevel)",
                                   value: game.offlineCap > 0 ? CoinFormat.duration(game.offlineCap) : "Off")
                    Button("Add 4 Hours (8 Levels)") { store.debugAddOfflineMining(levels: 8) }
                        .disabled(game.offlineMiningLevel >= Tuning.offlineMiningMaxLevel)
                    Button("Max It Out (\(CoinFormat.duration(GameState.offlineCap(level: Tuning.offlineMiningMaxLevel))))") {
                        store.debugAddOfflineMining(levels: Tuning.offlineMiningMaxLevel)
                    }
                    .disabled(game.offlineMiningLevel >= Tuning.offlineMiningMaxLevel)
                    Button("Turn It Off", role: .destructive) {
                        store.debugAddOfflineMining(levels: -Tuning.offlineMiningMaxLevel)
                    }
                    .disabled(game.offlineMiningLevel == 0)
                } header: {
                    Text("Offline Mining")
                } footer: {
                    Text("Without it, miners stop a minute after the app closes. Use Pretend I Was Away below to see the welcome-back screen.")
                }

                Section("Arcade") {
                    Button("Unlock Every Mini-Game") { store.debugUnlockAllGames() }
                        .disabled(MiniGame.allCases.allSatisfy(game.isUnlocked))
                    Button("Add 100 of Every Token") { store.debugAddTokens(100) }
                    Button("Add 10,000 of Every Token") { store.debugAddTokens(10_000) }
                    Button("Show Each Game's How to Play Again") {
                        for game in MiniGame.allCases {
                            UserDefaults.standard.removeObject(forKey: Preferences.helpSeenKey(game))
                        }
                    }
                }

                Section {
                    LabeledContent("Taps", value: CoinFormat.grouped(game.stats.taps))
                    Button("Unlock Steps Now") { store.debugUnlockSteps() }
                        .disabled(game.areStepsUnlocked)
                    Button("Show the Steps Invitation Again") { stepsInviteDismissed = false }
                        .disabled(!stepsInviteDismissed)
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Steps unlock after \(CoinFormat.grouped(Tuning.stepsUnlockTaps)) taps. The Simulator starts with no steps: add some by hand in its Health app (Steps › Add Data), then sync.")
                }

                Section {
                    Button("Start a Bull Run") { store.debugStartBullRun() }
                    Button("Drop an Airdrop") {
                        closeThen { store.debugDropAirdrop() }
                    }
                    Button("Drop a Whale Airdrop") {
                        closeThen { store.debugDropAirdrop(.whale) }
                    }
                    Button("Pretend I Was Away for 1 Hour") {
                        closeThen { store.debugPretendAway(3_600) }
                    }
                    Button("Pretend I Was Away for 8 Hours") {
                        closeThen { store.debugPretendAway(8 * 3_600) }
                    }
                } header: {
                    Text("Events")
                } footer: {
                    Text("Airdrops and time away close this screen so you can see them. Right now time away pays for up to \(CoinFormat.duration(game.timeAwayLimit)): the first minute, or the Offline Mining limit once it's longer.")
                }
            }
            .navigationTitle("Testing Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Closes this screen, then runs `action` once the sheet is out of the way.
    private func closeThen(_ action: @escaping @MainActor () -> Void) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            action()
        }
    }
}
#endif
