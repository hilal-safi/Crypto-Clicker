import Foundation
import CryptoClickerKit

// What the arcade games share: the start card, the game running on the app's clock, holding the
// run while the app is in the background, and the game-over card with what it paid (iOS:
// GamePanel, GameIntro, GameOverSummary and arcadeLifecycle).

/// Where an arcade game is, for its screen.
struct ArcadeStateView: Encodable {
    /// ready (the start card), playing, or over (the game-over card)
    let phase: String
    /// Games started on this screen, so the app restarts its clock for each.
    let run: Int
    let best: Int
    let over: GameOverView?
}

/// What a finished arcade game earned (iOS: GameOverSummary).
struct GameOverView: Encodable {
    /// "Game Over", "Time's Up"
    let title: String
    let score: String
    let isNewBest: Bool
    /// "New best! +50% coins", or "Best 12,345".
    let bestLine: String
    let reward: String
    let details: [String]
    /// "Daily challenge complete!" and what it paid.
    let challenge: String?
    let xp: XPView?
}

func gameOverView(title: String, score: Int, payout: ArcadePayout, best: Int, details: [String], xp: ArcadeAward?) -> GameOverView {
    GameOverView(
        title: title, score: CoinFormat.grouped(score), isNewBest: payout.isNewBest,
        bestLine: payout.isNewBest ? "New best! +\(CoinFormat.percent(Tuning.newBestBonus)) coins" : "Best \(CoinFormat.grouped(best))",
        reward: CoinFormat.short(payout.coins), details: details,
        challenge: payout.challenge.map(challengeLine), xp: xpView(xp))
}

/// What a completed daily challenge paid (iOS: ChallengeCompleteBadge).
func challengeLine(_ reward: ChallengeReward) -> String {
    reward.weeklyBonus > 0
        ? "+\(CoinFormat.short(reward.coins)) coins, and +\(CoinFormat.short(reward.weeklyBonus)) for the week's \(Tuning.weeklyChallengeGoal)th"
        : "+\(CoinFormat.short(reward.coins)) coins"
}

/// Flattens grid points for the frame: x, y, x, y…
func flat(_ points: some Sequence<GridPoint>) -> [Int] {
    points.flatMap { [$0.x, $0.y] }
}

/// Every arcade game's start-screen lines: its modes' records and what's particular today.
struct StartsView: Encodable {
    let snake: SnakeStartView
}

extension GameSession {
    var startsView: StartsView {
        let stats = state.stats
        return StartsView(
            snake: SnakeStartView(
                classic: stats.snakeGames == 0 ? "Pick an arena and play"
                    : "Best \(CoinFormat.grouped(stats.snakeBestScore)) · longest \(CoinFormat.grouped(stats.snakeLongest))",
                rush: stats.snakeRushes == 0 ? "One minute, three coins out"
                    : "Best \(CoinFormat.grouped(stats.snakeRushBestScore)) · \(CoinFormat.grouped(stats.snakeRushes)) played",
                arenas: SnakeGame.Arena.allCases.map { SnakeArenaView(id: $0.rawValue, name: $0.name, walls: flat($0.walls)) },
                speeds: GameSpeed.allCases.map { ChoiceView(id: $0.rawValue, name: $0.name) }))
    }
}

// MARK: - Hash Chain (Snake)

struct SnakeStartView: Encodable {
    let classic: String
    let rush: String
    let arenas: [SnakeArenaView]
    let speeds: [ChoiceView]
}

struct SnakeArenaView: Encodable {
    let id: String
    let name: String
    /// The arena's walls, x, y, x, y…
    let walls: [Int]
}

struct SnakeFrameView: Encodable {
    let state: ArcadeStateView
    /// The screen's title ("Hash Chain", an arena's name, or "Coin Rush"), and the start card's
    /// ("Coin Rush", or the arena's name: "Open").
    let title: String
    let readyTitle: String
    /// "Classic · Normal speed"
    let intro: String
    let isRush: Bool
    let width: Int
    let height: Int
    /// Head first, x, y, x, y…
    let body: [Int]
    let walls: [Int]
    let coins: [Int]
    let item: SnakeItemView?
    let magnetReach: Int
    let magnet: Bool
    let speedBoost: Bool
    let hasShield: Bool
    let grace: Int
    let score: Int
    let blocks: Int
    /// Seconds left in a Coin Rush.
    let timeLeft: Int
    let effects: [SnakeEffectView]
    /// Seconds until the next move.
    let tickInterval: Double
    let eaten: Int
    /// Power-ups picked up, and the last one, for the banner.
    let pickups: Int
    let pickedUp: String?
    let pickedUpName: String?
}

struct SnakeItemView: Encodable {
    let kind: String
    let x: Int
    let y: Int
    /// The share of its time left on the board.
    let share: Double
}

struct SnakeEffectView: Encodable {
    let kind: String
    let name: String
    /// The share of its time left, or nil for one without a timer (the shield, "Ready").
    let share: Double?
    let secondsLeft: Int?
}

final class SnakePlay: PlaySession {
    let game = MiniGame.snake
    private let mode: SnakeGame.Mode
    private var arena: SnakeGame.Arena
    private var speed: GameSpeed
    private var engine: SnakeGame
    private var isPlaying = false
    private var runs = 0
    private var over: GameOverView?
    private var pickups = 0
    private var pickedUp: SnakeGame.PowerUp?
    private var rng = SystemRandomNumberGenerator()

