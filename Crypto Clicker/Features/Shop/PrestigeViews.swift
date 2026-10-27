import SwiftUI
import CryptoClickerKit

/// Prestige: points earned so far, what prestiging now would bring, and the way into the perks.
struct PrestigeCard: View {
    @Environment(GameStore.self) private var store
    @State private var confirming = false
    @State private var showingPerks = false

    var body: some View {
        let game = store.game
        let claimable = game.claimablePrestigePoints
        let potential = game.prestigePotential
        let previous = pow(Double(potential), 3) * Tuning.prestigeScale
        let next = game.nextPrestigePointAt
        let fraction = min(1, max(0, (game.stats.lifetimeCoins - previous) / max(1, next - previous)))
        let recommended = game.isPrestigeRecommended
        let affordablePerks = PerkID.allCases.filter(game.canBuy).count
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Prestige", systemImage: "sparkles")
                    .font(.title3.bold())
                Spacer()
                if game.prestigePoints > 0 {
                    Text("\(CoinFormat.grouped(game.prestigePoints)) points · +\(CoinFormat.percent(game.prestigeGain(game.prestigePoints)))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.subtext)
                }
            }
            Text(message(claimable: claimable, recommended: recommended, speedUp: game.prestigeSpeedUp, next: next))
                .font(.subheadline)
                .foregroundStyle(recommended ? Color.primary : Theme.subtext)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: fraction)
                    .tint(Theme.arcadeButton)
                Text("\(CoinFormat.percent(fraction)) of the way to the next point")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.subtext)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { buttons(claimable: claimable, recommended: recommended, perks: affordablePerks) }
                VStack(spacing: 10) { buttons(claimable: claimable, recommended: recommended, perks: affordablePerks) }
            }
        }
        .glassCard(tint: Theme.arcade)
        .sheet(isPresented: $confirming) { PrestigeSheet() }
        .sheet(isPresented: $showingPerks) { PerkTreeView() }
    }

    @ViewBuilder
    private func buttons(claimable: Int, recommended: Bool, perks: Int) -> some View {
        if claimable > 0 {
            Button {
                confirming = true
            } label: {
                Text("Prestige for +\(CoinFormat.grouped(claimable))")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(recommended ? Theme.arcadeButton : Theme.arcadeButton.opacity(0.75))
        }
        Button {
            showingPerks = true
        } label: {
            Label(perks > 0 ? "Perks (\(perks) ready)" : "Perks", systemImage: "rosette")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Theme.arcadeButton)
    }

    private func message(claimable: Int, recommended: Bool, speedUp: Double, next: Double) -> String {
        if claimable == 0 {
            return "Mine \(CoinFormat.cost(next)) coins in all to earn your next prestige point. Every point adds \(CoinFormat.percent(Tuning.productionPerPrestigePoint)) production forever."
        }
        let points = "\(CoinFormat.grouped(claimable)) point\(claimable == 1 ? "" : "s")"
        if recommended {
            return "Prestige now for \(points): your next run mines \(CoinFormat.multiplier(speedUp)) as fast. Points also buy perks."
        }
        return "Prestiging now earns \(points), making the next run \(CoinFormat.multiplier(speedUp)) as fast. It's usually worth waiting for at least ×1.5."
    }
}

