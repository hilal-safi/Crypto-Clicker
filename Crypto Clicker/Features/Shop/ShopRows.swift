import SwiftUI
import CryptoClickerKit

/// One miner tier. Takes plain values, so SwiftUI skips redrawing rows whose numbers did not change.
struct MinerRow: View {
    let miner: MinerID
    let owned: Int
    let rate: Double
    let nextMilestone: Int?
    let buyCount: Int
    let price: Double
    let canAfford: Bool
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var purchases = 0

    var body: some View {
        HStack(spacing: 14) {
            Text(miner.emoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(.thinMaterial, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(miner.name)
                        .font(.headline)
                    if owned > 0 {
                        Text("×\(CoinFormat.grouped(owned))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(owned > 0 ? "\(CoinFormat.short(rate))/s" : miner.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let nextMilestone, owned > 0 {
                    MilestoneProgress(owned: owned, next: nextMilestone)
                }
            }
            Spacer(minLength: 8)
            Button {
                if store.buy(miner, quantity: buyCount) { purchases += 1 }
            } label: {
                VStack(spacing: 2) {
                    Text("Buy \(CoinFormat.grouped(buyCount))")
                        .font(.caption.weight(.semibold))
                    Text(CoinFormat.short(price))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
                .frame(minWidth: 72)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAfford)
            .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
            .accessibilityLabel("Buy \(buyCount) \(miner.name) for \(CoinFormat.short(price)) coins")
        }
        .rowCard()
    }
}

/// Progress from the last milestone to the next one, which doubles this miner's output.
struct MilestoneProgress: View {
    let owned: Int
    let next: Int

    var body: some View {
        let previous = Tuning.milestones.last { $0 <= owned } ?? 0
        let fraction = Double(owned - previous) / Double(max(1, next - previous))
        VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: fraction)
                .tint(Theme.bitcoin)
            Text("\(CoinFormat.grouped(next - owned)) more for \(CoinFormat.multiplier(Tuning.milestoneMultiplier)) output")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 180, alignment: .leading)
    }
}

/// The next tier, hidden until the one before it is owned.
struct LockedMinerRow: View {
    let miner: MinerID

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .frame(width: 52, height: 52)
                .background(.thinMaterial, in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text("???")
                    .font(.headline)
                if let previous = miner.previous {
                    Text("Buy a \(previous.name) to reveal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .rowCard()
        .opacity(0.8)
    }
}

struct UpgradeRow: View {
    let upgrade: UpgradeID
    let canAfford: Bool
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var purchases = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: upgrade.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(upgrade.category.color)
                .frame(width: 52, height: 52)
                .background(.thinMaterial, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(upgrade.name)
                    .font(.headline)
                Text(upgrade.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                if store.buy(upgrade) { purchases += 1 }
            } label: {
                Text(CoinFormat.short(upgrade.cost))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .frame(minWidth: 72)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAfford)
            .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
            .accessibilityLabel("Buy \(upgrade.name) for \(CoinFormat.short(upgrade.cost)) coins")
        }
        .rowCard()
    }
}

extension UpgradeCategory {
    var color: Color {
        switch self {
        case .tapping: Theme.bitcoin
        case .production: .blue
        case .steps: .green
        case .miniGames: .purple
        case .offline: .indigo
        }
    }
}
