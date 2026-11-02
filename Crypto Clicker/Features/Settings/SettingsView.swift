import SwiftUI
import CryptoClickerKit

/// The Settings tab: How to Play and Statistics first, then the game's settings. Footnotes use
/// full-size text: nothing here is small grey print.
struct SettingsView: View {
    /// Goes up by one each time another screen asks to open How to Play (the home screen's tip).
    var howToPlayRequests = 0
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.appearanceKey) private var appearance = Appearance.auto
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @AppStorage(Preferences.tapHapticStrengthKey) private var tapStrength = TapHapticStrength.strong
    @AppStorage(Preferences.soundsKey) private var sounds = false
    @AppStorage(Preferences.coinFinishKey) private var finish = CoinFinish.gold
    @AppStorage(Preferences.notifyMinersKey) private var notifyMiners = false
    @AppStorage(Preferences.notifyDailyKey) private var notifyDaily = false
    @State private var showingHowToPlay = false
    @State private var handledHowToPlayRequests = 0
    @State private var confirmingReset = false
    @State private var notificationsDenied = false
    #if DEBUG
    @State private var showingTestingTools = false
    #endif

    var body: some View {
        let game = store.game
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        HowToPlayView()
                    } label: {
                        SettingsLinkLabel(title: "How to Play", detail: "Every part of the game, and each game's rules",
                                          symbol: "questionmark.circle.fill", color: Theme.accent)
                    }
                    NavigationLink {
                        StatsPage()
                    } label: {
                        SettingsLinkLabel(title: "Statistics", detail: "Income chart, records and your journey",
                                          symbol: "chart.bar.xaxis", color: .blue)
                    }
                }

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
                    SettingsNote("Only while the game is closed: when Offline Mining runs out (from half an hour of it), and when a daily reward is waiting.")
                }

                difficultySection(game)

                healthSection(game)

                Section("Apple Watch") {
                    LabeledContent("Status", value: store.watchStatus.title)
                }

                Section {
                    Button("Reset All Progress", role: .destructive) { confirmingReset = true }
                } footer: {
                    SettingsNote("Erases coins, miners, upgrades, power-ups, tokens, prestige points, perks, achievements, daily streaks and statistics.")
                }

                Section("About") {
                    LabeledContent("Version", value: Self.version)
                }

                #if DEBUG
                Section {
                    Button("Testing Tools", systemImage: "ladybug") { showingTestingTools = true }
                } footer: {
                    SettingsNote("Add coins, tokens and miners, unlock everything and trigger events. Only in builds run from Xcode.")
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground(tint: Theme.settings) }
            .navigationTitle("Settings")
            .navigationDestination(isPresented: $showingHowToPlay) { HowToPlayView() }
            .onAppear { showHowToPlayIfAsked() }
            .onChange(of: howToPlayRequests) { _, _ in showHowToPlayIfAsked() }
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

    /// Opens How to Play once for each request from the home screen.
    private func showHowToPlayIfAsked() {
        guard handledHowToPlayRequests != howToPlayRequests else { return }
        handledHowToPlayRequests = howToPlayRequests
        showingHowToPlay = true
    }

    /// The three difficulties side by side with what each changes, the current one ticked, and how
    /// switching works during a run.
    private func difficultySection(_ game: GameState) -> some View {
        Section {
            ForEach(Difficulty.allCases) { difficulty in
                Button {
                    store.setDifficulty(difficulty)
                } label: {
                    DifficultyRow(difficulty: difficulty, isSelected: game.difficulty == difficulty)
                }
                .buttonStyle(.plain)
            }
            if game.runPrestigeMultiplier < game.difficulty.prestigeMultiplier {
                let kept = Difficulty.allCases.first { $0.prestigeMultiplier == game.runPrestigeMultiplier } ?? .easy
                Label("This run keeps \(kept.name)'s prestige points (\(CoinFormat.multiplier(kept.prestigeMultiplier))), the easiest difficulty used since it began. Your next run gets \(game.difficulty.name)'s \(CoinFormat.multiplier(game.difficulty.prestigeMultiplier)).",
                      systemImage: "info.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
        } header: {
            Text("Difficulty")
        } footer: {
            SettingsNote("Easy makes mining faster but prestiges pay fewer points; Hard makes it slower but prestiges pay more. Everything that follows your income moves with your miners: the income part of each tap, steps, airdrops and game prizes. Prices stay the same. A run's prestige points use the easiest difficulty picked since it began, so switching to Hard just before prestiging doesn't pay extra; a run that hasn't started mining yet takes the new difficulty in full.")
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
                let today = store.today
                LabeledContent("Each step pays", value: "\(CoinFormat.short(game.stepValue)) coins, the next day")
                if game.steps.todayKey == today {
                    LabeledContent("Today so far", value: "\(CoinFormat.grouped(game.steps.todaySteps)) steps · ≈ +\(CoinFormat.short(game.pendingStepCoins(today: today))) tomorrow")
                }
                LabeledContent("Steps walked", value: CoinFormat.grouped(game.stats.lifetimeSteps))
                LabeledContent("Steps paid for", value: CoinFormat.grouped(game.stats.stepsPaid))
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
            SettingsNote("Each day's steps are paid the next day, at that day's step value; today's count toward quests and achievements right away. Steps from your iPhone and Apple Watch are combined by Apple Health and each one is paid once. If no steps appear, allow access in the Health app under Sharing › Apps › Crypto Clicker.")
        }
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

/// A Settings footnote in full-size text with strong contrast, instead of the system's small grey.
struct SettingsNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.subtext)
            .textCase(nil)
            .padding(.top, 2)
    }
}

/// A row that opens a page: a colored icon, a title and a line about it.
private struct SettingsLinkLabel: View {
    let title: String
    let detail: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(color.gradient, in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
        }
        .padding(.vertical, 2)
    }
}

/// One difficulty: what it does to production and to prestige points, ticked when it's the one in use.
private struct DifficultyRow: View {
    let difficulty: Difficulty
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? .white : color)
                .frame(width: 40, height: 40)
                .background(isSelected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.15)), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(difficulty.name)
                    .font(.headline)
                Label(production, systemImage: "cpu")
                Label(prestige, systemImage: "rosette")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? color : Theme.subtext)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var production: String {
        let factor = difficulty.productionMultiplier
        if factor == 1 { return "Miners produce the usual amount" }
        return factor > 1 ? "Miners produce \(CoinFormat.percent(factor - 1)) more" : "Miners produce \(CoinFormat.percent(1 - factor)) less"
    }

    private var prestige: String {
        let factor = difficulty.prestigeMultiplier
        if factor == 1 { return "Prestiges earn the usual points" }
        if factor == 0.5 { return "Prestiges earn half the points" }
        return factor > 1 ? "Prestiges earn \(CoinFormat.percent(factor - 1)) more points" : "Prestiges earn \(CoinFormat.percent(1 - factor)) fewer points"
    }

    private var symbol: String {
        switch difficulty {
        case .easy: "tortoise.fill"
        case .normal: "scalemass.fill"
        case .hard: "flame.fill"
        }
    }

    private var color: Color {
        switch difficulty {
        case .easy: .green
        case .normal: .blue
        case .hard: .red
        }
    }
}
