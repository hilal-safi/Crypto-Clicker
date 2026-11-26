import Foundation
import CryptoClickerKit

// The run history (iOS: RunHistoryView): the prestige milestones, each unlocking a coin finish,
// the run in progress, the records, a chart of the latest runs and every finished run.

/// The run history (view "runHistory"), opened from the Prestige card and from Statistics.
struct RunHistoryView: Encodable {
    let milestones: [PrestigeMilestoneView]
    /// "You've prestiged 3 times. Each milestone unlocks a finish for the coin: …"
    let milestonesFooter: String
    /// "Run 4, so far"
    let currentTitle: String
    let current: [LineView]
    /// How this run measures up to the best finished ones.
    let currentFooter: String?
    /// The fastest run, the most points and so on, once a run has finished; empty before.
    let records: [LineView]
    /// The latest runs (up to 30), oldest first, for the chart; empty with fewer than two.
    let chart: [RunBarView]
    /// The coins chart's scale (it's logarithmic): a line at each power of ten it spans.
    let coinTicks: [ChartTickView]
    let chartFooter: String?
    /// Every run kept, newest first.
    let runs: [RunRowView]
    /// Shown while there are no runs.
    let runsEmpty: String?
    let runsFooter: String?
}

/// A prestige milestone (iOS: MilestoneRow): the coin finish it unlocks, and whether it's reached.
struct PrestigeMilestoneView: Encodable {
    /// The finish (`CoinFinish` raw value), for its picture.
    let finish: String
    /// "First prestige", "5 prestiges"
    let title: String
    /// "Forged coin finish"
    let detail: String
    let reached: Bool
    /// "Unlocked", or "3 to go"
    let status: String
}

/// One run on the chart: the points it earned, how long it took (in hours) and the coins it mined.
struct RunBarView: Encodable {
    let number: Int
    let points: Double
    let hours: Double
    let coins: Double
}

struct ChartTickView: Encodable {
    let value: Double
    let label: String
}

/// One finished run (iOS: RunRow).
struct RunRowView: Encodable {
    let number: Int
    /// "Run 3"
    let title: String
    /// "+12 points"
    let points: String
    /// "2d 4h · 1.2B mined · 7 tiers"
    let line: String
    /// When it ended (seconds since 1970), and its income then: "12.3K".
    let endedAt: Double
    let income: String
    let isFastest: Bool
    let isBiggest: Bool
}

extension GameSession {
    /// How many runs the chart compares.
    static let runChartLimit = 30

