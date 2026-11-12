import Foundation
import CryptoClickerKit

/// A short message at the top of the screen: an achievement, a quest paid, a bet returned.
struct Toast: Equatable, Sendable, Encodable {
    let id: Int
    let icon: String
    let title: String
    let message: String
}

/// The Shop's purchase popup. Purchases made while it's up add to it, so tapping Buy a few times
/// shows one running total; it goes nine seconds after the last purchase.
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
    /// Idle income and a tap's worth before the first of these purchases...
    let incomeBefore: Double
    let tapBefore: Double
    /// ...and after the latest.
    var incomeNow: Double
    var tapNow: Double
    /// The latest purchase; the popup stays up `lifetime` after it.
    var updatedAt: Date
    /// Goes up with every purchase added, so the app restarts the popup's timer.
    var stamp = 0

    static let lifetime: TimeInterval = 9

    init(id: Int, incomeBefore: Double, tapBefore: Double, at date: Date) {
        self.id = id
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
/// away, saving, the dailies, achievements and their announcements, the combo, the purchase popup
/// and the welcome-back report. Each method mirrors the `GameStore` method of the same name, so the
/// two apps play the same game. Not thread-safe: `Bridge` serialises every call.
final class GameSession {
    private(set) var state: GameState
    let saves: SaveStore
    private let prefsURL: URL
    /// The clock, injected so tests can move time.
    private let clock: () -> Date
    /// Whether steps can be counted here. Health Connect isn't wired up on Android yet, so step
    /// quests and Step Boosters are left out, as on an iPhone without Apple Health.
    let canTrackSteps = false

    /// Goes up whenever screens should look at the game again: at once for anything the player
    /// does, and at most once a second as the clock ticks.
    private(set) var revision = 0
    private var lastPublished = Date.distantPast

    /// Income is credited only while the app is on screen. In the background the game clock stays at
    /// `state.lastUpdate`, so the time away is paid once, up to the Offline Mining limit.
    private(set) var isInForeground = false
    /// A save exists but couldn't be read yet. Until it loads, nothing is saved.
    private(set) var isSaveLocked = false
    private(set) var unreadableSave: UnreadableSave?
    var errorMessage: String?
    private(set) var welcomeBack: WelcomeBack?
    private(set) var purchaseNote: PurchaseNote?
    /// Quick taps in a row (0 once the combo has lapsed).
    private(set) var comboStreak = 0
    private var lastTapAt = Date.distantPast
    private var pendingToasts: [Toast] = []
    private var nextID = 1
    private var lastSave: Date
    private var lastDayCheck = Date.distantPast
    private var hasUnsavedChanges = false
    private var hasReportedSaveError = false
    private var prefs: SessionPrefs

    /// Opens the game saved in `directory` (`game.json`, the same file and format as on iOS).
    init(directory: URL, clock: @escaping () -> Date = { Date() }) {
        self.clock = clock
        saves = SaveStore(url: directory.appendingPathComponent("game.json", isDirectory: false))
        prefsURL = directory.appendingPathComponent("session.json", isDirectory: false)
        prefs = SessionPrefs.load(from: prefsURL)
        let now = clock()
        lastSave = now
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

    /// The combo multiplier on the coin right now (×1 without a combo).
    var comboMultiplier: Double {
        comboStreak > 1 ? state.comboMultiplier(streak: comboStreak) : 1
    }

    /// Takes the toasts raised since the last call, oldest first.
    func drainToasts() -> [Toast] {
        defer { pendingToasts.removeAll() }
        return pendingToasts
    }

    private func makeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    // MARK: Lifecycle

    /// The app came on screen (iOS: the scene became active).
    func enterForeground() {
        loadIfLocked()
        isInForeground = true
        catchUp(to: now)
        refreshDaily(at: now, force: true)
    }

    /// The app left the screen (iOS: the scene went to the background).
    func enterBackground() {
        if isInForeground { catchUp(to: now) }
        isInForeground = false
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
    private func publish(at now: Date? = nil, ticking: Bool = false) {
        let now = now ?? self.now
        guard !ticking || now.timeIntervalSince(lastPublished) >= 1 else { return }
        lastPublished = now
        revision &+= 1
    }

    /// Puts a whole new game in place (a load, a restore, a reset).
    private func replaceGame(with game: GameState) {
        state = game
        publish()
    }

    /// One beat of the clock, five times a second while the app is on screen.
    func tick() {
        let now = self.now
        guard isInForeground else { return }
        catchUp(to: now)
        if comboStreak > 0 && now.timeIntervalSince(lastTapAt) > state.comboWindow { comboStreak = 0 }
        refreshDaily(at: now)
        recordIncomeIfDue(at: now)
        announceAchievements()
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
        publish(at: now)
        hasUnsavedChanges = true
        if !challengeWasComplete, state.daily.challenge?.isComplete == true { announceChallenge() }
        announceAchievements()
        announceArcade(award, rankBefore: rankBefore)
        if !isInForeground { save() }
        return result
    }

    // MARK: Actions

    /// Taps the coin. Taps in quick succession build a combo. Returns the coins this tap earned.
    @discardableResult
    func tap() -> Double {
        let now = self.now
        comboStreak = now.timeIntervalSince(lastTapAt) <= state.comboWindow ? comboStreak + 1 : 1
        lastTapAt = now
        let streak = comboStreak
        return perform { game, now in game.tap(at: now, combo: streak) }
    }

    @discardableResult
    func buy(_ miner: MinerID, quantity: Int) -> Bool {
        let before = purchaseBaseline
        let bought = perform { game, _ in game.buy(miner, quantity: quantity) }
        if bought { notePurchase(miner.name, count: quantity, before: before) }
        return bought
    }

    @discardableResult
    func buyMinerUpgrade(_ miner: MinerID) -> Bool {
        let before = purchaseBaseline
        let name = state.name(of: .minerUpgrade(miner))
        let bought = perform { game, _ in game.buyMinerUpgrade(miner) }
        if bought { notePurchase(name, before: before) }
        return bought
    }

    @discardableResult
    func buy(_ upgrade: UpgradeID) -> Bool {
        let before = purchaseBaseline
        let bought = perform { game, _ in game.buy(upgrade) }
        if bought { notePurchase(upgrade.name, effect: upgrade.addsCoins ? nil : upgrade.summary, before: before) }
        return bought
    }

    /// Buys the welcome-back screen's suggestion.
    @discardableResult
    func buySuggestion() -> Bool {
        guard let welcome = welcomeBack, let suggestion = welcome.suggestion, !welcome.boughtSuggestion else { return false }
        let before = purchaseBaseline
        let name = state.name(of: suggestion.purchase)
        let bought = perform { game, _ in game.buy(suggestion.purchase) }
        if bought {
            notePurchase(name, before: before)
            welcomeBack?.boughtSuggestion = true
        }
        return bought
    }

    /// Buys the next Offline Mining level. Saved at once, since it changes what time away pays.
    @discardableResult
    func buyOfflineMining() -> Bool {
        let before = purchaseBaseline
        let bought = perform { game, _ in game.buyOfflineMining() }
        if bought {
            notePurchase("Offline Mining",
                         effect: "Miners earn for up to \(CoinFormat.duration(state.offlineCap)) away",
                         before: before)
            save()
        }
        return bought
    }

    /// Buys a power-up's next level. Saved at once, like Offline Mining.
    @discardableResult
    func buyPowerUp(_ powerUp: PowerUpID) -> Bool {
        let before = purchaseBaseline
        let bought = perform { game, _ in game.buyPowerUp(powerUp) }
        if bought {
            notePurchase(powerUp.name, effect: powerUp.effect(atLevel: state.powerUpLevel(powerUp)), before: before)
            save()
        }
        return bought
    }

    func dismissWelcomeBack() {
        guard welcomeBack != nil else { return }
        welcomeBack = nil
        publish()
    }

    /// Takes the purchase popup away: now, or (`id`) only if it is still that popup.
    func dismissPurchaseNote(id: Int? = nil) {
        guard let note = purchaseNote, id.map({ note.id == $0 }) ?? true else { return }
        purchaseNote = nil
        publish()
    }

    // MARK: Purchase popup

    /// What a purchase popup measures from: idle income and a tap's worth, without boosts.
    private var purchaseBaseline: (income: Double, tap: Double) { (state.baseIdleIncome, state.baseTapValue) }

    /// Adds a purchase to the popup: to the one on screen if the last purchase was under nine
    /// seconds ago, else to a new one measured from `before` (`purchaseBaseline` before buying).
    private func notePurchase(_ name: String, count: Int = 1, effect: String? = nil,
                              before: (income: Double, tap: Double)) {
        let now = self.now
        var note = purchaseNote.flatMap { now.timeIntervalSince($0.updatedAt) < PurchaseNote.lifetime ? $0 : nil }
            ?? PurchaseNote(id: makeID(), incomeBefore: before.income, tapBefore: before.tap, at: now)
        note.add(name, count: count, effect: effect)
        note.incomeNow = state.baseIdleIncome
        note.tapNow = state.baseTapValue
        note.updatedAt = now
        note.stamp += 1
        purchaseNote = note
        publish()
    }

    // MARK: Dailies

    /// Issues the day's quests and challenge once the day changes, paying any finished quests left
    /// from before. Checked every few seconds, since midnight can pass while the app is open.
    func refreshDaily(at now: Date, force: Bool = false) {
        guard !isSaveLocked, force || now.timeIntervalSince(lastDayCheck) >= 5 else { return }
        lastDayCheck = now
        let today = StepDay.key(for: now)
        guard state.needsDailyRefresh(today: today) else { return }
        let canWalk = canTrackSteps
        let paid = perform { game, now in game.refreshDaily(today: today, canWalk: canWalk, at: now) }
        for payout in paid {
            show(toast(for: payout, title: "Yesterday's quest paid"))
        }
        save()
    }

    private func toast(for payout: RewardPayout, title: String) -> Toast {
        switch payout {
        case .coins(let amount):
            makeToast("🎁", title, "+\(CoinFormat.short(amount)) coins")
        case .tokens(let token, let count):
            makeToast("🎁", title, "+\(CoinFormat.grouped(count)) \(token.name)")
        case .bullRun(let multiplier, let duration):
            makeToast("🐂", title,
                      "Bull Run: production \(CoinFormat.multiplier(multiplier)) for \(CoinFormat.duration(duration))")
        }
    }

    /// Samples idle income for the Statistics chart every minute while the app is open.
    private func recordIncomeIfDue(at now: Date) {
        let last = state.incomeHistory.last?.date ?? .distantPast
        guard now.timeIntervalSince(last) >= Tuning.incomeSampleInterval || last > now else { return }
        state.recordIncomeSample(at: now)
        publish(at: now, ticking: true)
        hasUnsavedChanges = true
    }

    // MARK: Announcements

    /// Celebrates a completed daily challenge (and the week's bonus when it came with it).
    private func announceChallenge() {
        let week = state.daily.challengesThisWeek
        let bonus = week == Tuning.weeklyChallengeGoal
            ? " · weekly bonus +\(CoinFormat.short(state.weeklyChallengeBonus))" : ""
        show("🎯", "Daily challenge complete!", "+\(CoinFormat.short(state.challengeReward)) coins\(bonus)")
    }

    /// Celebrates the weekly variety goal and a new Arcade Rank, with what the rank unlocked.
    private func announceArcade(_ award: ArcadeAward?, rankBefore: Int) {
        if let reward = award?.weeklyReward, reward > 0 {
            show("🎲", "Weekly variety goal!",
                 "\(Tuning.weeklyVarietyGames) different games this week · +\(CoinFormat.short(reward)) coins")
        }
        let rank = state.arcadeRank
        guard rank > rankBefore else { return }
        let unlocked = state.cosmeticsUnlocked(sinceRank: rankBefore)
        show("🕹️", "Arcade Rank \(rank) · \(state.arcadeTitle)",
             unlocked.isEmpty ? "Keep playing to rank up" : "New look: " + unlocked.map(\.name).joined(separator: ", "))
    }

    private func announceAchievements() {
        let earned = state.refreshAchievements()
        guard !earned.isEmpty else { return }
        publish()
        for earned in earned {
            let xp = AchievementCatalog.arcadeIDs.contains(earned.achievement.id)
                ? " · +\(Tuning.arcadeXPPerAchievementTier) Arcade XP" : ""
            show(earned.achievement.emoji ?? "🏆", "\(earned.achievement.name) · \(earned.tierName)",
                 "Achievement unlocked · +\(CoinFormat.percent(state.productionPerAchievementTier)) production\(xp)")
        }
    }

    // MARK: Toasts

    private func makeToast(_ icon: String, _ title: String, _ message: String) -> Toast {
        Toast(id: makeID(), icon: icon, title: title, message: message)
    }

    private func show(_ icon: String, _ title: String, _ message: String) {
        show(makeToast(icon, title, message))
    }

    /// Queues a toast. The app shows them one at a time and keeps the latest five.
    private func show(_ toast: Toast) {
        pendingToasts.append(toast)
        if pendingToasts.count > 5 { pendingToasts.removeFirst(pendingToasts.count - 5) }
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
        guard !isSaveLocked else { return }
        replaceGame(with: GameState(now: now))
        pendingToasts = []
        welcomeBack = nil
        purchaseNote = nil
        comboStreak = 0
        refreshDaily(at: now, force: true)
        save()
    }

    #if DEBUG
    // MARK: Testing tools (debug builds only, like the iOS Testing Tools screen)

    /// Applies a testing shortcut through `perform`, then saves, as the iOS Testing Tools do.
    func debugChange(_ change: (inout GameState, Date) -> Void) {
        perform(change)
        save()
    }

    /// Acts as if the app had been closed for `seconds`: the next tick pays the time away (up to
    /// the Offline Mining limit) and shows the welcome-back screen, even if it showed today.
    func debugPretendAway(_ seconds: TimeInterval) {
        prefs.lastShortWelcomeDay = nil
        prefs.save(to: prefsURL)
        debugChange { game, _ in game.debugRewind(seconds) }
    }
    #endif
}

/// The few things the session remembers outside the save, as the iOS app keeps them in
/// `UserDefaults`.
struct SessionPrefs: Codable, Equatable {
    /// The day the once-a-day welcome-back screen (without Offline Mining) last showed.
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
