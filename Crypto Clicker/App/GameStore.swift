import SwiftUI
import CryptoClickerKit

enum AppTab: Hashable {
    case mine, shop, arcade, exchange, trophies
}

/// A short message that slides in at the top of the screen.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
}

/// What the welcome-back screen shows: what the miners earned while the app was closed, what that
/// unlocked, and the best thing to buy with it.
struct WelcomeBack: Identifiable {
    let report: OfflineReport
    /// Achievement tiers the coins earned away reached.
    let achievements: [EarnedTier]
    /// Prestige points the time away made claimable.
    let newPrestigePoints: Int
    /// The affordable purchase that adds income fastest for its price, when there is one.
    let suggestion: PurchaseSuggestion?

    var id: Double { report.id }
}

/// An airdrop on screen, waiting to be caught before it expires.
struct Airdrop: Identifiable, Equatable {
    let id = UUID()
    /// Decided when it appears, so a whale looks different from the start.
    let kind: AirdropKind
    let expiresAt: Date
    /// How long it stays in all, for the countdown ring.
    let lifetime: TimeInterval
}

/// Token prices, day changes, charts and news for the Coin Exchange. Prices only move once per
/// market tick, so this is worked out then rather than on every redraw.
struct MarketBoard: Equatable {
    struct Quote: Equatable {
        /// One token, in whole coins.
        let price: Double
        /// The move over the last day, as a share (0.1 = up 10%).
        let change: Double
        /// Price factors over the last day, oldest first, for the sparkline.
        let history: [Double]
    }

    let tick: Int64
    let quotes: [TokenID: Quote]
    /// The last day's stories, newest first.
    let news: [MarketNews]

    init(at date: Date) {
        tick = Market.tick(at: date)
        var quotes: [TokenID: Quote] = [:]
        for token in TokenID.allCases {
            let history = Market.history(token, endingAt: date, span: 86_400, points: 48)
            let first: Double = history.first ?? 1
            let last: Double = history.last ?? 1
            let change = last / max(first, Double.leastNonzeroMagnitude) - 1
            quotes[token] = Quote(price: Market.price(token, at: date), change: change, history: history)
        }
        self.quotes = quotes
        news = Market.news(before: date, span: 86_400)
    }

    func quote(_ token: TokenID) -> Quote {
        quotes[token] ?? Quote(price: token.price, change: 0, history: [])
    }
}

/// Owns the game and everything around it: the clock, saving, airdrops, the market board,
/// dailies, notifications, Apple Health and the watch. Views read `game` and call the action
/// methods below; every rule lives in CryptoClickerKit.
@Observable @MainActor
final class GameStore {
    private(set) var game: GameState
    var welcomeBack: WelcomeBack?
    var errorMessage: String?
    private(set) var toasts: [Toast] = []
    private(set) var airdrop: Airdrop?
    private(set) var isSyncingSteps = false
    private(set) var watchStatus = WatchBridge.Status.unsupported
    private(set) var market = MarketBoard(at: .now)
    /// Quick taps in a row (0 once the combo has lapsed).
    private(set) var comboStreak = 0
    /// Today's daily reward hasn't been claimed yet.
    private(set) var isDailyRewardReady = false
    /// Daily rewards waiting to be claimed, for the Trophies tab's badge. Kept up to date after every
    /// change, rather than worked out by views on every redraw.
    private(set) var dailyBadgeCount = 0
    /// A mini-game is on screen: airdrops wait and toasts queue until it closes, so nothing
    /// covers the game's controls or gives away a result early.
    var isInGame = false
    /// A balance to show instead of the real one while a slot spin is still being revealed.
    var heldCoins: Double?

    private let saves = SaveStore()
    private let stepTracker = StepTracker()
    private let watch = WatchBridge()
    private let notifier = Notifier()
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// Income is credited only while the app is on screen. In the background the game clock stays
    /// at `game.lastUpdate`, so wake-ups from the watch can't add up to more than the offline cap.
    @ObservationIgnored private var isInForeground = false
    /// A save exists but couldn't be read yet (iOS launched the app before the first unlock).
    /// Until it loads, nothing is saved or sent to the watch, so real progress is never overwritten.
    @ObservationIgnored private var isSaveLocked = false
    @ObservationIgnored private var nextAirdropAt = Date.distantFuture
    @ObservationIgnored private var lastTapAt = Date.distantPast
    @ObservationIgnored private var lastSave = Date.now
    @ObservationIgnored private var lastWatchPush = Date.distantPast
    @ObservationIgnored private var lastStepSync = Date.distantPast
    @ObservationIgnored private var lastDayCheck = Date.distantPast
    @ObservationIgnored private var hasUnsavedChanges = false
    @ObservationIgnored private var hasReportedSaveError = false

