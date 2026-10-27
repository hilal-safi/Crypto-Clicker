import SwiftUI
import CryptoClickerKit

/// Shown after time away: what the miners earned while the app was closed, what that unlocked,
/// the best thing to buy now, and on request a breakdown of where every coin came from.
struct WelcomeBackView: View {
    let welcome: WelcomeBack
    /// Opens the Shop at its power-ups. Called after this sheet starts closing.
    let openPowerUps: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showsBreakdown = false
    @State private var detent = PresentationDetent.medium

    private var report: OfflineReport { welcome.report }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    summary
                    if !highlights.isEmpty {
                        AwayHighlights(lines: highlights)
                    }
                    if let suggestion = welcome.suggestion {
                        BestBuyCard(suggestion: suggestion)
                    }
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

    /// What the time away unlocked: achievements, prestige points and finished quests.
    private var highlights: [AwayHighlights.Line] {
        var lines = welcome.achievements.map { earned in
            AwayHighlights.Line(icon: earned.achievement.emoji ?? "🏆",
                                text: "\(earned.achievement.name) · \(earned.tierName)")
        }
        if welcome.newPrestigePoints > 0 {
            lines.append(.init(icon: "🌟", text: "+\(CoinFormat.grouped(welcome.newPrestigePoints)) prestige points ready to claim"))
        }
        let quests = store.game.claimableQuestCount
        if quests > 0 {
            lines.append(.init(icon: "📜", text: quests == 1 ? "A quest is ready to claim" : "\(quests) quests are ready to claim"))
        }
        return lines
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

/// What the time away unlocked, as a short list.
private struct AwayHighlights: View {
    struct Line: Identifiable {
        let icon: String
        let text: String
        var id: String { text }
    }

    let lines: [Line]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("While you were away")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(lines) { line in
                HStack(spacing: 10) {
                    Text(line.icon)
                        .font(.title3)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                    Text(line.text)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowCard()
    }
}

/// The affordable purchase that adds the most income for its price, with a button to buy it.
private struct BestBuyCard: View {
    let suggestion: PurchaseSuggestion
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var isBought = false
    @State private var purchases = 0

    var body: some View {
        let canAfford = store.game.coins >= suggestion.price && store.game.price(of: suggestion.purchase) == suggestion.price
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accent.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Best buy now")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.subtext)
                Text(suggestion.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("+\(CoinFormat.rate(suggestion.incomeGain)) coins per second · pays for itself in \(CoinFormat.duration(suggestion.payback))")
                    .font(.footnote)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isBought {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.gain)
                    .accessibilityLabel("Bought")
            } else {
                Button {
                    if store.buy(suggestion.purchase) {
                        purchases += 1
                        withAnimation(.snappy) { isBought = true }
                    }
                } label: {
                    Text(CoinFormat.cost(suggestion.price))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(minWidth: 64)
                }
                .priceButtonStyle(canAfford: canAfford, tint: Theme.accent)
                .fixedSize()
                .disabled(!canAfford)
                .accessibilityLabel("Buy \(suggestion.name) for \(CoinFormat.cost(suggestion.price)) coins")
            }
        }
        .rowCard()
        .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
    }
}
