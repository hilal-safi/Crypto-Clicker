import SwiftUI
import CryptoClickerKit

/// Steps on the home screen. Hidden until the player has tapped the coin 2,000 times; then a
/// one-line invitation ("Earn coins from steps!" with Learn More, which explains steps and has the
/// button that starts them), and once steps are connected, today's count and what it pays. Kept
/// small so the coin and the inventory strip get the room.
struct StepsCard: View {
    /// Opens the explanation sheet, which the home screen presents.
    let learnMore: () -> Void
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.stepsInviteDismissedKey) private var inviteDismissed = false

    /// Whether the card shows at all.
    static func isShown(_ game: GameState, canTrackSteps: Bool, inviteDismissed: Bool) -> Bool {
        canTrackSteps && game.areStepsUnlocked && (game.steps.isConnected || !inviteDismissed)
    }

    /// Whether it shows today's steps (rather than the invitation, or nothing).
    static func showsCounter(_ game: GameState, canTrackSteps: Bool) -> Bool {
        canTrackSteps && game.areStepsUnlocked && game.steps.isConnected
    }

    var body: some View {
        let game = store.game
        if store.canTrackSteps && game.areStepsUnlocked {
            if game.steps.isConnected {
                // After the first prestige the steps take two thirds of the row and the prestige
                // points the last third; until then the steps have it all.
                if game.stats.prestiges > 0 {
                    ThirdSplit {
                        StepsTodayCard(fillsHeight: true)
                        PrestigeBadge(fillsHeight: true)
                    }
                    .transition(.opacity)
                } else {
                    StepsTodayCard()
                }
            } else if !inviteDismissed {
                invitation
            }
        }
    }

    private var invitation: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.walk")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.steps.gradient, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Earn coins from steps!")
                    .font(.subheadline.weight(.bold))
                Text("Every step you walk pays")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            // How steps work comes first; the explanation has the button that starts them.
            Button(action: learnMore) {
                Text("Learn More")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 2)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.stepsButton)
            Button("Not Now", systemImage: "xmark") {
                withAnimation { inviteDismissed = true }
            }
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.subtext)
            .buttonStyle(.borderless)
            .accessibilityHint("You can start later in Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(Theme.steps.opacity(0.18)), in: .rect(cornerRadius: 18))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Today's steps and what they pay: as they're walked, or tomorrow on the game's first day.
private struct StepsTodayCard: View {
    /// Fills the row's height, beside the prestige badge.
    var fillsHeight = false
    @Environment(GameStore.self) private var store

    var body: some View {
        let game = store.game
        let today = StepDay.key(for: .now)
        let isToday = game.steps.todayKey == today
        let pending = game.pendingStepCoins(today: today)
        let value = game.stepValue(today: today)
        let perStep = "\(CoinFormat.short(value)) coin\(value == 1 ? "" : "s")"
        HStack(spacing: 10) {
            Image(systemName: "figure.walk")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.steps)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(CoinFormat.grouped(isToday ? game.steps.todaySteps : 0)) steps today")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                // Beside the prestige badge, a shorter line that fits the narrower card.
                Group {
                    if fillsHeight {
                        Text(pending > 0 ? "About +\(CoinFormat.short(pending)) tomorrow"
                             : game.stepsPaidNextDay(today: today) ? "\(perStep) a step tomorrow"
                             : "\(perStep) a step")
                    } else {
                        Text(pending > 0 ? "Pays about +\(CoinFormat.short(pending)) tomorrow"
                             : game.stepsPaidNextDay(today: today) ? "Every step pays \(perStep) tomorrow"
                             : "Every step pays \(perStep) as you walk")
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.steps)
                .lineLimit(fillsHeight ? 1 : nil)
                .minimumScaleFactor(fillsHeight ? 0.8 : 1)
            }
            Spacer(minLength: 0)
            Button {
                Task { await store.syncSteps(force: true) }
            } label: {
                if store.isSyncingSteps {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.headline.weight(.semibold))
                }
            }
            .buttonStyle(.borderless)
            .disabled(store.isSyncingSteps)
            .accessibilityLabel("Sync steps")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
        .glassEffect(.regular.tint(Theme.steps.opacity(0.18)), in: .rect(cornerRadius: 18))
        // A tap (away from the sync button) explains what a step pays.
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.snappy(duration: 0.2)) { store.showsStepInfo.toggle() }
        }
        .accessibilityAction(named: "Coins per step") { store.showsStepInfo = true }
        .anchorPreference(key: StepsCardAnchor.self, value: .bounds) { $0 }
        .onDisappear { store.showsStepInfo = false }
    }
}

/// Where the steps card is on the Mine page, for its pop-up to point at.
struct StepsCardAnchor: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// The coins-per-step pop-up, drawn over the Mine page just above the steps card and pointing
/// down at it, like the Shop's info pop-ups: a tap on it or anywhere else puts it away.
struct StepInfoLayer: View {
    let anchor: Anchor<CGRect>?
    @Environment(GameStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            if store.showsStepInfo, let anchor {
                let card = proxy[anchor]
                let width = min(360, proxy.size.width - 32)
                let left = min(max(16, card.midX - width / 2), max(16, proxy.size.width - width - 16))
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture(perform: close)
                        .accessibilityHidden(true)
                    // Its bottom just above the card, however tall the text makes it.
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        StepInfoBubble(arrowX: card.midX - left, close: close)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: width, height: max(0, card.minY - 4), alignment: .bottom)
                    .offset(x: left)
                    .transition(.scale(scale: 0.85, anchor: UnitPoint(x: (card.midX - left) / width, y: 1))
                        .combined(with: .opacity))
                }
            }
        }
    }

    private func close() {
        withAnimation(.snappy(duration: 0.2)) { store.showsStepInfo = false }
    }
}

