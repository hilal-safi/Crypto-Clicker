import Foundation
import CryptoClickerKit
#if canImport(Android)
import Android // setenv
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// One request from the app: a command and its arguments. Arguments are shared by every command
/// and each reads the ones it needs.
struct Request: Decodable {
    let cmd: String
    /// The game revision the app already has: the game view is only sent once it has moved on.
    var known: Int?
    /// Leave the game view out, so a fast run of taps stays light (the next tick brings it).
    var noGame: Bool?
    /// Only the mini-game's frame (and toasts): for the many-a-second calls of a game being played.
    var lite: Bool?
    /// The screens on display, whose views the game view carries (see `GameView`).
    var views: [String]?
    /// The Numbers setting: amounts with every digit (true) or short.
    var exact: Bool?

    var id: String?
    var token: String?
    var kind: String?
    var quantity: Int?
    var amount: Double?
    var seconds: Double?
    var index: Int?
    var indices: [Int]?
    var flag: Bool?
    var x: Double?
    var y: Double?
    var values: [Double]?
    var options: [String: String]?
    /// A file's contents: a save file to import, or the backup folder's copy.
    var text: String?

    /// For `start`: the folder the save lives in, and this phone's id for the app (backups tell
    /// copies made on other devices by it).
    var dir: String?
    var device: String?
    /// The device's time zone (sent with `start` and `foreground`), for the game's days.
    var timeZone: String?
    /// Whether Health Connect is on this phone (sent with `start` and `foreground`).
    var canTrackSteps: Bool?
    /// For `creditSteps`: Health Connect's daily step totals.
    var days: [StepDayInput]?
    /// For `reminders`: the reminders turned on in Settings.
    var notifyMiners: Bool?
    var notifyDaily: Bool?
}

/// One day of steps from Health Connect: the day's start (seconds since 1970) and its total.
struct StepDayInput: Decodable {
    let start: Double
    let steps: Int
}

/// The answer to every request: the live balance, the game view when it changed, the toasts raised
/// since the last request, the mini-game's frame, and what the command returned.
struct Response: Encodable {
    let ok: Bool
    let error: String?
    let revision: Int?
    let live: LiveView?
    let game: GameView?
    let toasts: [Toast]
    let tap: TapView?
    let bought: Bool?
    let info: InfoView?
    let play: PlayView?
    let reminders: [ReminderView]?
    let widget: WidgetView?
    /// A file for the app to write: a save file to export, or the backup folder's copy.
    let data: String?
}

/// Facts about the native side, for diagnostics and tests.
struct InfoView: Encodable {
    /// The time zone the game keys its days in, and its offset from GMT now.
    let timeZone: String
    let secondsFromGMT: Int
    let saveVersion: Int
    let debugTools: Bool
}

/// A reminder for the app to schedule (see `GameSession.reminders`).
struct ReminderView: Encodable {
    /// "miners-stopped" or "daily-reward"
    let id: String
    /// When to send it, in seconds since 1970.
    let at: Double
    let title: String
    let body: String
}

/// What the home screen widget shows, projected from the game clock (see `BalanceSnapshot`).
struct WidgetView: Encodable {
    /// The balance now, as the game will credit it, short and with every digit.
    let balance: String
    let balanceExact: String
    /// "+12.3/s", or "Mining stopped".
    let rate: String
    let isMining: Bool
    /// When the miners stop (seconds since 1970), and the balance then.
    let miningEndsAt: Double
    let balanceWhenMiningEnds: String
    /// The snapshot itself, to keep for later projections (JSON).
    let snapshot: String
}

/// What a command returned, apart from the game it changed.
struct Outcome {
    var tap: TapView?
    var bought: Bool?
    var info: InfoView?
    var reminders: [ReminderView]?
    var widget: WidgetView?
    var data: String?

    static var done: Outcome { Outcome() }
}

struct BridgeError: Error {
    let message: String
}

/// The app's one door into the game: JSON in, JSON out. Every call is serialised, so the app may
/// call from any thread.
public enum Bridge {
    nonisolated(unsafe) private static let lock = NSLock()
    nonisolated(unsafe) static var session: GameSession?
    nonisolated(unsafe) private static var sessionDirectory: String?
    nonisolated(unsafe) private static var timeZoneID: String?
    /// A clock to use instead of the device's (tests).
    nonisolated(unsafe) static var clock: () -> Date = { Date() }

    #if DEBUG
    static let hasDebugTools = true
    #else
    static let hasDebugTools = false
    #endif

    /// Handles one request (UTF-8 JSON) and returns the response (UTF-8 JSON).
    public static func handle(_ request: Data) -> Data {
        lock.lock()
        defer { lock.unlock() }
        let response: Response
        do {
            let decoded = try JSONDecoder().decode(Request.self, from: request)
            response = try respond(to: decoded)
        } catch let error as BridgeError {
            response = failure(error.message)
        } catch {
            response = failure("Couldn't read the request: \(error)")
        }
        return encode(response)
    }

