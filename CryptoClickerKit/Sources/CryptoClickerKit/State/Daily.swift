import Foundation

/// What a daily quest asks for. Progress counts up from the moment the quest is issued.
public enum QuestKind: String, Codable, CaseIterable, Sendable {
    case tapCoin, buyMiners, earnCoins, catchAirdrops, walkSteps
    case winBlackjack, spinSlots, clearLines, eatSnakeCoins, breakBricks, popBubbles, sellTokens, score2048
    case cashOutMoon, hitPumpCoins, winPoker, matchTokens
    case winTokenSwapLevels, clearPumpRounds, reach2048Goals

    /// The instruction, with the target filled in: "Tap the coin 500 times".
    public func title(target: Double) -> String {
        let amount = CoinFormat.short(target)
        return switch self {
        case .tapCoin: "Tap the coin \(amount) times"
        case .buyMiners: "Buy \(amount) miners"
        case .earnCoins: "Earn \(amount) coins"
        case .catchAirdrops: "Catch \(amount) airdrops"
        case .walkSteps: "Walk \(amount) steps"
        case .winBlackjack: "Win \(amount) Blackjack hands"
        case .spinSlots: "Spin Crypto Slots \(amount) times"
        case .clearLines: "Clear \(amount) Tetris lines"
        case .eatSnakeCoins: "Eat \(amount) coins in Snake"
        case .breakBricks: "Break \(amount) bricks"
        case .popBubbles: "Pop \(amount) bubbles"
        case .sellTokens: "Sell \(amount) tokens on the market"
        case .score2048: "Score \(amount) points in 2048"
        case .cashOutMoon: "Cash out \(amount) times in To the Moon"
        case .hitPumpCoins: "Hit \(amount) coins in Pump and Dump"
        case .winPoker: "Win \(amount) Video Poker hands"
        case .matchTokens: "Match \(amount) tokens in Token Swap"
        case .winTokenSwapLevels: target == 1 ? "Win a Token Swap level" : "Win \(amount) Token Swap levels"
        case .clearPumpRounds: "Clear \(amount) rounds in Pump and Dump"
        case .reach2048Goals: "Reach \(amount) tile goals in 2048"
        }
    }

    /// SF Symbol shown with the quest.
    public var symbol: String {
        switch self {
        case .tapCoin: "hand.tap.fill"
        case .buyMiners: "cpu"
        case .earnCoins: "bitcoinsign.circle.fill"
        case .catchAirdrops: "shippingbox.fill"
        case .walkSteps: "figure.walk"
        case .winBlackjack: "suit.spade.fill"
        case .spinSlots: "dollarsign.arrow.circlepath"
        case .clearLines: "square.stack.3d.down.forward.fill"
        case .eatSnakeCoins: "arrow.turn.up.right"
        case .breakBricks: "square.grid.3x2.fill"
        case .popBubbles: "circle.hexagongrid.fill"
        case .sellTokens: "chart.line.uptrend.xyaxis"
        case .score2048: "square.grid.3x3.fill"
        case .cashOutMoon: "airplane.departure"
        case .hitPumpCoins: "hammer.fill"
        case .winPoker: "suit.diamond.fill"
        case .matchTokens: "diamond.fill"
        case .winTokenSwapLevels: "star.circle.fill"
        case .clearPumpRounds: "flag.checkered"
        case .reach2048Goals: "target"
        }
    }
}

/// What a quest or a streak day pays.
public enum QuestReward: Codable, Equatable, Sendable {
    /// Coins worth this many seconds of income at the moment the reward is claimed.
    case coins(seconds: Double)
    case tokens(TokenID, Int)
    case bullRun
}

/// What a claimed reward actually paid.
public enum RewardPayout: Equatable, Sendable {
    case coins(Double)
    case tokens(TokenID, Int)
    case bullRun(multiplier: Double, duration: TimeInterval)
}

/// One of the day's three quests.
public struct Quest: Codable, Equatable, Sendable, Identifiable {
    public let kind: QuestKind
    public let target: Double
    /// The tracked statistic when the quest was issued; progress counts up from here.
    public let baseline: Double
    public let reward: QuestReward
    public internal(set) var isClaimed = false

