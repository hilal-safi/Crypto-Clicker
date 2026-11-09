import SwiftUI
import CryptoClickerKit

enum AppTab: Hashable {
    case mine, shop, arcade, trophies, settings
}

/// A short message that slides in at the top of the screen.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
}

/// The Shop's purchase popup. Purchases made while it's up add to it instead of stacking more
/// popups, so tapping Buy a few times shows one running total; it goes three seconds after the
/// last purchase.
struct PurchaseNote: Identifiable, Equatable {
    struct Item: Equatable {
        let name: String
        var count: Int
        /// What it changed when that isn't coins: "Biggest combo ×3.5".
        var effect: String?
    }

    /// The same while purchases add to the popup, so it updates in place.
    let id = UUID()
    private(set) var items: [Item] = []
    /// Idle income and a tap's worth before the first of these purchases...
    let incomeBefore: Double
    let tapBefore: Double
    /// ...and after the latest.
    var incomeNow: Double
    var tapNow: Double
    /// The latest purchase; the popup stays up `lifetime` after it.
    var updatedAt: Date

    static let lifetime: TimeInterval = 3

    init(incomeBefore: Double, tapBefore: Double, at date: Date) {
        self.incomeBefore = incomeBefore
        self.tapBefore = tapBefore
        incomeNow = incomeBefore
        tapNow = tapBefore
        updatedAt = date
    }

    mutating func add(_ name: String, count: Int, effect: String?) {
        if let index = items.firstIndex(where: { $0.name == name }) {
            items[index].count += count
            if let effect { items[index].effect = effect }
        } else {
            items.append(Item(name: name, count: count, effect: effect))
        }
    }

    var itemCount: Int { items.reduce(0) { $0 + $1.count } }
    var addedIncome: Double { max(0, incomeNow - incomeBefore) }
    var addedTap: Double { max(0, tapNow - tapBefore) }
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

/// An airdrop on screen, waiting to be caught before it expires (see `AirdropSchedule`).
typealias Airdrop = AirdropDrop

/// Token prices, day changes, charts and news for the Shop's Tokens page. Prices only move once per
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
/// dailies, notifications, Apple Health and the watch. Views read `game` (and the live balance,
/// `coins`) and call the action methods; every rule lives in CryptoClickerKit.
///
/// The store is split by area: this file has the clock, saving and toasts; the player's actions,
/// the mini-games, progress (dailies, achievements) and the services beyond the app (Health, the
/// watch, widgets, reminders) are in the `GameStore+…` files beside it.
@Observable @MainActor
final class GameStore {
    /// The game as screens read it. It changes at once for anything the player does, but only
    /// about once a second as the clock ticks: every screen reads the game, so publishing each
    /// tick (five a second) redrew them all. The balance itself is `coins`, live on every tick.
    var game: GameState {
        _ = revision
        return state
    }
    /// The balance, live: it changes on every tick, so only the screens showing it redraw that often.
    private(set) var coins: Double = 0
    /// Goes up whenever screens should look at the game again.
    private var revision = 0
    /// The game itself, which the clock and every action change. Screens read `game`.
    @ObservationIgnored var state: GameState
    @ObservationIgnored private var lastPublished = Date.distantPast
    var welcomeBack: WelcomeBack?
    var errorMessage: String?
    /// Set when the save couldn't be read: the player is told before a new game starts saving.
    var unreadableSave: UnreadableSave?
    private(set) var toasts: [Toast] = []
    /// The Shop's purchase popup, while it's up.
    private(set) var purchaseNote: PurchaseNote?
    private(set) var watchStatus = WatchBridge.Status.unsupported
    private(set) var market = MarketBoard(at: .now)
    // Set by the store and its extensions in the GameStore+… files; screens only read them.
    /// The airdrop on screen (`airdrops.drop`, published).
    var airdrop: Airdrop?
    var isSyncingSteps = false
    /// Quick taps in a row (0 once the combo has lapsed).
    var comboStreak = 0
    /// Today's daily reward hasn't been claimed yet.
    var isDailyRewardReady = false
    /// Daily rewards waiting to be claimed, for the Trophies tab's badge. Kept up to date after every
    /// change, rather than worked out by views on every redraw.
    var dailyBadgeCount = 0
    /// A mini-game is on screen: airdrops wait and toasts queue until it closes, so nothing
    /// covers the game's controls or gives away a result early.
    var isInGame = false
    /// A balance to show instead of the real one while a slot spin is still being revealed.
    var heldCoins: Double?

