import Foundation
import CryptoClickerKit

// The Mine tab and its Income page: what the iOS MineView, GuideTips, InventoryStrip, StepsCard
// and IncomeBreakdownView work out from the game, as text ready to show.

/// The Mine tab under the balance and the coin (iOS: MineView).
struct MineView: Encodable {
    /// The coin's looks that the player's achievement stars (and, for the last finishes, prestiges)
    /// have unlocked (`CoinFinish`, `CoinRim` and `CoinTapEffect` raw values). A look picked and
    /// locked again (after a reset) falls back to the plain one, as on iOS.
    let finishes: [String]
    let rims: [String]
    let tapEffects: [String]
    /// The tips that apply now, in the order they're offered; the app leaves out the ones the
    /// player closed and shows the first.
    let tips: [TipView]
    let inventory: InventoryView
    /// The goals button beside the tokens: the goal closest to done (or the prestige the Shop
    /// suggests), for its ring. Nil once there's nothing left to buy or unlock.
    let goal: GoalRingView?
    /// Steps on this phone, once they're unlocked (2,000 taps); nil until then.
    let steps: StepsView?
    /// The prestige points, from the first prestige on.
    let prestige: PrestigePointsView?
}

/// The goals button's ring (iOS: GoalsButton): it fills as the closest goal nears, and is green
/// with a checkered flag once it's ready.
struct GoalRingView: Encodable {
    let progress: Double
    let isReady: Bool
    /// "Next: Buy a GPU Rig, 45%"
    let accessibility: String
}

/// A first-run tip (iOS: GuideTip).
struct TipView: Encodable {
    /// "tapCoin", "buyMiner", "combo", "offlineMining", "nextTier", "howToPlay", "daily", "tokens",
    /// "firstPoint" or "prestige": what closing it remembers, and where its button goes.
    let id: String
    let icon: String
    let text: String
    /// The button that goes there, if the tip has one.
    let action: String?
}

/// What the player owns, under the coin (iOS: InventoryStrip).
struct InventoryView: Encodable {
    let miners: [InventoryMinerView]
    /// Offline Mining's time, once bought.
    let offline: String?
    /// Offline Efficiency's share of the income, once it has a level: "40%".
    let efficiency: String?
    /// The biggest combo, once a combo power-up is bought.
    let combo: String?
    /// Upgrades bought of all: "3/42".
    let upgrades: String?
    /// Perks bought.
    let perks: String?
    let minersLabel: String
    let tokens: [InventoryTokenView]
    let tokensLabel: String
}

struct InventoryMinerView: Encodable {
    let id: String
    let emoji: String
    let count: String
    /// The Mk upgrade as a Roman numeral, and the Legacy multiplier as a number.
    let mark: String?
    let legacy: String?
}

struct InventoryTokenView: Encodable {
    let id: String
    let count: String
}

/// Steps on the Mine tab (iOS: StepsCard): the invitation until they're connected, then today's
/// count and what it pays.
struct StepsView: Encodable {
    let connected: Bool
    /// "1,234 steps today"
    let today: String
    /// What a step pays, in full and in the shorter form that fits beside the prestige points.
    let pays: String
    let paysShort: String
    let info: StepInfoView
}

/// The coins-per-step pop-up (iOS: StepInfoBubble).
struct StepInfoView: Encodable {
    /// On the game's first day, the steps pay the day after.
    let firstDay: Bool
    /// "Each step pays 12 coins", or the first day's explanation.
    let headline: String
    let explanation: String
    /// The next step booster, or that every one is bought.
    let next: String
}

/// The prestige points on the Mine tab (iOS: PrestigeBadge).
struct PrestigePointsView: Encodable {
    /// "Prestige 3"
    let title: String
    /// "1,234" and "points"
    let count: String
    let unit: String
    /// "×1.25"
    let bonus: String
    let accessibility: String
}

