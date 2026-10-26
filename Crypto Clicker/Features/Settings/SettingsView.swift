import SwiftUI
import CryptoClickerKit

struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.appearanceKey) private var appearance = Appearance.auto
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.tapHapticStrengthKey) private var tapStrength = TapHapticStrength.strong
    @AppStorage(Preferences.soundsKey) private var sounds = false
    @AppStorage(Preferences.coinFinishKey) private var finish = CoinFinish.gold
    @AppStorage(Preferences.notifyMinersKey) private var notifyMiners = false
    @AppStorage(Preferences.notifyDailyKey) private var notifyDaily = false
    @State private var confirmingReset = false
    @State private var notificationsDenied = false
    #if DEBUG
    @State private var showingTestingTools = false
    #endif

    var body: some View {
        let game = store.game
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    // A finish that's locked again (after a reset) shows as the gold it falls back to.
                    let shownFinish = finish.isUnlocked(stars: game.earnedAchievementTiers) ? finish : .gold
                    NavigationLink {
                        CoinFinishPicker()
                    } label: {
                        LabeledContent("Coin Finish") {
                            HStack(spacing: 8) {
                                Text(shownFinish.name)
                                CoinArt(finish: shownFinish)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                }

                Section("Feedback") {
                    Toggle("Haptics", isOn: $haptics)
                    if haptics {
                        Picker("Coin Tap Strength", selection: $tapStrength) {
                            ForEach(TapHapticStrength.allCases) { Text($0.title).tag($0) }
                        }
                    }
                    Toggle("Tap Sound", isOn: $sounds)
                }

                Section {
                    Toggle("When Miners Stop", isOn: $notifyMiners)
                        .onChange(of: notifyMiners) { _, isOn in checkPermission(isOn) { notifyMiners = false } }
                    Toggle("Daily Reward", isOn: $notifyDaily)
                        .onChange(of: notifyDaily) { _, isOn in checkPermission(isOn) { notifyDaily = false } }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Only while the game is closed: when Offline Mining runs out (from half an hour of it), and when a daily reward is waiting.")
                }

                Section {
                    Picker("Difficulty", selection: Binding(get: { game.difficulty }, set: { store.setDifficulty($0) })) {
                        ForEach(Difficulty.allCases) { Text($0.name).tag($0) }
                    }
                } header: {
                    Text("Difficulty")
                } footer: {
                    Text(difficultyFooter(game))
                }

                healthSection(game)

                Section("Apple Watch") {
                    LabeledContent("Status", value: store.watchStatus.title)
                }

                Section {
                    Button("Reset All Progress", role: .destructive) { confirmingReset = true }
                } footer: {
                    Text("Erases coins, miners, upgrades, tokens, prestige points, perks, achievements, daily streaks and statistics.")
                }

                Section("About") {
                    LabeledContent("Version", value: Self.version)
                }

                #if DEBUG
                Section {
                    Button("Testing Tools", systemImage: "ladybug") { showingTestingTools = true }
                } footer: {
                    Text("Add coins, tokens and miners, unlock everything and trigger events. Only in builds run from Xcode.")
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground(tint: Theme.settings) }
            .navigationTitle("Settings")
            .confirmationDialog("Reset all progress?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset Everything", role: .destructive) { store.resetGame() }
            } message: {
                Text("This can't be undone.")
            }
            .alert("Notifications are off", isPresented: $notificationsDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button("Not Now", role: .cancel) {}
            } message: {
                Text("Allow notifications for Crypto Clicker in the Settings app to get these reminders.")
            }
            #if DEBUG
            .sheet(isPresented: $showingTestingTools) { TestingToolsView() }
            #endif
        }
    }

    @ViewBuilder
    private func healthSection(_ game: GameState) -> some View {
        Section {
            if !store.canTrackSteps {
                Text("Apple Health isn't available on this device.")
                    .foregroundStyle(.subtext)
            } else if !game.areStepsUnlocked {
                LabeledContent("Unlocks after \(CoinFormat.grouped(Tuning.stepsUnlockTaps)) taps",
                               value: "\(CoinFormat.grouped(game.tapsUntilSteps)) to go")
            } else if game.steps.isConnected {
                LabeledContent("Each step earns", value: "\(CoinFormat.short(game.stepValue)) coins")
                LabeledContent("Steps rewarded", value: CoinFormat.grouped(game.stats.lifetimeSteps))
                if let lastSync = game.steps.lastSync {
                    LabeledContent("Last synced") {
                        Text(lastSync, style: .relative)
                    }
                }
                Button {
                    Task { await store.syncSteps(force: true) }
                } label: {
                    HStack {
                        Text("Sync Now")
                        Spacer()
                        if store.isSyncingSteps { ProgressView() }
                    }
                }
                .disabled(store.isSyncingSteps)
                Button("Stop Rewarding Steps", role: .destructive) { store.disconnectSteps() }
            } else {
                Button("Connect Apple Health") {
                    Task { await store.connectSteps() }
                }
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Steps from your iPhone and Apple Watch are combined by Apple Health and each one is paid once. If no steps appear, allow access in the Health app under Sharing › Apps › Crypto Clicker.")
        }
    }

    private func difficultyFooter(_ game: GameState) -> String {
        var text = game.difficulty.summary
        if game.runPrestigeMultiplier < game.difficulty.prestigeMultiplier {
            text += " This run's prestige points stay at \(CoinFormat.multiplier(game.runPrestigeMultiplier)), the lowest difficulty used since it began."
        }
        return text
    }

    /// Asks for permission when a reminder is switched on, and switches it back off if it's refused.
    private func checkPermission(_ isOn: Bool, revert: @escaping @MainActor () -> Void) {
        guard isOn else { return }
        Task {
            if await !store.requestNotificationPermission() {
                revert()
                notificationsDenied = true
            }
        }
    }

    private static let version: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }()
}

extension WatchBridge.Status {
    var title: String {
        switch self {
        case .unsupported: "Not available"
        case .notPaired: "No watch paired"
        case .appNotInstalled: "App not installed"
        case .connected: "Connected"
        }
    }
}
