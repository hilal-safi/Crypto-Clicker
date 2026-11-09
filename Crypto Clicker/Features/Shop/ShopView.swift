import SwiftUI
import CryptoClickerKit

enum BuyQuantity: Int, CaseIterable, Identifiable {
    case one = 1, ten = 10, hundred = 100, max = 0

    var id: Self { self }
    var title: String { self == .max ? "Max" : "×\(rawValue)" }

    /// Units to buy: a fixed batch, or as many as the balance allows (at least one, for the price label).
    func count(of miner: MinerID, in game: GameState) -> Int {
        self == .max ? Swift.max(1, game.maxAffordable(miner)) : rawValue
    }

    /// Tokens to buy: a fixed batch, or as many as `affordable` (at least one, for the price label).
    func count(affordable: Int) -> Int {
        self == .max ? Swift.max(1, affordable) : rawValue
    }

    /// Tokens to sell: up to a fixed batch, or all of them.
    func sellCount(owned: Int) -> Int {
        self == .max ? owned : Swift.min(rawValue, owned)
    }
}

/// The Shop, in two pages like Trophies: Power-ups (miners, power-ups, upgrades and prestige) and
/// Tokens (the coin exchange: crypto to bet at the casino or trade).
struct ShopView: View {
    /// Goes up by one each time another screen asks to show the power-ups (the welcome-back
    /// screen's Offline Mining button does).
    var powerUpRequests = 0
    /// Goes up by one each time another screen asks to show the tokens (the home screen's crypto card).
    var tokenRequests = 0
    @Environment(GameStore.self) private var store
    @State private var page = ShopPage.powerUps
    @State private var quantity = BuyQuantity.one
    @State private var showsPurchased = false
    @State private var handledPowerUpRequests = 0
    @State private var handledTokenRequests = 0

    enum ShopPage: String, CaseIterable, Identifiable {
        case powerUps = "Power-ups"
        case tokens = "Tokens"

        var id: Self { self }

        /// The page's name, from the String Catalog.
        var title: LocalizedStringResource {
            switch self {
            case .powerUps: "Power-ups"
            case .tokens: "Tokens"
            }
        }
    }

    private static let topID = "top"
    private static let powerUpsID = "power-ups"

