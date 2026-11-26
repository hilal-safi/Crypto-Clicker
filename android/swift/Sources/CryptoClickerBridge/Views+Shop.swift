import Foundation
import CryptoClickerKit

// The Shop: its Power-ups page (miners, power-ups, upgrades and prestige, with the perk tree) and
// its Tokens page (the coin exchange), as the iOS ShopView, ShopRows, PrestigeViews and
// ExchangeView work them out.

/// The Shop's Power-ups page (view "shop").
struct ShopView: Encodable {
    /// The shortcuts at the top of the page, once the list is long enough to scroll past:
    /// "miners", "powerUps", "upgrades" and (once prestige is in sight) "prestige".
    let shortcuts: [String]
    /// Prestige would speed the player up a lot: its card leads the page instead of closing it.
    let prestigeFirst: Bool
    /// The prestige card, once prestige is worth a look (recommended, or a point earned, or a
    /// tenth of the way to the first).
    let prestige: PrestigeView?
    /// "12.5 per second", beside the Miners heading.
    let minersDetail: String
    let miners: [MinerView]
    /// The next tier, hidden until the one before it is owned.
    let lockedMiner: LockedMinerView?
    let offlineMining: OfflineMiningView
    let powerUps: [PowerUpView]
    /// "3 still hidden", beside the Upgrades heading.
    let upgradesDetail: String?
    /// Shown when no upgrade is on sale.
    let upgradesEmpty: String?
    /// Upgrades on sale, cheapest first.
    let upgrades: [UpgradeView]
    /// Upgrades already bought.
    let purchased: [UpgradeView]
}

struct MinerView: Encodable {
    let id: String
    let emoji: String
    let name: String
    let owned: Int
    /// "Owned 12", under the buy button once one is owned.
    let ownedText: String?
    /// Coins per second once one is owned, else what the miner is.
    let line: String
    /// "Next one: +0.25/s"
    let nextOne: String
    let isBestValue: Bool
    /// "Mk II" once a Mk upgrade is bought.
    let mk: String?
    /// "×5" while Legacy lifts it.
    let legacy: String?
    let milestone: ProgressLine?
    let legacyProgress: ProgressLine?
    /// The buy button for ×1, ×10, ×100 and Max, in that order.
    let buy: [BuyOption]
    /// The next Mk upgrade, when one is on offer.
    let upgrade: MinerUpgradeView?
    /// The pop-up its icon opens.
    let info: MinerInfoView
}

/// What a miner is (iOS: MinerInfoBubble): its description, what the ones owned earn, and what
/// lifts it (the next milestone, and Legacy from the newer tiers).
struct MinerInfoView: Encodable {
    let blurb: String
    let owned: String?
    /// What one more adds against the income, and how soon it repays its price.
    let payback: String?
    let milestone: String?
    let legacy: String?
    /// Legacy already lifts it (the line is in Legacy's blue), rather than the line saying how it could.
    let legacyActive: Bool
}

struct ProgressLine: Encodable {
    let fraction: Double
    let text: String
}

struct BuyOption: Encodable {
    /// Units this button buys (for Max, as many as the balance allows, at least one).
    let count: Int
    /// "Buy 10"
    let label: String
    let price: String
    let canAfford: Bool
}

struct MinerUpgradeView: Encodable {
    /// "GPU Rig Mk III"
    let name: String
    /// "Doubles what your GPU Rigs mine"
    let detail: String
    let price: String
    let canAfford: Bool
}

struct LockedMinerView: Encodable {
    /// The last tiers wait for the first prestige.
    let needsPrestige: Bool
    let text: String
}

struct OfflineMiningView: Encodable {
    /// "Level 2", or "Not bought yet"
    let subtitle: String
    /// The next level's price; nil at the last level.
    let price: String?
    let canAfford: Bool
    /// Time away paid now, and at the next level.
    let now: String
    let next: String?
}

struct PowerUpView: Encodable {
    let id: String
    let name: String
    /// The SF Symbol the iOS app shows; Android maps it to a Material icon.
    let symbol: String
    let summary: String
    /// "Level 2 of 6"
    let subtitle: String
    let level: Int
    let maxLevel: Int
    /// Whether the row draws a bar per level (not for Offline Efficiency, which has too many).
    let showsPips: Bool
    /// The next level's price; nil at the last level (or while locked).
    let price: String?
    let canAfford: Bool
    /// "Biggest combo"
    let valueName: String
    let now: String
    let next: String?
    /// Set while it waits on another power-up: "Opens when Combo Booster reaches level 6".
    let locked: String?
}

