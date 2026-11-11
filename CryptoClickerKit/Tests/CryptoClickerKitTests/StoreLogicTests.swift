import Foundation
import Testing
@testable import CryptoClickerKit

/// The rules behind the app's store, which used to live in the app where nothing tested them:
/// saving and recovering a damaged save, airdrops, and greeting a returning player.
@Suite("Saves")
struct SaveStoreTests {
    /// A save file in a fresh folder of its own.
    func freshStore() throws -> SaveStore {
        let folder = FileManager.default.temporaryDirectory.appending(path: "save-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return SaveStore(url: folder.appending(path: "game.json", directoryHint: .notDirectory))
    }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    @Test func aFirstLaunchHasNoSaveAndASavedGameComesBack() throws {
        let store = try freshStore()
        #expect(store.load() == .missing)
        var game = GameState.make(miners: minersEarning(20), upgrades: [.coinClicker])
        game.coins = 12_345
        try store.save(game) // Creates the folder too.
        #expect(store.load() == .loaded(game))
        game.coins = 99
        try store.save(game) // Replaces the file whole.
        #expect(store.load() == .loaded(game))
    }

    @Test func aDamagedSaveIsSetAsideNeverDeletedAndCanBeTriedAgain() throws {
        let store = try freshStore()
        try store.save(GameState.make())
        try Data("{ not a game".utf8).write(to: store.url)
        // A quick look from outside the app (Siri) changes nothing.
        #expect(store.load(setsAsideUnreadable: false) == .unreadable(backup: store.url))
        #expect(exists(store.url))
        // The app moves it aside, untouched, under a dated name.
        let result = store.load(now: t0)
        guard case .unreadable(let backup) = result else {
            Issue.record("expected an unreadable save, got \(result)")
            return
        }
        #expect(backup.lastPathComponent == "game.unreadable-\(Int(t0.timeIntervalSince1970)).json")
        #expect(!exists(store.url) && exists(backup))
        #expect(try String(contentsOf: backup, encoding: .utf8) == "{ not a game")
        // Still damaged: trying again keeps it where it is.
        #expect(store.restore(from: backup) == nil)
        #expect(exists(backup))
        // Mended (say a newer version can read it): it goes back into place.
        var mended = GameState.make()
        mended.coins = 777
        try GameCoding.encoder().encode(mended).write(to: backup)
        #expect(store.restore(from: backup) == mended)
        #expect(!exists(backup) && store.load() == .loaded(mended))
    }

    @Test func restoringReplacesANewGameStartedMeanwhile() throws {
        let store = try freshStore()
        let backup = store.url.deletingLastPathComponent().appending(path: "old.json", directoryHint: .notDirectory)
        try store.save(GameState.make()) // A new game, saved after the old one was set aside.
        var old = GameState.make()
        old.coins = 42
        try GameCoding.encoder().encode(old).write(to: backup)
        #expect(store.restore(from: backup) == old)
        #expect(store.load() == .loaded(old))
    }
}

@Suite("Airdrop schedule")
struct AirdropScheduleTests {
    /// Owns miners and has mined enough for airdrops.
    func player() -> GameState {
        var game = GameState.make(miners: minersEarning(10))
        game.stats.lifetimeCoins = Tuning.airdropUnlockCoins
        return game
    }

    @Test func anAirdropWaitsItsTurnFallsAndIsCaught() throws {
        let game = player()
        var schedule = AirdropSchedule()
        #expect(schedule.isDue(at: t0)) // Not scheduled yet.
        schedule.schedule(from: t0, game: game, roll: 0)
        #expect(schedule.nextAt == t0.addingTimeInterval(game.airdropInterval.lowerBound))
        schedule.schedule(from: t0, game: game, roll: 1)
        #expect(schedule.nextAt == t0.addingTimeInterval(game.airdropInterval.upperBound))
        #expect(!schedule.isDue(at: t0))
        // Nothing before its time.
        #expect(schedule.update(at: at(10), game: game, isInGame: false, kindRoll: 0.5, delayRoll: 0.5) == nil)
        let fall = schedule.nextAt
        let event = schedule.update(at: fall, game: game, isInGame: false, kindRoll: 0.5, delayRoll: 0.5)
        let drop = try #require(schedule.drop)
        #expect(event == .appeared(drop))
        #expect(drop.expiresAt == fall.addingTimeInterval(game.airdropLifetime) && drop.lifetime == game.airdropLifetime)
        #expect(drop.kind == game.airdropKind(roll: 0.5))
        // Caught: off the screen, and the next one scheduled from the catch.
        let caught = schedule.catchDrop(at: fall.addingTimeInterval(3), game: game, roll: 0)
        #expect(caught == drop && schedule.drop == nil)
        #expect(schedule.nextAt == fall.addingTimeInterval(3 + game.airdropInterval.lowerBound))
        #expect(schedule.catchDrop(at: fall.addingTimeInterval(4), game: game, roll: 0) == nil)
    }

