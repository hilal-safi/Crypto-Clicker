import Foundation

/// Daily quests, the daily-reward streak and the daily Tetris challenge. Days are `StepDay` keys
/// (`yyyy-MM-dd` in the player's time zone), passed in so tests can choose them.
extension GameState {
    // MARK: Quests

    /// The lifetime statistic a quest counts up from.
    func questMetric(_ kind: QuestKind) -> Double {
        switch kind {
        case .tapCoin: Double(stats.taps)
        case .buyMiners: Double(stats.minersBought)
        case .earnCoins: stats.lifetimeCoins
        case .catchAirdrops: Double(stats.airdrops)
        case .walkSteps: Double(stats.lifetimeSteps)
        case .winBlackjack: Double(stats.blackjackWins)
        case .spinSlots: Double(stats.slotsSpins)
        case .clearLines: Double(stats.tetrisLines)
        case .eatSnakeCoins: Double(stats.snakeCoinsEaten)
        case .breakBricks: Double(stats.bricksBroken)
        case .popBubbles: Double(stats.bubblesPopped)
        case .sellTokens: Double(stats.tokensSold)
        case .score2048: Double(stats.merge2048Points)
        }
    }

    /// How far a quest has come, from 0 up to its target.
    public func progress(of quest: Quest) -> Double {
        min(max(0, questMetric(quest.kind) - quest.baseline), quest.target)
    }

    public func isComplete(_ quest: Quest) -> Bool { progress(of: quest) >= quest.target }

    /// Finished quests waiting to be claimed.
    public var claimableQuestCount: Int {
        daily.quests.filter { !$0.isClaimed && isComplete($0) }.count
    }

    /// Quests the player can work on now: games must be unlocked and steps connected.
    func eligibleQuestKinds(canWalk: Bool) -> [QuestKind] {
        QuestKind.allCases.filter { kind in
            switch kind {
            case .tapCoin, .buyMiners, .earnCoins, .catchAirdrops: true
            case .walkSteps: canWalk && steps.isConnected
            case .winBlackjack: isUnlocked(.blackjack)
            case .spinSlots: isUnlocked(.slots)
            case .clearLines: isUnlocked(.tetris)
            case .eatSnakeCoins: isUnlocked(.snake)
            case .breakBricks: isUnlocked(.brickBreaker)
            case .popBubbles: isUnlocked(.bubbleBlaster)
            case .sellTokens: stats.totalTokensBought > 0
            case .score2048: isUnlocked(.merge2048)
            }
        }
    }

    /// Issues `today`'s quests if they haven't been issued yet. Quests finished on an earlier day
    /// but never claimed are paid first, so nothing earned is lost overnight. Returns those payouts.
    @discardableResult
    public mutating func refreshDaily(today: String, canWalk: Bool, at now: Date) -> [RewardPayout] {
        guard daily.questDay != today else { return [] }
        var paid: [RewardPayout] = []
        for index in daily.quests.indices where !daily.quests[index].isClaimed && isComplete(daily.quests[index]) {
            daily.quests[index].isClaimed = true
            stats.questsCompleted += 1
            paid.append(pay(daily.quests[index].reward, at: now))
        }
        daily.quests = makeQuests(for: today, canWalk: canWalk)
        daily.questDay = today
        return paid
    }

    /// The day's quests: different kinds, picked the same way however often they are made.
    func makeQuests(for day: String, canWalk: Bool) -> [Quest] {
        var rng = SeededGenerator(seed: StableHash.mix(StableHash.of("quests-" + day), StableHash.of(created)))
        let kinds = eligibleQuestKinds(canWalk: canWalk).shuffled(using: &rng).prefix(Tuning.questsPerDay)
        var quests: [Quest] = []
        for (slot, kind) in kinds.enumerated() {
            let target = questTarget(kind, using: &rng)
            let reward = questReward(slot: slot, using: &rng)
            quests.append(Quest(kind: kind, target: target, baseline: questMetric(kind), reward: reward))
        }
        return quests
    }

    func questTarget<R: RandomNumberGenerator>(_ kind: QuestKind, using rng: inout R) -> Double {
        let choices: [Double] = switch kind {
        case .tapCoin: [200, 300, 500]
        case .buyMiners: [10, 15, 25]
        case .earnCoins: [1_800, 3_600].map { Self.roundTarget($0 * rewardIncome) }
        case .catchAirdrops: [2, 3, 4]
        case .walkSteps: [2_000, 4_000, 6_000]
        case .winBlackjack: [2, 3, 5]
        case .spinSlots: [10, 20, 30]
        case .clearLines: [5, 10, 20]
        case .eatSnakeCoins: [10, 15, 25]
        case .breakBricks: [20, 40, 60]
        case .popBubbles: [20, 40, 60]
        case .sellTokens: [3, 5, 10]
        case .score2048: [2_000, 5_000, 10_000]
        }
        return choices.randomElement(using: &rng) ?? choices[0]
    }

