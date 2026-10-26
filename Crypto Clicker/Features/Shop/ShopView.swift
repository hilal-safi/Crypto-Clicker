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
}

struct ShopView: View {
    /// Goes up by one each time another screen asks to show the power-ups (the welcome-back
    /// screen's Offline Mining button does).
    var powerUpRequests = 0
    @Environment(GameStore.self) private var store
    @State private var quantity = BuyQuantity.one
    @State private var showsPurchased = false
    @State private var handledPowerUpRequests = 0

    private static let powerUpsID = "power-ups"

    var body: some View {
        let game = store.game
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
        NavigationStack {
            ScrollViewReader { scroller in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if game.isPrestigeRecommended {
                            PrestigeCard()
                        }

                        SectionHeader(title: "Miners", detail: "\(CoinFormat.rate(game.baseProduction)) per second")
                        Picker("Buy quantity", selection: $quantity) {
                            ForEach(BuyQuantity.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        ForEach(revealedMiners) { miner in
                            let count = quantity.count(of: miner, in: game)
                            let price = game.price(of: miner, quantity: count)
                            let upgrade = game.availableMinerUpgrade(miner)
                            MinerRow(miner: miner, owned: game.owned(miner), rate: game.rate(of: miner),
                                     nextMilestone: game.nextMilestone(for: miner), buyCount: count,
                                     price: price, canAfford: price <= game.coins,
                                     mkLevel: game.minerUpgradeLevel(miner), upgradeLevel: upgrade?.level,
                                     upgradePrice: upgrade?.price,
                                     canAffordUpgrade: upgrade.map { $0.price <= game.coins } ?? false)
                        }
                        if let lockedMiner {
                            LockedMinerRow(miner: lockedMiner,
                                           needsPrestige: lockedMiner.needsPrestige && game.stats.prestiges == 0)
                        }

                        SectionHeader(title: "Power-ups", detail: "Kept when you prestige")
                            .id(Self.powerUpsID)
                        OfflineMiningRow(level: game.offlineMiningLevel, price: offlineMiningPrice,
                                         canAfford: offlineMiningPrice.map { $0 <= game.coins } ?? false)

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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
                .onAppear { showPowerUpsIfAsked(scroller) }
                .onChange(of: powerUpRequests) { _, _ in showPowerUpsIfAsked(scroller) }
            }
            .background { AppBackground(tint: Theme.shop) }
            .navigationTitle("Shop")
            .balanceToolbar()
        }
    }

    /// Scrolls to the power-ups once for each request.
    private func showPowerUpsIfAsked(_ scroller: ScrollViewProxy) {
        guard handledPowerUpRequests != powerUpRequests else { return }
        handledPowerUpRequests = powerUpRequests
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
