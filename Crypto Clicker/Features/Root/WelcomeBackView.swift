import SwiftUI
import CryptoClickerKit

/// Shown after time away: what the miners earned while the app was closed, what that unlocked,
/// the best thing to buy now, and on request a breakdown of where every coin came from.
///
/// Breakdown and Collect stay pinned at the bottom, and the sheet opens tall enough to show the
/// summary and the first card above them. Anything further down (more cards, the breakdown) is
/// pointed out by a "More below" chip that scrolls to it.
struct WelcomeBackView: View {
    let welcome: WelcomeBack
    /// Opens the Shop at its power-ups. Called after this sheet starts closing.
    let openPowerUps: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showsBreakdown = false
    @State private var detent = PresentationDetent.medium
    /// The summary with the first card, the pinned buttons, and the space below them.
    @State private var openingHeight: CGFloat = 0
    @State private var barHeight: CGFloat = 0
    @State private var bottomInset: CGFloat = 0
    /// The sheet's opening height, once measured.
    @State private var fittedHeight: CGFloat?
    /// Part of the page is out of sight below.
    @State private var hasMoreBelow = false

    private static let topPadding: CGFloat = 24
    private static let gap: CGFloat = 16
    private static let breakdownID = "breakdown"

    private enum Card: Hashable {
        case highlights, bestBuy, offlineMining
    }

    private var report: OfflineReport { welcome.report }

    private var cards: [Card] {
        var cards: [Card] = []
        if !highlights.isEmpty { cards.append(.highlights) }
        if welcome.suggestion != nil { cards.append(.bestBuy) }
        if report.wasCapped { cards.append(.offlineMining) }
        return cards
    }

    private var detents: Set<PresentationDetent> {
        if let fittedHeight { [.height(fittedHeight), .large] } else { [.medium, .large] }
    }

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: Self.gap) {
                    VStack(spacing: Self.gap) {
                        summary
                        if let first = cards.first { card(first).id(first) }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        openingHeight = height
                        fit()
                    }
                    ForEach(cards.dropFirst(), id: \.self) { card($0).id($0) }
                    if showsBreakdown {
                        OfflineBreakdown(report: report)
                            .id(Self.breakdownID)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, Self.topPadding)
                .padding(.bottom, Self.gap)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                // Content below what's visible above the buttons.
                geometry.contentSize.height + geometry.contentInsets.bottom - geometry.visibleRect.maxY > 24
            } action: { _, more in
                withAnimation(.snappy) { hasMoreBelow = more }
            }
            .overlay(alignment: .bottom) {
                if hasMoreBelow {
                    moreChip(scroller)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .safeAreaInset(edge: .bottom) {
                buttons(scroller)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        barHeight = height
                        fit()
                    }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset in
            bottomInset = inset
            fit()
        }
        .presentationDetents(detents, selection: $detent)
        .presentationDragIndicator(.visible)
    }

    /// Sizes the sheet to the summary, the first card and the buttons. It follows the
    /// measurements as they come in, unless the player has already dragged it to another height.
    private func fit() {
        guard openingHeight > 0, barHeight > 0 else { return }
        let height = (Self.topPadding + openingHeight + Self.gap + barHeight + bottomInset + 8).rounded(.up)
        guard abs(height - (fittedHeight ?? 0)) > 1 else { return }
        let wasFitted = fittedHeight.map { detent == .height($0) } ?? (detent == .medium)
        fittedHeight = height
        if wasFitted { detent = .height(height) }
    }

    private func scroll(to id: some Hashable, with scroller: ScrollViewProxy) {
        Task {
            // After the sheet has grown and the content is in place.
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.snappy) { scroller.scrollTo(id, anchor: .top) }
        }
    }

    private func buttons(_ scroller: ScrollViewProxy) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { breakdownButton(scroller); collectButton }
            VStack(spacing: 10) { collectButton; breakdownButton(scroller) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func breakdownButton(_ scroller: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.snappy) {
                showsBreakdown.toggle()
                if showsBreakdown { detent = .large }
            }
            if showsBreakdown { scroll(to: Self.breakdownID, with: scroller) }
        } label: {
            Label(showsBreakdown ? "Hide Breakdown" : "See Breakdown",
                  systemImage: showsBreakdown ? "chevron.up" : "list.bullet.rectangle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
        .fixedSize()
    }

    private var collectButton: some View {
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
    }

    /// Points out what's below: the other cards, or the breakdown.
    private func moreChip(_ scroller: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.snappy) { detent = .large }
            if let next = cards.dropFirst().first {
                scroll(to: next, with: scroller)
            } else if showsBreakdown {
                scroll(to: Self.breakdownID, with: scroller)
            }
        } label: {
            Label(cards.count > 2 ? "\(cards.count - 1) more below" : "More below", systemImage: "chevron.down")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityHint("Scrolls to the rest of the summary")
    }

    @ViewBuilder
    private func card(_ card: Card) -> some View {
        switch card {
        case .highlights:
            AwayHighlights(lines: highlights)
        case .bestBuy:
            if let suggestion = welcome.suggestion { BestBuyCard(suggestion: suggestion) }
        case .offlineMining:
            offlineMiningNote
        }
    }

    private var summary: some View {
        VStack(spacing: 10) {
            CoinIcon(size: 52)
            VStack(spacing: 4) {
                Text("Welcome back!")
                    .font(.title2.bold())
                Text("You were away for \(CoinFormat.duration(report.elapsed)).")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            VStack(spacing: 2) {
                Text("Your miners earned")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.subtext)
                CoinAmount(amount: report.earned, font: .system(size: 36, weight: .bold, design: .rounded), iconSize: 30)
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
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    CoinAmount(amount: source.coins, font: .subheadline.weight(.semibold))
                    Text(CoinFormat.percent(share))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
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
                    .font(.footnote.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.accent)
                Text(suggestion.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("+\(CoinFormat.rate(suggestion.incomeGain)) coins per second · pays for itself in \(CoinFormat.duration(suggestion.payback))")
                    .font(.subheadline)
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