    /// Rounds a coin target up to two significant figures, and to at least 1,000.
    static func roundTarget(_ value: Double) -> Double {
        guard value.isFinite, value > 1_000 else { return 1_000 }
        let unit = pow(10, (log10(value)).rounded(.down) - 1)
        return (value / unit).rounded(.up) * unit
    }

    /// The first quest pays 10 minutes of income, the second 20, and the third 30 minutes'
    /// worth of coins or tokens, or a Bull Run.
    func questReward<R: RandomNumberGenerator>(slot: Int, using rng: inout R) -> QuestReward {
        switch slot {
        case 0: return .coins(seconds: 600)
        case 1: return .coins(seconds: 1_200)
        default:
            let roll = Double.random(in: 0..<1, using: &rng)
            if roll < 0.25 { return .bullRun }
            if roll < 0.6, let tokens = tokenReward(worth: 1_800 * rewardIncome) { return tokens }
            return .coins(seconds: 1_800)
        }
    }

    /// Tokens worth about `value` coins at list price: the priciest kind that still makes five.
    func tokenReward(worth value: Double) -> QuestReward? {
        guard let token = TokenID.allCases.last(where: { $0.price * 5 <= value }) else { return nil }
        let count = Int(min(max((value / token.price).rounded(.down), 5), 500))
        return .tokens(token, count)
    }

    /// Pays a finished quest once.
    @discardableResult
    public mutating func claimQuest(_ id: Quest.ID, at now: Date) -> RewardPayout? {
        guard let index = daily.quests.firstIndex(where: { $0.id == id }),
              !daily.quests[index].isClaimed, isComplete(daily.quests[index]) else { return nil }
        daily.quests[index].isClaimed = true
        stats.questsCompleted += 1
        return pay(daily.quests[index].reward, at: now)
    }

    // MARK: Daily reward

    public func isDailyRewardReady(today: String) -> Bool { daily.lastRewardDay != today }

    /// The streak as of `today`: it is broken once a whole day passes without a claim.
    public func currentStreak(today: String, yesterday: String) -> Int {
        daily.lastRewardDay == today || daily.lastRewardDay == yesterday ? daily.streak : 0
    }

    /// The streak that claiming today's reward makes.
    public func streakIfClaimed(today: String, yesterday: String) -> Int {
        if daily.lastRewardDay == today { return daily.streak }
        return daily.lastRewardDay == yesterday ? daily.streak + 1 : 1
    }

    /// Position of streak day `streak` in the repeating week, from 1 to 7.
    public static func streakCycleDay(_ streak: Int) -> Int {
        (max(1, streak) - 1) % Tuning.streakCycle + 1
    }

    /// The reward for a day of the streak. The week builds up to an hour of income on day 7,
    /// then starts again.
    public func streakReward(day streak: Int) -> QuestReward {
        switch Self.streakCycleDay(streak) {
        case 1: .coins(seconds: 300)
        case 2: .coins(seconds: 600)
        case 3: tokenReward(worth: 900 * rewardIncome) ?? .coins(seconds: 900)
        case 4: .coins(seconds: 1_200)
        case 5: .bullRun
        case 6: .coins(seconds: 1_800)
        default: .coins(seconds: 3_600)
        }
    }

    /// Pays today's daily reward and extends the streak (or starts a new one).
    @discardableResult
    public mutating func claimDailyReward(today: String, yesterday: String, at now: Date) -> RewardPayout? {
        guard isDailyRewardReady(today: today) else { return nil }
        let streak = streakIfClaimed(today: today, yesterday: yesterday)
        daily.streak = streak
        daily.lastRewardDay = today
        stats.longestStreak = max(stats.longestStreak, streak)
        return pay(streakReward(day: streak), at: now)
    }

    // MARK: Paying rewards

    /// Pays a quest or streak reward. Coins are worth `seconds` of income when paid; Lucky Streak
    /// doubles coins and tokens, and makes a Bull Run last twice as long.
    mutating func pay(_ reward: QuestReward, at now: Date) -> RewardPayout {
        let multiplier = dailyRewardMultiplier
        switch reward {
        case .coins(let seconds):
            let amount = Self.wholeCoins(seconds * rewardIncome * multiplier, minimum: 1)
            credit(amount, source: .daily)
            return .coins(amount)
        case .tokens(let token, let count):
            let amount = Int(Double(count) * multiplier)
            giveTokens(token, amount: amount)
            return .tokens(token, amount)
        case .bullRun:
            let duration = bullRunDuration * multiplier
            startBullRun(duration: duration, at: now)
            return .bullRun(multiplier: Tuning.bullRunMultiplier, duration: duration)
        }
    }

    // MARK: Daily Tetris challenge

    /// The seed for `day`'s challenge: the same pieces all day, for everyone.
    public static func dailyChallengeSeed(day: String) -> UInt64 {
        StableHash.of("tetris-challenge-" + day)
    }

    /// Today's first challenge game that scores still pays double.
    public func isDailyChallengeBonusAvailable(today: String) -> Bool {
        !(daily.challengeDay == today && daily.challengeRewarded)
    }

    /// The best challenge score today.
    public func dailyChallengeBest(today: String) -> Int {
        daily.challengeDay == today ? daily.challengeBest : 0
    }
}