struct UpgradeView: Encodable {
    let id: String
    let name: String
    let summary: String
    let symbol: String
    /// tapping, production, steps or miniGames
    let category: String
    let price: String
    let canAfford: Bool
    /// What it adds, worked out for this game: "+12% income · pays for itself in 4m".
    let gain: String?
}

// MARK: Prestige

/// Prestige (iOS: PrestigeCard): points earned so far, what prestiging now would bring, and the
/// way into the perks.
struct PrestigeView: Encodable {
    /// "12 points · +24%", once a point is earned.
    let points: String?
    let message: String
    /// Prestiging now would speed the next run up a lot: the message is in full strength.
    let recommended: Bool
    /// The way to the next point, and "40% of the way to the next point".
    let fraction: Double
    let progress: String
    /// "Prestige for +3", when there's a point to claim.
    let claim: String?
    /// "Perks (2 ready)" or "Perks"
    let perksTitle: String
    /// What a prestige gains, resets and keeps, for its confirmation.
    let confirm: PrestigeConfirmView
}

/// Confirms a prestige (iOS: PrestigeSheet).
struct PrestigeConfirmView: Encodable {
    let gains: [ListSectionView]
    let resets: [SymbolLineView]
    let keeps: [SymbolLineView]
    /// The first prestige also reveals new miners.
    let firstNote: String?
    /// The coin finish this prestige unlocks (a prestige milestone): its raw value and the line.
    let finish: String?
    let finishNote: String?
    let canPrestige: Bool
}

/// A line with an SF Symbol before it.
struct SymbolLineView: Encodable {
    let symbol: String
    let text: String
}

/// The perk tree (view "perks"; iOS: PerkTreeView): three branches of permanent perks bought with
/// prestige points.
struct PerksView: Encodable {
    let available: String
    let earned: String
    let footer: String
    let branches: [PerkBranchView]
}

struct PerkBranchView: Encodable {
    let id: String
    let name: String
    let symbol: String
    let perks: [PerkView]
}

struct PerkView: Encodable {
    let id: String
    let name: String
    let summary: String
    let symbol: String
    let isOwned: Bool
    let canBuy: Bool
    /// "3 pts"
    let price: String
    /// "After Head Start" when it's open, "Needs Head Start first" when not; nil once owned or at a root.
    let requirement: String?
    let requirementMet: Bool
}

// MARK: Tokens

/// The Shop's Tokens page, the coin exchange (view "tokens"; iOS: TokensPage).
struct TokensView: Encodable {
    /// What the wallet's tokens are worth, and what selling everything would pay.
    let holdings: String
    let walletLine: String
    /// "▲ 12K (4.5%) in the last day", when the worth has moved.
    let dayChange: String?
    let dayChangeUp: Bool
    /// The tokens bought at a known price against what they cost: "Paid 1.2M · now 1.4M · ▲ 16%".
    let portfolio: String?
    let portfolioUp: Bool
    /// "Trading so far: +123K against what you paid · 4 sales at a profit"
    let trading: String?
    /// How trading works (iOS: MarketGuide), open until the first token is bought.
    let guide: [SymbolLineView]
    let guideStartsOpen: Bool
    let news: [NewsView]
    let tokens: [TokenView]
    /// The trades kept (the latest 50), newest first.
    let trades: [TradeView]
    /// "The latest 50 trades are kept. …", under the full list.
    let tradesFooter: String
}

/// A trade on the market (iOS: TradeRow).
struct TradeView: Encodable {
    let id: String
    let token: String
    /// "Bought 10 BTC" or "Sold 10 BTC"
    let title: String
    /// When it was made, in seconds since 1970.
    let date: Double
    /// "−1.2M" paid, or "+1.1M" received.
    let coins: String
    /// For a sale of bought tokens: "▲ 50K" against what they cost.
    let profit: String?
    let profitUp: Bool
}

/// What a Sell button would do, in full (iOS: SalePreviewLine).
struct SalePreviewView: Encodable {
    /// "Selling 10: 1.2M − 120K fee = 1.08M coins"
    let line: String
    /// "▲ 50K (4.8%) against what they cost", when some were bought.
    let profit: String?
    let profitUp: Bool
}

struct NewsView: Encodable {
    let id: String
    let isGood: Bool
    let headline: String
    /// When the news broke, in seconds since 1970 (the app writes "5 min ago").
    let date: Double
}