/// Where the coins come from, right now (iOS: IncomeBreakdownView).
struct IncomeView: Encodable {
    /// "12.3K coins per second"
    let headline: String
    /// "1.2K per tap · 44.3M an hour · 1.06B a day"
    let subline: String
    let bullRun: String?
    let sections: [ListSectionView]
}

/// A group of lines on a list page (Income, Statistics, Your Journey), as an iOS List section.
struct ListSectionView: Encodable {
    let header: String?
    let footer: String?
    let lines: [LineView]
}

/// One line on a list page. `kind` says how it's drawn:
/// - "value": the title, its value at the end (and a detail under the value): iOS ValueRow
/// - "share": an emoji (or a symbol), the title over a detail, a rate and its share, and a bar
///   for the share: iOS ShareRow
/// - "text": the title as a plain line
struct LineView: Encodable {
    let kind: String
    let title: String
    let value: String?
    let detail: String?
    let bold: Bool
    let emoji: String?
    let symbol: String?
    /// For "share", from 0 to 1.
    let share: Double?

    static func value(_ title: String, _ value: String, detail: String? = nil, bold: Bool = false) -> LineView {
        LineView(kind: "value", title: title, value: value, detail: detail, bold: bold, emoji: nil, symbol: nil, share: nil)
    }

    static func share(_ title: String, detail: String, rate: String, share: Double, emoji: String? = nil,
                      symbol: String? = nil) -> LineView {
        LineView(kind: "share", title: title, value: rate, detail: detail, bold: false, emoji: emoji, symbol: symbol,
                 share: clamped(share))
    }

    static func text(_ text: String) -> LineView {
        LineView(kind: "text", title: text, value: nil, detail: nil, bold: false, emoji: nil, symbol: nil, share: nil)
    }
}

// MARK: - Building

/// The first-run tips, in the order they're offered (iOS: GuideTip).
enum GuideTip: String, CaseIterable {
    case tapCoin, buyMiner, combo, offlineMining, nextTier, howToPlay, daily, tokens, firstPoint, prestige

    var icon: String {
        switch self {
        case .tapCoin: "👆"
        case .buyMiner: "💻"
        case .combo: "🔥"
        case .offlineMining: "🌙"
        case .nextTier: "🚀"
        case .howToPlay: "📖"
        case .daily: "🎁"
        case .tokens: "🪙"
        case .firstPoint: "✨"
        case .prestige: "🌟"
        }
    }

    func text(in game: GameState) -> String {
        switch self {
        case .nextTier:
            let miner = Self.nextTier(in: game) ?? .desktop
            return "You can afford \(miner.article) \(miner.name). Each new tier earns far more a second than the one before."
        case .firstPoint:
            let points = CoinFormat.grouped(game.prestigePointsToRecommend)
            return "Your first prestige point is earned, but prestiging now would barely speed you up. Keep mining: the Shop suggests it at \(points) points."
        default:
            return text
        }
    }

    private var text: String {
        switch self {
        case .nextTier, .firstPoint: ""
        case .tapCoin: "Tap the coin to mine your first coins."
        case .buyMiner: "You can afford a Chromebook. Miners earn coins for you every second."
        case .combo: "Tap quickly to build a combo: up to twice the coins per tap."
        case .offlineMining: "Miners keep earning for six minutes after you leave, at a share of your income that Offline Efficiency raises. Offline Mining lengthens the time."
        case .howToPlay: "How to Play is in the Settings tab, with the full rules for every game."
        case .daily: "A daily reward is waiting. Claim one every day to build a streak, and check the day's quests."
        case .tokens: "Casino games are played with tokens from the Shop. Their prices move every five minutes, but they're the game's own, not real crypto."
        case .prestige: "Prestiging now would speed you up a lot. Your points also buy permanent perks."
        }
    }

