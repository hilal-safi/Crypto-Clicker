import SwiftUI
import CryptoClickerKit

/// The goals button beside the tokens on the Mine tab: a flag in a ring that fills as the closest
/// goal nears, green once it's ready. Opens the goals pop-up.
struct GoalsButton: View {
    /// The goal closest to done (or the prestige the Shop suggests), for the ring.
    let goal: Goal?
    /// The corner radius of the card beside it, to match.
    let cornerRadius: CGFloat
    let action: () -> Void

    var body: some View {
        let progress = goal?.progress ?? 0
        let isReady = progress >= 1
        let color = isReady ? Theme.gain : Theme.accent
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.15), lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: isReady ? "flag.checkered" : "flag.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 38, height: 38)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .animation(.smooth, value: progress)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        .accessibilityLabel("Goals")
        .accessibilityValue(goal.map { "Next: \($0.title), \(isReady ? String(localized: "ready") : CoinFormat.percent(($0.progress * 100).rounded(.down) / 100))" } ?? "")
        .accessibilityHint("Shows your next goals")
    }
}

/// The next goals, from the Mine tab: the closest first, each a tap away from where it's done,
/// and the full Goals page in Trophies (with the starter milestones to claim).
struct GoalsSheet: View {
    /// Opens where a goal is worked toward.
    let open: (Goal.Kind) -> Void
    /// Opens Trophies › Goals.
    let openGoalsPage: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let game = store.game
        let featured = game.featuredGoal
        let goals = (featured.map { [$0] } ?? []) + game.nextGoals.filter { $0.id != featured?.id }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !game.claimableStarterMilestones.isEmpty {
                        Button {
                            leave(then: openGoalsPage)
                        } label: {
                            Label("A starter milestone is ready to claim in Trophies › Goals", systemImage: "gift.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .rowCard()
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(goals) { goal in
                        Button {
                            leave { open(goal.kind) }
                        } label: {
                            GoalCard(goal: goal)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(goal.kind.destination)
                    }
                    Button {
                        leave(then: openGoalsPage)
                    } label: {
                        Label("All Goals in Trophies", systemImage: "trophy.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .navigationTitle("Next Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Closes the pop-up, then goes on once it's out of the way.
    private func leave(then action: @escaping () -> Void) {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            action()
        }
    }
}
