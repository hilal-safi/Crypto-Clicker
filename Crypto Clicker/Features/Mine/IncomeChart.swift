import SwiftUI
import Charts
import CryptoClickerKit

/// How much history the income chart shows.
enum IncomeRange: String, CaseIterable, Identifiable {
    case day, week, month, all

    var id: Self { self }

    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .all: "All"
        }
    }

    /// How far back the range reaches (`nil` for all time).
    var span: TimeInterval? {
        switch self {
        case .day: 86_400
        case .week: 7 * 86_400
        case .month: 30 * 86_400
        case .all: nil
        }
    }

    /// The heading over the range's best income.
    var peakTitle: String {
        switch self {
        case .day: "Best in 24 hours"
        case .week: "Best in 7 days"
        case .month: "Best in 30 days"
        case .all: "Best ever"
        }
    }
}

/// Income over time with a Day, Week, Month or All range. The time axis writes what suits the span
/// it shows (minutes in the first hours of a game, then hours, weekdays, dates and months), and the
/// coin axis switches to steps of ten once income has grown a hundredfold, so early and late income
/// both stay visible.
struct IncomeChartCard: View {
    let samples: [IncomeSample]
    /// Right now, so the line always reaches the present.
    let current: IncomeSample
    @AppStorage(Preferences.incomeChartRangeKey) private var range = IncomeRange.day

    var body: some View {
        let data = IncomeChartData(samples: samples, current: current, range: range)
        VStack(alignment: .leading, spacing: 14) {
            Picker("Range", selection: $range) {
                ForEach(IncomeRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            header(data)
            if data.isDrawable {
                IncomePlot(data: data)
                    .frame(height: 210)
                    .accessibilityLabel("Income chart, \(range.title)")
                    .accessibilityValue("From \(CoinFormat.rate(data.points.first?.income ?? 0)) to \(CoinFormat.rate(current.income)) coins per second, best \(CoinFormat.rate(data.peak))")
                if let multiple = data.logStepMultiple {
                    Label("The scale grows \(multiple) times per line, so early and late income both show.",
                          systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
            } else {
                emptyState(hasIncome: current.income > 0)
            }
        }
        .padding(.vertical, 6)
    }

    private func header(_ data: IncomeChartData) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Right now")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.subtext)
                Text("\(CoinFormat.rate(current.income))/s")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(range.peakTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.subtext)
                Text("\(CoinFormat.rate(data.peak))/s")
                    .font(.title3.bold().monospacedDigit())
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func emptyState(hasIncome: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(hasIncome ? "Your income line starts here" : "Buy a miner to start your income line")
                .font(.headline)
            Text("The chart adds a point every minute while you play.")
                .font(.subheadline)
                .foregroundStyle(.subtext)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 170)
    }
}

/// The points the chart draws for a range, and how to scale them.
struct IncomeChartData {
    /// Oldest first, ending with the present.
    let points: [IncomeSample]
    let start: Date
    let end: Date
    /// The best income in the range.
    let peak: Double
    /// The coin axis: from `bottom` to `top`, logarithmic when `logTicks` isn't empty.
    let bottom: Double
    let top: Double
    /// The coin axis's lines on a log scale (empty on a linear one).
    let logTicks: [Double]

    /// The chart needs a minute of history and some income to draw anything worth seeing.
    static let minimumSpan: TimeInterval = 60

    init(samples: [IncomeSample], current: IncomeSample, range: IncomeRange) {
        let end = current.date
        let cutoff = range.span.map { end.addingTimeInterval(-$0) }
        var points = samples.filter { sample in
            sample.date < end && cutoff.map { sample.date >= $0 } ?? true
        }
        // A range that starts partway through the history begins at its left edge, at the income
        // of the sample just before it, so the line doesn't start partway across.
        if let cutoff, points.first?.date != cutoff, let before = samples.last(where: { $0.date < cutoff }) {
            points.insert(IncomeSample(date: cutoff, income: before.income), at: 0)
        }
        points.append(current)
        let peak = points.map(\.income).max() ?? 0
        let lowest = points.map(\.income).filter { $0 > 0 }.min() ?? 0
        let scale = Self.scale(lowest: lowest, peak: peak)
        if !scale.ticks.isEmpty {
            // A log scale can't show zero: those points (the very start, a reset) are left out.
            points = points.filter { $0.income > 0 }
        }
        self.points = points
        self.peak = peak
        self.end = end
        start = points.first?.date ?? end
        bottom = scale.bottom
        top = scale.top
        logTicks = scale.ticks
    }

    /// A linear axis from zero while income stays within a hundredfold; past that, a log axis
    /// from the power of ten below the lowest income, with about four lines.
    private static func scale(lowest: Double, peak: Double) -> (bottom: Double, top: Double, ticks: [Double]) {
        guard lowest > 0, peak / lowest > 100 else {
            return (0, peak > 0 ? peak * 1.15 : 1, [])
        }
        let low = log10(lowest).rounded(.down)
        let bottom = pow(10, low)
        let top = max(peak * 1.6, bottom * 10)
        let high = log10(top).rounded(.down)
        let every = max(1, Int((Double(high - low) / 4).rounded(.up)))
        let ticks = stride(from: Int(low), through: Int(high), by: every).map { pow(10, Double($0)) }
        return (bottom, top, ticks)
    }

    var isDrawable: Bool {
        points.count >= 2 && peak > 0 && end.timeIntervalSince(start) >= Self.minimumSpan
    }

    /// How many times each line on a log scale is the one below: "10", "100"...
    var logStepMultiple: String? {
        guard logTicks.count >= 2 else { return nil }
        let multiple = (logTicks[1] / logTicks[0]).rounded()
        return multiple < 1e6 ? CoinFormat.grouped(Int(multiple)) : CoinFormat.short(multiple)
    }
}

/// The plot itself: a filled line from the range's start to now, ending in a dot.
private struct IncomePlot: View {
    let data: IncomeChartData

    private static let fill = LinearGradient(colors: [Theme.accent.opacity(0.38), Theme.accent.opacity(0.04)],
                                             startPoint: .top, endPoint: .bottom)

    var body: some View {
        let axis = TimeAxisStyle(span: data.end.timeIntervalSince(data.start))
        Chart {
            ForEach(data.points, id: \.date) { sample in
                AreaMark(x: .value("Time", sample.date),
                         yStart: .value("Floor", data.bottom),
                         yEnd: .value("Coins per second", sample.income))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Self.fill)
                LineMark(x: .value("Time", sample.date), y: .value("Coins per second", sample.income))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Theme.accent)
            }
            if let now = data.points.last {
                PointMark(x: .value("Time", now.date), y: .value("Coins per second", now.income))
                    .symbolSize(110)
                    .foregroundStyle(Theme.accent)
            }
        }
        .chartXScale(domain: data.start...data.end)
        .chartYScale(domain: data.bottom...data.top, type: data.logTicks.isEmpty ? .linear : .log)
        .chartXAxis {
            AxisMarks(values: .stride(by: axis.component, count: axis.count)) { _ in
                AxisGridLine()
                AxisValueLabel(format: axis.format)
                    .font(.footnote.weight(.semibold))
            }
        }
        .chartYAxis {
            if data.logTicks.isEmpty {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    incomeMark(value)
                }
            } else {
                AxisMarks(values: data.logTicks) { value in
                    incomeMark(value)
                }
            }
        }
    }