    let saves = SaveStore()
    let stepTracker = StepTracker()
    let watch = WatchBridge()
    let notifier = Notifier()
    let balanceSharing = BalanceSharing()
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// Income is credited only while the app is on screen. In the background the game clock stays
    /// at `game.lastUpdate`, so wake-ups from the watch can't add up to more than the offline cap.
    @ObservationIgnored var isInForeground = false
    /// A save exists but couldn't be read yet (iOS launched the app before the first unlock).
    /// Until it loads, nothing is saved or sent to the watch, so real progress is never overwritten.
    @ObservationIgnored var isSaveLocked = false
    /// When airdrops fall and go.
    @ObservationIgnored var airdrops = AirdropSchedule()
    @ObservationIgnored var lastTapAt = Date.distantPast
    @ObservationIgnored private var lastSave = Date.now
    @ObservationIgnored var lastWatchPush = Date.distantPast
    @ObservationIgnored var lastBalanceShare = Date.distantPast
    @ObservationIgnored var lastStepSync = Date.distantPast
    @ObservationIgnored var lastDayCheck = Date.distantPast
    @ObservationIgnored var hasUnsavedChanges = false
    @ObservationIgnored private var hasReportedSaveError = false

    init() {
        switch saves.load() {
        case .loaded(let saved):
            state = saved
        case .missing:
            state = GameState()
        case .unavailable:
            state = GameState()
            isSaveLocked = true
        case .unreadable(let backup):
            // Nothing is saved over it until the player has been told and has chosen what to do.
            state = GameState()
            isSaveLocked = true
            unreadableSave = UnreadableSave(backup: backup)
        }
        coins = state.coins
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
            if airdrops.isDue(at: now) { scheduleAirdrop(from: now) }
            startTicking()
            pushToWatch(force: true)
            shareBalance(force: true)
            notifier.clear()
            Task { await syncSteps() }
        case .inactive:
            enterForeground()
            save()
        case .background:
            stopTicking()
            if isInForeground { catchUp(to: .now) }
            isInForeground = false
            clearAirdrop()
            comboStreak = 0
            save()
            pushToWatch(force: true)
            shareBalance(force: true)
            scheduleNotifications()
        @unknown default:
            break
        }
    }

    func enterForeground() {
        loadIfLocked()
        isInForeground = true
        catchUp(to: .now)
        applyWatchInbox()
        refreshMarket(at: .now)
        refreshDaily(at: .now, force: true)
    }

