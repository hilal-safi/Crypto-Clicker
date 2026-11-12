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

/// One request from the app: a command and its arguments.
struct Request: Decodable {
    let cmd: String
    /// The game revision the app already has: the game view is only sent once it has moved on.
    var known: Int?
    /// Leave the game view out, so a fast run of taps stays light (the next tick brings it).
    var noGame: Bool?
    var id: String?
    var quantity: Int?
    var amount: Double?
    var seconds: Double?
    /// For `start`: the folder the save lives in.
    var dir: String?
    /// The device's time zone (sent with `start` and `foreground`), for the game's days.
    var timeZone: String?
}

/// The answer to every request: the live balance, the game view when it changed, the toasts raised
/// since the last request, and what the command returned.
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
}

/// Facts about the native side, for diagnostics and tests.
struct InfoView: Encodable {
    /// The time zone the game keys its days in, and its offset from GMT now.
    let timeZone: String
    let secondsFromGMT: Int
    let saveVersion: Int
    let debugTools: Bool
}

struct BridgeError: Error {
    let message: String
}

/// The app's one door into the game: JSON in, JSON out. Every call is serialised, so the app may
/// call from any thread.
public enum Bridge {
    nonisolated(unsafe) private static let lock = NSLock()
    nonisolated(unsafe) private static var session: GameSession?
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
            try start(directory: request.dir)
        }
        guard let session = Self.session else { throw BridgeError(message: "The game hasn't started yet.") }
        var tap: TapView?
        var bought: Bool?
        var info: InfoView?
        switch request.cmd {
        case "start", "snapshot":
            break
        case "foreground":
            session.enterForeground()
        case "background":
            session.enterBackground()
        case "tick":
            session.tick()
        case "save":
            session.save()
        case "tap":
            let earned = session.tap()
            tap = TapView(earned: "+\(CoinFormat.short(earned))", earnedExact: "+\(CoinFormat.exact(earned))")
        case "buyMiner":
            bought = session.buy(try miner(request.id), quantity: max(1, request.quantity ?? 1))
        case "buyMinerUpgrade":
            bought = session.buyMinerUpgrade(try miner(request.id))
        case "buyUpgrade":
            bought = session.buy(try upgrade(request.id))
        case "buyOfflineMining":
            bought = session.buyOfflineMining()
        case "buyPowerUp":
            bought = session.buyPowerUp(try powerUp(request.id))
        case "buySuggestion":
            bought = session.buySuggestion()
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
        case "resetGame":
            session.resetGame()
        case "info":
            info = InfoView(timeZone: TimeZone.current.identifier,
                            secondsFromGMT: TimeZone.current.secondsFromGMT(for: Date()),
                            saveVersion: GameState.saveVersion, debugTools: hasDebugTools)
        default:
            #if DEBUG
            guard try debugCommand(request, session: session) else {
                throw BridgeError(message: "Unknown command \(request.cmd).")
            }
            #else
            throw BridgeError(message: "Unknown command \(request.cmd).")
            #endif
        }
        let sendsGame = request.noGame != true && request.known != session.revision
        return Response(ok: true, error: nil, revision: session.revision, live: session.liveView,
                        game: sendsGame ? session.gameView(debugTools: hasDebugTools) : nil,
                        toasts: session.drainToasts(), tap: tap, bought: bought, info: info)
    }

    /// Opens the game. Starting again with the same folder (the activity being recreated) keeps
    /// the game that is already running.
    private static func start(directory: String?) throws {
        guard let directory, !directory.isEmpty else { throw BridgeError(message: "start needs the save folder.") }
        if session != nil && sessionDirectory == directory { return }
        session = GameSession(directory: URL(fileURLWithPath: directory, isDirectory: true), clock: { Bridge.clock() })
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

    private static func miner(_ id: String?) throws -> MinerID {
        guard let id, let miner = MinerID(rawValue: id) else { throw BridgeError(message: "Unknown miner \(id ?? "nil").") }
        return miner
    }

    private static func upgrade(_ id: String?) throws -> UpgradeID {
        guard let id, let upgrade = UpgradeID(rawValue: id) else { throw BridgeError(message: "Unknown upgrade \(id ?? "nil").") }
        return upgrade
    }

    private static func powerUp(_ id: String?) throws -> PowerUpID {
        guard let id, let powerUp = PowerUpID(rawValue: id) else { throw BridgeError(message: "Unknown power-up \(id ?? "nil").") }
        return powerUp
    }

    #if DEBUG
    /// The Testing Tools, as on the iOS Testing Tools screen. Returns false for an unknown command.
    private static func debugCommand(_ request: Request, session: GameSession) throws -> Bool {
        switch request.cmd {
        case "debugAddCoins":
            let amount = request.amount ?? 0
            session.debugChange { game, _ in game.debugAddCoins(amount) }
        case "debugAddIncome":
            // What the miners would earn in `seconds` at the current rate.
            let seconds = request.seconds ?? 3_600
            session.debugChange { game, now in game.debugAddCoins((game.idleIncome(at: now) * seconds).rounded()) }
        case "debugAddMiners":
            let count = request.quantity ?? 10
            session.debugChange { game, _ in game.debugAddMiners(count) }
        case "debugGiveAllUpgrades":
            session.debugChange { game, _ in game.debugGiveAllUpgrades() }
        case "debugAddOfflineMining":
            let hours = (request.seconds ?? 3_600) / 3_600
            session.debugChange { game, _ in game.debugAddOfflineMining(hours: hours) }
        case "debugMaxPowerUps":
            session.debugChange { game, _ in game.debugMaxPowerUps() }
        case "debugBullRun":
            session.debugChange { game, now in game.debugStartBullRun(at: now) }
        case "debugEarnAllAchievements":
            session.debugChange { game, _ in game.debugEarnAllAchievements() }
        case "debugRewind":
            // As if the app had been closed for `seconds`: the next catch-up pays the time away.
            session.debugPretendAway(request.seconds ?? 3_600)
        default:
            return false
        }
        return true
    }
    #endif

    private static func failure(_ message: String) -> Response {
        Response(ok: false, error: message, revision: session?.revision, live: nil, game: nil, toasts: [],
                 tap: nil, bought: nil, info: nil)
    }

    private static func encode(_ response: Response) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(response) { return data }
        // A view held a number JSON can't (it shouldn't: views are kept finite).
        return Data(#"{"ok":false,"error":"Couldn't write the response.","toasts":[]}"#.utf8)
    }
}