    var actionTitle: String? {
        switch self {
        case .tapCoin, .combo: nil
        case .buyMiner, .nextTier: "Shop"
        case .offlineMining: "Get It"
        case .howToPlay: "Open"
        case .daily: "Daily"
        case .tokens: "Tokens"
        case .firstPoint: "Details"
        case .prestige: "Prestige"
        }
    }

    /// The first of the early tiers (Desktop to Data Center) not owned yet, once it shows in the Shop.
    static func nextTier(in game: GameState) -> MinerID? {
        MinerID.allCases.prefix(5).dropFirst().first { game.isRevealed($0) && game.owned($0) == 0 }
    }

    func applies(to game: GameState, dailyRewardReady: Bool) -> Bool {
        switch self {
        case .tapCoin:
            game.stats.taps < 15 && game.totalMiners == 0 && game.stats.prestiges == 0
        case .buyMiner:
            game.totalMiners == 0 && game.stats.prestiges == 0 && game.coins >= game.price(of: .chromebook, quantity: 1)
        case .combo:
            game.stats.bestCombo < 10 && game.stats.taps >= 60
        case .offlineMining:
            game.offlineMiningLevel == 0 && game.totalMiners >= 3 && game.offlineMiningPrice.map { game.coins >= $0 } == true
        case .nextTier:
            game.stats.prestiges == 0 && Self.nextTier(in: game).map { game.coins >= game.price(of: $0, quantity: 1) } == true
        case .howToPlay:
            (2...15).contains(game.totalMiners) && game.stats.prestiges == 0
        case .daily:
            dailyRewardReady && game.stats.longestStreak == 0 && game.totalMiners > 0
        case .tokens:
            // Once a casino game is open, until the first token is bought.
            game.unlockedGames.contains { $0.isCasino } && game.stats.totalTokensBought == 0
        case .firstPoint:
            game.stats.prestiges == 0 && game.claimablePrestigePoints > 0 && !game.isPrestigeRecommended
        case .prestige:
            game.stats.prestiges == 0 && game.isPrestigeRecommended
        }
    }
}

extension GameSession {
    /// A coin amount in the form the player picked: every digit, or short.
    func amount(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exact(value) : CoinFormat.short(value)
    }

    /// Coins a second in the form the player picked.
    func rateText(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exactRate(value) : CoinFormat.rate(value)
    }

    var mineView: MineView {
        let game = state
        let stars = game.earnedAchievementTiers
        let featured = game.featuredGoal
        return MineView(
            finishes: CoinFinish.allCases.filter { game.isUnlocked($0) }.map(\.rawValue),
            rims: CoinRim.allCases.filter { $0.isUnlocked(stars: stars) }.map(\.rawValue),
            tapEffects: CoinTapEffect.allCases.filter { $0.isUnlocked(stars: stars) }.map(\.rawValue),
            tips: GuideTip.allCases.filter { $0.applies(to: game, dailyRewardReady: isDailyRewardReady) }.map {
                TipView(id: $0.rawValue, icon: $0.icon, text: $0.text(in: game), action: $0.actionTitle)
            },
            inventory: inventoryView,
            goal: featured.map { goal -> GoalRingView in
                let isReady = goal.progress >= 1
                return GoalRingView(
                    progress: clamped(goal.progress), isReady: isReady,
                    accessibility: "Next: \(goal.title), \(isReady ? "ready" : CoinFormat.percent((goal.progress * 100).rounded(.down) / 100))")
            },
            steps: canTrackSteps && game.areStepsUnlocked ? stepsView : nil,
            prestige: game.stats.prestiges > 0 ? prestigePointsView : nil)
    }