/// A token on the market (iOS: TokenMarketRow).
struct TokenView: Encodable {
    let id: String
    let name: String
    let ticker: String
    /// "stable", "moderate" or "volatile", with its name and what it means.
    let volatility: String
    let volatilityName: String
    let volatilityExplanation: String
    /// "Bitcoin stays between 50% and 150% of its usual price, 1M coins."
    let range: String
    let price: String
    /// "▲ 4.2%"
    let change: String
    let isUp: Bool
    /// "Own 12 · worth 1.2M", or "None owned"
    let holding: String
    /// Price factors over the last day, oldest first, for the sparkline.
    let history: [Double]
    /// Buying and selling ×1, ×10, ×100 and Max, in that order.
    let buy: [TradeOption]
    let sell: [TradeOption]
}

struct TradeOption: Encodable {
    let count: Int
    /// "Buy 10" or "Sell 10"
    let label: String
    /// The price, or what the sale pays ("+1.2M"), or "None owned".
    let value: String
    let enabled: Bool
    /// For a sale: the fee, the coins and how it compares with what the tokens cost.
    let preview: SalePreviewView?
}

// MARK: - Building

extension GameSession {
    var shopView: ShopView {
        let game = state
        let revealed = MinerID.allCases.filter(game.isRevealed)
        let locked = MinerID.allCases.first { !game.isRevealed($0) }
        let bestValue = revealed.count > 1 ? game.bestValueMiner : nil
        // Step Boosters are only offered where steps can be counted.
        let notOwned = UpgradeID.allCases.filter {
            !game.upgrades.contains($0) && (canTrackSteps || $0.category != .steps)
        }
        let available = notOwned.filter(game.isRevealed).sorted { $0.cost < $1.cost }
        let undiscovered = notOwned.count - available.count
        let purchased = UpgradeID.allCases.filter(game.upgrades.contains)
        let recommended = game.isPrestigeRecommended
        let showsPrestige = recommended || game.prestigePoints > 0 || game.stats.lifetimeCoins >= Tuning.prestigeScale / 10
        // Shortcuts once the list is long enough to scroll past.
        let shortcuts = revealed.count >= 4 ? ["miners", "powerUps", "upgrades"] + (showsPrestige ? ["prestige"] : []) : []
        return ShopView(
            shortcuts: shortcuts,
            prestigeFirst: recommended,
            prestige: showsPrestige ? prestigeView : nil,
            minersDetail: "\(CoinFormat.rate(game.baseProduction)) per second",
            miners: revealed.map { minerView($0, isBestValue: $0 == bestValue) },
            lockedMiner: locked.map { lockedMinerView($0) },
            offlineMining: offlineMiningView,
            powerUps: PowerUpID.allCases.compactMap { powerUpView($0) },
            upgradesDetail: undiscovered > 0 ? "\(undiscovered) still hidden" : nil,
            upgradesEmpty: available.isEmpty
                ? (undiscovered > 0 ? "Keep mining to discover more upgrades." : "Every upgrade is yours.") : nil,
            upgrades: available.map { upgradeView($0, owned: false) },
            purchased: purchased.map { upgradeView($0, owned: true) })
    }

    func minerView(_ miner: MinerID, isBestValue: Bool) -> MinerView {
        let game = state
        let owned = game.owned(miner)
        let mkLevel = game.minerUpgradeLevel(miner)
        let legacy = game.legacyMultiplier(miner)
        let boosts = game.legacyBeneficiaries(of: miner)
        let milestone = game.nextMilestone(for: miner).flatMap { next -> ProgressLine? in
            guard owned > 0 else { return nil }
            let previous = Tuning.milestones.last { $0 <= owned } ?? 0
            return ProgressLine(
                fraction: clamped(Double(owned - previous) / Double(max(1, next - previous))),
                text: "\(CoinFormat.grouped(next - owned)) more for \(CoinFormat.multiplier(Tuning.milestoneMultiplier)) output")
        }
        // From the first milestone, so it doesn't crowd the opening.
        let legacyProgress: ProgressLine? = !boosts.isEmpty && owned >= 25
            ? ProgressLine(fraction: clamped(Double(owned) / Double(Tuning.legacyUnits)),
                           text: "\(CoinFormat.grouped(Tuning.legacyUnits - owned)) more to boost \(legacyNames(boosts)) \(CoinFormat.multiplier(Tuning.legacyMultiplier))")
            : nil
        let buy = [1, 10, 100, 0].map { quantity -> BuyOption in
            // Max buys as many as the balance allows (at least one, for the price label).
            let count = quantity == 0 ? max(1, game.maxAffordable(miner)) : quantity
            let price = game.price(of: miner, quantity: count)
            return BuyOption(count: count, label: "Buy \(CoinFormat.grouped(count))",
                             price: CoinFormat.cost(price), canAfford: price <= game.coins)
        }
        let upgrade = game.availableMinerUpgrade(miner).map { offer in
            MinerUpgradeView(name: miner.upgradeName(level: offer.level),
                             detail: "Doubles what your \(miner.pluralName) mine",
                             price: CoinFormat.cost(offer.price), canAfford: offer.price <= game.coins)
        }
        return MinerView(
            id: miner.rawValue, emoji: miner.emoji, name: miner.name, owned: owned,
            ownedText: owned > 0 ? "Owned \(CoinFormat.grouped(owned))" : nil,
            line: owned > 0 ? "\(CoinFormat.rate(game.rate(of: miner))) coins per second" : miner.blurb,
            nextOne: "Next one: +\(CoinFormat.rate(game.nextUnitGain(miner)))/s",
            isBestValue: isBestValue,
            mk: mkLevel > 0 ? "Mk \(MinerID.markName(level: mkLevel - 1))" : nil,
            legacy: legacy > 1 ? CoinFormat.multiplier(legacy) : nil,
            milestone: milestone, legacyProgress: legacyProgress, buy: buy, upgrade: upgrade,
            info: minerInfoView(miner))
    }