    /// Loads the save that was unreadable at launch, now that the device is unlocked.
    func loadIfLocked() {
        guard isSaveLocked, unreadableSave == nil else { return }
        switch saves.load() {
        case .loaded(let saved): replaceGame(with: saved)
        case .missing: replaceGame(with: GameState())
        case .unreadable(let backup):
            unreadableSave = UnreadableSave(backup: backup)
            return
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
    func finishLoading() {
        guard !isSaveLocked else { return }
        if let stake = state.refundBlackjackStake() {
            publish()
            show(Toast(icon: "🃏", title: "Bet returned",
                       message: "\(CoinFormat.grouped(stake.amount)) \(stake.token.ticker) from an unfinished \(MiniGame.blackjack.name) hand"))
            save()
        }
        if let round = state.refundMoonRound() {
            publish()
            show(Toast(icon: MiniGame.moon.icon, title: "Bet returned",
                       message: "\(CoinFormat.grouped(round.bet)) \(round.token.ticker) from an unfinished flight"))
            save()
        }
        if let hand = state.finishPokerRound() {
            publish()
            show(Toast(icon: MiniGame.videoPoker.icon, title: "\(MiniGame.videoPoker.name) hand played out",
                       message: hand.isWin
                        ? "\(hand.hand.name): \(CoinFormat.grouped(hand.tokensWon)) \(hand.token.ticker) back"
                        : "\(hand.hand.name) on the hand you left"))
            save()
        }
        // Through `perform`, like a game that ended normally, so the run also earns its Arcade XP
        // and counts toward the week's variety goal.
        if let paid = perform({ game, _ in game.payUnfinishedRun() }) {
            show(Toast(icon: paid.run.game.icon, title: "\(paid.run.game.name) paid out",
                       message: "+\(CoinFormat.short(paid.payout.coins)) coins for \(CoinFormat.grouped(paid.run.score)) points"))
            save()
        }
        applyWatchInbox()
        refreshDaily(at: .now, force: true)
    }

    /// Lets screens know the game changed: the live balance always, and the rest at once for an
    /// action, or at most once a second for the clock's ticks.
    func publish(at now: Date = .now, ticking: Bool = false) {
        if coins != state.coins { coins = state.coins }
        guard !ticking || now.timeIntervalSince(lastPublished) >= 1 else { return }
        lastPublished = now
        revision &+= 1
    }

    /// Puts a whole new game in place (a load, a restore, a reset).
    func replaceGame(with game: GameState) {
        state = game
        publish()
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
        if comboStreak > 0 && now.timeIntervalSince(lastTapAt) > state.comboWindow { comboStreak = 0 }
        updateAirdrop(at: now)
        refreshMarket(at: now)
        refreshDaily(at: now)
        recordIncomeIfDue(at: now)
        announceAchievements()
        let sinceSave = now.timeIntervalSince(lastSave)
        if sinceSave >= 30 || (hasUnsavedChanges && sinceSave >= 5) { save() }
        pushToWatch()
        shareBalance()
        if game.steps.isConnected && now.timeIntervalSince(lastStepSync) >= 300 {
            lastStepSync = now
            Task { await syncSteps(force: true) }
        }
    }

    /// Credits income up to `now`; time away is reported once it is long enough to matter (see
    /// `ReturnGreeting`). The welcome-back screen gathers what the time away unlocked, rather than
    /// a pile of toasts.
    func catchUp(to now: Date) {
        let claimableBefore = state.claimablePrestigePoints
        let report = state.advance(to: now)
        publish(at: now, ticking: true)
        guard let report else { return }
        let defaults = UserDefaults.standard
        let today = StepDay.key(for: now)
        switch ReturnGreeting.choose(for: report, lastWelcomeDay: defaults.string(forKey: Preferences.lastShortWelcomeDayKey), today: today) {
        case .none:
            break
        case .welcomeBack(let marksDay):
            if marksDay { defaults.set(today, forKey: Preferences.lastShortWelcomeDayKey) }
            welcomeBack = WelcomeBack(report: report, achievements: state.refreshAchievements(),
                                      newPrestigePoints: max(0, state.claimablePrestigePoints - claimableBefore),
                                      suggestion: state.bestPurchase)
            publish()
        case .toast:
            let message = report.offlineCap == 0
                ? "+\(CoinFormat.short(report.earned)) coins · miners stop a minute after you leave"
                : "+\(CoinFormat.short(report.earned)) coins while you were away"
            show(Toast(icon: "⏱️", title: "Welcome back", message: message))
        }
    }

    /// Runs one game action (after crediting income up to now, when on screen) and announces
    /// new achievements. In the background there is no clock to save later, so it saves at once.
    @discardableResult
    func perform<Result>(_ action: (inout GameState, Date) -> Result) -> Result {
        let now = Date.now
        if isInForeground { catchUp(to: now) }
        let challengeWasComplete = state.daily.challenge?.isComplete ?? true
        let rankBefore = state.arcadeRank
        let arcade = state.arcadeSnapshot
        let result = action(&state, now)
        // Arcade XP and the weekly variety goal, for whatever games the action finished.
        let award = state.awardArcadeProgress(since: arcade, today: StepDay.key(for: now))
        publish(at: now)
        hasUnsavedChanges = true
        if !challengeWasComplete, game.daily.challenge?.isComplete == true { announceChallenge() }
        announceAchievements()
        announceArcade(award, rankBefore: rankBefore)
        refreshDailyStatus(at: now)
        if !isInForeground { save() }
        return result
    }

    // MARK: Market

    func refreshMarket(at now: Date) {
        guard Market.tick(at: now) != market.tick else { return }
        market = MarketBoard(at: now)
    }

    // MARK: Toasts

    func show(_ toast: Toast) {
        toasts.append(toast)
        if toasts.count > 5 { toasts.removeFirst(toasts.count - 5) }
    }

    func dismiss(_ toast: Toast) {
        toasts.removeAll { $0.id == toast.id }
    }

    /// What a purchase popup measures from: idle income and a tap's worth, without boosts.
    var purchaseBaseline: (income: Double, tap: Double) { (state.baseIdleIncome, state.baseTapValue) }

    /// Adds a purchase to the popup: to the one on screen if the last purchase was under three
    /// seconds ago, else to a new one measured from `before` (`purchaseBaseline` before buying).
    func notePurchase(_ name: String, count: Int = 1, effect: String? = nil, before: (income: Double, tap: Double)) {
        let now = Date.now
        var note = purchaseNote.flatMap { now.timeIntervalSince($0.updatedAt) < PurchaseNote.lifetime ? $0 : nil }
            ?? PurchaseNote(incomeBefore: before.income, tapBefore: before.tap, at: now)
        note.add(name, count: count, effect: effect)
        note.incomeNow = state.baseIdleIncome
        note.tapNow = state.baseTapValue
        note.updatedAt = now
        purchaseNote = note
    }

    /// Takes the purchase popup away: now, or (`ifUnchangedSince`) only if nothing was bought since.
    func dismissPurchaseNote(ifUnchangedSince date: Date? = nil) {
        guard let note = purchaseNote, date.map({ note.updatedAt == $0 }) ?? true else { return }
        purchaseNote = nil
    }

    // MARK: Saving

    @discardableResult
    func save() -> Bool {
        guard !isSaveLocked else { return false }
        do {
            try saves.save(state)
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

    /// Tries the damaged save once more; if it reads now, the game carries on from it.
    func retryUnreadableSave() {
        guard let problem = unreadableSave else { return }
        if let saved = saves.restore(from: problem.backup) {
            replaceGame(with: saved)
            unreadableSave = nil
            isSaveLocked = false
            finishLoading()
        } else {
            unreadableSave = UnreadableSave(backup: problem.backup, attempts: problem.attempts + 1)
        }
    }

    /// Starts a new game after an unreadable save. The old file stays where it was set aside.
    func startOverAfterUnreadableSave() {
        guard unreadableSave != nil else { return }
        unreadableSave = nil
        replaceGame(with: GameState())
        isSaveLocked = false
        finishLoading()
        save()
    }

    func resetGame() {
        replaceGame(with: GameState())
        toasts = []
        clearAirdrop()
        welcomeBack = nil
        comboStreak = 0
        scheduleAirdrop(from: .now)
        refreshDaily(at: .now, force: true)
        save()
        pushToWatch(force: true)
    }
}

/// A save that couldn't be read, kept aside under `backup`.
struct UnreadableSave: Equatable {
    let backup: URL
    /// Times "Try Again" has failed.
    var attempts = 0

    var fileName: String { backup.lastPathComponent }
}
