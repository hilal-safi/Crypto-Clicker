import Foundation
import CryptoClickerKit

/// A short message at the top of the screen: an achievement, a quest paid, a bet returned.
struct Toast: Equatable, Sendable, Encodable {
    let id: Int
    let icon: String
    let title: String
    let message: String
    /// The numbers the player watches (per second, per tap, per step) as they are now, when the
    /// toast changed them.
    let gains: [ToastGainView]
}

/// One number a toast changed: "PER SECOND  +217  now 21.7K", or just the new total when the
/// change was too small to show.
struct ToastGainView: Equatable, Sendable, Encodable {
    let title: String
    /// What it added, or nil when the new total is all there is to show.
    let added: String?
    let total: String
}

/// The Shop's purchase popup. Purchases made while it's up add to it instead of stacking more
/// popups, so tapping Buy a few times shows one running total; it goes nine seconds after the
/// last purchase.
struct PurchaseNote: Equatable, Sendable {
    struct Item: Equatable, Sendable {
        let name: String
        var count: Int
        /// What it changed when that isn't coins: "Biggest combo ×3.5".
        var effect: String?
    }

    /// The same while purchases add to the popup, so it updates in place.
    let id: Int
    private(set) var items: [Item] = []
    /// Idle income, a tap's worth and a step's worth before the first of these purchases...
    let incomeBefore: Double
    let tapBefore: Double
    let stepBefore: Double
    /// ...and after the latest.
    var incomeNow: Double
    var tapNow: Double
    var stepNow: Double
    /// Whether steps are connected, so a step's worth is worth showing.
    let showsSteps: Bool
    /// The latest purchase; the popup stays up `lifetime` after it.
    var updatedAt: Date
    /// Goes up with every purchase added, so the app restarts the popup's timer.
    var stamp = 0

    static let lifetime: TimeInterval = 9

    init(id: Int, incomeBefore: Double, tapBefore: Double, stepBefore: Double, showsSteps: Bool, at date: Date) {
        self.id = id
        self.incomeBefore = incomeBefore
        self.tapBefore = tapBefore
        self.stepBefore = stepBefore
        self.showsSteps = showsSteps
        incomeNow = incomeBefore
        tapNow = tapBefore
        stepNow = stepBefore
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
    var addedStep: Double { showsSteps ? max(0, stepNow - stepBefore) : 0 }
}

/// What the welcome-back screen shows: what the miners earned while the app was closed, what that
/// unlocked, and the best thing to buy with it.
struct WelcomeBack: Sendable {
    let id: Int
    let report: OfflineReport
    /// Achievement tiers the coins earned away reached.
    let achievements: [EarnedTier]
    /// Prestige points the time away made claimable.
    let newPrestigePoints: Int
    /// The affordable purchase that adds income fastest for its price, when there is one.
    let suggestion: PurchaseSuggestion?
    /// The suggestion was bought from the screen.
    var boughtSuggestion = false
    /// Steps walked while away and the coins they paid: added when the step sync finishes while
    /// this screen is up, so it shows them instead of a separate popup.
    var steps = 0
    var stepCoins = 0.0
}

/// An airdrop on screen, waiting to be caught before it expires (see `AirdropSchedule`).
typealias Airdrop = AirdropDrop

/// Token prices, day changes, charts and news for the Shop's Tokens page. Prices only move once per
/// market tick, so this is worked out then rather than on every view.
struct MarketBoard: Equatable, Sendable {
    struct Quote: Equatable, Sendable {
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

/// A save that couldn't be read, kept aside under `backup`.
struct UnreadableSave: Equatable, Sendable {
    let backup: URL
    /// Times "Try Again" has failed.
    var attempts = 0

    var fileName: String { backup.lastPathComponent }
}

/// Plays the game for the Android app. Every rule lives in CryptoClickerKit; this is everything the
/// iOS app's `GameStore` does around the rules, without the UI: the clock and catching up after time
/// away, saving, airdrops, the market board, the dailies, achievements and their announcements, the
/// combo, the purchase popup and the welcome-back report. It is split by area like `GameStore`
/// (`GameSession+Actions`, `+Progress`, `+Games`, `+Services`, `+Debug`), and each method mirrors the
/// `GameStore` method of the same name, so the two apps play the same game. Not thread-safe: `Bridge`
/// serialises every call.
final class GameSession {
    /// The game itself, which the clock and every action change.
    var state: GameState
    /// The game as views read it (on iOS, the published copy of `state`).
    var game: GameState { state }
    let saves: SaveStore
    let prefsURL: URL
    /// The clock, injected so tests can move time.
    private let clock: () -> Date
    /// Whether steps can be counted here (Health Connect is on this phone). Step quests and Step
    /// Boosters are only offered where they can be, as on an iPhone without Apple Health.
    var canTrackSteps = false
    /// Coin amounts with every digit rather than short (the app's Numbers setting, sent with every
    /// request): the views write amounts in this form, as the iOS screens read the preference.
    var exactNumbers = false

