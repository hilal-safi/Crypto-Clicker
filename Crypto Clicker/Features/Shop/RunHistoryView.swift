import SwiftUI
import Charts
import CryptoClickerKit

/// Every finished run side by side, under the prestige milestones (each unlocks a coin finish) and
/// the run in progress. Opened from the Prestige card and from Statistics.
struct RunHistoryView: View {
    /// Shows a Done button, for the sheet the Prestige card opens.
    var showsDone = false
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false
    @AppStorage(Preferences.runChartMetricKey) private var metric = RunMetric.points

    var body: some View {
        let game = store.game
        List {
            milestones(game)
            currentRun(game)
            if !game.runHistory.isEmpty {
                records(game)
            }
            runs(game)
        }
        .monospacedDigit()
        .navigationTitle("Run History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    // MARK: Sections

    private func milestones(_ game: GameState) -> some View {
        let prestiges = game.stats.prestiges
        let done = prestiges == 0 ? "You haven't prestiged yet."
            : "You've prestiged \(prestiges == 1 ? "once" : "\(CoinFormat.grouped(prestiges)) times")."
        return Section {
            ForEach(CoinFinish.allCases.filter { $0.prestigesNeeded != nil }) { finish in
                MilestoneRow(finish: finish, prestiges: prestiges)
            }
        } header: {
            Text("Milestones")
        } footer: {
            SettingsNote("\(done) Each milestone unlocks a finish for the coin: pick it in Settings, under Coin Finish.")
        }
    }

    private func currentRun(_ game: GameState) -> some View {
        let elapsed = max(0, Date.now.timeIntervalSince(game.runStart))
        let tiers = MinerID.allCases.filter { game.owned($0) > 0 }.count
        return Section {
            ValueRow(title: "Running for", value: CoinFormat.duration(elapsed))
            ValueRow(title: "Coins mined", value: amount(game.stats.runCoins))
            ValueRow(title: "Income", value: "\(rate(game.baseIdleIncome)) per second")
            ValueRow(title: "Miner tiers", value: CoinFormat.grouped(tiers))
            ValueRow(title: "Points ready", value: CoinFormat.grouped(game.claimablePrestigePoints))
        } header: {
            Text("Run \(CoinFormat.grouped(game.stats.prestiges + 1)), so far")
        } footer: {
            // How this run measures up to the best finished ones.
            if let richest = game.richestRun, let productive = game.mostProductiveRun {
                SettingsNote("Best finished runs: \(amount(richest.coins)) mined (run \(richest.number)), \(rate(productive.income)) a second (run \(productive.number)).")
            }
        }
    }

    private func records(_ game: GameState) -> some View {
        Section("Records") {
            if let fastest = game.fastestRun {
                ValueRow(title: "Fastest run", value: "\(CoinFormat.duration(fastest.duration)) · run \(fastest.number)")
            }
            if let biggest = game.biggestRun {
                ValueRow(title: "Most points", value: "\(CoinFormat.grouped(biggest.points)) · run \(biggest.number)")
            }
            if let richest = game.richestRun {
                ValueRow(title: "Most coins mined", value: "\(amount(richest.coins)) · run \(richest.number)")
            }
            if let productive = game.mostProductiveRun {
                ValueRow(title: "Highest income", value: "\(rate(productive.income))/s · run \(productive.number)")
            }
            ValueRow(title: "Runs within two days", value: CoinFormat.grouped(game.stats.quickRuns))
        }
    }

    @ViewBuilder
    private func runs(_ game: GameState) -> some View {
        let history = game.runHistory
        if history.count >= 2 {
            Section {
                RunChart(runs: Array(history.suffix(RunChart.limit)), metric: $metric)
            } header: {
                Text("Compared")
            } footer: {
                if history.count > RunChart.limit {
                    SettingsNote("The latest \(RunChart.limit) runs.")
                }
            }
        }
        // A badge means something only once there are runs to beat.
        let fastest = history.count > 1 ? game.fastestRun?.number : nil
        let biggest = history.count > 1 ? game.biggestRun?.number : nil
        Section {
            if history.isEmpty {
                Text(game.stats.prestiges == 0
                     ? "Each run appears here once you prestige: how long it took, what it mined and the points it earned."
                     : "Your next prestige starts the history: runs from before version 2.1 weren't recorded.")
                    .foregroundStyle(.subtext)
            }
            ForEach(history.reversed()) { run in
                RunRow(run: run, coins: amount(run.coins), income: rate(run.income),
                       isFastest: run.number == fastest, isBiggest: run.number == biggest)
            }
        } header: {
            Text("Runs")
        } footer: {
            if let first = history.first, first.number > 1 {
                SettingsNote(history.count >= Tuning.runHistoryLimit
                             ? "The latest \(Tuning.runHistoryLimit) runs, newest first. Records count every run, including older ones."
                             : "Newest first. Runs from before version 2.1 weren't recorded.")
            }
        }
    }

    private func amount(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exact(value) : CoinFormat.short(value)
    }

    private func rate(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exactRate(value) : CoinFormat.rate(value)
    }
}

/// What the run chart compares.
enum RunMetric: String, CaseIterable, Identifiable {
    case points, length, coins

    var id: Self { self }

    var title: String {
        switch self {
        case .points: "Points"
        case .length: "Length"
        case .coins: "Coins"
        }
    }
}

/// The latest runs as bars: the points each earned, how long each took (in hours) or the coins
/// each mined (on a scale of tens, since each run mines far more than the one before).
private struct RunChart: View {
    static let limit = 30
    let runs: [RunRecord]
    @Binding var metric: RunMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Compare", selection: $metric) {
                ForEach(RunMetric.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            plot
                .frame(height: 180)
                .accessibilityLabel("\(metric.title) of the latest \(runs.count) runs")
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var plot: some View {
        switch metric {
        case .points:
            Chart(runs) { run in
                BarMark(x: .value("Run", run.number), y: .value("Points", run.points))
                    .foregroundStyle(Theme.arcadeButton.gradient)
            }
            .chartXAxisLabel("Run")
        case .length:
            Chart(runs) { run in
                BarMark(x: .value("Run", run.number), y: .value("Hours", run.duration / 3_600))
                    .foregroundStyle(Color.blue.gradient)
            }
            .chartXAxisLabel("Run")
            .chartYAxisLabel("Hours")
        case .coins:
            Chart(runs) { run in
                BarMark(x: .value("Run", run.number), y: .value("Coins", max(run.coins, 1)))
                    .foregroundStyle(Theme.bitcoin.gradient)
            }
            .chartYScale(type: .log)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let coins = value.as(Double.self) { Text(CoinFormat.short(coins)) }
                    }
                }
            }
            .chartXAxisLabel("Run")
        }
    }
}

