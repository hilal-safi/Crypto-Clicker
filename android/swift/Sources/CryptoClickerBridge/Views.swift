import Foundation
import CryptoClickerKit

// What the Android screens show, worked out here from the game so both apps word and round every
// number the same way (CoinFormat). Kotlin only lays these out. Each view is plain data, sent as
// JSON; keys that would be nil are left out.

/// The balance and what changes it, sent on every tick (five times a second).
struct LiveView: Encodable, Equatable {
    /// The balance as a number, for animations.
    let coins: Double
    /// The balance in the short form (`12.3K`) and with every digit.
    let balance: String
    let balanceExact: String
    /// Coins per second (Bull Run included) and per tap, in both forms.
    let income: String
    let incomeExact: String
    let tap: String
    let tapExact: String
    /// The combo while quick taps keep it going (from its first +0.1).
    let combo: ComboView?
    /// The Bull Run while one lasts.
    let bullRun: BullRunView?
}

struct ComboView: Encodable, Equatable {
    /// "Combo ×1.5"
    let title: String
    /// "12 taps!"
    let taps: String
    /// At the combo's maximum: the pill turns red.
    let isMax: Bool
}

struct BullRunView: Encodable, Equatable {
    /// "BULL RUN ×2"
    let title: String
    /// "×2"
    let multiplier: String
    /// Time left: "4m 3s"
    let remaining: String
}

/// What one tap earned, for the "+value" that floats up from the coin.
struct TapView: Encodable, Equatable {
    let earned: String
    let earnedExact: String
}

/// Everything the screens show apart from the live balance. Sent when it changes: at once after
/// an action, at most once a second from the clock.
struct GameView: Encodable {
    let shop: ShopView
    let welcomeBack: WelcomeBackView?
    let purchaseNote: PurchaseNoteView?
    let unreadableSave: UnreadableSaveView?
    let errorMessage: String?
    /// Whether this build has the Testing Tools (debug builds only).
    let debugTools: Bool
}

// MARK: - Shop

struct ShopView: Encodable {
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
}

// MARK: - Popups

struct PurchaseNoteView: Encodable {
    let id: Int
    /// Goes up with every purchase added, so the app restarts the popup's timer.
    let stamp: Int
    /// "Item purchased!" or "3 items purchased!"
    let title: String
    /// The latest names: "GPU Rig ×3, Overclocking"
    let names: String
    /// "+2 more" when there are more names than shown.
    let more: String?
    let perSecond: GainView?
    let perTap: GainView?
    /// Effects other than coins: "Biggest combo ×3.5"
    let effects: String?
    /// Seconds until it goes, of `lifetime`.
    let remaining: Double
    let lifetime: Double
}

struct GainView: Encodable {
    /// "+10.3K"
    let added: String
    /// "now 10.5K"
    let total: String
}

struct WelcomeBackView: Encodable {
    let id: Int
    /// "You were away for 3h 4m."
    let away: String
    /// What the miners earned, short form.
    let earned: String
    let highlights: [IconLine]
    let suggestion: SuggestionView?
    /// Why only part of the time was paid, with a shortcut to Offline Mining.
    let offlineNote: OfflineNoteView?
    let time: [TitledValue]
    let sources: [SourceView]
    let total: String
    let multipliers: [TitledValue]
    let multiplierTotal: String
}

struct IconLine: Encodable {
    let icon: String
    let text: String
}

struct TitledValue: Encodable {
    let title: String
    let value: String
}

struct SuggestionView: Encodable {
    let name: String
    /// "+6 coins per second · pays for itself in 8m 20s"
    let detail: String
    let price: String
    let canAfford: Bool
    let bought: Bool
}

struct OfflineNoteView: Encodable {
    let text: String
    let button: String
}

struct SourceView: Encodable {
    /// A miner's emoji, or nil for automatic taps (the app shows a tap icon).
    let emoji: String?
    let name: String
    /// "×12" or "3.5 per second"
    let detail: String
    let coins: String
    let share: String
    let fraction: Double
}

struct UnreadableSaveView: Encodable {
    let title: String
    let message: String
}

// MARK: - Building the views

