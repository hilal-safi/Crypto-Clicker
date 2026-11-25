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
/// an action, at most once a second from the clock. What floats over every tab is always here;
/// each screen's own view only while the app says that screen is on display (`Request.views`),
/// so the game isn't worked out for screens nobody is looking at.
struct GameView: Encodable {
    let welcomeBack: WelcomeBackView?
    let purchaseNote: PurchaseNoteView?
    let airdrop: AirdropView?
    let unreadableSave: UnreadableSaveView?
    let errorMessage: String?
    /// Whether this build has the Testing Tools (debug builds only).
    let debugTools: Bool
    /// Daily rewards waiting to be claimed, for the Trophies tab's badge.
    let dailyBadge: Int
    /// Starter milestones reached and waiting to be claimed (the Goals page's count).
    let starterClaims: Int
    /// Whether steps are connected (the app reads Health Connect every few minutes while open) and
    /// how many days back it reads.
    let stepsConnected: Bool
    let stepWindowDays: Int

    // Screens ("shop", …), when asked for.
    let shop: ShopView?
    let tokens: TokensView?
    let perks: PerksView?
    let goals: GoalsView?
    let daily: DailyView?
    let achievements: AchievementsView?
    let arcade: ArcadeView?
    let gameCards: [GameCardView]?
    let guides: [GuideView]?
    let style: StyleView?
    /// The looks equipped for each kind, as "slot=cosmetic", for the game screens.
    let looks: [String]?
    let mine: MineView?
    let income: IncomeView?
}

/// A falling airdrop: catch it before it goes for coins or a Bull Run. A rare whale is bigger,
/// bluer and worth up to an hour of income.
struct AirdropView: Encodable {
    let id: String
    let isWhale: Bool
    /// "Airdrop incoming!" or "Whale airdrop!"
    let title: String
    /// "Tap to catch it"
    let subtitle: String
    /// Seconds until it goes, of `lifetime`.
    let remaining: Double
    let lifetime: Double
    let accessibility: String
}

// MARK: - Shop

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
    /// What a step walked from now on pays, once steps are connected.
    let perStep: GainView?
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

    func gameView(views: Set<String>, debugTools: Bool) -> GameView {
        GameView(welcomeBack: welcomeBackView, purchaseNote: purchaseNoteView, airdrop: airdropView,
                 unreadableSave: unreadableSaveView, errorMessage: errorMessage, debugTools: debugTools,
                 dailyBadge: dailyBadgeCount, starterClaims: game.claimableStarterMilestones.count, stepsConnected: game.steps.isConnected,
                 stepWindowDays: Tuning.stepWindowDays,
                 shop: views.contains("shop") ? shopView : nil,
                 tokens: views.contains("tokens") ? tokensView : nil,
                 perks: views.contains("perks") ? perksView : nil,
                 goals: views.contains("goals") ? goalsView : nil,
                 daily: views.contains("daily") ? dailyView : nil,
                 achievements: views.contains("achievements") ? achievementsView : nil,
                 arcade: views.contains("arcade") ? arcadeView : nil,
                 gameCards: views.contains("gameCards") ? gameCardsView : nil,
                 guides: views.contains("guides") ? guidesView : nil,
                 style: views.contains("style") ? styleView : nil,
                 looks: views.contains("looks") ? equippedLooks : nil,
                 mine: views.contains("mine") ? mineView : nil,
                 income: views.contains("income") ? incomeView : nil)
    }

    var airdropView: AirdropView? {
        guard let airdrop else { return nil }
        let isWhale = airdrop.kind == .whale
        return AirdropView(
            id: airdrop.id.uuidString, isWhale: isWhale,
            title: isWhale ? "Whale airdrop!" : "Airdrop incoming!",
            subtitle: isWhale ? "Catch it for an hour of mining" : "Tap to catch it",
            remaining: max(0, airdrop.expiresAt.timeIntervalSince(now)), lifetime: max(1, airdrop.lifetime),
            accessibility: isWhale ? "Whale airdrop, worth an hour of mining. Tap to catch it before it disappears."
                                   : "Airdrop. Tap to catch it before it disappears.")
    }

    // MARK: Shop

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
            perStep: note.addedStep > 0
                ? GainView(added: "+\(CoinFormat.short(note.addedStep))", total: "now \(CoinFormat.short(note.stepNow))") : nil,
            effects: effects.isEmpty ? nil
                : effects.prefix(effectsShown).joined(separator: " · ")
                    + (effects.count > effectsShown ? " · +\(effects.count - effectsShown) more" : ""),
            remaining: remaining, lifetime: PurchaseNote.lifetime)
    }

    var welcomeBackView: WelcomeBackView? {
        guard let welcome = welcomeBack else { return nil }
        let game = state
        let report = welcome.report
        // What the time away gave: the steps walked and what they paid, then what it unlocked.
        var highlights: [IconLine] = []
        if welcome.steps > 0 {
            let steps = CoinFormat.grouped(welcome.steps)
            highlights.append(IconLine(icon: "👣", text: welcome.stepCoins > 0
                ? "\(steps) steps · +\(CoinFormat.short(welcome.stepCoins)) coins" : "\(steps) steps · paid tomorrow"))
        }
        highlights += welcome.achievements.map { earned in
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
        let percent = Int((report.efficiency * 100).rounded())
        let offlineNote = report.wasCapped
            ? OfflineNoteView(
                text: hasOfflineMining
                    ? "Offline Mining paid for \(CoinFormat.duration(report.credited)) of that, at \(percent)% of your income. Level it up to earn for longer, or raise Offline Efficiency to earn more."
                    : "Miners earn for \(CoinFormat.duration(Tuning.baseAwayTime)) after you leave, at \(percent)% of your income. Offline Mining keeps them earning for longer.",
                button: hasOfflineMining ? "Upgrade Offline Mining" : "Get Offline Mining")
            : nil
        let paidFor = report.offlineCap == 0 ? "\(CoinFormat.duration(report.credited)) (no Offline Mining)"
            : report.wasCapped ? "\(CoinFormat.duration(report.credited)) (Offline Mining limit)"
            : CoinFormat.duration(report.credited)
        var time = [TitledValue(title: "Away", value: CoinFormat.duration(report.elapsed)),
                    TitledValue(title: "Paid for", value: paidFor)]
        if report.offlineCap > 0 {
            time.append(TitledValue(title: "Income paid", value: "\(percent)%"))
        }
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
