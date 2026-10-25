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
    @Environment(GameStore.self) private var store
    @State private var quantity = BuyQuantity.one
    @State private var showsPurchased = false

    var body: some View {
        let game = store.game
        let revealedMiners = MinerID.allCases.filter(game.isRevealed)
        let lockedMiner = MinerID.allCases.first { !game.isRevealed($0) }
        let available = UpgradeID.allCases
            .filter { !game.upgrades.contains($0) && game.isRevealed($0) }
            .sorted { $0.cost < $1.cost }
        let undiscovered = UpgradeID.allCases.count - available.count - game.upgrades.count
        let purchased = UpgradeID.allCases.filter(game.upgrades.contains)
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if game.claimableForks > 0 {
                        HardForkCard()
                    }

                    SectionHeader(title: "Miners", detail: "\(CoinFormat.short(game.baseProduction))/s")
                    Picker("Buy quantity", selection: $quantity) {
                        ForEach(BuyQuantity.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    ForEach(revealedMiners) { miner in
                        let count = quantity.count(of: miner, in: game)
                        let price = game.price(of: miner, quantity: count)
                        MinerRow(miner: miner, owned: game.owned(miner), rate: game.rate(of: miner),
                                 nextMilestone: game.nextMilestone(for: miner), buyCount: count,
                                 price: price, canAfford: price <= game.coins)
                    }
                    if let lockedMiner {
                        LockedMinerRow(miner: lockedMiner)
                    }

                    SectionHeader(title: "Upgrades",
                                  detail: undiscovered > 0 ? "\(undiscovered) still hidden" : nil)
                    if available.isEmpty {
                        Text(undiscovered > 0 ? "Keep mining to discover more upgrades." : "Every upgrade is yours.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .rowCard()
                    }
                    ForEach(available) { upgrade in
                        UpgradeRow(upgrade: upgrade, canAfford: upgrade.cost <= game.coins)
                    }
                    if !purchased.isEmpty {
                        DisclosureGroup(isExpanded: $showsPurchased) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(purchased) { upgrade in
                                    Label {
                                        VStack(alignment: .leading) {
                                            Text(upgrade.name).font(.subheadline.weight(.semibold))
                                            Text(upgrade.summary).font(.caption).foregroundStyle(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: upgrade.symbol)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            Text("Purchased (\(purchased.count))")
                                .font(.headline)
                        }
                        .rowCard()
                    }

                    if game.claimableForks == 0 && (game.forks > 0 || game.stats.lifetimeCoins >= Tuning.forkScale / 10) {
                        HardForkCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background { AppBackground(tint: Theme.shop) }
            .navigationTitle("Shop")
            .balanceToolbar()
        }
    }
}