    /// Absences shorter than this get a toast instead of the welcome-back sheet.
    private static let welcomeBackThreshold: TimeInterval = 5 * 60

    init() {
        switch saves.load() {
        case .loaded(let saved):
            game = saved
        case .missing:
            game = GameState()
        case .unavailable:
            game = GameState()
            isSaveLocked = true
        }
        watch.onTapBatchesReceived = { [weak self] in self?.applyWatchInbox() }
        watch.onRefreshRequest = { [weak self] in self?.refreshWatch() }
        watch.onStatusChange = { [weak self] status in
            self?.watchStatus = status
            self?.pushToWatch(force: true)
        }
        watch.activate()
        finishLoading()
    }

    var canTrackSteps: Bool { StepTracker.isAvailable }

    /// Today's and yesterday's day keys, for the dailies.
    var today: String { StepDay.key(for: .now) }
    var yesterday: String { StepDay.previousKey(before: .now) }

    /// The combo multiplier on the coin right now (×1 without a combo).
    var comboMultiplier: Double {
        comboStreak > 1 ? game.comboMultiplier(streak: comboStreak) : 1
    }

    // MARK: Lifecycle

    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .active:
            enterForeground()
            let now = Date.now
            if nextAirdropAt <= now || nextAirdropAt == .distantFuture { scheduleAirdrop(from: now) }
            startTicking()
            pushToWatch(force: true)
            notifier.clear()
            Task { await syncSteps() }
        case .inactive:
            enterForeground()
            save()
        case .background:
            stopTicking()
            if isInForeground { catchUp(to: .now) }
            isInForeground = false
            airdrop = nil
            comboStreak = 0
            save()
            pushToWatch(force: true)
            scheduleNotifications()
        @unknown default:
            break
        }
    }

    private func enterForeground() {
        loadIfLocked()
        isInForeground = true
        catchUp(to: .now)
        applyWatchInbox()
        refreshMarket(at: .now)
        refreshDaily(at: .now, force: true)
    }

    /// Loads the save that was unreadable at launch, now that the device is unlocked.
    private func loadIfLocked() {
        guard isSaveLocked else { return }
        switch saves.load() {
        case .loaded(let saved): game = saved
        case .missing: game = GameState()
        case .unavailable:
            // Unlocked and still unreadable: a real error. Keep the file safe and say so.
            if UIApplication.shared.isProtectedDataAvailable && errorMessage == nil {
                errorMessage = "Your saved game couldn't be opened, so progress isn't being saved. Try restarting Crypto Clicker."
            }
            return
        }
        isSaveLocked = false
        finishLoading()
    }

    /// Settles anything a previous run left unfinished, once the real save is loaded.
    private func finishLoading() {
        guard !isSaveLocked else { return }
        if let stake = game.refundBlackjackStake() {
            show(Toast(icon: "🃏", title: "Bet returned",
                       message: "\(CoinFormat.grouped(stake.amount)) \(stake.token.ticker) from an unfinished Blackjack hand"))
            save()
        }
        if let round = game.refundMoonRound() {
            show(Toast(icon: MiniGame.moon.icon, title: "Bet returned",
                       message: "\(CoinFormat.grouped(round.bet)) \(round.token.ticker) from an unfinished flight"))
            save()
        }
        if let hand = game.finishPokerRound() {
            show(Toast(icon: MiniGame.videoPoker.icon, title: "Video Poker hand played out",
                       message: hand.isWin
                        ? "\(hand.hand.name): \(CoinFormat.grouped(hand.tokensWon)) \(hand.token.ticker) back"
                        : "\(hand.hand.name) on the hand you left"))
            save()
        }
        if let paid = game.payUnfinishedRun() {
            show(Toast(icon: paid.run.game.icon, title: "\(paid.run.game.name) paid out",
                       message: "+\(CoinFormat.short(paid.payout.coins)) coins for \(CoinFormat.grouped(paid.run.score)) points"))
            save()
        }
        applyWatchInbox()
        refreshDaily(at: .now, force: true)
    }

    private func startTicking() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                self.tick(at: .now)
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick(at now: Date) {
        guard isInForeground else { return }
        catchUp(to: now)
        if comboStreak > 0 && now.timeIntervalSince(lastTapAt) > Tuning.comboWindow { comboStreak = 0 }
        updateAirdrop(at: now)
        refreshMarket(at: now)
        refreshDaily(at: now)
        recordIncomeIfDue(at: now)
        announceAchievements()
        let sinceSave = now.timeIntervalSince(lastSave)
        if sinceSave >= 30 || (hasUnsavedChanges && sinceSave >= 5) { save() }
        pushToWatch()
        if game.steps.isConnected && now.timeIntervalSince(lastStepSync) >= 300 {
            lastStepSync = now
            Task { await syncSteps(force: true) }
        }
    }

    /// Credits income up to `now`; time away is reported once it is long enough to matter. The
    /// welcome-back screen gathers what the time away unlocked, rather than a pile of toasts.
    private func catchUp(to now: Date) {
        let claimableBefore = game.claimablePrestigePoints
        guard let report = game.advance(to: now), report.earned >= 1 else { return }
        if report.elapsed >= Self.welcomeBackThreshold && shouldWelcomeBack(report, at: now) {
            welcomeBack = WelcomeBack(report: report, achievements: game.refreshAchievements(),
                                      newPrestigePoints: max(0, game.claimablePrestigePoints - claimableBefore),
                                      suggestion: game.bestPurchase)
        } else {
            let message = report.offlineCap == 0
                ? "+\(CoinFormat.short(report.earned)) coins · miners stop a minute after you leave"
                : "+\(CoinFormat.short(report.earned)) coins while you were away"
            show(Toast(icon: "⏱️", title: "Welcome back", message: message))
        }
    }

    /// With Offline Mining every long absence gets the welcome-back screen. Without it the miners
    /// earned only a minute, so the screen (with its Offline Mining tip) shows once a day and a
    /// toast covers the other returns.
    private func shouldWelcomeBack(_ report: OfflineReport, at now: Date) -> Bool {
        guard report.offlineCap == 0 else { return true }
        let today = StepDay.key(for: now)
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Preferences.lastShortWelcomeDayKey) != today else { return false }
        defaults.set(today, forKey: Preferences.lastShortWelcomeDayKey)
        return true
    }

    /// Runs one game action (after crediting income up to now, when on screen) and announces
    /// new achievements. In the background there is no clock to save later, so it saves at once.
    @discardableResult
    private func perform<Result>(_ action: (inout GameState, Date) -> Result) -> Result {
        let now = Date.now
        if isInForeground { catchUp(to: now) }
        let challengeWasComplete = game.daily.challenge?.isComplete ?? true
        let result = action(&game, now)
        hasUnsavedChanges = true
        if !challengeWasComplete, game.daily.challenge?.isComplete == true { announceChallenge() }
        announceAchievements()
        refreshDailyStatus(at: now)
        if !isInForeground { save() }
        return result
    }

    /// Celebrates a completed daily challenge (and the week's bonus when it came with it).
    private func announceChallenge() {
        let week = game.daily.challengesThisWeek
        let bonus = week == Tuning.weeklyChallengeGoal
            ? " · weekly bonus +\(CoinFormat.short(game.weeklyChallengeBonus))" : ""
        show(Toast(icon: "🎯", title: "Daily challenge complete!",
                   message: "+\(CoinFormat.short(game.challengeReward)) coins\(bonus)"))
    }

    /// Updates the daily badge, assigning only real changes so views don't redraw for nothing.
    private func refreshDailyStatus(at now: Date) {
        let ready = game.isDailyRewardReady(today: StepDay.key(for: now))
        let count = game.claimableQuestCount + (ready ? 1 : 0)
        if ready != isDailyRewardReady { isDailyRewardReady = ready }
        if count != dailyBadgeCount { dailyBadgeCount = count }
    }

    // MARK: Actions

    /// Taps the coin. Taps in quick succession build a combo. Returns the coins this tap earned.
    @discardableResult
    func tap() -> Double {
        let now = Date.now
        comboStreak = now.timeIntervalSince(lastTapAt) <= Tuning.comboWindow ? comboStreak + 1 : 1
        lastTapAt = now
        let streak = comboStreak
        return perform { game, now in game.tap(at: now, combo: streak) }
    }

    @discardableResult
    func buy(_ miner: MinerID, quantity: Int) -> Bool {
        perform { game, _ in game.buy(miner, quantity: quantity) }
    }

    @discardableResult
    func buyMinerUpgrade(_ miner: MinerID) -> Bool {
        perform { game, _ in game.buyMinerUpgrade(miner) }
    }

    @discardableResult
    func buy(_ upgrade: UpgradeID) -> Bool {
        perform { game, _ in game.buy(upgrade) }
    }

    /// Buys the next Offline Mining level. Saved at once, since it changes what time away pays.
    /// Buys a suggested purchase (from the welcome-back screen).
    @discardableResult
    func buy(_ purchase: Purchase) -> Bool {
        perform { game, _ in game.buy(purchase) }
    }

    @discardableResult
    func buyOfflineMining() -> Bool {
        let bought = perform { game, _ in game.buyOfflineMining() }
        if bought {
            save()
            pushToWatch(force: true)
        }
        return bought
    }

    @discardableResult
    func unlock(_ miniGame: MiniGame) -> Bool {
        perform { game, _ in game.unlock(miniGame) }
    }

    func setDifficulty(_ difficulty: Difficulty) {
        perform { game, _ in game.setDifficulty(difficulty) }
    }

    // MARK: Prestige

    @discardableResult
    func prestige() -> Int {
        let gained = perform { game, now in game.prestige(at: now) }
        guard gained > 0 else { return 0 }
        airdrop = nil
        comboStreak = 0
        show(Toast(icon: "🌟", title: "Prestige complete",
                   message: "+\(CoinFormat.grouped(gained)) points · production +\(CoinFormat.percent(game.prestigeGain(gained)))"))
        save()
        pushToWatch(force: true)
        return gained
    }

    @discardableResult
    func buyPerk(_ perk: PerkID) -> Bool {
        let bought = perform { game, _ in game.buyPerk(perk) }
        if bought {
            show(Toast(icon: "🎖️", title: perk.name, message: perk.summary))
            save()
        }
        return bought
    }

    // MARK: Market

    @discardableResult
    func buyTokens(_ token: TokenID, quantity: Int) -> Bool {
        perform { game, now in game.buyTokens(token, quantity: quantity, at: now) }
    }

    /// Sells tokens at the market price. Returns the coins received.
    @discardableResult
    func sellTokens(_ token: TokenID, quantity: Int) -> Double? {
        let paid = perform { game, now in game.sellTokens(token, quantity: quantity, at: now) }
        if let paid {
            show(Toast(icon: "📈", title: "Sold \(CoinFormat.grouped(quantity)) \(token.ticker)",
                       message: "+\(CoinFormat.short(paid)) coins"))
        }
        return paid
    }

    private func refreshMarket(at now: Date) {
        guard Market.tick(at: now) != market.tick else { return }
        market = MarketBoard(at: now)
    }

    // MARK: Airdrops

    func claimAirdrop() {
        guard let airdrop else { return }
        self.airdrop = nil
        let reward = perform { game, now in game.claimAirdrop(airdrop.kind, at: now) }
        scheduleAirdrop(from: .now)
        switch reward {
        case .coins(let amount):
            show(Toast(icon: "🪂", title: "Airdrop caught!", message: "+\(CoinFormat.short(amount)) coins"))
        case .bullRun(let multiplier, let duration):
            show(Toast(icon: "🐂", title: "Bull Run!",
                       message: "Production \(CoinFormat.multiplier(multiplier)) for \(CoinFormat.duration(duration))"))
        case .whale(let amount):
            show(Toast(icon: "🐋", title: "Whale airdrop!", message: "+\(CoinFormat.short(amount)) coins: an hour of mining"))
        }
    }

    private func scheduleAirdrop(from now: Date) {
        nextAirdropAt = now.addingTimeInterval(.random(in: game.airdropInterval))
    }

    private func updateAirdrop(at now: Date) {
        if let airdrop {
            guard now >= airdrop.expiresAt else { return }
            self.airdrop = nil
            scheduleAirdrop(from: now)
        } else if now >= nextAirdropAt, game.totalMiners > 0, !isInGame {
            spawnAirdrop(game.airdropKind(roll: .random(in: 0..<1)), at: now)
        }
    }

    private func spawnAirdrop(_ kind: AirdropKind, at now: Date) {
        let lifetime = game.airdropLifetime
        airdrop = Airdrop(kind: kind, expiresAt: now.addingTimeInterval(lifetime), lifetime: lifetime)
    }

    // MARK: Mini-games

    /// Stakes tokens on the current Blackjack round. Saved at once, so a hand cut short by the
    /// app closing is refunded on the next launch.
    @discardableResult
    func placeBet(_ token: TokenID, amount: Int) -> Bool {
        let placed = perform { game, _ in game.placeBlackjackBet(token, amount: amount) }
        if placed { save() }
        return placed
    }

    @discardableResult
    func settleBlackjack(_ results: [BlackjackResult], token: TokenID) -> Double {
        let bonus = perform { game, _ in game.settleBlackjack(results, token: token) }
        save()
        return bonus
    }

    /// Spins Crypto Slots: the bet, the spin and the payout happen in one saved step.
    @discardableResult
    func spinSlots(_ token: TokenID, bet: Int) -> SlotsSpin? {
        let spin = perform { game, _ in
            var rng = SystemRandomNumberGenerator()
            return game.spinSlots(token, bet: bet, using: &rng)
        }
        if spin != nil { save() }
        return spin
    }

    /// Launches a To the Moon flight: the bet is taken and the flight saved at once, so a flight
    /// cut short by the app closing is refunded on the next launch.
    @discardableResult
    func launchMoon(_ token: TokenID, bet: Int, autoCashOut: Double?) -> Bool {
        let launched = perform { game, _ in
            var rng = SystemRandomNumberGenerator()
            return game.launchMoon(token, bet: bet, autoCashOut: autoCashOut, using: &rng)
        }
        if launched { save() }
        return launched
    }

    /// Returns the bet of a flight left without its screen (it can't be watched, so it can't be won).
    func refundMoonRound() {
        guard game.moonRound != nil else { return }
        perform { game, _ in game.refundMoonRound() }
        save()
    }

    /// Ends the flight `seconds` after launch: a cash-out, or a crash.
    @discardableResult
    func settleMoon(after seconds: TimeInterval) -> MoonResult? {
        let result = perform { game, _ in game.settleMoon(after: seconds) }
        if result != nil { save() }
        return result
    }

    /// Deals a Video Poker hand: the bet is taken and the hand saved at once, so a hand cut short
    /// by the app closing is played out (with the suggested holds) on the next launch.
    @discardableResult
    func dealPoker(_ token: TokenID, bet: Int) -> PokerRound? {
        let round = perform { game, _ in
            var rng = SystemRandomNumberGenerator()
            return game.dealPoker(token, bet: bet, using: &rng)
        }
        if round != nil { save() }
        return round
    }

    /// Replaces the cards not held and pays the hand.
    @discardableResult
    func drawPoker(holding held: Set<Int>) -> PokerResult? {
        let result = perform { game, _ in game.drawPoker(holding: held) }
        if result != nil { save() }
        return result
    }

    @discardableResult
    func finishTokenSwap(score: Int, tokens: Int, bestChain: Int, blasts: Int) -> ArcadePayout {
        let payout = perform { game, _ in
            game.finishTokenSwap(score: score, tokens: tokens, bestChain: bestChain, blasts: blasts)
        }
        save()
        return payout
    }

    @discardableResult
    func finishTetris(score: Int, lines: Int, rewardPoints: Int) -> ArcadePayout {
        let payout = perform { game, _ in game.finishTetris(score: score, lines: lines, rewardPoints: rewardPoints) }
        save()
        return payout
    }

    @discardableResult
    func finishSnake(score: Int, length: Int) -> ArcadePayout {
        let payout = perform { game, _ in game.finishSnake(score: score, length: length) }
        save()
        return payout
    }

    @discardableResult
    func finishBrickBreaker(score: Int, bricks: Int, level: Int) -> ArcadePayout {
        let payout = perform { game, _ in game.finishBrickBreaker(score: score, bricks: bricks, level: level) }
        save()
        return payout
    }

    @discardableResult
    func finishBubbleBlaster(score: Int, popped: Int, bestShot: Int) -> ArcadePayout {
        let payout = perform { game, _ in game.finishBubbleBlaster(score: score, popped: popped, bestShot: bestShot) }
        save()
        return payout
    }

    @discardableResult
    func finishPumpDump(score: Int, coinsHit: Int, bestCombo: Int, scamsHit: Int) -> ArcadePayout {
        let payout = perform { game, _ in
            game.finishPumpDump(score: score, coinsHit: coinsHit, bestCombo: bestCombo, scamsHit: scamsHit)
        }
        save()
        return payout
    }

    @discardableResult
    func finishMerge2048(score: Int, bestTile: Int) -> ArcadePayout {
        let payout = perform { game, _ in game.finishMerge2048(score: score, bestTile: bestTile) }
        save()
        return payout
    }

    /// Saves an arcade game in progress as the app goes to the background, so its points are
    /// paid on the next launch if iOS closes the app.
    func holdArcadeRun(_ run: ArcadeRun) {
        perform { game, _ in game.holdArcadeRun(run) }
        save()
    }

    /// The player is back in the held game.
    func releaseArcadeRun() {
        guard game.unfinishedRun != nil else { return }
        perform { game, _ in game.releaseArcadeRun() }
    }

    // MARK: Dailies

    /// Issues the day's quests and challenge once the day changes (or the first game is unlocked),
    /// paying any finished quests left from before. Checked every few seconds, since midnight can
    /// pass while the app is open.
    private func refreshDaily(at now: Date, force: Bool = false) {
        guard !isSaveLocked, force || now.timeIntervalSince(lastDayCheck) >= 5 else { return }
        lastDayCheck = now
        let today = StepDay.key(for: now)
        refreshDailyStatus(at: now) // The badge also changes at midnight and as quests finish.
        guard game.needsDailyRefresh(today: today) else { return }
        let canWalk = canTrackSteps
        let paid = perform { game, now in game.refreshDaily(today: today, canWalk: canWalk, at: now) }
        for payout in paid {
            show(toast(for: payout, title: "Yesterday's quest paid"))
        }
        save()
    }

    func claimQuest(_ quest: Quest) {
        guard let payout = perform({ game, now in game.claimQuest(quest.id, at: now) }) else { return }
        show(toast(for: payout, title: "Quest complete"))
        save()
    }

    func claimDailyReward() {
        let today = today, yesterday = yesterday
        guard let payout = perform({ game, now in game.claimDailyReward(today: today, yesterday: yesterday, at: now) })
        else { return }
        show(toast(for: payout, title: "Day \(game.daily.streak) reward"))
        save()
    }

    private func toast(for payout: RewardPayout, title: String) -> Toast {
        switch payout {
        case .coins(let amount):
            Toast(icon: "🎁", title: title, message: "+\(CoinFormat.short(amount)) coins")
        case .tokens(let token, let count):
            Toast(icon: "🎁", title: title, message: "+\(CoinFormat.grouped(count)) \(token.name)")
        case .bullRun(let multiplier, let duration):
            Toast(icon: "🐂", title: title,
                  message: "Bull Run: production \(CoinFormat.multiplier(multiplier)) for \(CoinFormat.duration(duration))")
        }
    }

    /// Samples idle income for the Statistics chart every half hour while the app is open.
    private func recordIncomeIfDue(at now: Date) {
        let last = game.incomeHistory.last?.date ?? .distantPast
        guard now.timeIntervalSince(last) >= Tuning.incomeSampleInterval || last > now else { return }
        game.recordIncomeSample(at: now)
        hasUnsavedChanges = true
    }

    func resetGame() {
        game = GameState()
        toasts = []
        airdrop = nil
        welcomeBack = nil
        comboStreak = 0
        scheduleAirdrop(from: .now)
        refreshDaily(at: .now, force: true)
        save()
        pushToWatch(force: true)
    }

    // MARK: Toasts

    private func show(_ toast: Toast) {
        toasts.append(toast)
        if toasts.count > 5 { toasts.removeFirst(toasts.count - 5) }
    }

    func dismiss(_ toast: Toast) {
        toasts.removeAll { $0.id == toast.id }
    }

    private func announceAchievements() {
        for earned in game.refreshAchievements() {
            show(Toast(icon: earned.achievement.emoji ?? "🏆",
                       title: "\(earned.achievement.name) · \(earned.tierName)",
                       message: "Achievement unlocked · +\(CoinFormat.percent(game.productionPerAchievementTier)) production"))
        }
    }

    // MARK: Notifications

    /// Asks once for permission to send reminders. Returns whether they are allowed.
    func requestNotificationPermission() async -> Bool {
        await notifier.requestPermission()
    }

    /// Schedules the reminders turned on in Settings, as the app goes to the background.
    private func scheduleNotifications() {
        guard !isSaveLocked else { return }
        let defaults = UserDefaults.standard
        let now = Date.now
        var reminders: [Notifier.Reminder] = []
        let cap = game.offlineCap
        let income = game.baseIdleIncome
        if defaults.bool(forKey: Preferences.notifyMinersKey), cap >= 30 * 60, income > 0 {
            reminders.append(Notifier.Reminder(
                id: .minersStopped, date: game.lastUpdate.addingTimeInterval(cap),
                title: "Your miners have stopped",
                body: "Offline Mining ran for \(CoinFormat.duration(cap)). Open Crypto Clicker to collect about \(CoinFormat.short(income * cap)) coins and start them again."))
        }
        if defaults.bool(forKey: Preferences.notifyDailyKey) {
            let today = StepDay.key(for: now)
            let isWaiting = game.isDailyRewardReady(today: today)
            let date = Notifier.nextReminder(after: now, rewardWaitingToday: isWaiting)
            let streak = game.streakIfClaimed(today: StepDay.key(for: date), yesterday: StepDay.previousKey(before: date))
            let sameDay = StepDay.key(for: date) == today
            reminders.append(Notifier.Reminder(
                id: .dailyReward, date: date,
                title: sameDay ? "Your daily reward is waiting" : "Your daily reward is ready",
                body: streak > 1 ? "Claim it to make your streak \(streak) days." : "Claim it in Trophies › Daily."))
        }
        notifier.replace(with: reminders)
    }

    // MARK: Apple Health

    /// Asks for Health access and starts rewarding steps. Steps unlock after 2,500 taps.
    func connectSteps() async {
        guard game.areStepsUnlocked, !game.steps.isConnected else { return }
        do {
            try await stepTracker.requestAccess()
        } catch {
            errorMessage = "Apple Health couldn't be connected. \(error.localizedDescription)"
            return
        }
        perform { game, now in game.connectSteps(today: StepDay.key(for: now)) }
        await syncSteps(force: true)
    }

    func disconnectSteps() {
        perform { game, _ in game.disconnectSteps() }
        pushToWatch(force: true)
    }

    /// Pays for new steps. Safe to call at any time: the ledger never pays a step twice.
    func syncSteps(force: Bool = false) async {
        let now = Date.now
        guard !isSaveLocked, game.steps.isConnected, !isSyncingSteps,
              force || now.timeIntervalSince(lastStepSync) >= 60 else { return }
        isSyncingSteps = true
        lastStepSync = now
        defer { isSyncingSteps = false }
        // Health data can't be read while the iPhone is locked; the next sync catches up.
        guard let days = try? await stepTracker.dailySteps(days: Tuning.stepWindowDays) else { return }
        let credit = perform { game, now in game.creditSteps(days, today: StepDay.key(for: now), at: now) }
        if credit.steps > 0 {
            show(Toast(icon: "👣", title: "\(CoinFormat.grouped(credit.steps)) new steps",
                       message: "+\(CoinFormat.short(credit.coins)) coins"))
        }
        pushToWatch(force: true)
    }

    // MARK: Apple Watch

    /// Applies watch taps waiting in the inbox, then clears them once the game that includes
    /// them is saved. Batch ids make a repeat (after a crash in between) harmless.
    private func applyWatchInbox() {
        guard !isSaveLocked else { return }
        let batches = watch.inbox.pending()
        guard !batches.isEmpty else { return }
        for batch in batches {
            perform { game, now in game.applyWatchTaps(batch, at: now) }
        }
        if save() { watch.inbox.remove(Set(batches.map(\.id))) }
        pushToWatch(force: true)
    }

    private func refreshWatch() {
        pushToWatch(force: true)
        Task { await syncSteps(force: true) }
    }

    private func pushToWatch(force: Bool = false) {
        guard !isSaveLocked else { return }
        let now = Date.now
        guard force || now.timeIntervalSince(lastWatchPush) >= 15 else { return }
        lastWatchPush = now
        if isInForeground { catchUp(to: now) }
        // The balance is anchored at the game clock, which stays put in the background, so the watch
        // projects exactly what the phone will credit (up to the offline cap) when it next opens.
        watch.send(game.watchSnapshot(at: now))
    }

    // MARK: Saving

    @discardableResult
    private func save() -> Bool {
        guard !isSaveLocked else { return false }
        do {
            try saves.save(game)
            lastSave = .now
            hasUnsavedChanges = false
            return true
        } catch {
            lastSave = .now // Retry on the normal schedule rather than every tick.
            if !hasReportedSaveError {
                hasReportedSaveError = true
                errorMessage = "Your progress couldn't be saved. \(error.localizedDescription)"
            }
            return false
        }
    }
}