    func minerInfoView(_ miner: MinerID) -> MinerInfoView {
        let game = state
        let owned = game.owned(miner)
        let tiers = game.legacyTiers(for: miner)
        var legacy: String?
        if tiers > 0 {
            legacy = "Legacy \(CoinFormat.multiplier(game.legacyMultiplier(miner))): \(CoinFormat.multiplier(Tuning.legacyMultiplier)) for each of \(tiers) newer \(tiers == 1 ? "tier" : "tiers") with \(CoinFormat.grouped(Tuning.legacyUnits)) or more owned."
        } else if miner.tier + Tuning.legacyTierGap < MinerID.allCases.count {
            let first = MinerID.allCases[miner.tier + Tuning.legacyTierGap]
            legacy = "Legacy: earns \(CoinFormat.multiplier(Tuning.legacyMultiplier)) more for each tier from \(first.name) up with \(CoinFormat.grouped(Tuning.legacyUnits)) owned."
        }
        // What one more adds against the income, and how soon it repays its price.
        let gain = game.nextUnitGain(miner)
        let income = game.baseIdleIncome
        var payback: String?
        if gain > 0, income > 0, let seconds = GameState.payback(price: game.price(of: miner, quantity: 1), gain: gain) {
            payback = "One more adds \(CoinFormat.rate(gain)) a second, \(shareText(gain / income)) of your income, and pays for itself in \(CoinFormat.duration(seconds))."
        }
        return MinerInfoView(
            blurb: miner.blurb,
            owned: owned > 0 ? "Owned \(CoinFormat.grouped(owned)) · \(CoinFormat.rate(game.rate(of: miner))) coins per second" : nil,
            payback: payback,
            milestone: game.nextMilestone(for: miner).map {
                "At \(CoinFormat.grouped($0)) owned, they all earn \(CoinFormat.multiplier(Tuning.milestoneMultiplier)) more."
            },
            legacy: legacy, legacyActive: tiers > 0)
    }

    private func legacyNames(_ boosts: [MinerID]) -> String {
        switch boosts.count {
        case 1: boosts[0].name
        case 2: "\(boosts[0].name) and \(boosts[1].name)"
        default: "\(boosts.count) older miners"
        }
    }

    func lockedMinerView(_ miner: MinerID) -> LockedMinerView {
        let needsPrestige = miner.needsPrestige && state.stats.prestiges == 0
        let text = needsPrestige
            ? "Prestige once to discover new miners beyond the stars."
            : miner.previous.map { "Buy a \($0.name) to reveal" } ?? ""
        return LockedMinerView(needsPrestige: needsPrestige, text: text)
    }

    var offlineMiningView: OfflineMiningView {
        let game = state
        let level = game.offlineMiningLevel
        let price = game.offlineMiningPrice
        let cap = GameState.offlineCap(level: level)
        let nextCap = GameState.offlineCap(level: level + 1)
        return OfflineMiningView(
            subtitle: level > 0 ? "Level \(level)" : "Not bought yet",
            price: price.map(CoinFormat.cost), canAfford: price.map { $0 <= game.coins } ?? false,
            now: CoinFormat.duration(max(cap, Tuning.baseAwayTime)),
            next: price != nil ? CoinFormat.duration(nextCap) : nil)
    }

