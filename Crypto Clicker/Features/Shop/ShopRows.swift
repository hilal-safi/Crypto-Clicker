import SwiftUI
import CryptoClickerKit

/// One miner tier, with its next Mk upgrade once enough are owned. Takes plain values, so SwiftUI
/// skips redrawing rows whose numbers did not change. Shows what one more unit adds, and marks the
/// miner whose next unit adds the most for its price ("Best value").
struct MinerRow: View {
    let miner: MinerID
    let owned: Int
    let rate: Double
    /// Coins per second the next unit adds (a milestone doubles them all).
    let perUnit: Double
    let isBestValue: Bool
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
        HStack(spacing: 12) {
            Text(miner.emoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Theme.shop.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                // The name has a line to itself, so it never breaks in two.
                Text(miner.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if isBestValue {
                    Label("Best value", systemImage: "star.fill")
                        .font(.footnote.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.06, green: 0.46, blue: 0.22).gradient, in: .capsule)
                        .accessibilityLabel("Best value: the next one adds the most per coin")
                }
                if owned > 0 || mkLevel > 0 {
                    HStack(spacing: 6) {
                        if owned > 0 {
                            Text("Owned \(CoinFormat.grouped(owned))")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.subtext)
                        }
                        if mkLevel > 0 {
                            Text("Mk \(MinerID.markName(level: mkLevel - 1))")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 1)
                                .background(Theme.accent.opacity(0.16), in: .capsule)
                        }
                    }
                    .lineLimit(1)
                }
                Text(owned > 0 ? "\(CoinFormat.rate(rate)) coins per second" : miner.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Next one: +\(CoinFormat.rate(perUnit))/s", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                if let nextMilestone, owned > 0 {
                    MilestoneProgress(owned: owned, next: nextMilestone)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                if store.buy(miner, quantity: buyCount) { purchases += 1 } else { refusals += 1 }
            } label: {
                VStack(spacing: 2) {
                    Text("Buy \(CoinFormat.grouped(buyCount))")
                        .font(.footnote.weight(.bold))
                    Text(CoinFormat.cost(price))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
                .frame(minWidth: 72)
            }
            .priceButtonStyle(canAfford: canAfford, tint: Theme.accent)
            .fixedSize()
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("Doubles what your \(miner.pluralName) mine")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                if store.buyMinerUpgrade(miner) { purchases += 1 } else { refusals += 1 }
            } label: {
                Text(CoinFormat.cost(price))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .frame(minWidth: 72)
            }
            .priceButtonStyle(canAfford: canAfford, tint: Theme.accent)
            .fixedSize()
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
                .font(.subheadline.weight(.semibold))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(upgrade.summary)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                if store.buy(upgrade) { purchases += 1 } else { refusals += 1 }
            } label: {
                Text(CoinFormat.cost(upgrade.cost))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .frame(minWidth: 72)
            }
            .priceButtonStyle(canAfford: canAfford, tint: Theme.accent)
            .fixedSize()
            .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
            .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
            .accessibilityLabel("Buy \(upgrade.name) for \(CoinFormat.cost(upgrade.cost)) coins")
        }
        .rowCard()
    }
}