    var inventoryView: InventoryView {
        let game = state
        let miners = MinerID.allCases.filter { game.owned($0) > 0 }
        let tokens = TokenID.allCases.filter { game.tokenCount($0) > 0 }
        let hasComboPowerUps = PowerUpID.allCases.contains { $0.isCombo && game.powerUpLevel($0) > 0 }
        let efficiencyLevel = game.powerUpLevel(.offlineEfficiency)
        let efficiency = "\(Tuning.offlineEfficiencyPercent(level: efficiencyLevel))%"
        // Legacy as a plain number ("5", "3,125"), then short once it's long ("48.8K").
        func legacyText(_ multiplier: Double) -> String {
            multiplier < 10_000 ? CoinFormat.grouped(Int(multiplier.rounded())) : CoinFormat.short(multiplier)
        }
        var parts = miners.map { "\(game.owned($0)) \($0.name)" }
        if game.offlineMiningLevel > 0 { parts.append("Offline Mining \(CoinFormat.duration(game.offlineCap)) at \(efficiency)") }
        if hasComboPowerUps { parts.append("combos up to \(CoinFormat.multiplier(game.comboMaxMultiplier))") }
        if !game.upgrades.isEmpty { parts.append("\(game.upgrades.count) upgrades") }
        if !game.perks.isEmpty { parts.append("\(game.perks.count) perks") }
        let value = tokens.reduce(0.0) { $0 + market.quote($1).price * Double(game.tokenCount($1)) }
        return InventoryView(
            miners: miners.map { miner in
                let mk = game.minerUpgradeLevel(miner)
                let legacy = game.legacyMultiplier(miner)
                return InventoryMinerView(id: miner.rawValue, emoji: miner.emoji,
                                          count: CoinFormat.short(Double(game.owned(miner))),
                                          mark: mk > 0 ? MinerID.markName(level: mk - 1) : nil,
                                          legacy: legacy > 1 ? legacyText(legacy) : nil)
            },
            offline: game.offlineMiningLevel > 0 ? CoinFormat.duration(game.offlineCap) : nil,
            efficiency: efficiencyLevel > 0 ? efficiency : nil,
            combo: hasComboPowerUps ? CoinFormat.multiplier(game.comboMaxMultiplier) : nil,
            upgrades: game.upgrades.isEmpty ? nil : "\(game.upgrades.count)/\(UpgradeID.allCases.count)",
            perks: game.perks.isEmpty ? nil : "\(game.perks.count)",
            minersLabel: "Miners and power-ups: " + parts.joined(separator: ", "),
            tokens: tokens.map { InventoryTokenView(id: $0.rawValue, count: CoinFormat.short(Double(game.tokenCount($0)))) },
            tokensLabel: "Crypto worth \(CoinFormat.short(value)) coins: "
                + tokens.map { "\(game.tokenCount($0)) \($0.name)" }.joined(separator: ", "))
    }

    var stepsView: StepsView {
        let game = state
        let today = self.today
        let isToday = game.steps.todayKey == today
        let pending = game.pendingStepCoins(today: today)
        let value = game.stepValue(today: today)
        let perStep = "\(CoinFormat.short(value)) coin\(value == 1 ? "" : "s")"
        let paidTomorrow = game.stepsPaidNextDay(today: today)
        return StepsView(
            connected: game.steps.isConnected,
            today: "\(CoinFormat.grouped(isToday ? game.steps.todaySteps : 0)) steps today",
            pays: pending > 0 ? "Pays about +\(CoinFormat.short(pending)) tomorrow"
                : paidTomorrow ? "Every step pays \(perStep) tomorrow"
                : "Every step pays \(perStep) as you walk",
            paysShort: pending > 0 ? "About +\(CoinFormat.short(pending)) tomorrow"
                : paidTomorrow ? "\(perStep) a step tomorrow"
                : "\(perStep) a step",
            info: stepInfoView)
    }

