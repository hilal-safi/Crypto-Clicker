import Foundation

/// What a daily quest asks for. Progress counts up from the moment the quest is issued.
public enum QuestKind: String, Codable, CaseIterable, Sendable {
    case tapCoin, buyMiners, earnCoins, catchAirdrops, walkSteps
    case winBlackjack, spinSlots, clearLines, eatSnakeCoins, breakBricks, popBubbles, sellTokens, score2048

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

/// Daily quests, the daily-reward streak and the daily Tetris challenge.
public struct DailyProgress: Codable, Equatable, Sendable {
    /// The day today's quests belong to (a `StepDay` key).
    public internal(set) var questDay: String?
    public internal(set) var quests: [Quest] = []
    /// Consecutive days the daily reward was claimed, as of `lastRewardDay`.
    public internal(set) var streak = 0
    public internal(set) var lastRewardDay: String?
    /// The day of the last daily Tetris challenge game, its best score, and whether that day's
    /// double reward has been paid.
    public internal(set) var challengeDay: String?
    public internal(set) var challengeBest = 0
    public internal(set) var challengeRewarded = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case questDay, quests, streak, lastRewardDay, challengeDay, challengeBest, challengeRewarded
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        quests = c.value(.quests, default: [])
        // Quests that can't be read are issued again rather than lost for the day.
        questDay = quests.isEmpty ? nil : c.value(.questDay, default: nil)
        streak = max(0, c.value(.streak, default: 0))
        lastRewardDay = c.value(.lastRewardDay, default: nil)
        challengeDay = c.value(.challengeDay, default: nil)
        challengeBest = c.value(.challengeBest, default: 0)
        challengeRewarded = c.value(.challengeRewarded, default: false)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(questDay, forKey: .questDay)
        try c.encode(quests, forKey: .quests)
        try c.encode(streak, forKey: .streak)
        try c.encodeIfPresent(lastRewardDay, forKey: .lastRewardDay)
        try c.encodeIfPresent(challengeDay, forKey: .challengeDay)
        try c.encode(challengeBest, forKey: .challengeBest)
        try c.encode(challengeRewarded, forKey: .challengeRewarded)
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
