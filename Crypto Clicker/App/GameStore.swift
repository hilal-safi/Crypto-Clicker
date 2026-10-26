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

/// An airdrop on screen, waiting to be caught before it expires.
struct Airdrop: Identifiable, Equatable {
    let id = UUID()
    let expiresAt: Date
}

/// Owns the game and everything around it: the clock, saving, airdrops, Apple Health and the watch.
/// Views read `game` and call the action methods below; every rule lives in CryptoClickerKit.
@Observable @MainActor
final class GameStore {
    private(set) var game: GameState
    var welcomeBack: OfflineReport?
    var errorMessage: String?
    private(set) var toasts: [Toast] = []
    private(set) var airdrop: Airdrop?
    private(set) var isSyncingSteps = false
    private(set) var watchStatus = WatchBridge.Status.unsupported
    /// A mini-game is on screen: airdrops wait and toasts queue until it closes, so nothing
    /// covers the game's controls or gives away a result early.
    var isInGame = false
    /// A balance to show instead of the real one while a slot spin is still being revealed.
    var heldCoins: Double?

    private let saves = SaveStore()
    private let stepTracker = StepTracker()
    private let watch = WatchBridge()
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// Income is credited only while the app is on screen. In the background the game clock stays
    /// at `game.lastUpdate`, so wake-ups from the watch can't add up to more than the offline cap.
    @ObservationIgnored private var isInForeground = false
    /// A save exists but couldn't be read yet (iOS launched the app before the first unlock).
    /// Until it loads, nothing is saved or sent to the watch, so real progress is never overwritten.
    @ObservationIgnored private var isSaveLocked = false
    @ObservationIgnored private var nextAirdropAt = Date.distantFuture
    @ObservationIgnored private var lastSave = Date.now
    @ObservationIgnored private var lastWatchPush = Date.distantPast
    @ObservationIgnored private var lastStepSync = Date.distantPast
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