    var stepInfoView: StepInfoView {
        let game = state
        let firstDay = game.stepsPaidNextDay(today: today)
        let value = game.stepValue
        let boost = game.stepMultiplier
        let share = Int((Tuning.stepSeconds * 100).rounded())
        let coins = value == 1 ? "coin" : "coins"
        let next = UpgradeID.allCases.first { $0.category == .steps && !game.upgrades.contains($0) }
        var nextText = "Every step booster is bought."
        if let next, case .steps(let factor) = next.effect {
            nextText = "Next: \(next.name), \(CoinFormat.multiplier(factor)), for \(CoinFormat.short(next.cost)) coins in the Shop."
        }
        let income = "A step is worth \(share)% of a second's income (\(CoinFormat.rate(game.rewardIncome)) a second), at least a coin"
        return StepInfoView(
            firstDay: firstDay,
            headline: firstDay
                ? "Today's steps pay 1 coin each, tomorrow. From then on, steps pay \(CoinFormat.short(value)) \(coins) each as you walk."
                : "Each step pays \(CoinFormat.short(value)) \(coins)",
            explanation: boost > 1 ? "\(income), \(CoinFormat.multiplier(boost)) from step boosters." : "\(income).",
            next: nextText)
    }

    var prestigePointsView: PrestigePointsView {
        let game = state
        let points = game.prestigePoints
        let count = points < 100_000 ? CoinFormat.grouped(points) : CoinFormat.short(Double(points))
        let unit = points == 1 ? "point" : "points"
        return PrestigePointsView(
            title: "Prestige \(CoinFormat.grouped(game.stats.prestiges))", count: count, unit: unit,
            bonus: CoinFormat.multiplier(game.prestigeBonus),
            accessibility: "Prestige: \(points) \(unit), production \(CoinFormat.multiplier(game.prestigeBonus))")
    }

    // MARK: Income

