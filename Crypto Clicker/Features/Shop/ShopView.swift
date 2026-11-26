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

/// The parts of the Shop other screens can ask for, and the shortcuts at the top of its
/// Power-ups page jump to.
enum ShopSection: String, CaseIterable, Identifiable {
    case miners, powerUps, upgrades, prestige, tokens

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .miners: "Miners"
        case .powerUps: "Power-ups"
        case .upgrades: "Upgrades"
        case .prestige: "Prestige"
        case .tokens: "Tokens"
        }
    }

    var symbol: String {
        switch self {
        case .miners: "cpu.fill"
        case .powerUps: "bolt.fill"
        case .upgrades: "sparkles"
        case .prestige: "rosette"
        case .tokens: "bitcoinsign.circle.fill"
        }
    }
}

/// The Shop, in two pages like Trophies: Power-ups (miners, power-ups, upgrades and prestige) and
/// Tokens (the coin exchange: crypto to bet at the casino or trade).
struct ShopView: View {
    /// The part of the Shop another screen asked for last: the welcome-back screen's Offline
    /// Mining button asks for the power-ups, the Mine tab's crypto card for the tokens, and a goal
    /// for where it's bought.
    var request = TabRequest(ShopSection.miners)
    @Environment(GameStore.self) private var store
    @State private var page = ShopPage.powerUps
    @State private var quantity = BuyQuantity.one
    @State private var showsPurchased = false
    @State private var handledRequest = 0

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
                            // Shortcuts once the list is long enough to scroll past.
                            if MinerID.allCases.filter(game.isRevealed).count >= 4 {
                                SectionShortcuts(sections: shortcutSections(game)) { section in
                                    withAnimation(.smooth) { scroller.scrollTo(section, anchor: .top) }
                                }
                            }
                            powerUpsPage(game)
                        }
                    }
                    // The miner info pop-up floats over the list, pointing at the tapped icon.
                    .overlayPreferenceValue(MinerIconAnchors.self) { MinerInfoLayer(anchors: $0) }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
                .onAppear { showIfAsked(scroller) }
                .onChange(of: request) { _, _ in showIfAsked(scroller) }
                .onChange(of: page) { _, _ in store.shopInfoMiner = nil; store.shopInfoToken = nil }
                .onDisappear { store.shopInfoMiner = nil; store.shopInfoToken = nil }
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
                .id(ShopSection.prestige)
        }

        SectionHeader(title: "Miners", detail: "\(CoinFormat.rate(game.baseProduction)) per second")
            .id(ShopSection.miners)
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
            .id(ShopSection.powerUps)
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
            .id(ShopSection.upgrades)
        if available.isEmpty {
            Text(undiscovered > 0 ? "Keep mining to discover more upgrades." : "Every upgrade is yours.")
                .font(.subheadline)
                .foregroundStyle(.subtext)
                .frame(maxWidth: .infinity)
                .rowCard()
        }
        ForEach(available) { upgrade in
            UpgradeRow(upgrade: upgrade, canAfford: upgrade.cost <= game.coins, gain: gainText(of: upgrade, in: game))
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

        if !game.isPrestigeRecommended && Self.showsPrestigeBelow(game) {
            PrestigeCard()
                .id(ShopSection.prestige)
        }
    }

    /// The prestige card sits at the end of the list once prestige is in sight (and at the top
    /// when the Shop suggests one).
    private static func showsPrestigeBelow(_ game: GameState) -> Bool {
        game.prestigePoints > 0 || game.stats.lifetimeCoins >= Tuning.prestigeScale / 10
    }

    /// The shortcuts for the sections on the Power-ups page now.
    private func shortcutSections(_ game: GameState) -> [ShopSection] {
        let prestige = game.isPrestigeRecommended || Self.showsPrestigeBelow(game)
        return [.miners, .powerUps, .upgrades] + (prestige ? [.prestige] : [])
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
                        legacyBoosts: game.legacyBeneficiaries(of: miner),
                        upgradeLevel: upgrade?.level, upgradePrice: upgrade?.price,
                        canAffordUpgrade: upgrade.map { $0.price <= game.coins } ?? false)
    }

    /// What an upgrade adds in this game: a share of income and how soon it repays its price, or a
    /// share of each tap for tapping upgrades without automatic taps. Nil for upgrades that add
    /// neither (steps and mini-games: their summaries say what they do).
    private func gainText(of upgrade: UpgradeID, in game: GameState) -> String? {
        let income = game.baseIdleIncome
        let gain = game.incomeGain(of: upgrade)
        if income > 0, gain > 0, let payback = GameState.payback(price: upgrade.cost, gain: gain) {
            return "\(PaybackLine.shareText(gain / income)) income · pays for itself in \(CoinFormat.duration(payback))"
        }
        let tap = game.baseTapValue
        let tapGain = game.tapGain(of: upgrade)
        if tap > 0, tapGain > 0 {
            return "\(PaybackLine.shareText(tapGain / tap)) per tap"
        }
        return nil
    }

    /// Shows the part of the Shop asked for, once for each request: the tokens page from the top,
    /// or the power-ups page scrolled to a section.
    private func showIfAsked(_ scroller: ScrollViewProxy) {
        guard handledRequest != request.number else { return }
        handledRequest = request.number
        let section = request.place
        if section == .tokens {
            page = .tokens
            scroller.scrollTo(Self.topID, anchor: .top)
            return
        }
        page = .powerUps
        Task {
            // Let the tab switch settle so the list is on screen.
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.smooth) { scroller.scrollTo(section, anchor: .top) }
        }
    }
}

/// Buttons that jump down the Power-ups page to its sections.
private struct SectionShortcuts: View {
    let sections: [ShopSection]
    let jump: (ShopSection) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(sections) { section in
                    Button {
                        jump(section)
                    } label: {
                        Label {
                            Text(section.title)
                        } icon: {
                            Image(systemName: section.symbol)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityHint("Scrolls to \(Text(section.title))")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
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