#if DEBUG
// MARK: - Testing tools

/// Shortcuts behind the Testing Tools screen. Like that screen, they exist only in builds run
/// from Xcode (the Debug configuration) and are left out of App Store builds.
extension GameStore {
    /// Adds coins that count as mined, so upgrades, achievements and prestige unlock as in play.
    func debugAddCoins(_ amount: Double) {
        debugChange { game, _ in game.debugAddCoins(amount) }
    }

    /// Adds what the miners would earn in `seconds` at the current rate.
    func debugAddIncome(seconds: TimeInterval) {
        debugChange { game, now in game.debugAddCoins((game.idleIncome(at: now) * seconds).rounded()) }
    }

    func debugAddTokens(_ amount: Int) {
        debugChange { game, _ in game.debugAddTokens(amount) }
    }

    func debugAddMiners(_ count: Int) {
        debugChange { game, _ in game.debugAddMiners(count) }
    }

    func debugGiveAllUpgrades() {
        debugChange { game, _ in game.debugGiveAllUpgrades() }
    }

    func debugAddOfflineMining(levels: Int) {
        debugChange { game, _ in game.debugAddOfflineMining(levels: levels) }
    }

    func debugUnlockAllGames() {
        debugChange { game, _ in game.debugUnlockAllGames() }
    }