/// A prestige milestone: the coin finish it unlocks, and whether it's been reached.
private struct MilestoneRow: View {
    let finish: CoinFinish
    let prestiges: Int
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let needed = finish.prestigesNeeded ?? 0
        let reached = prestiges >= needed
        // At the largest text sizes the status goes under the name, rather than squeezing it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            CoinArt(finish: finish)
                .frame(width: 34, height: 34)
                .opacity(reached ? 1 : 0.5)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(needed == 1 ? "First prestige" : "\(needed) prestiges")
                    .font(.subheadline.weight(.semibold))
                Text("\(finish.name) coin finish")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            if reached {
                Label("Unlocked", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.green)
            } else {
                Text("\(CoinFormat.grouped(needed - prestiges)) to go")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.subtext)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One finished run: its points, how long it took, what it mined and how it ended, with a badge
/// for the fastest and the one that earned the most points.
private struct RunRow: View {
    let run: RunRecord
    let coins: String
    let income: String
    let isFastest: Bool
    let isBiggest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Run \(CoinFormat.grouped(run.number))")
                    .font(.headline)
                Spacer(minLength: 8)
                Text("+\(CoinFormat.grouped(run.points)) \(run.points == 1 ? "point" : "points")")
                    .font(.subheadline.weight(.bold))
            }
            Text("\(CoinFormat.duration(run.duration)) · \(coins) mined · \(run.tiers) \(run.tiers == 1 ? "tier" : "tiers")")
                .font(.subheadline)
                .foregroundStyle(.subtext)
            Text("Ended \(run.endedAt.formatted(date: .abbreviated, time: .shortened)) at \(income) a second")
                .font(.subheadline)
                .foregroundStyle(.subtext)
            if isFastest || isBiggest {
                // Side by side, or one under the other at the largest text sizes.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { badges }
                    VStack(alignment: .leading, spacing: 6) { badges }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var badges: some View {
        if isFastest { RunBadge(title: "Fastest", symbol: "bolt.fill", color: .blue) }
        if isBiggest { RunBadge(title: "Most points", symbol: "mountain.2.fill", color: Theme.arcadeButton) }
    }
}

private struct RunBadge: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.footnote.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: .capsule)
    }
}
