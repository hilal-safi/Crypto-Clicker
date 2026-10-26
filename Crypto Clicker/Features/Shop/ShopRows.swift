import SwiftUI
import CryptoClickerKit

/// One miner tier, with its next Mk upgrade once enough are owned. Takes plain values, so SwiftUI
/// skips redrawing rows whose numbers did not change.
struct MinerRow: View {
    let miner: MinerID
    let owned: Int
    let rate: Double
    let nextMilestone: Int?
    let buyCount: Int
    let price: Double
    let canAfford: Bool
    /// Mk upgrades bought this run.
    let mkLevel: Int
    /// The Mk upgrade on offer, if one is.
    let upgradeLevel: Int?
    let upgradePrice: Double?
    let canAffordUpgrade: Bool
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var purchases = 0
    @State private var refusals = 0

    var body: some View {
        VStack(spacing: 12) {
            mainRow
            if let upgradeLevel, let upgradePrice {
                Divider()
                MinerUpgradeOffer(miner: miner, level: upgradeLevel, price: upgradePrice, canAfford: canAffordUpgrade)
            }
        }
        .rowCard()
    }

    private var mainRow: some View {
        HStack(spacing: 14) {
            Text(miner.emoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Theme.shop.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(miner.name)
                        .font(.headline)
                    if owned > 0 {
                        Text("×\(CoinFormat.grouped(owned))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.subtext)
                    }
                    if mkLevel > 0 {
                        Text("Mk \(MinerID.markName(level: mkLevel - 1))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Theme.accent.opacity(0.14), in: .capsule)
                    }
                }
                Text(owned > 0 ? "\(CoinFormat.rate(rate)) coins per second" : miner.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .lineLimit(2)
                if let nextMilestone, owned > 0 {
                    MilestoneProgress(owned: owned, next: nextMilestone)
                }
            }
            Spacer(minLength: 8)
            Button {
                if store.buy(miner, quantity: buyCount) { purchases += 1 } else { refusals += 1 }
            } label: {
                VStack(spacing: 2) {
                    Text("Buy \(CoinFormat.grouped(buyCount))")
                        .font(.caption.weight(.semibold))
                    Text(CoinFormat.cost(price))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
                .frame(minWidth: 72)
            }
            .priceButtonStyle(canAfford: canAfford, tint: Theme.accent)
            .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
            .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
            .accessibilityLabel("Buy \(buyCount) \(miner.name) for \(CoinFormat.cost(price)) coins")
        }
    }
}

/// A miner's next Mk upgrade: doubles that miner's output for the rest of the run.
struct MinerUpgradeOffer: View {
    let miner: MinerID
    let level: Int
    let price: Double
    let canAfford: Bool
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var purchases = 0
    @State private var refusals = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.up.forward.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(miner.upgradeName(level: level))
                    .font(.subheadline.weight(.semibold))
                Text("Doubles what your \(miner.pluralName) mine")
                    .font(.caption)
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 8)
            Button {
                if store.buyMinerUpgrade(miner) { purchases += 1 } else { refusals += 1 }
            } label: {
                Text(CoinFormat.cost(price))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .frame(minWidth: 72)
            }
            .priceButtonStyle(canAfford: canAfford, tint: Theme.accent)
            .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
            .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
            .accessibilityLabel("Buy \(miner.upgradeName(level: level)) for \(CoinFormat.cost(price)) coins")
        }
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
                .foregroundStyle(.subtext)
        }
        .frame(maxWidth: 180, alignment: .leading)
    }
}

/// The next tier, hidden until the one before it is owned. The last tiers also wait for the
/// first prestige.
struct LockedMinerRow: View {
    let miner: MinerID
    let needsPrestige: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: needsPrestige ? "sparkles" : "lock.fill")
                .font(.title3)
                .foregroundStyle(needsPrestige ? Theme.accent : Theme.subtext)
                .frame(width: 52, height: 52)
                .background((needsPrestige ? Theme.accent : Color.secondary).opacity(0.14), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text("???")
                    .font(.headline)
                if needsPrestige {
                    Text("Prestige once to discover new miners beyond the stars.")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                } else if let previous = miner.previous {
                    Text("Buy a \(previous.name) to reveal")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
            }
            Spacer(minLength: 0)
        }
        .rowCard()
    }
}

struct UpgradeRow: View {
    let upgrade: UpgradeID
    let canAfford: Bool
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var purchases = 0
    @State private var refusals = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: upgrade.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(upgrade.category.color)
                .frame(width: 52, height: 52)
                .background(upgrade.category.color.opacity(0.15), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(upgrade.name)
                    .font(.headline)
                Text(upgrade.summary)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                if store.buy(upgrade) { purchases += 1 } else { refusals += 1 }
            } label: {
                Text(CoinFormat.cost(upgrade.cost))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .frame(minWidth: 72)
            }
            .priceButtonStyle(canAfford: canAfford, tint: Theme.accent)
            .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
            .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
            .accessibilityLabel("Buy \(upgrade.name) for \(CoinFormat.cost(upgrade.cost)) coins")
        }
        .rowCard()
    }
}

/// The Offline Mining power-up: its current limit, what the next level adds, and its price.
struct OfflineMiningRow: View {
    let level: Int
    let price: Double?
    let canAfford: Bool
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var purchases = 0
    @State private var refusals = 0

    var body: some View {
        let cap = GameState.offlineCap(level: level)
        let nextCap = GameState.offlineCap(level: level + 1)
        HStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.indigo)
                .frame(width: 52, height: 52)
                .background(Color.indigo.opacity(0.15), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Offline Mining")
                        .font(.headline)
                    if level > 0 {
                        Text("Level \(level)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.subtext)
                    }
                }
                Text(level == 0
                     ? "Miners stop a minute after you leave the app. Keep them mining while it's closed."
                     : "Miners keep earning for \(CoinFormat.duration(cap)) after you leave the app.")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                if price != nil {
                    Label("Next level: \(CoinFormat.duration(nextCap))", systemImage: "arrow.up.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.subtext)
                }
            }
            Spacer(minLength: 8)
            if let price {
                Button {
                    if store.buyOfflineMining() { purchases += 1 } else { refusals += 1 }
                } label: {
                    Text(CoinFormat.cost(price))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(minWidth: 72)
                }
                .priceButtonStyle(canAfford: canAfford, tint: Theme.accent)
                .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
                .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
                .accessibilityLabel("Buy Offline Mining level \(level + 1) for \(CoinFormat.cost(price)) coins")
            } else {
                Label("Max", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.green)
            }
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
        }
    }
}