    @AxisMarkBuilder
    private func incomeMark(_ value: AxisValue) -> some AxisMark {
        AxisGridLine()
        AxisValueLabel {
            if let income = value.as(Double.self) {
                Text(CoinFormat.rate(income))
                    .font(.footnote.weight(.semibold))
            }
        }
    }
}

/// Where the time axis puts its labels for a span of time, and how it writes them: hours and
/// minutes for the first hours, then hours, weekdays, dates and finally months.
struct TimeAxisStyle {
    let component: Calendar.Component
    let count: Int
    let format: Date.FormatStyle

    init(span: TimeInterval) {
        switch span {
        case ..<(3 * 3_600):
            component = .minute
            count = Self.step(for: span, unit: 60, choices: [1, 2, 5, 10, 15, 30, 60])
            format = .dateTime.hour().minute()
        case ..<(36 * 3_600):
            component = .hour
            count = Self.step(for: span, unit: 3_600, choices: [1, 2, 3, 4, 6, 8, 12])
            format = .dateTime.hour()
        case ..<(10 * 86_400):
            component = .day
            count = Self.step(for: span, unit: 86_400, choices: [1, 2, 3])
            format = .dateTime.weekday(.abbreviated)
        case ..<(120 * 86_400):
            component = .day
            count = Self.step(for: span, unit: 86_400, choices: [3, 5, 7, 10, 14, 30])
            format = .dateTime.month(.abbreviated).day()
        default:
            component = .month
            count = Self.step(for: span, unit: 30 * 86_400, choices: [1, 2, 3, 6, 12, 24])
            format = .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    /// The smallest step that leaves about four labels across `span`.
    private static func step(for span: TimeInterval, unit: TimeInterval, choices: [Int]) -> Int {
        choices.first { Double($0) * unit * 4 >= span } ?? choices[choices.count - 1]
    }
}