    public var id: String { kind.rawValue }
    public var title: String { kind.title(target: target) }
}

/// What a daily challenge asks for. Each kind belongs to one game (or, for the arcade mix, to
/// three of them), and is only picked once that game is unlocked.
public enum DailyChallengeKind: String, Codable, CaseIterable, Sendable {
    case tetris, merge2048, snake, brickBreaker, bubbleBlaster, pumpDump, tokenSwap
    case blackjack, slots, moon, videoPoker
    /// Score in three different arcade games.
    case arcadeMix
    /// Deal yourself a natural at Blackjack: Blackjack's other challenge, picked instead of the
    /// hands-won one half the time, so Blackjack comes up no more often than any other game.
    case blackjackNatural

    /// The game this challenge is played in; `nil` for the arcade mix.
    public var game: MiniGame? {
        switch self {
        case .tetris: .tetris
        case .merge2048: .merge2048
        case .snake: .snake
        case .brickBreaker: .brickBreaker
        case .bubbleBlaster: .bubbleBlaster
        case .pumpDump: .pumpDump
        case .tokenSwap: .tokenSwap
        case .blackjack: .blackjack
        case .slots: .slots
        case .moon: .moon
        case .videoPoker: .videoPoker
        case .arcadeMix: nil
        case .blackjackNatural: .blackjack
        }
    }

    /// The day's theme, shown above the goal.
    public var dayName: String {
        switch self {
        case .tetris: "Block Day"
        case .merge2048: "Puzzle Day"
        case .snake: "Survival Day"
        case .brickBreaker: "Precision Day"
        case .bubbleBlaster: "Pop Day"
        case .pumpDump: "Reflex Day"
        case .tokenSwap: "Match Day"
        case .blackjack, .slots, .moon, .videoPoker, .blackjackNatural: "Casino Day"
        case .arcadeMix: "Arcade Day"
        }
    }

    /// The goal, with the target filled in: "Eat 15 coins in one Snake game".
    public func goal(target: Int) -> String {
        let amount = CoinFormat.grouped(target)
        return switch self {
        case .tetris: "Score \(amount) in one Tetris game"
        case .merge2048: "Make a \(target) tile in 2048"
        case .snake: "Eat \(amount) coins in one Snake game"
        case .brickBreaker: "Break \(amount) bricks in one Brick Breaker game"
        case .bubbleBlaster: "Pop \(amount) bubbles in one Bubble Blaster game"
        case .pumpDump: "Score \(amount) in one Pump and Dump run"
        case .tokenSwap: "Score \(amount) in one round of Token Swap Classic"
        case .blackjack: "Win \(amount) Blackjack hands today"
        case .slots: "Win \(amount) spins at Crypto Slots today"
        case .moon: "Cash out at 2× or more \(amount) times in To the Moon today"
        case .videoPoker: "Make two pair or better \(amount) times in Video Poker today"
        case .arcadeMix: "Score in \(amount) different arcade games today"
        case .blackjackNatural: target == 1 ? "Deal yourself a natural blackjack today" : "Deal yourself \(amount) natural blackjacks today"
        }
    }

    /// Counts the best single game rather than a running total for the day.
    public var isBestOfOneGame: Bool {
        switch self {
        case .tetris, .merge2048, .snake, .brickBreaker, .bubbleBlaster, .pumpDump, .tokenSwap: true
        case .blackjack, .slots, .moon, .videoPoker, .arcadeMix, .blackjackNatural: false
        }
    }

    /// The targets a day can ask for.
    var targets: [Int] {
        switch self {
        case .tetris: [2_000, 3_500, 5_000]
        case .merge2048: [256, 512]
        case .snake: [12, 18, 25]
        case .brickBreaker: [25, 35, 50]
        case .bubbleBlaster: [30, 45, 60]
        case .pumpDump: [2_000, 3_000, 4_500]
        case .tokenSwap: [2_000, 3_000, 4_000]
        case .blackjack: [2, 3, 4]
        case .slots: [3, 5]
        case .moon: [2, 3]
        case .videoPoker: [2, 3]
        case .arcadeMix: [3]
        case .blackjackNatural: [1]
        }
    }
}