    /// Forgets the session (tests).
    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        session = nil
        sessionDirectory = nil
        timeZoneID = nil
    }

    private static func respond(to request: Request) throws -> Response {
        useTimeZone(request.timeZone)
        if request.cmd == "start" {
            try start(directory: request.dir, device: request.device)
        }
        guard let session = Self.session else { throw BridgeError(message: "The game hasn't started yet.") }
        if let canTrackSteps = request.canTrackSteps, canTrackSteps != session.canTrackSteps {
            session.canTrackSteps = canTrackSteps
            session.publish()
        }
        if let exact = request.exact, exact != session.exactNumbers {
            session.exactNumbers = exact
            session.publish()
        }
        let outcome = try run(request, session)
        if request.lite == true {
            return Response(ok: true, error: nil, revision: session.revision, live: nil, game: nil,
                            toasts: session.drainToasts(), tap: outcome.tap, bought: outcome.bought, info: nil,
                            play: session.play?.view(session: session), reminders: nil, widget: nil, data: nil)
        }
        let sendsGame = request.noGame != true && request.known != session.revision
        let views = Set(request.views ?? [])
        return Response(ok: true, error: nil, revision: session.revision, live: session.liveView,
                        game: sendsGame ? session.gameView(views: views, debugTools: hasDebugTools) : nil,
                        toasts: session.drainToasts(), tap: outcome.tap, bought: outcome.bought, info: outcome.info,
                        play: session.play?.view(session: session), reminders: outcome.reminders,
                        widget: outcome.widget, data: outcome.data)
    }

    /// Runs one command: each area's commands in turn, until one knows it.
    private static func run(_ request: Request, _ session: GameSession) throws -> Outcome {
        if let outcome = try coreCommands(request, session) { return outcome }
        if let outcome = try shopCommands(request, session) { return outcome }
        if let outcome = try progressCommands(request, session) { return outcome }
        if let outcome = try serviceCommands(request, session) { return outcome }
        if let outcome = try backupCommands(request, session) { return outcome }
        if let outcome = try playCommands(request, session) { return outcome }
        #if DEBUG
        if let outcome = try debugCommands(request, session) { return outcome }
        #endif
        throw BridgeError(message: "Unknown command \(request.cmd).")
    }

    /// Opens the game. Starting again with the same folder (the activity being recreated) keeps
    /// the game that is already running.
    private static func start(directory: String?, device: String?) throws {
        guard let directory, !directory.isEmpty else { throw BridgeError(message: "start needs the save folder.") }
        if session != nil && sessionDirectory == directory { return }
        session = GameSession(directory: URL(fileURLWithPath: directory, isDirectory: true), device: device,
                              clock: { Bridge.clock() })
        sessionDirectory = directory
    }

    /// The kit keys each day in the device's time zone (`TimeZone.current`), as on iOS. Android keeps
    /// its zone in a system property rather than the TZ variable, so the app sends it (again when it
    /// comes on screen, in case the player has travelled) and it is set for this process here.
    private static func useTimeZone(_ identifier: String?) {
        guard let identifier, !identifier.isEmpty, identifier != timeZoneID else { return }
        setenv("TZ", identifier, 1)
        NSTimeZone.resetSystemTimeZone() // In case TimeZone.current was already read and kept.
        timeZoneID = identifier
    }

    private static func failure(_ message: String) -> Response {
        Response(ok: false, error: message, revision: session?.revision, live: nil, game: nil, toasts: [],
                 tap: nil, bought: nil, info: nil, play: nil, reminders: nil, widget: nil, data: nil)
    }

    private static func encode(_ response: Response) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(response) { return data }
        // A view held a number JSON can't (it shouldn't: views are kept finite).
        return Data(#"{"ok":false,"error":"Couldn't write the response.","toasts":[]}"#.utf8)
    }

    // MARK: Arguments

    static func identifier<T: RawRepresentable>(_ raw: String?, as type: T.Type, _ what: String) throws -> T where T.RawValue == String {
        guard let raw, let value = T(rawValue: raw) else { throw BridgeError(message: "Unknown \(what) \(raw ?? "nil").") }
        return value
    }

    static func miner(_ id: String?) throws -> MinerID { try identifier(id, as: MinerID.self, "miner") }
    static func upgrade(_ id: String?) throws -> UpgradeID { try identifier(id, as: UpgradeID.self, "upgrade") }
    static func powerUp(_ id: String?) throws -> PowerUpID { try identifier(id, as: PowerUpID.self, "power-up") }
    static func perk(_ id: String?) throws -> PerkID { try identifier(id, as: PerkID.self, "perk") }
    static func token(_ id: String?) throws -> TokenID { try identifier(id, as: TokenID.self, "token") }
    static func miniGame(_ id: String?) throws -> MiniGame { try identifier(id, as: MiniGame.self, "game") }
    static func cosmetic(_ id: String?) throws -> Cosmetic { try identifier(id, as: Cosmetic.self, "look") }
    static func difficulty(_ id: String?) throws -> Difficulty { try identifier(id, as: Difficulty.self, "difficulty") }
}