    var body: some View {
        let game = store.game
        NavigationStack {
            ScrollViewReader { scroller in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Picker("Page", selection: $page) {
                            ForEach(ShopPage.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .id(Self.topID)
                        if page == .tokens {
                            TokensPage()
                        } else {
                            powerUpsPage(game)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
                .onAppear {
                    showTokensIfAsked(scroller)
                    showPowerUpsIfAsked(scroller)
                }
                .onChange(of: powerUpRequests) { _, _ in showPowerUpsIfAsked(scroller) }
                .onChange(of: tokenRequests) { _, _ in showTokensIfAsked(scroller) }
            }
            .background { AppBackground(tint: page == .tokens ? .green : Theme.shop) }
            .navigationTitle("Shop")
            .balanceToolbar()
        }
    }

    /// Miners, power-ups, upgrades and prestige.
    @ViewBuilder
    private func powerUpsPage(_ game: GameState) -> some View {
        let revealedMiners = MinerID.allCases.filter(game.isRevealed)
        let lockedMiner = MinerID.allCases.first { !game.isRevealed($0) }
        // Step Boosters are only offered where Apple Health can count steps.
        let notOwned = UpgradeID.allCases.filter {
            !game.upgrades.contains($0) && (store.canTrackSteps || $0.category != .steps)
        }
        let available = notOwned.filter(game.isRevealed).sorted { $0.cost < $1.cost }
        let undiscovered = notOwned.count - available.count
        let purchased = UpgradeID.allCases.filter(game.upgrades.contains)
        let offlineMiningPrice = game.offlineMiningPrice
        if game.isPrestigeRecommended {
            PrestigeCard()
        }

        SectionHeader(title: "Miners", detail: "\(CoinFormat.rate(game.baseProduction)) per second")
        Picker("Buy quantity", selection: $quantity) {
            ForEach(BuyQuantity.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        let bestValue = revealedMiners.count > 1 ? game.bestValueMiner : nil
        ForEach(revealedMiners) { miner in
            minerRow(miner, game: game, isBestValue: miner == bestValue)
        }
        if let lockedMiner {
            LockedMinerRow(miner: lockedMiner,
                           needsPrestige: lockedMiner.needsPrestige && game.stats.prestiges == 0)
        }

        SectionHeader(title: "Power-ups", detail: "Kept when you prestige")
            .id(Self.powerUpsID)
        OfflineMiningRow(level: game.offlineMiningLevel, price: offlineMiningPrice,
                         canAfford: offlineMiningPrice.map { $0 <= game.coins } ?? false)
        ForEach(PowerUpID.allCases) { powerUp in
            if game.isRevealed(powerUp) {
                let price = game.powerUpPrice(powerUp)
                PowerUpRow(powerUp: powerUp, level: game.powerUpLevel(powerUp), price: price,
                           canAfford: price.map { $0 <= game.coins } ?? false)
            } else if let required = powerUp.requires, game.powerUpLevel(required) > 0 {
                LockedPowerUpRow(powerUp: powerUp, required: required)
            }
        }

        SectionHeader(title: "Upgrades",
                      detail: undiscovered > 0 ? "\(undiscovered) still hidden" : nil)
        if available.isEmpty {
            Text(undiscovered > 0 ? "Keep mining to discover more upgrades." : "Every upgrade is yours.")
                .font(.subheadline)
                .foregroundStyle(.subtext)
                .frame(maxWidth: .infinity)
                .rowCard()
        }
        ForEach(available) { upgrade in
            UpgradeRow(upgrade: upgrade, canAfford: upgrade.cost <= game.coins)
        }
        if !purchased.isEmpty {
            DisclosureGroup(isExpanded: $showsPurchased) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(purchased) { upgrade in
                        PurchasedUpgradeRow(upgrade: upgrade)
                    }
                }
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Purchased (\(purchased.count))", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rowCard()
        }

        if !game.isPrestigeRecommended
            && (game.prestigePoints > 0 || game.stats.lifetimeCoins >= Tuning.prestigeScale / 10) {
            PrestigeCard()
        }
    }

    private func minerRow(_ miner: MinerID, game: GameState, isBestValue: Bool) -> MinerRow {
        let count = quantity.count(of: miner, in: game)
        let price = game.price(of: miner, quantity: count)
        let upgrade = game.availableMinerUpgrade(miner)
        return MinerRow(miner: miner, owned: game.owned(miner), rate: game.rate(of: miner),
                        perUnit: game.nextUnitGain(miner), isBestValue: isBestValue,
                        nextMilestone: game.nextMilestone(for: miner), buyCount: count,
                        price: price, canAfford: price <= game.coins,
                        mkLevel: game.minerUpgradeLevel(miner), legacy: game.legacyMultiplier(miner),
                        upgradeLevel: upgrade?.level, upgradePrice: upgrade?.price,
                        canAffordUpgrade: upgrade.map { $0.price <= game.coins } ?? false)
    }

    /// Shows the tokens page once for each request.
    private func showTokensIfAsked(_ scroller: ScrollViewProxy) {
        guard handledTokenRequests != tokenRequests else { return }
        handledTokenRequests = tokenRequests
        page = .tokens
        scroller.scrollTo(Self.topID, anchor: .top)
    }

    /// Shows the power-ups page, scrolled to the power-ups, once for each request.
    private func showPowerUpsIfAsked(_ scroller: ScrollViewProxy) {
        guard handledPowerUpRequests != powerUpRequests else { return }
        handledPowerUpRequests = powerUpRequests
        page = .powerUps
        Task {
            // Let the tab switch settle so the list is on screen.
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.smooth) { scroller.scrollTo(Self.powerUpsID, anchor: .top) }
        }
    }
}

/// An upgrade already bought: its icon, name and effect, across the full width of the card.
private struct PurchasedUpgradeRow: View {
    let upgrade: UpgradeID

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: upgrade.symbol)
                .font(.headline)
                .foregroundStyle(upgrade.category.color)
                .frame(width: 38, height: 38)
                .background(upgrade.category.color.opacity(0.15), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(upgrade.name)
                    .font(.headline)
                Text(upgrade.summary)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