    /// A power-up's row, or nil while it's hidden.
    func powerUpView(_ powerUp: PowerUpID) -> PowerUpView? {
        let game = state
        let level = game.powerUpLevel(powerUp)
        if game.isRevealed(powerUp) {
            let price = game.powerUpPrice(powerUp)
            return PowerUpView(
                id: powerUp.rawValue, name: powerUp.name, symbol: powerUp.symbol, summary: powerUp.summary,
                subtitle: "Level \(level) of \(powerUp.maxLevel)", level: level, maxLevel: powerUp.maxLevel,
                showsPips: powerUp.showsLevelPips,
                price: price.map(CoinFormat.cost), canAfford: price.map { $0 <= game.coins } ?? false,
                valueName: powerUp.valueName, now: powerUp.value(atLevel: level),
                next: price != nil ? powerUp.value(atLevel: level + 1) : nil, locked: nil)
        }
        guard let required = powerUp.requires, game.powerUpLevel(required) > 0 else { return nil }
        return PowerUpView(
            id: powerUp.rawValue, name: powerUp.name, symbol: powerUp.symbol, summary: powerUp.summary,
            subtitle: "Locked", level: level, maxLevel: powerUp.maxLevel, showsPips: powerUp.showsLevelPips,
            price: nil, canAfford: false, valueName: powerUp.valueName, now: powerUp.value(atLevel: level),
            next: nil, locked: "Opens when \(required.name) reaches level \(required.maxLevel)")
    }

    func upgradeView(_ upgrade: UpgradeID, owned: Bool) -> UpgradeView {
        UpgradeView(id: upgrade.rawValue, name: upgrade.name, summary: upgrade.summary, symbol: upgrade.symbol,
                    category: categoryKey(upgrade.category), price: CoinFormat.cost(upgrade.cost),
                    canAfford: !owned && upgrade.cost <= state.coins, gain: owned ? nil : gainText(of: upgrade))
    }

    /// What an upgrade adds in this game: a share of income and how soon it repays its price, or a
    /// share of each tap for tapping upgrades without automatic taps. Nil for upgrades that add
    /// neither (steps and mini-games: their summaries say what they do).
    private func gainText(of upgrade: UpgradeID) -> String? {
        let game = state
        let income = game.baseIdleIncome
        let gain = game.incomeGain(of: upgrade)
        if income > 0, gain > 0, let payback = GameState.payback(price: upgrade.cost, gain: gain) {
            return "\(shareText(gain / income)) income · pays for itself in \(CoinFormat.duration(payback))"
        }
        let tap = game.baseTapValue
        let tapGain = game.tapGain(of: upgrade)
        if tap > 0, tapGain > 0 {
            return "\(shareText(tapGain / tap)) per tap"
        }
        return nil
    }

    /// A purchase's share of the income, as the Shop writes it: "+2.1%", or "+<0.1%" for a sliver.
    private func shareText(_ share: Double) -> String {
        share > 0 && share < 0.001 ? "+<0.1%" : "+\(CoinFormat.percent(share))"
    }

    func categoryKey(_ category: UpgradeCategory) -> String {
        switch category {
        case .tapping: "tapping"
        case .production: "production"
        case .steps: "steps"
        case .miniGames: "miniGames"
        }
    }

    // MARK: Prestige

    var prestigeView: PrestigeView {
        let game = state
        let claimable = game.claimablePrestigePoints
        let potential = game.prestigePotential
        let previous = pow(Double(potential), 3) * Tuning.prestigeScale
        let next = game.nextPrestigePointAt
        let fraction = clamped((game.stats.lifetimeCoins - previous) / max(1, next - previous))
        let recommended = game.isPrestigeRecommended
        let affordablePerks = PerkID.allCases.filter(game.canBuy).count
        let message: String
        if claimable == 0 {
            message = "Mine \(CoinFormat.cost(next)) coins in all to earn your next prestige point. Every point adds \(CoinFormat.percent(Tuning.productionPerPrestigePoint)) production forever."
        } else {
            let points = "\(CoinFormat.grouped(claimable)) point\(claimable == 1 ? "" : "s")"
            message = recommended
                ? "Prestige now for \(points): your next run mines \(CoinFormat.multiplier(game.prestigeSpeedUp)) as fast. Points also buy perks."
                : "Prestiging now earns \(points), making the next run \(CoinFormat.multiplier(game.prestigeSpeedUp)) as fast. It's usually worth waiting for at least ×1.5."
        }
        return PrestigeView(
            points: game.prestigePoints > 0
                ? "\(CoinFormat.grouped(game.prestigePoints)) points · +\(CoinFormat.percent(game.prestigeGain(game.prestigePoints)))" : nil,
            message: message, recommended: recommended, fraction: fraction,
            progress: "\(CoinFormat.percent(fraction)) of the way to the next point",
            claim: claimable > 0 ? "Prestige for +\(CoinFormat.grouped(claimable))" : nil,
            perksTitle: affordablePerks > 0 ? "Perks (\(affordablePerks) ready)" : "Perks",
            confirm: prestigeConfirmView)
    }

