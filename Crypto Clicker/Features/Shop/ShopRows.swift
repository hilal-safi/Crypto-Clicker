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
    /// What Legacy multiplies this miner by (1 until newer tiers reach 100 units).
    let legacy: Double
    /// The older miners this one lifts with Legacy once it reaches 100.
    let legacyBoosts: [MinerID]
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
            // The icon carries the Mk badge above it and the Legacy badge below it.
            VStack(spacing: 6) {
                if mkLevel > 0 {
                    Text("Mk \(MinerID.markName(level: mkLevel - 1))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Theme.accent.opacity(0.16), in: .capsule)
                }
                Text(miner.emoji)
                    .font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(Theme.shop.opacity(0.14), in: .circle)
                    .accessibilityHidden(true)
                if legacy > 1 {
                    Label(CoinFormat.multiplier(legacy), systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.legacy)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Theme.legacy.opacity(0.16), in: .capsule)
                        .accessibilityLabel("Legacy: earns \(CoinFormat.multiplier(legacy)) from newer miners")
                }
            }
            .lineLimit(1)
            .fixedSize()
            VStack(alignment: .leading, spacing: 4) {
                // The name has a line to itself, so it never breaks in two.
                Text(miner.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if isBestValue {
                    HStack(spacing: 6) {
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
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                Text(owned > 0 ? "\(CoinFormat.rate(rate)) coins per second" : miner.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Next one: +\(CoinFormat.rate(perUnit))/s", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                // Each bar sits with its own caption, with clear space between the two.
                VStack(alignment: .leading, spacing: 12) {
                    if let nextMilestone, owned > 0 {
                        MilestoneProgress(owned: owned, next: nextMilestone)
                    }
                    // From the first milestone, so it doesn't crowd the opening.
                    if !legacyBoosts.isEmpty && owned >= 25 {
                        LegacyProgress(owned: owned, boosts: legacyBoosts)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // How many are owned sits under the buy button.
            VStack(spacing: 6) {
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
                .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
                .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
                .accessibilityLabel("Buy \(buyCount) \(miner.name) for \(CoinFormat.cost(price)) coins")
                if owned > 0 {
                    Text("Owned \(CoinFormat.grouped(owned))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.subtext)
                        .lineLimit(1)
                }
            }
            .fixedSize()
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

/// Progress toward the 100 units that lift older miners with Legacy, in Legacy's blue:
/// "10 more to boost Chromebook ×5".
struct LegacyProgress: View {
    let owned: Int
    let boosts: [MinerID]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: Double(owned) / Double(Tuning.legacyUnits))
                .tint(Theme.legacy)
            Text("\(CoinFormat.grouped(Tuning.legacyUnits - owned)) more to boost \(names) \(CoinFormat.multiplier(Tuning.legacyMultiplier))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 180, alignment: .leading)
    }

    private var names: String {
        switch boosts.count {
        case 1: boosts[0].name
        case 2: String(localized: "\(boosts[0].name) and \(boosts[1].name)")
        default: String(localized: "\(boosts.count) older miners")
        }
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

/// The Offline Mining power-up, laid out like the combo power-ups: a header with its level and
/// price, what it does, then the time away it pays for now and at the next level.
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
            Text("Keeps miners earning while the app is closed: a minute more a level up to 10 minutes, then 5 minutes to an hour, 15 minutes to 3 hours and half an hour up to three days.")
                .font(.subheadline)
                .foregroundStyle(.subtext)
                .fixedSize(horizontal: false, vertical: true)
            NowAndNext(title: "Time away paid", now: level > 0 ? CoinFormat.duration(cap) : String(localized: "Off"),
                       next: price != nil ? CoinFormat.duration(nextCap) : nil, color: .indigo)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowCard()
        .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
        .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
    }
}

/// A combo power-up: a header with its name, level and price, what it does, its level as a bar of
/// pips across the card, then what it gives now and at the next level. Kept when you prestige.
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
            Text(powerUp.summary)
                .font(.subheadline)
                .foregroundStyle(.subtext)
                .fixedSize(horizontal: false, vertical: true)
            LevelPips(level: level, maxLevel: powerUp.maxLevel, color: powerUp.color)
            NowAndNext(title: powerUp.valueName, now: powerUp.value(atLevel: level),
                       next: price != nil ? powerUp.value(atLevel: level + 1) : nil, color: powerUp.color)
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

/// What a power-up gives now and at its next level, side by side under what it measures:
/// "BIGGEST COMBO  Now ×3.5 → Next ×4". Without a next level, only now.
private struct NowAndNext: View {
    let title: String
    let now: String
    let next: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.subtext)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                value("Now", now, color: .primary)
                if let next {
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.subtext)
                        .accessibilityHidden(true)
                    value("Next", next, color: color)
                }
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func value(_ label: LocalizedStringKey, _ text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.subtext)
            Text(text)
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
        }
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
        case .comboKeeper: Color(red: 0.18, green: 0.48, blue: 0.95)
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