    /// Goes up whenever screens should look at the game again: at once for anything the player
    /// does, and at most once a second as the clock ticks.
    private(set) var revision = 0
    private var lastPublished = Date.distantPast

    /// Income is credited only while the app is on screen. In the background the game clock stays at
    /// `state.lastUpdate`, so the time away is paid once, up to the Offline Mining limit.
    var isInForeground = false
    /// A save exists but couldn't be read yet. Until it loads, nothing is saved.
    var isSaveLocked = false
    var unreadableSave: UnreadableSave?
    var errorMessage: String?
    var welcomeBack: WelcomeBack?
    var purchaseNote: PurchaseNote?
    /// The airdrop on screen (`airdrops.drop`, published).
    var airdrop: Airdrop?
    /// When airdrops fall and go.
    var airdrops = AirdropSchedule()
    var market: MarketBoard
    /// Quick taps in a row (0 once the combo has lapsed).
    var comboStreak = 0
    var lastTapAt = Date.distantPast
    /// Today's daily reward hasn't been claimed yet.
    var isDailyRewardReady = false
    /// Daily rewards waiting to be claimed, for the Trophies tab's badge.
    var dailyBadgeCount = 0
    /// A mini-game is on screen: airdrops wait (and the app holds toasts) until it closes.
    var isInGame = false
    /// What the last action earned toward Arcade Rank (`nil` when it finished no game), for the
    /// result screen that action leads to. Read right after a game's finish call.
    private(set) var lastArcadeAward: ArcadeAward?
    /// The mini-game being played, when one is open (see `PlaySession`).
    var play: PlaySession?

    var pendingToasts: [Toast] = []
    private var nextID = 1
    var lastSave: Date
    var lastDayCheck = Date.distantPast
    var hasUnsavedChanges = false
    var hasReportedSaveError = false
    var prefs: SessionPrefs

    /// Opens the game saved in `directory` (`game.json`, the same file and format as on iOS).
    init(directory: URL, clock: @escaping () -> Date = { Date() }) {
        self.clock = clock
        saves = SaveStore(url: directory.appendingPathComponent("game.json", isDirectory: false))
        prefsURL = directory.appendingPathComponent("session.json", isDirectory: false)
        prefs = SessionPrefs.load(from: prefsURL)
        let now = clock()
        lastSave = now
        market = MarketBoard(at: now)
        switch saves.load(now: now) {
        case .loaded(let saved):
            state = saved
        case .missing:
            state = GameState(now: now)
        case .unavailable:
            state = GameState(now: now)
            isSaveLocked = true
        case .unreadable(let backup):
            // Nothing is saved over it until the player has been told and has chosen what to do.
            state = GameState(now: now)
            isSaveLocked = true
            unreadableSave = UnreadableSave(backup: backup)
        }
        finishLoading()
    }

    var now: Date { clock() }

    /// Today's and yesterday's day keys, for the dailies.
    var today: String { StepDay.key(for: now) }
    var yesterday: String { StepDay.previousKey(before: now) }

    /// The combo multiplier on the coin right now (×1 without a combo).
    var comboMultiplier: Double {
        comboStreak > 1 ? state.comboMultiplier(streak: comboStreak) : 1
    }

    /// Takes the toasts raised since the last call, oldest first.
    func drainToasts() -> [Toast] {
        defer { pendingToasts.removeAll() }
        return pendingToasts
    }

    func makeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    // MARK: Lifecycle

    /// The app came on screen (iOS: the scene became active).
    func enterForeground() {
        loadIfLocked()
        isInForeground = true
        catchUp(to: now)
        refreshMarket(at: now)
        refreshDaily(at: now, force: true)
        if airdrops.isDue(at: now) { scheduleAirdrop(from: now) }
    }

    /// The app left the screen (iOS: the scene went to the background).
    func enterBackground() {
        if isInForeground { catchUp(to: now) }
        isInForeground = false
        clearAirdrop()
        comboStreak = 0
        save()
    }