extension GameSession {
    var liveView: LiveView {
        let game = state
        let now = self.now
        let income = game.idleIncome(at: now)
        let tapValue = game.tapValue(at: now)
        let multiplier = comboMultiplier
        let combo = multiplier > 1
            ? ComboView(title: "Combo ×\(String(format: "%.1f", multiplier))",
                        taps: "\(CoinFormat.grouped(comboStreak)) taps!",
                        isMax: multiplier >= game.comboMaxMultiplier)
            : nil
        let bullRun = game.activeBoost(at: now).map { boost in
            BullRunView(title: "BULL RUN \(CoinFormat.multiplier(boost.multiplier))",
                        multiplier: CoinFormat.multiplier(boost.multiplier),
                        remaining: CoinFormat.duration(max(0, boost.endsAt.timeIntervalSince(now))))
        }
        return LiveView(coins: finite(game.coins),
                        balance: CoinFormat.short(game.coins), balanceExact: CoinFormat.exact(game.coins),
                        income: CoinFormat.rate(income), incomeExact: CoinFormat.exactRate(income),
                        tap: CoinFormat.short(tapValue), tapExact: CoinFormat.exact(tapValue),
                        combo: combo, bullRun: bullRun)
    }

    func gameView(debugTools: Bool) -> GameView {
        GameView(shop: shopView, welcomeBack: welcomeBackView, purchaseNote: purchaseNoteView,
                 unreadableSave: unreadableSaveView, errorMessage: errorMessage, debugTools: debugTools)
    }

