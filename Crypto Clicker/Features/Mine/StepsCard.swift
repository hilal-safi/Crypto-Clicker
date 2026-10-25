import SwiftUI
import CryptoClickerKit

/// Steps walked today and what each step is worth, or an invitation to connect Apple Health.
struct StepsCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let game = store.game
        if !store.canTrackSteps {
            EmptyView()
        } else if game.steps.isConnected {
            let isToday = game.steps.todayKey == StepDay.key(for: .now)
            HStack(spacing: 14) {
                Image(systemName: "figure.walk")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.green)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(CoinFormat.grouped(isToday ? game.steps.todaySteps : 0)) steps today")
                        .font(.headline)
                        .monospacedDigit()
                    Text("Every step earns \(CoinFormat.short(game.stepValue)) coins")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
            .frame(maxWidth: .infinity)
            .glassCard(tint: Color.green.opacity(0.15))
        } else {
            Button {
                Task { await store.connectSteps() }
            } label: {
                Label("Earn coins by walking", systemImage: "figure.walk")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(.green)
        }
    }
}