    var prestigeConfirmView: PrestigeConfirmView {
        let game = state
        let claimable = game.claimablePrestigePoints
        var gains: [LineView] = [
            .value("Points gained", "+\(CoinFormat.grouped(claimable))"),
            .value("Production bonus after", "+\(CoinFormat.percent(game.prestigeGain(game.prestigePoints + claimable)))"),
            .value("Next run speed", CoinFormat.multiplier(game.prestigeSpeedUp)),
        ]
        if game.runPrestigeMultiplier != 1 {
            gains.append(.value("Difficulty multiplier", CoinFormat.multiplier(game.runPrestigeMultiplier)))
        }
        var resets = [SymbolLineView(symbol: "arrow.counterclockwise", text: "Coins, tokens and miners")]
        if !game.hasPerk(.engineeringTeam) {
            resets.append(SymbolLineView(symbol: "arrow.up.forward.circle", text: "Miner Mk upgrades"))
        }
        let upgrades: String = switch (game.hasPerk(.blueprints), game.hasPerk(.muscleMemory)) {
        case (true, true): "Step and mini-game upgrades (Blueprints and Muscle Memory keep the rest)"
        case (true, false): "Tapping, step and mini-game upgrades (Blueprints keeps production upgrades)"
        case (false, true): "Production, step and mini-game upgrades (Muscle Memory keeps tapping upgrades)"
        case (false, false): "Upgrades"
        }
        resets.append(SymbolLineView(symbol: "sparkles", text: upgrades))
        var keeps = [
            SymbolLineView(symbol: "rosette", text: "Prestige points, their bonus and your perks"),
            SymbolLineView(symbol: "trophy", text: "Achievements and statistics"),
            SymbolLineView(symbol: "moon.zzz", text: "Offline Mining and Offline Efficiency"),
            SymbolLineView(symbol: "gamecontroller", text: "Unlocked mini-games"),
            SymbolLineView(symbol: "calendar", text: "Your daily streak and quests"),
            SymbolLineView(symbol: "figure.walk", text: "Steps already rewarded"),
        ]
        if game.hasPerk(.headStart) {
            keeps.append(SymbolLineView(symbol: "flag.checkered", text: "Head Start: 10 Chromebooks, 10 Desktops and 5 GPU Rigs"))
        }
        let finish = CoinFinish.allCases.first { $0.prestigesNeeded == game.stats.prestiges + 1 }
        return PrestigeConfirmView(
            gains: [ListSectionView(header: nil, footer: nil, lines: gains)],
            resets: resets, keeps: keeps,
            firstNote: game.stats.prestiges == 0
                ? "Your first prestige also reveals three new miners beyond the Space Mining Colony." : nil,
            finish: finish?.rawValue,
            finishNote: finish.map { "This prestige unlocks the \($0.name) coin finish." },
            canPrestige: claimable > 0)
    }

    var perksView: PerksView {
        let game = state
        return PerksView(
            available: CoinFormat.grouped(game.availablePrestigePoints),
            earned: CoinFormat.grouped(game.prestigePoints),
            footer: "Every point ever earned adds \(CoinFormat.percent(Tuning.productionPerPrestigePoint)) production, even after you spend it on perks. Perks last forever.",
            branches: PerkBranch.allCases.map { branch in
                PerkBranchView(id: branch.rawValue, name: branch.name, symbol: branchSymbol(branch),
                               perks: perks(in: branch).map { perkView($0) })
            })
    }

    private func branchSymbol(_ branch: PerkBranch) -> String {
        switch branch {
        case .mining: "cpu"
        case .tapping: "hand.tap.fill"
        case .fortune: "dice.fill"
        }
    }

    /// A branch's perks in tree order: each perk followed by the ones it opens up (iOS: PerkTreeView.perks).
    private func perks(in branch: PerkBranch) -> [PerkID] {
        let all = PerkID.allCases.filter { $0.branch == branch }.sorted { $0.cost < $1.cost }
        func children(of parent: PerkID?) -> [PerkID] {
            all.filter { $0.requires == parent }.flatMap { [$0] + children(of: $0) }
        }
        return children(of: nil)
    }

