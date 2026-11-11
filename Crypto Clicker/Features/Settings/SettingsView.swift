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
    @AppStorage(Preferences.coinRimKey) private var rim = CoinRim.plain
    @AppStorage(Preferences.coinTapEffectKey) private var tapEffect = CoinTapEffect.none
    @AppStorage(Preferences.notifyMinersKey) private var notifyMiners = false
    @AppStorage(Preferences.notifyDailyKey) private var notifyDaily = false
    @AppStorage(Preferences.liveActivityKey) private var liveActivity = true
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
                        SettingsLinkLabel(title: "How to Play", detail: "Rules for every part of the game",
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
                    NumberFormatPicker()
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
                    NavigationLink {
                        CoinRimPicker()
                    } label: {
                        LabeledContent("Coin Rim", value: (rim.isUnlocked(stars: game.earnedAchievementTiers) ? rim : .plain).name)
                    }
                    NavigationLink {
                        CoinTapEffectPicker()
                    } label: {
                        LabeledContent("Tap Effect", value: (tapEffect.isUnlocked(stars: game.earnedAchievementTiers) ? tapEffect : .none).name)
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
                    SettingsHeader("Notifications", info: "Sent only while the game is closed: when Offline Mining runs out (if you have half an hour of it or more), and when a daily reward is waiting to be claimed.")
                } footer: {
                    SettingsNote("Sent only while the game is closed.")
                }

                Section {
                    Toggle("Live Activity", isOn: $liveActivity)
                        .onChange(of: liveActivity) { _, _ in store.liveActivitySettingChanged() }
                } header: {
                    SettingsHeader("Lock Screen and Widgets", info: "The Live Activity shows your coin and balance on the Lock Screen and in the Dynamic Island while the game is closed: what your miners earn a second, how long they keep going, and what you'll have when they stop. It updates each time you leave the game.\n\nThe Balance widget does the same on the Home Screen or the Lock Screen, its number growing as your miners earn. To add it, touch and hold an empty spot, tap Edit, then Add Widget, and pick Crypto Clicker.")
                } footer: {
                    SettingsNote("Add the Balance widget from the Home Screen or Lock Screen editor.")
                }

                difficultySection(game)

                healthSection(game)

                Section("Apple Watch") {
                    LabeledContent("Status", value: store.watchStatus.title)
                }

                Section {
                    LabeledContent("Version", value: Self.version)
                    #if DEBUG
                    Button("Testing Tools", systemImage: "ladybug") { showingTestingTools = true }
                    #endif
                } header: {
                    Text("About")
                } footer: {
                    #if DEBUG
                    SettingsNote("Testing Tools are only in builds run from Xcode.")
                    #endif
                }

                Section {
                    Button("Reset All Progress", role: .destructive) { confirmingReset = true }
                } header: {
                    Text("Progress")
                } footer: {
                    SettingsNote("Erases everything, prestige and achievements included.")
                }
            }
            // The same gap between every pair of sections, footer or not, and room above the
            // tab bar at the bottom.
            .listSectionSpacing(28)
            .contentMargins(.bottom, 24, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background { AppBackground(tint: Theme.settings) }
            .navigationTitle("Settings")
            .navigationDestination(isPresented: $showingHowToPlay) { HowToPlayView() }
            .onAppear { showHowToPlayIfAsked() }
            .onChange(of: howToPlayRequests) { _, _ in showHowToPlayIfAsked() }
            // A centred alert, not a popover pointing at whichever row it lands near.
            .alert("Reset all progress?", isPresented: $confirmingReset) {
                Button("Reset Everything", role: .destructive) { store.resetGame() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your coins, miners, prestige, achievements and records will be erased. This can't be undone.")
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

    /// The three difficulties, one line each with what they change, the current one ticked. How
    /// switching works during a run is behind the ⓘ.
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
                Label("This run keeps \(kept.name)'s prestige points until you prestige.", systemImage: "info.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
        } header: {
            SettingsHeader("Difficulty", info: "Easy mines faster, but prestiges pay fewer points; Hard mines slower and pays more. Everything that follows your income moves with it (the income part of each tap, steps, airdrops and game prizes); prices stay the same.\n\nA run's prestige points use the easiest difficulty picked since it began, so switching to Hard just before prestiging doesn't pay extra. Before your first miner, a new difficulty applies in full.")
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
                LabeledContent("Each step pays", value: Self.coins(game.stepValue))
                if game.steps.todayKey == today {
                    LabeledContent("Today", value: "\(CoinFormat.grouped(game.steps.todaySteps)) steps")
                    if game.stepsPaidNextDay(today: today) {
                        LabeledContent("Pays tomorrow", value: "≈ \(Self.coins(game.pendingStepCoins(today: today)))")
                    }
                }
                LabeledContent("Steps walked", value: CoinFormat.grouped(game.stats.lifetimeSteps))
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
            SettingsHeader("Apple Health", info: "Steps are paid as you walk, each time the game syncs with Apple Health, and count toward quests and achievements right away. Your first day's steps are the exception: they're paid the next day, at your step value then, so walking can't skip the opening. Steps from your iPhone and Apple Watch are combined by Apple Health, and each one is paid once.\n\nIf no steps appear, allow access in the Health app under Sharing › Apps › Crypto Clicker.")
        } footer: {
            SettingsNote(game.stepsPaidNextDay(today: store.today)
                         ? "Today's steps are paid tomorrow; after that, as you walk."
                         : "Steps are paid as you walk.")
        }
    }

    /// "1 coin", "250 coins", "1.2M coins".
    private static func coins(_ amount: Double) -> String {
        amount == 1 ? "1 coin" : "\(CoinFormat.short(amount)) coins"
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
    let text: Text

    init(_ text: LocalizedStringKey) {
        self.text = Text(text)
    }

    @_disfavoredOverload
    init<Content: StringProtocol>(_ text: Content) {
        self.text = Text(text)
    }

    var body: some View {
        text
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

/// One difficulty: its name and what it does to mining and prestige points, in the same label and
/// value pairs as the Arcade's records, ticked when it's the one in use.
private struct DifficultyRow: View {
    let difficulty: Difficulty
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? .white : color)
                .frame(width: 34, height: 34)
                .background(isSelected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.15)), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(difficulty.name)
                    .font(.headline)
                RecordLine(facts: effects, tint: color)
            }
            Spacer(minLength: 8)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// MINING ×1.5 · PRESTIGE ×0.5, the same way for every difficulty.
    private var effects: [RecordFact] {
        [RecordFact(String(localized: "Mining"), CoinFormat.multiplier(difficulty.productionMultiplier)),
         RecordFact(String(localized: "Prestige"), CoinFormat.multiplier(difficulty.prestigeMultiplier))]
    }

    private var symbol: String {
        switch difficulty {
        case .easy: "gauge.with.dots.needle.0percent"
        case .normal: "gauge.with.dots.needle.50percent"
        case .hard: "gauge.with.dots.needle.100percent"
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

/// A section header with an ⓘ at its end that explains the section in a popover, so the page
/// doesn't carry paragraphs.
struct SettingsHeader: View {
    let title: Text
    let info: Text
    @State private var isShowingInfo = false

    init(_ title: LocalizedStringKey, info: LocalizedStringKey) {
        self.title = Text(title)
        self.info = Text(info)
    }

    @_disfavoredOverload
    init<Title: StringProtocol, Info: StringProtocol>(_ title: Title, info: Info) {
        self.title = Text(title)
        self.info = Text(info)
    }

    var body: some View {
        HStack {
            title
            Spacer()
            Button {
                isShowingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .textCase(nil)
            .accessibilityLabel(Text("About \(title)"))
            .popover(isPresented: $isShowingInfo) {
                VStack(alignment: .leading, spacing: 8) {
                    title
                        .font(.headline)
                    info
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Full-strength text (black, or near-white in dark mode), not the section
                // header's grey that the popover would otherwise inherit.
                .foregroundStyle(Color.primary)
                .padding(16)
                .frame(width: 300, alignment: .leading)
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}