    var runHistoryView: RunHistoryView {
        let game = state
        let stats = game.stats
        let prestiges = stats.prestiges
        let history = game.runHistory

        let done = prestiges == 0 ? "You haven't prestiged yet."
            : "You've prestiged \(prestiges == 1 ? "once" : "\(CoinFormat.grouped(prestiges)) times")."
        let milestones = CoinFinish.allCases.compactMap { finish -> PrestigeMilestoneView? in
            guard let needed = finish.prestigesNeeded else { return nil }
            let reached = prestiges >= needed
            return PrestigeMilestoneView(
                finish: finish.rawValue, title: needed == 1 ? "First prestige" : "\(needed) prestiges",
                detail: "\(finish.name) coin finish", reached: reached,
                status: reached ? "Unlocked" : "\(CoinFormat.grouped(needed - prestiges)) to go")
        }

        let elapsed = max(0, now.timeIntervalSince(game.runStart))
        let tiers = MinerID.allCases.filter { game.owned($0) > 0 }.count
        let current: [LineView] = [
            .value("Running for", CoinFormat.duration(elapsed)),
            .value("Coins mined", amount(stats.runCoins)),
            .value("Income", "\(rateText(game.baseIdleIncome)) per second"),
            .value("Miner tiers", CoinFormat.grouped(tiers)),
            .value("Points ready", CoinFormat.grouped(game.claimablePrestigePoints)),
        ]
        var currentFooter: String?
        if let richest = game.richestRun, let productive = game.mostProductiveRun {
            currentFooter = "Best finished runs: \(amount(richest.coins)) mined (run \(richest.number)), \(rateText(productive.income)) a second (run \(productive.number))."
        }

        var records: [LineView] = []
        if !history.isEmpty {
            if let fastest = game.fastestRun {
                records.append(.value("Fastest run", "\(CoinFormat.duration(fastest.duration)) · run \(fastest.number)"))
            }
            if let biggest = game.biggestRun {
                records.append(.value("Most points", "\(CoinFormat.grouped(biggest.points)) · run \(biggest.number)"))
            }
            if let richest = game.richestRun {
                records.append(.value("Most coins mined", "\(amount(richest.coins)) · run \(richest.number)"))
            }
            if let productive = game.mostProductiveRun {
                records.append(.value("Highest income", "\(rateText(productive.income))/s · run \(productive.number)"))
            }
            records.append(.value("Runs within two days", CoinFormat.grouped(stats.quickRuns)))
        }

        let charted = history.count >= 2 ? Array(history.suffix(Self.runChartLimit)) : []
        let chart = charted.map { run in
            RunBarView(number: run.number, points: Double(run.points), hours: finite(run.duration / 3_600),
                       coins: finite(max(run.coins, 1)))
        }

        // A badge means something only once there are runs to beat.
        let fastest = history.count > 1 ? game.fastestRun?.number : nil
        let biggest = history.count > 1 ? game.biggestRun?.number : nil
        var runsFooter: String?
        if let first = history.first, first.number > 1 {
            runsFooter = history.count >= Tuning.runHistoryLimit
                ? "The latest \(Tuning.runHistoryLimit) runs, newest first. Records count every run, including older ones."
                : "Newest first. Runs from before version 2 weren't recorded."
        }
        return RunHistoryView(
            milestones: milestones,
            milestonesFooter: "\(done) Each milestone unlocks a finish for the coin: pick it in Settings, under Coin Finish.",
            currentTitle: "Run \(CoinFormat.grouped(prestiges + 1)), so far",
            current: current, currentFooter: currentFooter, records: records,
            chart: chart, coinTicks: Self.powersOfTen(spanning: chart.map(\.coins)),
            chartFooter: history.count > Self.runChartLimit ? "The latest \(Self.runChartLimit) runs." : nil,
            runs: history.reversed().map { run in
                RunRowView(
                    number: run.number, title: "Run \(CoinFormat.grouped(run.number))",
                    points: "+\(CoinFormat.grouped(run.points)) \(run.points == 1 ? "point" : "points")",
                    line: "\(CoinFormat.duration(run.duration)) · \(amount(run.coins)) mined · \(run.tiers) \(run.tiers == 1 ? "tier" : "tiers")",
                    endedAt: run.endedAt.timeIntervalSince1970, income: rateText(run.income),
                    isFastest: run.number == fastest, isBiggest: run.number == biggest)
            },
            runsEmpty: history.isEmpty
                ? (prestiges == 0
                    ? "Each run appears here once you prestige: how long it took, what it mined and the points it earned."
                    : "Your next prestige starts the history: runs from before version 2 weren't recorded.")
                : nil,
            runsFooter: runsFooter)
    }

    /// Lines for a logarithmic scale: each power of ten from below the smallest value to above the
    /// largest, every second or third one when there are many, labelled as the game writes coins.
    static func powersOfTen(spanning values: [Double]) -> [ChartTickView] {
        let positive = values.filter { $0.isFinite && $0 > 0 }
        guard let low = positive.min(), let high = positive.max() else { return [] }
        let first = Int(log10(low).rounded(.down))
        let last = max(first + 1, Int(log10(high).rounded(.up)))
        let count = last - first + 1
        let step = count > 10 ? 3 : count > 5 ? 2 : 1
        return stride(from: first, through: last, by: step).map { power -> ChartTickView in
            let value = pow(10, Double(power))
            return ChartTickView(value: value, label: CoinFormat.short(value))
        }
    }
}