/// Today's challenge and how far it has come.
public struct DailyChallenge: Codable, Equatable, Sendable {
    /// The day it belongs to (a `StepDay` key).
    public let day: String
    public let kind: DailyChallengeKind
    public let target: Int
    /// The best single game so far today, or today's running total, depending on the kind.
    public internal(set) var progress = 0
    /// Arcade games scored in today, for the arcade mix.
    public internal(set) var gamesScored: Set<MiniGame> = []
    /// Reached the target; the reward has been paid.
    public internal(set) var isComplete = false

    public var goal: String { kind.goal(target: target) }

    public init(day: String, kind: DailyChallengeKind, target: Int) {
        self.day = day
        self.kind = kind
        self.target = target
    }

    private enum CodingKeys: String, CodingKey { case day, kind, target, progress, gamesScored, isComplete }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(String.self, forKey: .day)
        kind = try c.decode(DailyChallengeKind.self, forKey: .kind)
        target = max(1, try c.decode(Int.self, forKey: .target))
        progress = max(0, c.value(.progress, default: 0))
        gamesScored = c.enumSet(.gamesScored, as: MiniGame.self)
        isComplete = c.value(.isComplete, default: false)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(day, forKey: .day)
        try c.encode(kind, forKey: .kind)
        try c.encode(target, forKey: .target)
        try c.encode(progress, forKey: .progress)
        try c.encode(gamesScored.sortedRawValues, forKey: .gamesScored)
        try c.encode(isComplete, forKey: .isComplete)
    }
}

/// What completing a daily challenge paid.
public struct ChallengeReward: Equatable, Sendable {
    public let coins: Double
    /// Paid as well when this challenge completed the week's set; 0 otherwise.
    public let weeklyBonus: Double
}

/// Daily quests, the daily-reward streak and the daily challenge.
public struct DailyProgress: Codable, Equatable, Sendable {
    /// The day the game began (a `StepDay` key). Daily rewards, quests and the challenge start the
    /// day after, so they don't swamp the first minutes of play. `nil` for games begun before this.
    public internal(set) var firstDay: String?
    /// The day today's quests belong to (a `StepDay` key).
    public internal(set) var questDay: String?
    public internal(set) var quests: [Quest] = []
    /// Consecutive days the daily reward was claimed, as of `lastRewardDay`.
    public internal(set) var streak = 0
    public internal(set) var lastRewardDay: String?
    /// The latest daily challenge (today's, once it has been issued).
    public internal(set) var challenge: DailyChallenge?
    /// The week (the `StepDay` key of its Monday) that `challengesThisWeek` counts.
    public internal(set) var challengeWeek: String?
    public internal(set) var challengesThisWeek = 0

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case firstDay, questDay, quests, streak, lastRewardDay, challenge, challengeWeek, challengesThisWeek
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstDay = c.value(.firstDay, default: nil)
        quests = c.value(.quests, default: [])
        // Quests that can't be read are issued again rather than lost for the day.
        questDay = quests.isEmpty ? nil : c.value(.questDay, default: nil)
        streak = max(0, c.value(.streak, default: 0))
        lastRewardDay = c.value(.lastRewardDay, default: nil)
        // Older saves kept a Tetris-only challenge under other names; a new one is issued instead.
        challenge = c.value(.challenge, default: nil)
        challengeWeek = c.value(.challengeWeek, default: nil)
        challengesThisWeek = max(0, c.value(.challengesThisWeek, default: 0))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(firstDay, forKey: .firstDay)
        try c.encodeIfPresent(questDay, forKey: .questDay)
        try c.encode(quests, forKey: .quests)
        try c.encode(streak, forKey: .streak)
        try c.encodeIfPresent(lastRewardDay, forKey: .lastRewardDay)
        try c.encodeIfPresent(challenge, forKey: .challenge)
        try c.encodeIfPresent(challengeWeek, forKey: .challengeWeek)
        try c.encode(challengesThisWeek, forKey: .challengesThisWeek)
    }
}

/// Idle income at a moment, for the income chart.
public struct IncomeSample: Codable, Equatable, Sendable {
    public let date: Date
    public let income: Double

    public init(date: Date, income: Double) {
        self.date = date
        self.income = income
    }
}