/// What a step pays and why: the share of income, the step boosters' multiplier and the next
/// booster to buy, and on the game's first day, the coin a step its steps pay the day after.
private struct StepInfoBubble: View {
    let arrowX: CGFloat
    let close: () -> Void
    @Environment(GameStore.self) private var store

    var body: some View {
        let game = store.game
        let today = StepDay.key(for: .now)
        let firstDay = game.stepsPaidNextDay(today: today)
        let value = game.stepValue
        let boost = game.stepMultiplier
        let share = Int((Tuning.stepSeconds * 100).rounded())
        let next = UpgradeID.allCases.first { $0.category == .steps && !game.upgrades.contains($0) }
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.headline)
                    .foregroundStyle(Theme.steps)
                    .accessibilityHidden(true)
                Text("Coins per step")
                    .font(.headline)
                Spacer(minLength: 0)
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.subtext)
                    .accessibilityHidden(true)
            }
            if firstDay {
                Text("Today's steps pay 1 coin each, tomorrow. From then on, steps pay \(CoinFormat.short(value)) \(value == 1 ? "coin" : "coins") each as you walk.")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Each step pays \(CoinFormat.short(value)) \(value == 1 ? "coin" : "coins")")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Theme.steps)
            }
            Text(boost > 1
                 ? "A step is worth \(share)% of a second's income (\(CoinFormat.rate(game.rewardIncome)) a second), at least a coin, \(CoinFormat.multiplier(boost)) from step boosters."
                 : "A step is worth \(share)% of a second's income (\(CoinFormat.rate(game.rewardIncome)) a second), at least a coin.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            if let next, case .steps(let factor) = next.effect {
                Text("Next: \(next.name), \(CoinFormat.multiplier(factor)), for \(CoinFormat.short(next.cost)) coins in the Shop.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Every step booster is bought.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.subtext)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12 + Callout.arrow.height)
        .background {
            Callout(arrowX: arrowX, pointsDown: true)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .overlay { Callout(arrowX: arrowX, pointsDown: true).stroke(.primary.opacity(0.12), lineWidth: 1) }
        .contentShape(Callout(arrowX: arrowX, pointsDown: true))
        .onTapGesture(perform: close)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(named: "Close", close)
    }
}

/// The prestige points, shown on the home screen once the first prestige is done: a third of the
/// steps row, or a row of its own (`isWide`) for a player without steps.
struct PrestigeBadge: View {
    var isWide = false
    /// Fills the row's height, beside the steps.
    var fillsHeight = false
    @Environment(GameStore.self) private var store

    var body: some View {
        let game = store.game
        let points = game.prestigePoints
        let count = points < 100_000 ? CoinFormat.grouped(points) : CoinFormat.short(Double(points))
        let unit = points == 1 ? String(localized: "point") : String(localized: "points")
        Group {
            if isWide {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 24)
                    Text("Prestige \(CoinFormat.grouped(game.stats.prestiges))")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("\(count) \(unit) · \(CoinFormat.multiplier(game.prestigeBonus))")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                        Text(count)
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                    }
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, isWide ? 12 : 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
        .glassEffect(.regular.tint(Theme.gold.opacity(0.2)), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prestige: \(points) \(unit), production \(CoinFormat.multiplier(game.prestigeBonus))")
    }
}

/// Two views side by side, the first two thirds of the width and the second a third, both as
/// tall as the taller one.
private struct ThirdSplit: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let height = zip(subviews, widths(for: width, count: subviews.count))
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
            .max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths(for: bounds.width, count: subviews.count)) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    private func widths(for width: CGFloat, count: Int) -> [CGFloat] {
        let room = max(0, width - spacing)
        return count == 2 ? [room * 2 / 3, room / 3] : Array(repeating: width, count: count)
    }
}

/// How steps work, with the button that starts them.
struct StepsIntroView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isConnecting = false

    private let points: [(icon: String, title: String, text: String)] = [
        ("figure.walk", "Walk with iPhone or Apple Watch",
         "Apple Health counts your steps from both and combines them, so nothing is counted twice."),
        ("bitcoinsign.circle.fill", "Every step pays coins",
         "Steps are paid as you walk, at least a coin a step, and more as your mining income grows. Only your first day's steps wait until the next day. Steps count toward quests and achievements right away."),
        ("checkmark.seal.fill", "Each step is paid once",
         "Steps are added up by day. Syncing again, or late steps from your watch, never pays the same step twice."),
        ("bolt.fill", "Boost your stride",
         "Step Boosters in the Shop multiply what every step earns."),
        ("lock.shield.fill", "Private",
         "Crypto Clicker only reads your step count. It never writes to Apple Health or shares your data."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Earn coins from steps!")
                            .font(.largeTitle.bold())
                        Text("Turn your daily walks into coins for your mining empire.")
                            .font(.title3)
                            .foregroundStyle(.subtext)
                    }
                    ForEach(points, id: \.title) { point in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: point.icon)
                                .font(.title2)
                                .foregroundStyle(Theme.steps)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(point.title)
                                    .font(.headline)
                                Text(point.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.subtext)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    isConnecting = true
                    Task {
                        // Health's permission sheet appears over this one; close this once it's done.
                        await store.connectSteps()
                        isConnecting = false
                        dismiss()
                    }
                } label: {
                    Group {
                        if isConnecting {
                            ProgressView()
                        } else {
                            Text(store.game.steps.isConnected ? "Steps Connected" : "Start Earning")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.stepsButton)
                .disabled(store.game.steps.isConnected || isConnecting)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
