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
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        // Once a second while the screen is lit; once a minute on the dimmed Always On screen,
        // which watchOS otherwise keeps redrawing every second.
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 60 : 1)) { context in
            let balance = store.balance(at: context.date)
            VStack(spacing: 4) {
                Text(CoinFormat.short(balance))
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: balance))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("+\(CoinFormat.rate(store.income(at: context.date)))/s")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 1.00, green: 0.78, blue: 0.40))
                Button(action: store.tap) {
                    Image("coin")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .shadow(color: Color(red: 0.97, green: 0.58, blue: 0.10).opacity(0.5), radius: 8)
                        .contentShape(.circle)
                }
                .buttonStyle(CoinPressStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: store.taps)
                .accessibilityLabel("Mine coin")
                .accessibilityHint("Earns \(CoinFormat.short(store.tapValue)) coins per tap")
                if !store.hasSnapshot {
                    Text("Open Crypto Clicker on your iPhone to sync.")
                        .font(.footnote.weight(.medium))
                        .multilineTextAlignment(.center)
                } else {
                    Text("+\(CoinFormat.short(store.tapValue)) per tap")
                        .font(.footnote.weight(.semibold))
                }
            }
            // Only taps animate the balance; the passing seconds just change the digits, so the
            // screen isn't animating most of the time.
            .animation(.snappy(duration: 0.25), value: store.taps)
        }
        .containerBackground(watchGradient, for: .tabView)
    }
}

struct StepsPage: View {
    @Environment(WatchStore.self) private var store
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Label("Steps", systemImage: "figure.walk")
                    .font(.headline)
                    .foregroundStyle(.green)
                if let snapshot = store.snapshot, snapshot.stepsConnected {
                    Text(CoinFormat.grouped(store.stepsToday))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text("steps today")
                        .font(.headline)
                    // Phones from before steps were paid as they're walked leave the flag out.
                    let nextDay = snapshot.stepsPaidNextDay ?? true
                    if store.stepsToday > 0 {
                        Text("≈ +\(CoinFormat.short(Double(store.stepsToday) * snapshot.stepValue)) coins\(nextDay ? " tomorrow" : " today")")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                    Text(nextDay
                         ? "Each step pays \(CoinFormat.short(snapshot.stepValue)) coins the day after, when you open Crypto Clicker on your iPhone."
                         : "Each step pays \(CoinFormat.short(snapshot.stepValue)) coins, paid when Crypto Clicker on your iPhone syncs your steps.")
                        .font(.body)
                    if !store.liveStepsEnabled {
                        Button("Show Live Steps") {
                            Task { await store.enableLiveSteps() }
                        }
                        .buttonStyle(.glass)
                        .padding(.top, 4)
                    }
                } else {
                    Text("Turn steps into coins in Crypto Clicker on your iPhone. Steps unlock after \(CoinFormat.grouped(Tuning.stepsUnlockTaps)) taps.")
                        .font(.body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(Color.green.gradient.opacity(0.35), for: .tabView)
        // A Health read when the page shows, then once a minute while the screen is lit; none on the
        // dimmed Always On screen.
        .task(id: isLuminanceReduced) {
            guard !isLuminanceReduced else { return }
            while !Task.isCancelled {
                await store.refreshLiveSteps()
                try? await Task.sleep(for: .seconds(60))
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
                    row("Income", "\(CoinFormat.rate(snapshot.income(at: .now)))/s")
                    row("Per tap", CoinFormat.short(snapshot.tapValue))
                    row("Offline Mining", snapshot.offlineCap > 0 ? CoinFormat.duration(snapshot.offlineCap) : "Off")
                    if store.queue.pendingTaps > 0 {
                        row("Taps sending", CoinFormat.grouped(store.queue.pendingTaps))
                    }
                    HStack {
                        Text("Synced")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(snapshot.date, style: .relative)
                    }
                }
                Label(store.isPhoneReachable ? "iPhone connected" : "iPhone not reachable",
                      systemImage: store.isPhoneReachable ? "iphone" : "exclamationmark.triangle")
                    .foregroundStyle(store.isPhoneReachable ? .green : .orange)
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
    }
}

/// The coin shrinks a little while pressed.
private struct CoinPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
