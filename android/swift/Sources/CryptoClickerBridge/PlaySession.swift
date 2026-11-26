import Foundation
import CryptoClickerKit

/// A mini-game being played. The kit's game engines are values that the iOS game screens keep in
/// their state and drive with timers and gestures; on Android they are kept here, and the app
/// drives them with `play.…` commands and draws the frame `view` returns.
protocol PlaySession: AnyObject {
    var game: MiniGame { get }
    /// Handles one `play.<action>` command. Returns false for an action it doesn't know.
    func handle(_ action: String, _ request: Request, session: GameSession) throws -> Bool
    /// What the game screen draws now.
    func view(session: GameSession) -> PlayView
    /// The app went to the background with the game open: hold the run, or refund the bet, as the
    /// iOS game screens do.
    func background(session: GameSession)
    /// The app came back with the game open: let go of a held run.
    func foreground(session: GameSession)
    /// The game screen closed.
    func close(session: GameSession)
}

extension PlaySession {
    func background(session: GameSession) {}
    func foreground(session: GameSession) {}
    func close(session: GameSession) {}
}

/// The open mini-game's frame: the part for that game.
struct PlayView: Encodable {
    /// The game's id (`MiniGame.rawValue`).
    let game: String
    let blackjack: BlackjackFrameView?
    let poker: PokerFrameView?
    let slots: SlotsFrameView?
    let moon: MoonFrameView?
    let snake: SnakeFrameView?
}

extension PlayView {
    init(_ game: MiniGame, blackjack: BlackjackFrameView? = nil, poker: PokerFrameView? = nil,
         slots: SlotsFrameView? = nil, moon: MoonFrameView? = nil, snake: SnakeFrameView? = nil) {
        self.init(game: game.rawValue, blackjack: blackjack, poker: poker, slots: slots, moon: moon, snake: snake)
    }
}

extension Bridge {
    /// `play.open` starts a game screen, `play.close` ends it, and every other `play.…` command goes
    /// to the open game.
    static func playCommands(_ request: Request, _ session: GameSession) throws -> Outcome? {
        guard request.cmd.hasPrefix("play.") else { return nil }
        let action = String(request.cmd.dropFirst("play.".count))
        switch action {
        case "open":
            let game = try miniGame(request.id)
            session.play?.close(session: session)
            session.play = try makePlaySession(game, request, session: session)
        case "close":
            session.play?.close(session: session)
            session.play = nil
        default:
            guard let play = session.play else { throw BridgeError(message: "No game is open.") }
            guard try play.handle(action, request, session: session) else {
                throw BridgeError(message: "\(play.game.name) has no action \(action).")
            }
        }
        return .done
    }

    /// The session for a game screen.
    static func makePlaySession(_ game: MiniGame, _ request: Request, session: GameSession) throws -> PlaySession {
        switch game {
        case .blackjack: return BlackjackPlay(request, session: session)
        case .videoPoker: return PokerPlay(session: session)
        case .slots: return SlotsPlay(request, session: session)
        case .moon: return MoonPlay(request, session: session)
        case .snake: return SnakePlay(request, session: session)
        default: throw BridgeError(message: "\(game.name) isn't on Android yet.")
        }
    }
}