/// Confirms a prestige: what it gains, what resets and what stays.
struct PrestigeSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let game = store.game
        let claimable = game.claimablePrestigePoints
        NavigationStack {
            List {
                Section {
                    LabeledContent("Points gained", value: "+\(CoinFormat.grouped(claimable))")
                    LabeledContent("Production bonus after",
                                   value: "+\(CoinFormat.percent(game.prestigeGain(game.prestigePoints + claimable)))")
                    LabeledContent("Next run speed", value: CoinFormat.multiplier(game.prestigeSpeedUp))
                    if game.runPrestigeMultiplier != 1 {
                        LabeledContent("Difficulty multiplier", value: CoinFormat.multiplier(game.runPrestigeMultiplier))
                    }
                }
                Section("Resets") {
                    Label("Coins, tokens and miners", systemImage: "arrow.counterclockwise")
                    if !game.hasPerk(.engineeringTeam) {
                        Label("Miner Mk upgrades", systemImage: "arrow.up.forward.circle")
                    }
                    Label(resetUpgradesText(game), systemImage: "sparkles")
                }
                Section("Keeps") {
                    Label("Prestige points, their bonus and your perks", systemImage: "rosette")
                    Label("Achievements and statistics", systemImage: "trophy")
                    Label("Offline Mining", systemImage: "moon.zzz")
                    Label("Unlocked mini-games", systemImage: "gamecontroller")
                    Label("Your daily streak and quests", systemImage: "calendar")
                    Label("Steps already rewarded", systemImage: "figure.walk")
                    if game.hasPerk(.headStart) {
                        Label("Head Start: 10 Chromebooks, 10 Desktops and 5 GPU Rigs", systemImage: "flag.checkered")
                    }
                }
                if game.stats.prestiges == 0 {
                    Section {
                        Label("Your first prestige also reveals three new miners beyond the Space Mining Colony.",
                              systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle("Prestige")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(role: .destructive) {
                    store.prestige()
                    dismiss()
                } label: {
                    Text("Prestige and Start Over")
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

    private func resetUpgradesText(_ game: GameState) -> String {
        switch (game.hasPerk(.blueprints), game.hasPerk(.muscleMemory)) {
        case (true, true): "Step and mini-game upgrades (Blueprints and Muscle Memory keep the rest)"
        case (true, false): "Tapping, step and mini-game upgrades (Blueprints keeps production upgrades)"
        case (false, true): "Production, step and mini-game upgrades (Muscle Memory keeps tapping upgrades)"
        case (false, false): "Upgrades"
        }
    }
}

extension PerkBranch {
    var color: Color {
        switch self {
        case .mining: .blue
        case .tapping: Theme.accent
        case .fortune: Theme.arcadeButton
        }
    }

    var symbol: String {
        switch self {
        case .mining: "cpu"
        case .tapping: "hand.tap.fill"
        case .fortune: "dice.fill"
        }
    }
}

/// The perk tree: three branches of permanent perks bought with prestige points. Spending points
/// never lowers their production bonus.
struct PerkTreeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let game = store.game
        NavigationStack {
            List {
                Section {
                    LabeledContent("Points to spend", value: CoinFormat.grouped(game.availablePrestigePoints))
                    LabeledContent("Earned in all", value: CoinFormat.grouped(game.prestigePoints))
                } footer: {
                    Text("Every point ever earned adds \(CoinFormat.percent(Tuning.productionPerPrestigePoint)) production, even after you spend it on perks. Perks last forever.")
                }
                ForEach(PerkBranch.allCases) { branch in
                    Section {
                        ForEach(Self.perks(in: branch)) { perk in
                            PerkRow(perk: perk, isOwned: game.hasPerk(perk), isAvailable: game.isPerkAvailable(perk),
                                    canBuy: game.canBuy(perk), color: branch.color)
                        }
                    } header: {
                        Label(branch.rawValue, systemImage: branch.symbol)
                    }
                }
            }
            .navigationTitle("Perks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    /// A branch's perks in tree order: each perk followed by the ones it opens up.
    static func perks(in branch: PerkBranch) -> [PerkID] {
        let all = PerkID.allCases.filter { $0.branch == branch }.sorted { $0.cost < $1.cost }
        func children(of parent: PerkID?) -> [PerkID] {
            all.filter { $0.requires == parent }.flatMap { [$0] + children(of: $0) }
        }
        return children(of: nil)
    }
}

private struct PerkRow: View {
    let perk: PerkID
    let isOwned: Bool
    let isAvailable: Bool
    let canBuy: Bool
    let color: Color
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var purchases = 0
    @State private var refusals = 0

    var body: some View {
        HStack(spacing: 12) {
            if perk.requires != nil {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.subtext)
                    .accessibilityHidden(true)
            }
            Image(systemName: perk.symbol)
                .font(.headline)
                .foregroundStyle(isOwned ? .white : color)
                .frame(width: 38, height: 38)
                .background(isOwned ? color : color.opacity(0.15), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(perk.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(perk.summary)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                if !isOwned, !isAvailable, let required = perk.requires {
                    Label("Needs \(required.name)", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.subtext)
                }
            }
            Spacer(minLength: 8)
            if isOwned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Owned")
            } else {
                Button {
                    if store.buyPerk(perk) { purchases += 1 } else { refusals += 1 }
                } label: {
                    Text("\(CoinFormat.grouped(perk.cost)) pts")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(minWidth: 64)
                }
                .priceButtonStyle(canAfford: canBuy, tint: Theme.arcadeButton)
                .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
                .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
                .accessibilityLabel("Buy \(perk.name) for \(perk.cost) points")
            }
        }
        .padding(.leading, perk.requires == nil ? 0 : 8)
    }
}