// MARK: - Commands

extension Bridge {
    /// The app's lifecycle, the clock, the coin, saving and the screens' dismissals.
    static func coreCommands(_ request: Request, _ session: GameSession) throws -> Outcome? {
        switch request.cmd {
        case "start", "snapshot":
            break
        case "foreground":
            session.enterForeground()
            session.play?.foreground(session: session)
        case "background":
            session.play?.background(session: session)
            session.enterBackground()
        case "tick":
            session.tick()
        case "save":
            session.save()
        case "tap":
            let earned = session.tap()
            return Outcome(tap: TapView(earned: "+\(CoinFormat.short(earned))", earnedExact: "+\(CoinFormat.exact(earned))"))
        case "dismissWelcomeBack":
            session.dismissWelcomeBack()
        case "dismissPurchaseNote":
            session.dismissPurchaseNote(id: request.quantity)
        case "dismissError":
            session.dismissError()
        case "retryUnreadableSave":
            session.retryUnreadableSave()
        case "startOver":
            session.startOverAfterUnreadableSave()
        case "checkNewerSave":
            session.checkNewerSaveAgain()
        case "startOverNewerSave":
            session.startOverAfterNewerSave()
        case "resetGame":
            session.resetGame()
        case "setInGame":
            // A mini-game is on screen: airdrops wait until it closes (iOS: store.isInGame).
            session.isInGame = request.flag ?? false
        case "info":
            return Outcome(info: InfoView(timeZone: TimeZone.current.identifier,
                                          secondsFromGMT: TimeZone.current.secondsFromGMT(for: Date()),
                                          saveVersion: GameState.saveVersion, debugTools: hasDebugTools))
        default:
            return nil
        }
        return .done
    }

    /// Buying: the Shop, the welcome-back suggestion, prestige and perks, tokens, games and looks.
    static func shopCommands(_ request: Request, _ session: GameSession) throws -> Outcome? {
        switch request.cmd {
        case "buyMiner":
            return Outcome(bought: session.buy(try miner(request.id), quantity: max(1, request.quantity ?? 1)))
        case "buyMinerUpgrade":
            return Outcome(bought: session.buyMinerUpgrade(try miner(request.id)))
        case "buyUpgrade":
            return Outcome(bought: session.buy(try upgrade(request.id)))
        case "buyOfflineMining":
            return Outcome(bought: session.buyOfflineMining())
        case "buyPowerUp":
            return Outcome(bought: session.buyPowerUp(try powerUp(request.id)))
        case "buySuggestion":
            return Outcome(bought: session.buySuggestion())
        case "prestige":
            return Outcome(bought: session.prestige() > 0)
        case "buyPerk":
            return Outcome(bought: session.buyPerk(try perk(request.id)))
        case "buyTokens":
            return Outcome(bought: session.buyTokens(try token(request.id), quantity: max(1, request.quantity ?? 1)))
        case "sellTokens":
            return Outcome(bought: session.sellTokens(try token(request.id), quantity: max(1, request.quantity ?? 1)) != nil)
        case "unlockGame":
            return Outcome(bought: session.unlock(try miniGame(request.id)))
        case "setDifficulty":
            session.setDifficulty(try difficulty(request.id))
        case "equip":
            session.equip(try cosmetic(request.id))
        case "claimAirdrop":
            session.claimAirdrop()
        default:
            return nil
        }
        return .done
    }

    /// The dailies: quests, the daily reward.
    static func progressCommands(_ request: Request, _ session: GameSession) throws -> Outcome? {
        switch request.cmd {
        case "claimQuest":
            guard let id = request.id else { throw BridgeError(message: "claimQuest needs a quest.") }
            session.claimQuest(id)
        case "claimDailyReward":
            session.claimDailyReward()
        case "claimStarter":
            guard let milestone = request.id.flatMap(StarterMilestone.init(rawValue:)) else {
                throw BridgeError(message: "Unknown starter milestone \(request.id ?? "").")
            }
            session.claimStarterMilestone(milestone)
        default:
            return nil
        }
        return .done
    }