    func debugUnlockSteps() {
        debugChange { game, _ in game.debugUnlockSteps() }
    }

    func debugStartBullRun() {
        debugChange { game, now in game.debugStartBullRun(at: now) }
    }

    func debugAddPrestigePoints(_ points: Int) {
        debugChange { game, _ in game.debugAddPrestigePoints(points) }
    }

    func debugCompleteQuests() {
        debugChange { game, _ in game.debugCompleteQuests() }
    }

    /// Makes today's reward, quests and a fresh challenge available again (the streak carries on).
    func debugResetDaily() {
        let yesterday = yesterday
        debugChange { game, _ in game.debugResetDaily(yesterday: yesterday) }
        refreshDaily(at: .now, force: true)
    }

    /// Shows an airdrop now instead of in a few minutes.
    func debugDropAirdrop(_ kind: AirdropKind = .coins) {
        spawnAirdrop(kind, at: .now)
    }

    /// Acts as if the app had been closed for `seconds`: the next tick pays the time away
    /// (up to the offline limit) and shows the welcome-back screen.
    func debugPretendAway(_ seconds: TimeInterval) {
        UserDefaults.standard.removeObject(forKey: Preferences.lastShortWelcomeDayKey)
        debugChange { game, _ in game.debugRewind(seconds) }
    }

    private func debugChange(_ change: (inout GameState, Date) -> Void) {
        perform(change)
        save()
        pushToWatch(force: true)
    }
}
#endif