    // MARK: Lifecycle

    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .active:
            enterForeground()
            let now = Date.now
            if nextAirdropAt <= now || nextAirdropAt == .distantFuture { scheduleAirdrop(from: now) }
            startTicking()
            pushToWatch(force: true)
            Task { await syncSteps() }
        case .inactive:
            enterForeground()
            save()
        case .background:
            stopTicking()
            if isInForeground { catchUp(to: .now) }
            isInForeground = false
            airdrop = nil
            save()
            pushToWatch(force: true)
        @unknown default:
            break
        }
    }

    private func enterForeground() {
        loadIfLocked()
        isInForeground = true
        catchUp(to: .now)
        applyWatchInbox()
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
        if let paid = game.payUnfinishedRun() {
            show(Toast(icon: paid.run.game.icon, title: "\(paid.run.game.name) paid out",
                       message: "+\(CoinFormat.short(paid.reward)) coins for \(CoinFormat.grouped(paid.run.score)) points"))
            save()
        }
        applyWatchInbox()
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
        updateAirdrop(at: now)
        announceAchievements()
        let sinceSave = now.timeIntervalSince(lastSave)
        if sinceSave >= 30 || (hasUnsavedChanges && sinceSave >= 5) { save() }
        pushToWatch()
        if game.steps.isConnected && now.timeIntervalSince(lastStepSync) >= 300 {
            lastStepSync = now
            Task { await syncSteps(force: true) }
        }
    }

    /// Credits income up to `now`; time away is reported once it is long enough to matter.
    private func catchUp(to now: Date) {
        guard let report = game.advance(to: now), report.earned >= 1 else { return }
        if report.elapsed >= Self.welcomeBackThreshold {
            welcomeBack = report
        } else {
            show(Toast(icon: "⏱️", title: "Welcome back", message: "+\(CoinFormat.short(report.earned)) coins while you were away"))
        }
    }

    /// Runs one game action (after crediting income up to now, when on screen) and announces
    /// new achievements. In the background there is no clock to save later, so it saves at once.
    @discardableResult
    private func perform<Result>(_ action: (inout GameState, Date) -> Result) -> Result {
        let now = Date.now
        if isInForeground { catchUp(to: now) }
        let result = action(&game, now)
        hasUnsavedChanges = true
        announceAchievements()
        if !isInForeground { save() }
        return result
    }

    // MARK: Actions

    func tap() {
        perform { game, now in game.tap(at: now) }
    }

    @discardableResult
    func buy(_ miner: MinerID, quantity: Int) -> Bool {
        perform { game, _ in game.buy(miner, quantity: quantity) }
    }

    @discardableResult
    func buy(_ upgrade: UpgradeID) -> Bool {
        perform { game, _ in game.buy(upgrade) }
    }

    @discardableResult
    func buyTokens(_ token: TokenID, quantity: Int) -> Bool {
        perform { game, _ in game.buyTokens(token, quantity: quantity) }
    }

    /// Buys the next Offline Mining level. Saved at once, since it changes what time away pays.
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

    @discardableResult
    func hardFork() -> Int {
        let gained = perform { game, now in game.hardFork(at: now) }
        guard gained > 0 else { return 0 }
        airdrop = nil
        show(Toast(icon: "🍴", title: "Hard Fork complete",
                   message: "+\(gained) forks · production +\(CoinFormat.percent(game.forkGain(gained)))"))
        save()
        return gained
    }

    func claimAirdrop() {
        guard airdrop != nil else { return }
        airdrop = nil
        let reward = perform { game, now in game.claimAirdrop(roll: .random(in: 0..<1), at: now) }
        scheduleAirdrop(from: .now)
        switch reward {
        case .coins(let amount):
            show(Toast(icon: "🪂", title: "Airdrop caught!", message: "+\(CoinFormat.short(amount)) coins"))
        case .bullRun(let multiplier, let duration):
            show(Toast(icon: "🐂", title: "Bull Run!",
                       message: "Production \(CoinFormat.multiplier(multiplier)) for \(CoinFormat.duration(duration))"))
        }
    }

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

    @discardableResult
    func finishTetris(score: Int, lines: Int) -> Double {
        let reward = perform { game, _ in game.finishTetris(score: score, lines: lines) }
        save()
        return reward
    }

    @discardableResult
    func finishSnake(score: Int) -> Double {
        let reward = perform { game, _ in game.finishSnake(score: score) }
        save()
        return reward
    }

    @discardableResult
    func finishBrickBreaker(score: Int, bricks: Int) -> Double {
        let reward = perform { game, _ in game.finishBrickBreaker(score: score, bricks: bricks) }
        save()
        return reward
    }

    @discardableResult
    func finishBubbleBlaster(score: Int, popped: Int) -> Double {
        let reward = perform { game, _ in game.finishBubbleBlaster(score: score, popped: popped) }
        save()
        return reward
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

    func resetGame() {
        game = GameState()
        toasts = []
        airdrop = nil
        welcomeBack = nil
        scheduleAirdrop(from: .now)
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
                       message: "Achievement unlocked · +1% production"))
        }
    }

    // MARK: Airdrops

    private func scheduleAirdrop(from now: Date) {
        nextAirdropAt = now.addingTimeInterval(.random(in: Tuning.airdropInterval))
    }

    private func updateAirdrop(at now: Date) {
        if let airdrop {
            guard now >= airdrop.expiresAt else { return }
            self.airdrop = nil
            scheduleAirdrop(from: now)
        } else if now >= nextAirdropAt, game.totalMiners > 0, !isInGame {
            airdrop = Airdrop(expiresAt: now.addingTimeInterval(Tuning.airdropLifetime))
        }
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
    /// Adds coins that count as mined, so upgrades, achievements and Hard Forks unlock as in play.
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

    /// Shows an airdrop now instead of in a few minutes.
    func debugDropAirdrop() {
        airdrop = Airdrop(expiresAt: .now.addingTimeInterval(Tuning.airdropLifetime))
    }

    /// Acts as if the app had been closed for `seconds`: the next tick pays the time away
    /// (up to the offline limit) and shows the welcome-back screen.
    func debugPretendAway(_ seconds: TimeInterval) {
        debugChange { game, _ in game.debugRewind(seconds) }
    }

    private func debugChange(_ change: (inout GameState, Date) -> Void) {
        perform(change)
        save()
        pushToWatch(force: true)
    }
}
#endif
