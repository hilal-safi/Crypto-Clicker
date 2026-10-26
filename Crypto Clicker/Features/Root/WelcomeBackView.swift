import SwiftUI
import CryptoClickerKit

/// Shown after time away: what the miners earned while the app was closed, and on request a
/// breakdown of where every coin came from.
struct WelcomeBackView: View {
    let report: OfflineReport
    /// Opens the Shop at its power-ups. Called after this sheet starts closing.
    let openPowerUps: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showsBreakdown = false
    @State private var detent = PresentationDetent.medium

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    summary
                    if report.wasCapped {
                        offlineMiningNote
                    }
                    Button {
                        withAnimation(.snappy) {
                            showsBreakdown.toggle()
                            if showsBreakdown { detent = .large }
                        }
                    } label: {
                        Label(showsBreakdown ? "Hide Breakdown" : "See Breakdown",
                              systemImage: showsBreakdown ? "chevron.up" : "list.bullet.rectangle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    if showsBreakdown {
                        OfflineBreakdown(report: report)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Collect")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
    }

    private var summary: some View {
        VStack(spacing: 14) {
            CoinIcon(size: 64)
            VStack(spacing: 6) {
                Text("Welcome back!")
                    .font(.title.bold())
                Text("You were away for \(CoinFormat.duration(report.elapsed)).")
                    .font(.body)
                    .foregroundStyle(.subtext)
            }
            VStack(spacing: 4) {
                Text("Your miners earned")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.subtext)
                CoinAmount(amount: report.earned, font: .system(size: 40, weight: .bold, design: .rounded), iconSize: 34)
            }
        }
        .multilineTextAlignment(.center)
    }

    /// Explains why only part of the time was paid, with a shortcut to Offline Mining.
    private var offlineMiningNote: some View {
        let hasOfflineMining = report.offlineCap > 0
        return VStack(spacing: 10) {
            Label {
                Text(hasOfflineMining
                     ? "Offline Mining paid for \(CoinFormat.duration(report.credited)) of that. Level it up to earn for longer."
                     : "Miners stop a minute after you leave. Offline Mining keeps them earning while the app is closed.")
            } icon: {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.indigo)
            }
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                dismiss()
                openPowerUps()
            } label: {
                Text(hasOfflineMining ? "Upgrade Offline Mining" : "Get Offline Mining")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .rowCard()
    }
}

/// Where the coins earned while away came from: time, sources and multipliers.
private struct OfflineBreakdown: View {
    let report: OfflineReport

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Time") {
                row("Away", CoinFormat.duration(report.elapsed))
                row("Paid for", paidFor)
                if report.boostedSeconds > 0 {
                    row("Bull Run \(CoinFormat.multiplier(report.boostMultiplier))", CoinFormat.duration(report.boostedSeconds))
                }
            }
            section("Earned by") {
                ForEach(report.sources) { source in
                    SourceRow(source: source, share: report.earned > 0 ? source.coins / report.earned : 0)
                }
                Divider()
                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    CoinAmount(amount: report.earned, font: .subheadline.weight(.bold))
                }
            }
            section("Production multipliers") {
                let multipliers = report.multipliers
                row("Upgrades", CoinFormat.multiplier(multipliers.upgrades))
                row("Prestige", CoinFormat.multiplier(multipliers.prestige))
                row("Achievements", CoinFormat.multiplier(multipliers.achievements))
                row("Difficulty", CoinFormat.multiplier(multipliers.difficulty))
                Divider()
                HStack {
                    Text("All together")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text(CoinFormat.multiplier(multipliers.total))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
            }
        }
    }

    private var paidFor: String {
        if report.offlineCap == 0 { return "\(CoinFormat.duration(report.credited)) (no Offline Mining)" }
        if report.wasCapped { return "\(CoinFormat.duration(report.credited)) (Offline Mining limit)" }
        return CoinFormat.duration(report.credited)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rowCard()
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.subtext)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

/// One source of coins with its share of the total.
private struct SourceRow: View {
    let source: OfflineReport.Source
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                icon
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.subtext)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    CoinAmount(amount: source.coins, font: .subheadline.weight(.semibold))
                    Text(CoinFormat.percent(share))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.subtext)
                }
            }
            ProgressView(value: min(max(share, 0), 1))
                .tint(Theme.accent)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(detail): \(CoinFormat.short(source.coins)) coins, \(CoinFormat.percent(share)) of the total")
    }

    @ViewBuilder private var icon: some View {
        switch source.kind {
        case .miner(let miner):
            Text(miner.emoji)
                .font(.title3)
        case .autoTaps:
            Image(systemName: "hand.tap.fill")
                .font(.headline)
                .foregroundStyle(Theme.accent)
        }
    }

    private var name: String {
        switch source.kind {
        case .miner(let miner): miner.name
        case .autoTaps: "Automatic taps"
        }
    }

    private var detail: String {
        switch source.kind {
        case .miner: "×\(CoinFormat.grouped(Int(source.count)))"
        case .autoTaps: "\(CoinFormat.rate(source.count)) per second"
        }
    }
}