    var incomeView: IncomeView {
        let game = state
        let now = self.now
        let production = game.production(at: now)
        let idle = game.idleIncome(at: now)
        let autoTaps = max(0, idle - production)
        let boost = game.activeBoost(at: now)
        let tapValue = game.tapValue(at: now)
        let miners = MinerID.allCases
            .filter { game.owned($0) > 0 }
            .sorted { game.rate(of: $0) > game.rate(of: $1) }

        var earned: [LineView] = []
        if miners.isEmpty {
            earned.append(.text("Buy a miner in the Shop and it shows up here."))
        }
        for miner in miners {
            let minerRate = game.rate(of: miner) * (boost?.multiplier ?? 1)
            earned.append(.share("\(miner.name) ×\(CoinFormat.grouped(game.owned(miner)))", detail: boosts(of: miner),
                                 rate: rateText(minerRate), share: idle > 0 ? minerRate / idle : 0, emoji: miner.emoji))
        }
        if autoTaps > 0 {
            earned.append(.share("Automatic taps",
                                 detail: "\(CoinFormat.rate(game.autoTapsPerSecond)) a second, each worth \(CoinFormat.percent(game.autoTapStrength)) of a tap",
                                 rate: rateText(autoTaps), share: idle > 0 ? autoTaps / idle : 0, symbol: "hand.tap.fill"))
        }

        // What the miners make with their milestones, Mk upgrades and Legacy, before the
        // multipliers below.
        let global = game.globalMultiplier
        var multipliers: [LineView] = [
            .value("Miners before these", "\(rateText(global > 0 ? game.baseProduction / global : 0))/s"),
            .value("Upgrades", CoinFormat.multiplier(game.upgradeProductionMultiplier)),
            .value("Prestige (\(CoinFormat.grouped(game.prestigePoints)) points)", CoinFormat.multiplier(game.prestigeBonus)),
            .value("Achievements (\(game.earnedAchievementTiers) stars)", CoinFormat.multiplier(game.achievementBonus)),
            .value("Difficulty (\(game.difficulty.name))", CoinFormat.multiplier(game.difficulty.productionMultiplier)),
        ]
        if let boost { multipliers.append(.value("Bull Run", CoinFormat.multiplier(boost.multiplier))) }
        multipliers.append(.value("All together", CoinFormat.multiplier(game.globalMultiplier * (boost?.multiplier ?? 1)), bold: true))
        multipliers.append(.value("Production", "\(rateText(production))/s", bold: true))

        var tap: [LineView] = [
            .value("Flat part", amount(game.tapBase)),
            .value("\(CoinFormat.percent(game.tapShare)) of production", amount(game.tapShare * production)),
        ]
        if game.tapPerkMultiplier != 1 { tap.append(.value("Strong Fingers", CoinFormat.multiplier(game.tapPerkMultiplier))) }
        tap.append(.value("Each tap", amount(tapValue), bold: true))
        tap.append(.value("With the biggest combo (\(CoinFormat.multiplier(game.comboMaxMultiplier)))",
                          amount((tapValue * game.comboMaxMultiplier).rounded())))
        tap.append(.value("Combo pace", "+0.1 every \(CoinFormat.compact(game.comboTapsPerStep)) quick taps"))
        if comboStreak > 1 {
            tap.append(.value("Combo now", "\(CoinFormat.multiplier(comboMultiplier)) · \(comboStreak) taps"))
        }

        var other: [LineView] = [
            .value("While away", "Up to \(CoinFormat.duration(game.timeAwayLimit)) at \(Tuning.offlineEfficiencyPercent(level: game.powerUpLevel(.offlineEfficiency)))% · \(amount(game.baseIdleIncome * game.paidAwaySeconds(game.timeAwayLimit)))"),
        ]
        if game.steps.isConnected {
            other.append(.value("Each step", game.stepsPaidNextDay(today: today)
                ? "\(amount(game.stepValue(today: today))), paid tomorrow" : "\(amount(game.stepValue)), paid as you walk"))
        }
        other.append(.value("Coin airdrop", "Up to \(amount(game.rewardIncome * Tuning.airdropIncomeSeconds))"))
        other.append(.value("Whale airdrop", amount(game.whaleAmount)))
        let questIncome = game.challengeRewardIncome * game.dailyRewardMultiplier
        other.append(.value("Daily quests", "\(amount(questIncome * 600)) to \(amount(questIncome * 1_800))"))

        return IncomeView(
            headline: "\(rateText(idle)) coins per second",
            subline: "\(amount(tapValue)) per tap · \(amount(idle * 3_600)) an hour · \(amount(idle * 86_400)) a day",
            bullRun: boost.map { "Bull Run \(CoinFormat.multiplier($0.multiplier)) for \(CoinFormat.duration($0.endsAt.timeIntervalSince(now)))" },
            sections: [
                ListSectionView(header: "Earned every second",
                                footer: "Milestones (25, 50, 100… owned) and Mk upgrades each double a miner; late in the game Legacy lifts the oldest. Shares include any Bull Run.",
                                lines: earned),
                ListSectionView(header: "Production multipliers",
                                footer: "The miners' own output, times every multiplier, makes production. Automatic taps come on top of it.",
                                lines: multipliers),
                ListSectionView(header: "What a tap earns",
                                footer: "Tapping upgrades add a share of a second's production to every tap. Quick taps in a row build a combo, and the combo power-ups in the Shop raise how big it gets and how fast it builds.",
                                lines: tap),
                ListSectionView(header: "Other ways coins arrive", footer: nil, lines: other),
            ])
    }

    /// What multiplies a miner: its milestones, Mk upgrades and Legacy.
    private func boosts(of miner: MinerID) -> String {
        let game = state
        var parts = ["Milestones \(CoinFormat.multiplier(GameState.milestoneMultiplier(owned: game.owned(miner))))"]
        let mkLevel = game.minerUpgradeLevel(miner)
        if mkLevel > 0 {
            parts.append("Mk \(MinerID.markName(level: mkLevel - 1)) \(CoinFormat.multiplier(pow(Tuning.minerUpgradeMultiplier, Double(mkLevel))))")
        }
        let legacy = game.legacyMultiplier(miner)
        if legacy > 1 { parts.append("Legacy \(CoinFormat.multiplier(legacy))") }
        return parts.joined(separator: " · ")
    }
}
