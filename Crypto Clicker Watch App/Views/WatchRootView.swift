import SwiftUI
import CryptoClickerKit

/// Three vertical pages: mine, steps, and the numbers behind them.
struct WatchRootView: View {
    var body: some View {
        TabView {
            MinePage()
            StepsPage()
            StatsPage()
        }
        .tabViewStyle(.verticalPage)
    }
}

private let watchGradient = LinearGradient(
    colors: [Color(red: 0.97, green: 0.58, blue: 0.10).opacity(0.45), .black],
    startPoint: .top, endPoint: .bottom)

struct MinePage: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let balance = store.balance(at: context.date)
            VStack(spacing: 4) {
                Text(CoinFormat.short(balance))
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: balance))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("+\(CoinFormat.short(store.income(at: context.date)))/s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button(action: store.tap) {
                    Image("coin")
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: .circle)
                .sensoryFeedback(.impact(weight: .light), trigger: store.taps)
                .accessibilityLabel("Mine coin")
                .accessibilityHint("Earns \(CoinFormat.short(store.tapValue)) coins per tap")
                if !store.hasSnapshot {
                    Text("Open Crypto Clicker on your iPhone to sync.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("+\(CoinFormat.short(store.tapValue)) per tap")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.snappy(duration: 0.3), value: balance)
        }
        .containerBackground(watchGradient, for: .tabView)
    }
}

struct StepsPage: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Label("Steps", systemImage: "figure.walk")
                    .font(.headline)
                    .foregroundStyle(.green)
                if let snapshot = store.snapshot, snapshot.stepsConnected {
                    Text(CoinFormat.grouped(max(store.liveSteps ?? 0, store.collectedStepsToday)))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text("steps today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Each step earns \(CoinFormat.short(snapshot.stepValue)) coins")
                        .font(.footnote)
                    if store.uncollectedSteps > 0 {
                        Text("≈ +\(CoinFormat.short(Double(store.uncollectedSteps) * snapshot.stepValue)) coins to collect. Open the iPhone app to sync.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !store.liveStepsEnabled {
                        Button("Show Live Steps") {
                            Task { await store.enableLiveSteps() }
                        }
                        .buttonStyle(.glass)
                        .padding(.top, 4)
                    }
                } else {
                    Text("Connect Apple Health in Crypto Clicker on your iPhone to turn steps into coins.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(Color.green.gradient.opacity(0.35), for: .tabView)
        .task {
            while !Task.isCancelled {
                await store.refreshLiveSteps()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}

struct StatsPage: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Label("Stats", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.97, green: 0.58, blue: 0.10))
                if let snapshot = store.snapshot {
                    row("Income", "\(CoinFormat.short(snapshot.income(at: .now)))/s")
                    row("Per tap", CoinFormat.short(snapshot.tapValue))
                    row("Offline limit", CoinFormat.duration(snapshot.offlineCap))
                    if store.queue.pendingTaps > 0 {
                        row("Taps sending", CoinFormat.grouped(store.queue.pendingTaps))
                    }
                    HStack {
                        Text("Synced")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(snapshot.date, style: .relative)
                    }
                    .font(.footnote)
                }
                Label(store.isPhoneReachable ? "iPhone connected" : "iPhone not reachable",
                      systemImage: store.isPhoneReachable ? "iphone" : "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(Color.blue.gradient.opacity(0.3), for: .tabView)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.footnote)
    }
}
