import SwiftUI
import CryptoClickerKit

/// Steps on the home screen. Hidden until the player has tapped the coin 2,500 times; then a
/// one-line invitation ("Earn coins from steps!" with Learn More and Start), and once steps are
/// connected, today's count. Kept compact so the coin stays big.
struct StepsCard: View {
    /// Opens the explanation sheet, which the home screen presents.
    let learnMore: () -> Void
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.stepsInviteDismissedKey) private var inviteDismissed = false

    var body: some View {
        let game = store.game
        if store.canTrackSteps && game.areStepsUnlocked {
            if game.steps.isConnected {
                StepsTodayCard()
            } else if !inviteDismissed {
                invitation
            }
        }
    }

    private var invitation: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Theme.steps.gradient, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Earn coins from steps!")
                    .font(.subheadline.weight(.bold))
                Button("Learn More", action: learnMore)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                    .tint(Theme.stepsButton)
            }
            Spacer(minLength: 4)
            Button {
                Task { await store.connectSteps() }
            } label: {
                Text("Start")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.stepsButton)
            Button("Not Now", systemImage: "xmark") {
                withAnimation { inviteDismissed = true }
            }
            .labelStyle(.iconOnly)
            .font(.footnote.weight(.bold))
            .foregroundStyle(.subtext)
            .buttonStyle(.borderless)
            .accessibilityHint("You can start later in Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(Theme.steps.opacity(0.18)), in: .rect(cornerRadius: 22))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Today's steps and what each one is worth.
private struct StepsTodayCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let game = store.game
        let isToday = game.steps.todayKey == StepDay.key(for: .now)
        HStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.steps)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(CoinFormat.grouped(isToday ? game.steps.todaySteps : 0)) steps today")
                    .font(.headline)
                    .monospacedDigit()
                Text("Every step earns \(CoinFormat.short(game.stepValue)) coin\(game.stepValue == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 0)
            Button {
                Task { await store.syncSteps(force: true) }
            } label: {
                if store.isSyncingSteps {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.semibold))
                }
            }
            .buttonStyle(.borderless)
            .disabled(store.isSyncingSteps)
            .accessibilityLabel("Sync steps")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(Theme.steps.opacity(0.18)), in: .rect(cornerRadius: 22))
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
         "A step is worth at least one coin, and more as your mining income grows."),
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