/// The Offline Mining power-up: its current limit, what the next level adds, and its price. Laid
/// out like the combo power-ups: a header line, then the details across the whole card.
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
        VStack(alignment: .leading, spacing: 10) {
            PowerUpHeader(title: "Offline Mining", subtitle: level > 0 ? "Level \(level)" : "Not bought yet") {
                Image(systemName: "moon.zzz.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 46, height: 46)
                    .background(Color.indigo.opacity(0.15), in: .circle)
            } action: {
                if let price {
                    PowerUpPriceButton(price: price, canAfford: canAfford,
                                       label: "Buy Offline Mining level \(level + 1) for \(CoinFormat.cost(price)) coins") {
                        if store.buyOfflineMining() { purchases += 1 } else { refusals += 1 }
                    }
                } else {
                    MaxedBadge()
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowCard()
        .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
        .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
    }
}

/// A combo power-up: a header with its name, level and price, its level as a bar of pips across the
/// card, what it gives now and what the next level adds. Kept when you prestige.
struct PowerUpRow: View {
    let powerUp: PowerUpID
    let level: Int
    let price: Double?
    let canAfford: Bool
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var purchases = 0
    @State private var refusals = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PowerUpHeader(title: powerUp.name, subtitle: "Level \(level) of \(powerUp.maxLevel)") {
                Image(systemName: powerUp.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(powerUp.color.gradient, in: .circle)
            } action: {
                if let price {
                    PowerUpPriceButton(price: price, canAfford: canAfford,
                                       label: "Buy \(powerUp.name) level \(level + 1) for \(CoinFormat.cost(price)) coins") {
                        if store.buyPowerUp(powerUp) { purchases += 1 } else { refusals += 1 }
                    }
                } else {
                    MaxedBadge()
                }
            }
            LevelPips(level: level, maxLevel: powerUp.maxLevel, color: powerUp.color)
            Text(level == 0 ? powerUp.summary : powerUp.effect(atLevel: level))
                .font(.subheadline.weight(level == 0 ? .regular : .semibold))
                .foregroundStyle(level == 0 ? Theme.subtext : .primary)
                .fixedSize(horizontal: false, vertical: true)
            if price != nil {
                Label("Next: \(powerUp.effect(atLevel: level + 1))", systemImage: "arrow.up.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(powerUp.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowCard()
        .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
        .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
        .accessibilityElement(children: .contain)
    }
}

/// A power-up still locked behind another, saying what opens it.
struct LockedPowerUpRow: View {
    let powerUp: PowerUpID
    let required: PowerUpID

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PowerUpHeader(title: powerUp.name, subtitle: "Locked") {
                Image(systemName: "lock.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(powerUp.color)
                    .frame(width: 46, height: 46)
                    .background(powerUp.color.opacity(0.15), in: .circle)
            } action: {
                EmptyView()
            }
            Text(powerUp.summary)
                .font(.subheadline)
                .foregroundStyle(.subtext)
                .fixedSize(horizontal: false, vertical: true)
            Label("Opens when \(required.name) reaches level \(required.maxLevel)", systemImage: "lock.open.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(powerUp.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowCard()
        .accessibilityElement(children: .combine)
    }
}

/// The top line of a power-up card: its icon, its name with a line under it, and the buy button (or
/// Max) at the far end, so the details below get the card's whole width.
private struct PowerUpHeader<Icon: View, Action: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let icon: Icon
    @ViewBuilder let action: Action

    var body: some View {
        HStack(spacing: 12) {
            icon
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.subtext)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            action
        }
    }
}

/// The price of a power-up's next level, as a button: filled when it's affordable.
private struct PowerUpPriceButton: View {
    let price: Double
    let canAfford: Bool
    let label: String
    let buy: () -> Void

    var body: some View {
        Button(action: buy) {
            Text(CoinFormat.cost(price))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .frame(minWidth: 64)
        }
        .priceButtonStyle(canAfford: canAfford, tint: Theme.accent)
        .fixedSize()
        .accessibilityLabel(label)
    }
}

/// Shown instead of a price once a power-up is at its last level.
private struct MaxedBadge: View {
    var body: some View {
        Label("Max", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.green)
    }
}

/// A power-up's level as a bar of pips across the card: filled up to the level reached.
struct LevelPips: View {
    let level: Int
    let maxLevel: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<maxLevel, id: \.self) { index in
                Capsule()
                    .fill(index < level ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.2)))
                    .frame(maxWidth: .infinity)
                    .frame(height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level) of \(maxLevel)")
    }
}

extension PowerUpID {
    var color: Color {
        switch self {
        case .comboBooster: Color(red: 0.95, green: 0.30, blue: 0.10)
        case .comboOverdrive: Color(red: 0.62, green: 0.25, blue: 0.95)
        case .quickCombos: Color(red: 0.05, green: 0.62, blue: 0.62)
        }
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