    // MARK: Shop

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
        return ShopView(
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
            milestone: milestone, legacyProgress: legacyProgress, buy: buy, upgrade: upgrade)
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
            now: CoinFormat.duration(max(cap, Tuning.awayThreshold)),
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
                price: price.map(CoinFormat.cost), canAfford: price.map { $0 <= game.coins } ?? false,
                valueName: powerUp.valueName, now: powerUp.value(atLevel: level),
                next: price != nil ? powerUp.value(atLevel: level + 1) : nil, locked: nil)
        }
        guard let required = powerUp.requires, game.powerUpLevel(required) > 0 else { return nil }
        return PowerUpView(
            id: powerUp.rawValue, name: powerUp.name, symbol: powerUp.symbol, summary: powerUp.summary,
            subtitle: "Level \(level) of \(powerUp.maxLevel)", level: level, maxLevel: powerUp.maxLevel,
            price: nil, canAfford: false, valueName: powerUp.valueName, now: powerUp.value(atLevel: level),
            next: nil, locked: "Opens when \(required.name) reaches level \(required.maxLevel)")
    }

    func upgradeView(_ upgrade: UpgradeID, owned: Bool) -> UpgradeView {
        UpgradeView(id: upgrade.rawValue, name: upgrade.name, summary: upgrade.summary, symbol: upgrade.symbol,
                    category: categoryKey(upgrade.category), price: CoinFormat.cost(upgrade.cost),
                    canAfford: !owned && upgrade.cost <= state.coins)
    }

    private func categoryKey(_ category: UpgradeCategory) -> String {
        switch category {
        case .tapping: "tapping"
        case .production: "production"
        case .steps: "steps"
        case .miniGames: "miniGames"
        }
    }

    // MARK: Popups

    var purchaseNoteView: PurchaseNoteView? {
        guard let note = purchaseNote else { return nil }
        let namesShown = 3, effectsShown = 2
        let latest = Array(note.items.reversed())
        let names = latest.prefix(namesShown).map { $0.count > 1 ? "\($0.name) ×\(CoinFormat.grouped($0.count))" : $0.name }
        let effects = latest.compactMap(\.effect)
        let remaining = max(0, PurchaseNote.lifetime - now.timeIntervalSince(note.updatedAt))
        return PurchaseNoteView(
            id: note.id, stamp: note.stamp,
            title: note.itemCount == 1 ? "Item purchased!" : "\(CoinFormat.grouped(note.itemCount)) items purchased!",
            names: names.joined(separator: ", "),
            more: note.items.count > namesShown ? "+\(note.items.count - namesShown) more" : nil,
            perSecond: note.addedIncome > 0
                ? GainView(added: "+\(CoinFormat.rate(note.addedIncome))", total: "now \(CoinFormat.rate(note.incomeNow))") : nil,
            perTap: note.addedTap > 0
                ? GainView(added: "+\(CoinFormat.short(note.addedTap))", total: "now \(CoinFormat.short(note.tapNow))") : nil,
            effects: effects.isEmpty ? nil
                : effects.prefix(effectsShown).joined(separator: " · ")
                    + (effects.count > effectsShown ? " · +\(effects.count - effectsShown) more" : ""),
            remaining: remaining, lifetime: PurchaseNote.lifetime)
    }

    var welcomeBackView: WelcomeBackView? {
        guard let welcome = welcomeBack else { return nil }
        let game = state
        let report = welcome.report
        var highlights = welcome.achievements.map { earned in
            IconLine(icon: earned.achievement.emoji ?? "🏆", text: "\(earned.achievement.name) · \(earned.tierName)")
        }
        if welcome.newPrestigePoints > 0 {
            highlights.append(IconLine(icon: "🌟", text: "+\(CoinFormat.grouped(welcome.newPrestigePoints)) prestige points ready to claim"))
        }
        let quests = game.claimableQuestCount
        if quests > 0 {
            highlights.append(IconLine(icon: "📜", text: quests == 1 ? "A quest is ready to claim" : "\(quests) quests are ready to claim"))
        }
        let suggestion = welcome.suggestion.map { suggestion in
            SuggestionView(
                name: suggestion.name,
                detail: "+\(CoinFormat.rate(suggestion.incomeGain)) coins per second · pays for itself in \(CoinFormat.duration(suggestion.payback))",
                price: CoinFormat.cost(suggestion.price),
                // As on iOS: affordable, and still at the price shown (not bought elsewhere since).
                canAfford: suggestion.price <= game.coins && game.price(of: suggestion.purchase) == suggestion.price,
                bought: welcome.boughtSuggestion)
        }
        let hasOfflineMining = report.offlineCap > 0
        let offlineNote = report.wasCapped
            ? OfflineNoteView(
                text: hasOfflineMining
                    ? "Offline Mining paid for \(CoinFormat.duration(report.credited)) of that. Level it up to earn for longer."
                    : "Miners stop a minute after you leave. Offline Mining keeps them earning while the app is closed.",
                button: hasOfflineMining ? "Upgrade Offline Mining" : "Get Offline Mining")
            : nil
        let paidFor = report.offlineCap == 0 ? "\(CoinFormat.duration(report.credited)) (no Offline Mining)"
            : report.wasCapped ? "\(CoinFormat.duration(report.credited)) (Offline Mining limit)"
            : CoinFormat.duration(report.credited)
        var time = [TitledValue(title: "Away", value: CoinFormat.duration(report.elapsed)),
                    TitledValue(title: "Paid for", value: paidFor)]
        if report.boostedSeconds > 0 {
            time.append(TitledValue(title: "Bull Run \(CoinFormat.multiplier(report.boostMultiplier))",
                                    value: CoinFormat.duration(report.boostedSeconds)))
        }
        let sources = report.sources.map { source -> SourceView in
            let share = report.earned > 0 ? source.coins / report.earned : 0
            switch source.kind {
            case .miner(let miner):
                return SourceView(emoji: miner.emoji, name: miner.name, detail: "×\(CoinFormat.grouped(Int(source.count)))",
                                  coins: CoinFormat.short(source.coins), share: CoinFormat.percent(share),
                                  fraction: clamped(share))
            case .autoTaps:
                return SourceView(emoji: nil, name: "Automatic taps", detail: "\(CoinFormat.rate(source.count)) per second",
                                  coins: CoinFormat.short(source.coins), share: CoinFormat.percent(share),
                                  fraction: clamped(share))
            }
        }
        let multipliers = report.multipliers
        return WelcomeBackView(
            id: welcome.id, away: "You were away for \(CoinFormat.duration(report.elapsed)).",
            earned: CoinFormat.short(report.earned), highlights: highlights, suggestion: suggestion,
            offlineNote: offlineNote, time: time, sources: sources, total: CoinFormat.short(report.earned),
            multipliers: [TitledValue(title: "Upgrades", value: CoinFormat.multiplier(multipliers.upgrades)),
                          TitledValue(title: "Prestige", value: CoinFormat.multiplier(multipliers.prestige)),
                          TitledValue(title: "Achievements", value: CoinFormat.multiplier(multipliers.achievements)),
                          TitledValue(title: "Difficulty", value: CoinFormat.multiplier(multipliers.difficulty))],
            multiplierTotal: CoinFormat.multiplier(multipliers.total))
    }

    var unreadableSaveView: UnreadableSaveView? {
        guard let problem = unreadableSave else { return nil }
        return UnreadableSaveView(
            title: problem.attempts > 0 ? "Still couldn't read your save" : "Your saved game couldn't be read",
            message: "Part of the save file is damaged, so your progress can't be opened right now. Nothing has been deleted: the file is kept on this device as \(problem.fileName), so it can still be recovered. Until you choose, nothing new is saved.")
    }
}

/// Replaces NaN or infinity with zero, so a view never carries a number JSON can't hold.
func finite(_ value: Double) -> Double { value.isFinite ? value : 0 }

/// A progress fraction between 0 and 1.
func clamped(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 1) : 0 }
