import SwiftUI
import CryptoClickerKit

/// Prestige: progress toward the next fork point, and the way into a Hard Fork.
struct HardForkCard: View {
    @Environment(GameStore.self) private var store
    @State private var confirming = false

    var body: some View {
        let game = store.game
        let claimable = game.claimableForks
        let previous = pow(Double(game.forkPoints), 3) * Tuning.forkScale
        let next = game.nextForkPointAt
        let fraction = (game.stats.lifetimeCoins - previous) / max(1, next - previous)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Hard Fork", systemImage: "arrow.triangle.branch")
                    .font(.title3.bold())
                Spacer()
                if game.forks > 0 {
                    Text("\(CoinFormat.grouped(game.forks)) forks · +\(CoinFormat.percent(game.forkGain(game.forks)))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if claimable > 0 {
                Text("Start a new run now to gain \(CoinFormat.grouped(claimable)) fork\(claimable == 1 ? "" : "s"): +\(CoinFormat.percent(game.forkGain(claimable))) production, forever.")
                    .font(.subheadline)
            } else {
                Text("Mine \(CoinFormat.short(next)) coins in total to earn your next fork point.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(1, max(0, fraction)))
                .tint(Theme.arcade)
            Button {
                confirming = true
            } label: {
                Text(claimable > 0 ? "Hard Fork for +\(CoinFormat.grouped(claimable))" : "Not ready yet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.arcade)
            .disabled(claimable == 0)
        }
        .glassCard(tint: Theme.arcade.opacity(0.15))
        .sheet(isPresented: $confirming) {
            HardForkSheet()
        }
    }
}

struct HardForkSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let game = store.game
        let claimable = game.claimableForks
        NavigationStack {
            List {
                Section {
                    LabeledContent("Forks gained", value: "+\(CoinFormat.grouped(claimable))")
                    LabeledContent("Production bonus after", value: "+\(CoinFormat.percent(game.forkGain(game.forks + claimable)))")
                    if game.runForkMultiplier != 1 {
                        LabeledContent("Difficulty multiplier", value: CoinFormat.multiplier(game.runForkMultiplier))
                    }
                }
                Section("Resets") {
                    Label("Coins, miners and upgrades", systemImage: "arrow.counterclockwise")
                }
                Section("Keeps") {
                    Label("Forks and their bonus", systemImage: "arrow.triangle.branch")
                    Label("Achievements and statistics", systemImage: "trophy")
                    Label("Tokens and unlocked mini-games", systemImage: "gamecontroller")
                    Label("Steps already rewarded", systemImage: "figure.walk")
                }
            }
            .navigationTitle("Hard Fork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(role: .destructive) {
                    store.hardFork()
                    dismiss()
                } label: {
                    Text("Fork and Start Over")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .disabled(claimable == 0)
                .padding()
            }
        }
        .presentationDetents([.medium, .large])
    }
}