    /// Health Connect, reminders and the widget.
    static func serviceCommands(_ request: Request, _ session: GameSession) throws -> Outcome? {
        switch request.cmd {
        case "connectSteps":
            return Outcome(bought: session.connectSteps())
        case "disconnectSteps":
            session.disconnectSteps()
        case "creditSteps":
            session.creditSteps((request.days ?? []).map { (start: Date(timeIntervalSince1970: $0.start), steps: $0.steps) })
        case "reminders":
            let reminders = session.reminders(notifyMiners: request.notifyMiners ?? false, notifyDaily: request.notifyDaily ?? false)
            return Outcome(reminders: reminders.map {
                ReminderView(id: $0.id.rawValue, at: $0.date.timeIntervalSince1970, title: $0.title, body: $0.body)
            })
        case "widget":
            let finish = request.id.flatMap(CoinFinish.init(rawValue:)) ?? .gold
            return Outcome(widget: widgetView(session.balanceSnapshot(finish: finish), at: session.now))
        default:
            return nil
        }
        return .done
    }

    /// Settings › Backup and Save Files: backing up, restoring, save files and the backup folder,
    /// whose file the app reads and writes (it holds the permission to the folder).
    static func backupCommands(_ request: Request, _ session: GameSession) throws -> Outcome? {
        switch request.cmd {
        case "backup.now":
            session.backUpNow()
        case "backup.export":
            return Outcome(data: session.saveFileData())
        case "backup.readFile":
            session.readSaveFile(request.text ?? "")
        case "backup.restore":
            session.restoreBackup(request.id ?? "")
        case "backup.confirm":
            session.confirmPendingCopy()
        case "backup.dismiss":
            session.dismissPendingCopy()
        case "backup.inspectFolder":
            // `id` is the folder's name (none: no folder is picked), `text` the copy in it.
            session.inspectBackupFolder(name: request.id, copy: request.text)
        case "backup.folderData":
            return Outcome(data: session.backupFolderData(name: request.id ?? "Backup folder", existing: request.text,
                                                          replacing: request.flag ?? false))
        case "backup.folderWritten":
            session.backupFolderWritten(request.flag ?? false, problem: request.text)
        default:
            return nil
        }
        return .done
    }

    /// The widget's numbers at `now`, from a snapshot.
    static func widgetView(_ snapshot: BalanceSnapshot, at now: Date) -> WidgetView {
        let coins = snapshot.coins(at: now)
        let income = snapshot.income(at: now)
        let encoded = (try? JSONEncoder().encode(snapshot)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return WidgetView(balance: CoinFormat.short(coins), balanceExact: CoinFormat.exact(coins),
                          rate: snapshot.isMining(at: now) ? "+\(CoinFormat.rate(income))/s" : "Mining stopped",
                          isMining: snapshot.isMining(at: now),
                          miningEndsAt: snapshot.miningEndsAt.timeIntervalSince1970,
                          balanceWhenMiningEnds: CoinFormat.short(snapshot.coinsWhenMiningEnds),
                          snapshot: encoded)
    }

    #if DEBUG
    /// The Testing Tools, as on the iOS Testing Tools screen.
    static func debugCommands(_ request: Request, _ session: GameSession) throws -> Outcome? {
        switch request.cmd {
        case "debugAddCoins":
            session.debugAddCoins(request.amount ?? 0)
        case "debugAddIncome":
            session.debugAddIncome(seconds: request.seconds ?? 3_600)
        case "debugAddTokens":
            session.debugAddTokens(request.quantity ?? 100)
        case "debugAddMiners":
            session.debugAddMiners(request.quantity ?? 10)
        case "debugGiveAllUpgrades":
            session.debugGiveAllUpgrades()
        case "debugAddOfflineMining":
            session.debugAddOfflineMining(hours: (request.seconds ?? 3_600) / 3_600)
        case "debugMaxPowerUps":
            session.debugMaxPowerUps()
        case "debugUnlockAllGames":
            session.debugUnlockAllGames()
        case "debugReachArcadeRank":
            session.debugReachArcadeRank(request.quantity ?? 1)
        case "debugBullRun":
            session.debugStartBullRun()
        case "debugEarnAllAchievements":
            session.debugEarnAllAchievements()
        case "debugUnlockSteps":
            session.debugUnlockSteps()
        case "debugAddPrestigePoints":
            session.debugAddPrestigePoints(request.quantity ?? 1)
        case "debugCountPrestiges":
            session.debugCountPrestiges(request.quantity ?? 5)
        case "debugCompleteQuests":
            session.debugCompleteQuests()
        case "debugResetDaily":
            session.debugResetDaily()
        case "debugDropAirdrop":
            session.debugDropAirdrop(request.kind.flatMap(AirdropKind.init(rawValue:)) ?? .coins)
        case "debugRewind":
            // As if the app had been closed for `seconds`: the next catch-up pays the time away.
            session.debugPretendAway(request.seconds ?? 3_600)
        default:
            return nil
        }
        return .done
    }
    #endif
}