    private func perkView(_ perk: PerkID) -> PerkView {
        let game = state
        let owned = game.hasPerk(perk)
        let available = game.isPerkAvailable(perk)
        var requirement: String?
        if !owned, let required = perk.requires {
            requirement = available ? "After \(required.name)" : "Needs \(required.name) first"
        }
        return PerkView(id: perk.rawValue, name: perk.name, summary: perk.summary, symbol: perk.symbol,
                        isOwned: owned, canBuy: game.canBuy(perk),
                        price: "\(CoinFormat.grouped(perk.cost)) \(perk.cost == 1 ? "pt" : "pts")",
                        requirement: requirement, requirementMet: available)
    }

    // MARK: Tokens

    var tokensView: TokensView {
        let game = state
        let holdings = TokenID.allCases.reduce(0.0) { $0 + market.quote($1).price * Double(game.tokenCount($1)) }
        let sale = (holdings * game.marketSellRate).rounded()
        let fee = game.marketSellRate < 1
            ? "Selling costs a \(CoinFormat.percent(1 - game.marketSellRate)) fee"
            : "No selling fee (Market Insider)"
        // What the same tokens were worth a day ago.
        let dayAgo = TokenID.allCases.reduce(0.0) { total, token in
            let quote = market.quote(token)
            return total + quote.price / max(1 + quote.change, 1e-9) * Double(game.tokenCount(token))
        }
        let dayChange = holdings - dayAgo
        let portfolio = game.portfolio(at: now)
        let stats = game.stats
        var portfolioLine: String?
        if portfolio.paid > 0, let share = portfolio.changeShare {
            portfolioLine = "Paid \(CoinFormat.short(portfolio.paid)) · now \(CoinFormat.short(portfolio.worthOfPaid)) · \(portfolio.change >= 0 ? "▲" : "▼") \(CoinFormat.percent(abs(share)))"
        }
        let feeShare = 1 - game.marketSellRate
        return TokensView(
            holdings: amount(holdings),
            walletLine: holdings > 0 ? "Sells for \(CoinFormat.short(sale)) · \(fee)" : "Buy tokens below to bet them or trade them.",
            dayChange: holdings > 0 && dayAgo > 0 && abs(dayChange) >= 1
                ? "\(dayChange >= 0 ? "▲" : "▼") \(CoinFormat.short(abs(dayChange))) (\(CoinFormat.percent(abs(dayChange) / dayAgo))) in the last day" : nil,
            dayChangeUp: dayChange >= 0,
            portfolio: portfolioLine, portfolioUp: portfolio.change >= 0,
            trading: stats.tokensSold > 0 && (stats.tradingProfit != 0 || stats.profitableSales > 0)
                ? "Trading so far: \(stats.tradingProfit >= 0 ? "+" : "−")\(CoinFormat.short(abs(stats.tradingProfit))) against what you paid · \(stats.profitableSales) sales at a profit" : nil,
            guide: [
                SymbolLineView(symbol: "gamecontroller.fill", text: "These are the game's own tokens. Their prices are simulated, not real cryptocurrency prices, and no real money is involved."),
                SymbolLineView(symbol: "clock.arrow.2.circlepath", text: "Prices move every five minutes, and news nudges them up or down. Volatile tokens move the most; Tether hardly at all. Tap a token's icon to see how it moves."),
                SymbolLineView(symbol: "arrow.up.right", text: feeShare > 0
                    ? "Buy low and sell high. Selling takes a \(CoinFormat.percent(feeShare)) fee, so a token has to rise by more than that before selling it pays."
                    : "Buy low and sell high. Market Insider means selling costs no fee."),
                SymbolLineView(symbol: "suit.spade.fill", text: "Tokens are the casino's chips too. They reset when you prestige, so sell or spend them before you do."),
            ],
            guideStartsOpen: stats.totalTokensBought == 0,
            news: market.news.prefix(3).map {
                NewsView(id: $0.id, isGood: $0.isGood, headline: $0.headline, date: $0.date.timeIntervalSince1970)
            },
            tokens: TokenID.allCases.map(tokenView),
            trades: game.recentTrades.reversed().map(tradeView),
            tradesFooter: "The latest \(Tuning.tradeHistoryLimit) trades are kept. A sale's result compares it with the average price you've paid for that token.")
    }