    @Test func oneThatRunsOutIsMissedUnlessAGameHeldItBack() throws {
        let game = player()
        for inGame in [false, true] {
            var schedule = AirdropSchedule()
            let drop = schedule.spawn(.whale, at: t0, game: game)
            #expect(schedule.update(at: at(1), game: game, isInGame: inGame, kindRoll: 0, delayRoll: 0) == nil)
            let event = schedule.update(at: drop.expiresAt, game: game, isInGame: inGame, kindRoll: 0, delayRoll: 0)
            #expect(event == .expired(drop, missed: !inGame))
            #expect(schedule.drop == nil && schedule.nextAt == drop.expiresAt.addingTimeInterval(game.airdropInterval.lowerBound))
        }
    }

    @Test func noneFallBeforeTheFirstMinerOrDuringAGame() {
        var schedule = AirdropSchedule(nextAt: t0)
        #expect(schedule.update(at: at(1), game: GameState.make(), isInGame: false, kindRoll: 0, delayRoll: 0) == nil)
        // Nor before 50,000 coins have been mined, so a lucky airdrop can't rush the opening.
        var early = player()
        early.stats.lifetimeCoins = Tuning.airdropUnlockCoins - 1
        #expect(!early.areAirdropsUnlocked)
        #expect(schedule.update(at: at(1), game: early, isInGame: false, kindRoll: 0, delayRoll: 0) == nil)
        #expect(player().areAirdropsUnlocked)
        #expect(schedule.update(at: at(1), game: player(), isInGame: true, kindRoll: 0, delayRoll: 0) == nil)
        #expect(schedule.drop == nil)
        // It falls as soon as the game closes.
        if case .appeared = schedule.update(at: at(2), game: player(), isInGame: false, kindRoll: 0, delayRoll: 0) {} else {
            Issue.record("expected an airdrop once the game closed")
        }
        // Going to the background takes it away without a miss.
        schedule.clear()
        #expect(schedule.drop == nil)
    }
}

@Suite("Welcome back")
struct ReturnGreetingTests {
    @Test func longAbsencesGetTheScreenShortOnesAToast() throws {
        var mining = GameState.make(miners: minersEarning(10))
        mining.setOfflineMining(hours: 2)
        let away = mining.advance(to: at(3_600))
        let long = try #require(away)
        #expect(ReturnGreeting.choose(for: long, lastWelcomeDay: "2026-11-03", today: "2026-11-03") == .welcomeBack(marksDay: false))
        var quick = GameState.make(miners: minersEarning(10))
        let back = quick.advance(to: at(120))
        let short = try #require(back)
        #expect(ReturnGreeting.choose(for: short, lastWelcomeDay: nil, today: "2026-11-03") == .toast)
    }

    @Test func withoutOfflineMiningTheScreenShowsOnceADay() throws {
        var game = GameState.make(miners: minersEarning(10))
        let away = game.advance(to: at(3_600))
        let report = try #require(away)
        #expect(report.offlineCap == 0)
        #expect(ReturnGreeting.choose(for: report, lastWelcomeDay: "2026-11-02", today: "2026-11-03") == .welcomeBack(marksDay: true))
        #expect(ReturnGreeting.choose(for: report, lastWelcomeDay: "2026-11-03", today: "2026-11-03") == .toast)
    }

    @Test func nothingEarnedNothingSaid() throws {
        var empty = GameState.make()
        if let report = empty.advance(to: at(3_600)) {
            #expect(ReturnGreeting.choose(for: report, lastWelcomeDay: nil, today: "2026-11-03") == .none)
        }
    }
}