    /// Loads the save that couldn't be read at launch, if it reads now.
    func loadIfLocked() {
        guard isSaveLocked, unreadableSave == nil else { return }
        switch saves.load(now: now) {
        case .loaded(let saved): replaceGame(with: saved)
        case .missing: replaceGame(with: GameState(now: now))
        case .unreadable(let backup):
            unreadableSave = UnreadableSave(backup: backup)
            publish()
            return
        case .unavailable:
            if errorMessage == nil {
                errorMessage = "Your saved game couldn't be opened, so progress isn't being saved. Try restarting Crypto Clicker."
                publish()
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
            show("🃏", "Bet returned",
                 "\(CoinFormat.grouped(stake.amount)) \(stake.token.ticker) from an unfinished \(MiniGame.blackjack.name) hand")
            save()
        }
        if let round = state.refundMoonRound() {
            publish()
            show(MiniGame.moon.info.icon, "Bet returned",
                 "\(CoinFormat.grouped(round.bet)) \(round.token.ticker) from an unfinished flight")
            save()
        }
        if let hand = state.finishPokerRound() {
            publish()
            show(MiniGame.videoPoker.info.icon, "\(MiniGame.videoPoker.name) hand played out",
                 hand.isWin
                    ? "\(hand.hand.name): \(CoinFormat.grouped(hand.tokensWon)) \(hand.token.ticker) back"
                    : "\(hand.hand.name) on the hand you left")
            save()
        }
        // Through `perform`, like a game that ended normally, so the run also earns its Arcade XP
        // and counts toward the week's variety goal.
        if let paid = perform({ game, _ in game.payUnfinishedRun() }) {
            show(paid.run.game.info.icon, "\(paid.run.game.name) paid out",
                 "+\(CoinFormat.short(paid.payout.coins)) coins for \(CoinFormat.grouped(paid.run.score)) points")
            save()
        }
        refreshDaily(at: now, force: true)
    }

    /// Lets screens know the game changed: at once for an action, or at most once a second for the
    /// clock's ticks.
    func publish(at now: Date? = nil, ticking: Bool = false) {
        let now = now ?? self.now
        guard !ticking || now.timeIntervalSince(lastPublished) >= 1 else { return }
        lastPublished = now
        revision &+= 1
    }

    /// Puts a whole new game in place (a load, a restore, a reset).
    func replaceGame(with game: GameState) {
        state = game
        publish()
    }

    /// One beat of the clock, five times a second while the app is on screen.
    func tick() {
        let now = self.now
        guard isInForeground else { return }
        catchUp(to: now)
        if comboStreak > 0 && now.timeIntervalSince(lastTapAt) > state.comboWindow { comboStreak = 0 }
        updateAirdrop(at: now)
        refreshMarket(at: now)
        refreshDaily(at: now)
        recordIncomeIfDue(at: now)
        announceAchievements()
        // The popup's nine seconds (the app also counts them down, and dismisses early on a tap).
        if let note = purchaseNote, now.timeIntervalSince(note.updatedAt) >= PurchaseNote.lifetime {
            purchaseNote = nil
            publish()
        }
        let sinceSave = now.timeIntervalSince(lastSave)
        if sinceSave >= 30 || (hasUnsavedChanges && sinceSave >= 5) { save() }
    }

    /// Credits income up to `now`; time away is reported once it is long enough to matter (see
    /// `ReturnGreeting`). The welcome-back screen gathers what the time away unlocked, rather than
    /// a pile of toasts.
    func catchUp(to now: Date) {
        let claimableBefore = state.claimablePrestigePoints
        let report = state.advance(to: now)
        publish(at: now, ticking: true)
        guard let report else { return }
        let today = StepDay.key(for: now)
        switch ReturnGreeting.choose(for: report, lastWelcomeDay: prefs.lastShortWelcomeDay, today: today) {
        case .none:
            break
        case .welcomeBack(let marksDay):
            if marksDay {
                prefs.lastShortWelcomeDay = today
                prefs.save(to: prefsURL)
            }
            welcomeBack = WelcomeBack(id: makeID(), report: report, achievements: state.refreshAchievements(),
                                      newPrestigePoints: max(0, state.claimablePrestigePoints - claimableBefore),
                                      suggestion: state.bestPurchase)
            publish()
        case .toast:
            let message = report.offlineCap == 0
                ? "+\(CoinFormat.short(report.earned)) coins · miners stop a minute after you leave"
                : "+\(CoinFormat.short(report.earned)) coins while you were away"
            show("⏱️", "Welcome back", message)
        }
    }

    /// Runs one game action (after crediting income up to now, when on screen) and announces what it
    /// earned. In the background there is no clock to save later, so it saves at once.
    @discardableResult
    func perform<Result>(_ action: (inout GameState, Date) -> Result) -> Result {
        let now = self.now
        if isInForeground { catchUp(to: now) }
        let challengeWasComplete = state.daily.challenge?.isComplete ?? true
        let rankBefore = state.arcadeRank
        let arcade = state.arcadeSnapshot
        let result = action(&state, now)
        // Arcade XP and the weekly variety goal, for whatever games the action finished.
        let award = state.awardArcadeProgress(since: arcade, today: StepDay.key(for: now))
        lastArcadeAward = award
        publish(at: now)
        hasUnsavedChanges = true
        if !challengeWasComplete, state.daily.challenge?.isComplete == true { announceChallenge() }
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
        publish(at: now)
    }

    // MARK: Toasts

    func makeToast(_ icon: String, _ title: String, _ message: String, gains: [ToastGainView] = []) -> Toast {
        Toast(id: makeID(), icon: icon, title: title, message: message, gains: gains)
    }

    func show(_ icon: String, _ title: String, _ message: String) {
        show(makeToast(icon, title, message))
    }

    /// Queues a toast. The app shows them one at a time and keeps the latest five.
    func show(_ toast: Toast) {
        pendingToasts.append(toast)
        if pendingToasts.count > 5 { pendingToasts.removeFirst(pendingToasts.count - 5) }
    }

    // MARK: Purchase popup

    /// What a purchase popup measures from: idle income and a tap's worth, without boosts, and what
    /// a step walked from now on pays.
    var purchaseBaseline: (income: Double, tap: Double, step: Double) {
        (state.baseIdleIncome, state.baseTapValue, state.stepValue)
    }

    /// Adds a purchase to the popup: to the one on screen if the last purchase was under nine
    /// seconds ago, else to a new one measured from `before` (`purchaseBaseline` before buying).
    func notePurchase(_ name: String, count: Int = 1, effect: String? = nil,
                      before: (income: Double, tap: Double, step: Double)) {
        let now = self.now
        var note = purchaseNote.flatMap { now.timeIntervalSince($0.updatedAt) < PurchaseNote.lifetime ? $0 : nil }
            ?? PurchaseNote(id: makeID(), incomeBefore: before.income, tapBefore: before.tap, stepBefore: before.step,
                            showsSteps: state.steps.isConnected, at: now)
        note.add(name, count: count, effect: effect)
        note.incomeNow = state.baseIdleIncome
        note.tapNow = state.baseTapValue
        note.stepNow = state.stepValue
        note.updatedAt = now
        note.stamp += 1
        purchaseNote = note
        publish()
    }

    /// Takes the purchase popup away: now, or (`id`) only if it is still that popup.
    func dismissPurchaseNote(id: Int? = nil) {
        guard let note = purchaseNote, id.map({ note.id == $0 }) ?? true else { return }
        purchaseNote = nil
        publish()
    }

    func dismissWelcomeBack() {
        guard welcomeBack != nil else { return }
        welcomeBack = nil
        publish()
    }

    // MARK: Saving

    @discardableResult
    func save() -> Bool {
        guard !isSaveLocked else { return false }
        do {
            try saves.save(state)
            lastSave = now
            hasUnsavedChanges = false
            return true
        } catch {
            lastSave = now // Retry on the normal schedule rather than every tick.
            if !hasReportedSaveError {
                hasReportedSaveError = true
                errorMessage = "Your progress couldn't be saved. \(error.localizedDescription)"
                publish()
            }
            return false
        }
    }

    func dismissError() {
        guard errorMessage != nil else { return }
        errorMessage = nil
        publish()
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
            publish()
        }
    }

    /// Starts a new game after an unreadable save. The old file stays where it was set aside.
    func startOverAfterUnreadableSave() {
        guard unreadableSave != nil else { return }
        unreadableSave = nil
        replaceGame(with: GameState(now: now))
        isSaveLocked = false
        finishLoading()
        save()
    }

    /// Starts again from nothing (Settings).
    func resetGame() {
        replaceGame(with: GameState(now: now))
        pendingToasts = []
        clearAirdrop()
        welcomeBack = nil
        purchaseNote = nil
        play = nil
        comboStreak = 0
        scheduleAirdrop(from: now)
        refreshDaily(at: now, force: true)
        save()
    }
}

/// Small settings the iOS app keeps in UserDefaults, kept beside the save here.
struct SessionPrefs: Codable, Equatable {
    /// The day the short welcome-back screen last showed (see `ReturnGreeting`).
    var lastShortWelcomeDay: String?

    static func load(from url: URL) -> SessionPrefs {
        guard let data = try? Data(contentsOf: url),
              let prefs = try? JSONDecoder().decode(SessionPrefs.self, from: data) else { return SessionPrefs() }
        return prefs
    }

    func save(to url: URL) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