    private func tradeView(_ trade: TokenTrade) -> TradeView {
        TradeView(
            id: trade.id, token: trade.token.rawValue,
            title: trade.isSale ? "Sold \(CoinFormat.grouped(-trade.quantity)) \(trade.token.ticker)"
                : "Bought \(CoinFormat.grouped(trade.quantity)) \(trade.token.ticker)",
            date: trade.date.timeIntervalSince1970,
            coins: "\(trade.isSale ? "+" : "−")\(CoinFormat.short(trade.coins))",
            profit: trade.profit.map { "\($0 >= 0 ? "▲" : "▼") \(CoinFormat.short(abs($0)))" },
            profitUp: (trade.profit ?? 0) >= 0)
    }

    /// What selling `count` would come to (iOS: SalePreviewLine).
    private func salePreview(_ token: TokenID, count: Int) -> SalePreviewView {
        let preview = state.salePreview(of: token, quantity: count, at: now)
        let line = preview.fee > 0
            ? "Selling \(CoinFormat.grouped(count)): \(CoinFormat.short(preview.worth)) − \(CoinFormat.short(preview.fee)) fee = \(CoinFormat.short(preview.net)) coins"
            : "Selling \(CoinFormat.grouped(count)): \(CoinFormat.short(preview.net)) coins, no fee"
        var profitLine: String?
        if let profit = preview.profit, let paid = preview.paid, paid > 0 {
            let arrow = profit >= 0 ? "▲" : "▼"
            profitLine = preview.bought < preview.count
                ? "\(arrow) \(CoinFormat.short(abs(profit))) (\(CoinFormat.percent(abs(profit) / paid))) on the \(CoinFormat.grouped(preview.bought)) you bought, against what they cost"
                : "\(arrow) \(CoinFormat.short(abs(profit))) (\(CoinFormat.percent(abs(profit) / paid))) against what they cost"
        }
        return SalePreviewView(line: line, profit: profitLine, profitUp: (preview.profit ?? 0) >= 0)
    }

    private func tokenView(_ token: TokenID) -> TokenView {
        let game = state
        let quote = market.quote(token)
        let owned = game.tokenCount(token)
        let affordable = Int(min((game.coins / max(1, quote.price)).rounded(.down), 1_000_000))
        let isUp = quote.change >= 0
        let level = token.volatilityLevel
        let range = token.priceRange
        let buy = [1, 10, 100, 0].map { quantity -> TradeOption in
            let count = quantity == 0 ? max(1, affordable) : quantity
            return TradeOption(count: count, label: "Buy \(CoinFormat.grouped(count))",
                               value: CoinFormat.cost(quote.price * Double(count)), enabled: affordable > 0 && count <= affordable,
                               preview: nil)
        }
        let sell = [1, 10, 100, 0].map { quantity -> TradeOption in
            let count = quantity == 0 ? owned : min(quantity, owned)
            let sale = (quote.price * Double(count) * game.marketSellRate).rounded()
            return TradeOption(count: count, label: count > 0 ? "Sell \(CoinFormat.grouped(count))" : "Sell",
                               value: count > 0 ? "+\(CoinFormat.short(sale))" : "None owned", enabled: count > 0,
                               preview: count > 0 ? salePreview(token, count: count) : nil)
        }
        return TokenView(
            id: token.rawValue, name: token.name, ticker: token.ticker,
            volatility: level.rawValue, volatilityName: level.name, volatilityExplanation: volatilityExplanation(level),
            range: "\(token.name) stays between \(CoinFormat.percent(range.lowerBound)) and \(CoinFormat.percent(range.upperBound)) of its usual price, \(CoinFormat.cost(token.price)) coins.",
            price: CoinFormat.cost(quote.price),
            change: "\(isUp ? "▲" : "▼") \(CoinFormat.percent(abs(quote.change)))", isUp: isUp,
            holding: owned > 0 ? "Own \(CoinFormat.grouped(owned)) · worth \(CoinFormat.short(quote.price * Double(owned)))" : "None owned",
            history: quote.history.map(finite), buy: buy, sell: sell)
    }

    private func volatilityExplanation(_ level: TokenVolatility) -> String {
        switch level {
        case .stable: "A stablecoin: its price barely moves, news and all. A safe place to keep tokens, with nothing to gain from trading."
        case .moderate: "Its price drifts up and down over hours and days, and news nudges it. Buying on a dip and selling on a rise can pay, after the fee."
        case .volatile: "Its price swings hard and jumps about every few minutes: it can halve, or nearly double. The biggest trading gains, and the biggest losses."
        }
    }
}