    init(_ request: Request, session: GameSession) {
        mode = request.options?["mode"] == "coinRush" ? .coinRush : .classic
        arena = request.options?["arena"].flatMap(SnakeGame.Arena.init(rawValue:)) ?? .open
        speed = request.options?["speed"].flatMap(GameSpeed.init(rawValue:)) ?? .normal
        engine = SnakeGame(mode: mode, arena: arena, speed: speed, using: &rng)
    }

    func handle(_ action: String, _ request: Request, session: GameSession) throws -> Bool {
        switch action {
        case "start":
            if let options = request.options {
                arena = options["arena"].flatMap(SnakeGame.Arena.init(rawValue:)) ?? arena
                speed = options["speed"].flatMap(GameSpeed.init(rawValue:)) ?? speed
            }
            engine = SnakeGame(mode: mode, arena: arena, speed: speed, using: &rng)
            over = nil
            pickedUp = nil
            isPlaying = true
            runs += 1
        case "turn":
            guard isPlaying, let direction = request.kind.flatMap(Self.direction) else { return true }
            engine.turn(direction)
        case "step":
            guard isPlaying else { return true }
            let collected = engine.powerUpsCollected
            let item = engine.item?.kind
            engine.step(using: &rng)
            if engine.powerUpsCollected > collected, let item {
                pickups += 1
                pickedUp = item
            }
            if engine.isOver { endGame(session) }
        case "end":
            endGame(session)
        default:
            return false
        }
        return true
    }

    private static func direction(_ name: String) -> SnakeDirection? {
        switch name {
        case "up": .up
        case "down": .down
        case "left": .left
        case "right": .right
        default: nil
        }
    }

    private func endGame(_ session: GameSession) {
        guard isPlaying else { return }
        isPlaying = false
        let payout = session.finishSnake(score: engine.score, length: engine.body.count, coins: engine.eaten, time: engine.time,
                                         powerUps: engine.powerUpsCollected, mode: engine.mode)
        let collected = engine.powerUpsCollected
        over = gameOverView(
            title: engine.mode == .coinRush && engine.timeLeft == 0 ? "Time's Up" : "Game Over",
            score: engine.score, payout: payout, best: bestScore(session), details: [
                "\(engine.eaten) coins · \(engine.body.count) blocks · \(CoinFormat.stopwatch(engine.time))",
                "\(collected) power-up\(collected == 1 ? "" : "s")" + (engine.mode == .classic ? " · \(engine.arena.name)" : " · Coin Rush"),
            ], xp: session.lastArcadeAward)
    }

    private func bestScore(_ session: GameSession) -> Int {
        mode == .coinRush ? session.game.stats.snakeRushBestScore : session.game.stats.snakeBestScore
    }

    /// The game so far, held while the app is in the background.
    private var heldRun: ArcadeRun {
        ArcadeRun(game: .snake, score: engine.score, detail: engine.body.count,
                  stage: engine.mode == .coinRush ? ArcadeRun.coinRushStage : 0,
                  records: .init(coins: engine.eaten, seconds: engine.time, powerUps: engine.powerUpsCollected))
    }

    func background(session: GameSession) {
        if isPlaying { session.holdArcadeRun(heldRun) }
    }

    func foreground(session: GameSession) {
        if isPlaying { session.releaseArcadeRun() }
    }

    func close(session: GameSession) { endGame(session) }

    func view(session: GameSession) -> PlayView {
        PlayView(.snake, snake: SnakeFrameView(
            state: ArcadeStateView(phase: isPlaying ? "playing" : over == nil ? "ready" : "over", run: runs,
                                   best: bestScore(session), over: over),
            title: mode == .coinRush ? "Coin Rush" : arena == .open ? MiniGame.snake.name : arena.name,
            readyTitle: mode == .coinRush ? "Coin Rush" : arena.name,
            intro: (mode == .coinRush ? "One minute, three coins out at once" : "Classic") + " · \(speed.name) speed",
            isRush: mode == .coinRush, width: SnakeGame.width, height: SnakeGame.height,
            body: flat(engine.body), walls: flat(engine.walls.sorted { ($0.y, $0.x) < ($1.y, $1.x) }), coins: flat(engine.coins),
            item: engine.item.map { SnakeItemView(kind: $0.kind.rawValue, x: $0.position.x, y: $0.position.y,
                                                  share: clamped($0.timeLeft / SnakeGame.powerUpLifetime)) },
            magnetReach: SnakeGame.magnetReach, magnet: engine.isActive(.magnet), speedBoost: engine.isActive(.speedBoost),
            hasShield: engine.hasShield, grace: engine.graceTicks, score: engine.score, blocks: engine.body.count,
            timeLeft: Int(engine.timeLeft.rounded(.up)),
            effects: SnakeGame.PowerUp.allCases.filter(engine.isActive).map { kind -> SnakeEffectView in
                let left = engine.effects[kind]
                return SnakeEffectView(kind: kind.rawValue, name: kind.name,
                                       share: left.flatMap { left in kind.duration.map { clamped(left / $0) } },
                                       secondsLeft: left.map { Int($0.rounded(.up)) })
            },
            tickInterval: engine.tickInterval, eaten: engine.eaten, pickups: pickups,
            pickedUp: pickedUp?.rawValue, pickedUpName: pickedUp?.name))
    }
}
