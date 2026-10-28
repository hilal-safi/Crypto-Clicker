import Foundation

/// The records a finished game changes, taken before an action so `awardArcadeProgress` can see
/// what it did: games played, best scores, challenges completed and stars earned.
public struct ArcadeSnapshot: Equatable, Sendable {
    let played: [MiniGame: Int]
    let best: [MiniGame: Int]
    let bestSprint: Double
    let bestRush: Int
    let challenges: Int
    let stars: Int
}

/// What a finished game earned toward Arcade Rank.
public struct ArcadeAward: Equatable, Sendable {
    public let xp: Int
    public let rankBefore: Int
    public let rankAfter: Int
    /// Coins the week's variety goal paid, when this game reached it (0 otherwise).
    public let weeklyReward: Double

    public var rankedUp: Bool { rankAfter > rankBefore }
}

/// Arcade Rank and the weekly variety goal. XP comes from finishing games, with more for a new best
/// score, the first game of each kind each day, the daily challenge, stars and game achievements.
/// Casino rounds give a little XP, up to a daily cap, so XP rewards playing (and playing many
/// games) rather than betting.
extension GameState {
    public var arcadeSnapshot: ArcadeSnapshot {
        ArcadeSnapshot(played: Dictionary(uniqueKeysWithValues: MiniGame.allCases.map { ($0, timesPlayed($0)) }),
                       best: Dictionary(uniqueKeysWithValues: MiniGame.allCases.map { ($0, bestScore($0)) }),
                       bestSprint: stats.tetrisBestSprint, bestRush: stats.snakeRushBestScore,
                       challenges: stats.challengesCompleted, stars: tokenSwap.totalStars + merge2048Daily.totalStars)
    }

    public var arcadeRank: Int { ArcadeRank.rank(forXP: arcade.xp) }

    public var arcadeTitle: String { ArcadeRank.title(forRank: arcadeRank) }

    /// XP earned into the current rank, and what the next rank needs from it.
    public var arcadeRankProgress: (xp: Int, needed: Int) {
        let rank = arcadeRank
        let floor = ArcadeRank.xpNeeded(forRank: rank)
        return (arcade.xp - floor, ArcadeRank.xpNeeded(forRank: rank + 1) - floor)
    }

    /// Coins the week's variety goal pays (Lucky Streak doubles them, like the daily rewards).
    public var weeklyVarietyReward: Double {
        Self.wholeCoins(Tuning.weeklyVarietySeconds * rewardIncome * dailyRewardMultiplier, minimum: 1)
    }

    /// Games played in the week containing `today`.
    public func gamesPlayed(inWeekOf today: String) -> Set<MiniGame> {
        arcade.week == StepDay.weekKey(of: today) ? arcade.gamesThisWeek : []
    }

    /// Whether the week containing `today` has had its variety goal paid.
    public func isWeeklyGoalPaid(inWeekOf today: String) -> Bool {
        arcade.week == StepDay.weekKey(of: today) && arcade.isWeekPaid
    }

    /// Awards XP for what changed since `before` (games finished, new bests, the daily challenge,
    /// stars) and counts the games toward the week's variety goal, paying it the moment it's met.
    /// Returns `nil` when nothing changed.
    @discardableResult
    public mutating func awardArcadeProgress(since before: ArcadeSnapshot, today: String) -> ArcadeAward? {
        let after = arcadeSnapshot
        let finished = MiniGame.allCases.filter { after.played[$0, default: 0] > before.played[$0, default: 0] }
        let challenges = max(0, after.challenges - before.challenges)
        let stars = max(0, after.stars - before.stars)
        guard !finished.isEmpty || challenges > 0 || stars > 0 else { return nil }
        if arcade.day != today {
            arcade.day = today
            arcade.gamesToday = []
            arcade.casinoXPToday = 0
        }
        let rankBefore = arcadeRank
        // Counted without overflowing, however large the numbers (a 32-bit `Int` on Apple Watch).
        var xp = 0
        func add(_ count: Int, times each: Int) {
            let (product, overflow) = max(0, count).multipliedReportingOverflow(by: each)
            xp = xp.addingCount(overflow ? .max : product)
        }
        for game in finished {
            let count = after.played[game, default: 0] - before.played[game, default: 0]
            if game.isCasino {
                // A little for each round, up to what's left of today's cap.
                let room = max(0, Tuning.arcadeCasinoXPPerDay - arcade.casinoXPToday)
                let casino = min(min(count, room) * Tuning.arcadeXPPerCasinoRound, room)
                arcade.casinoXPToday += casino
                add(casino, times: 1)
            } else {
                add(count, times: Tuning.arcadeXPPerGame)
                if after.best[game, default: 0] > before.best[game, default: 0] { add(1, times: Tuning.arcadeXPNewBest) }
            }
            if arcade.gamesToday.insert(game).inserted { add(1, times: Tuning.arcadeXPFirstPlayToday) }
        }
        let fasterSprint = after.bestSprint > 0 && (before.bestSprint == 0 || after.bestSprint < before.bestSprint)
        if fasterSprint || after.bestRush > before.bestRush { add(1, times: Tuning.arcadeXPNewBest) }
        add(challenges, times: Tuning.arcadeXPChallenge)
        add(stars, times: Tuning.arcadeXPPerStar)

        // The week's variety goal.
        var weeklyReward = 0.0
        let week = StepDay.weekKey(of: today)
        if arcade.week != week {
            arcade.week = week
            arcade.gamesThisWeek = []
            arcade.isWeekPaid = false
        }
        arcade.gamesThisWeek.formUnion(finished)
        if !arcade.isWeekPaid && arcade.gamesThisWeek.count >= Tuning.weeklyVarietyGames {
            arcade.isWeekPaid = true
            arcade.weeklyGoals += 1
            weeklyReward = payDailyCoins(seconds: Tuning.weeklyVarietySeconds)
            add(1, times: Tuning.arcadeXPWeeklyGoal)
        }
        arcade.xp = arcade.xp.addingCount(xp)
        return ArcadeAward(xp: xp, rankBefore: rankBefore, rankAfter: arcadeRank, weeklyReward: weeklyReward)
    }

    /// Arcade XP for play before Arcade Rank existed, given once to a save that has none: arcade
    /// games finished, game achievement tiers, daily challenges and Token Swap stars, at the usual
    /// rates. Casino rounds don't count (their XP is capped by the day, and the days are gone).
    var legacyArcadeXP: Int {
        let games = MiniGame.allCases.filter { !$0.isCasino }.reduce(0) { $0.addingCount(timesPlayed($1)) }
        let tiers = AchievementCatalog.arcadeIDs.reduce(0) { $0.addingCount(achievementTiers[$1, default: 0]) }
        var xp = 0
        for (count, each) in [(games, Tuning.arcadeXPPerGame), (tiers, Tuning.arcadeXPPerAchievementTier),
                              (stats.challengesCompleted, Tuning.arcadeXPChallenge), (tokenSwap.totalStars, Tuning.arcadeXPPerStar)] {
            let (product, overflow) = max(0, count).multipliedReportingOverflow(by: each)
            xp = xp.addingCount(overflow ? .max : product)
        }
        return xp
    }

    /// XP for game achievement tiers, from `refreshAchievements`.
    mutating func awardAchievementXP(_ tiers: [EarnedTier]) {
        let count = tiers.filter { AchievementCatalog.arcadeIDs.contains($0.achievement.id) }.count
        let (xp, overflow) = count.multipliedReportingOverflow(by: Tuning.arcadeXPPerAchievementTier)
        arcade.xp = arcade.xp.addingCount(overflow ? .max : xp)
    }

    // MARK: Cosmetics

    public func isUnlocked(_ cosmetic: Cosmetic) -> Bool {
        switch cosmetic.unlock {
        case .free: true
        case .rank(let rank): arcadeRank >= rank
        case .achievement(let id, let tier): achievementTiers[id, default: 0] > tier
        }
    }

    /// The cosmetic in use for a slot: the one picked, or the slot's default.
    public func equipped(_ slot: CosmeticSlot) -> Cosmetic {
        arcade.equipped[slot] ?? slot.standard
    }

    /// Picks an unlocked cosmetic for its slot.
    @discardableResult
    public mutating func equip(_ cosmetic: Cosmetic) -> Bool {
        guard isUnlocked(cosmetic) else { return false }
        arcade.equipped[cosmetic.slot] = cosmetic == cosmetic.slot.standard ? nil : cosmetic
        return true
    }

    /// What unlocks a cosmetic, for the locked card.
    public func unlockText(_ cosmetic: Cosmetic) -> String {
        switch cosmetic.unlock {
        case .free:
            return "Free"
        case .rank(let rank):
            return "Arcade Rank \(rank)"
        case .achievement(let id, let tier):
            let name = AchievementCatalog.all.first { $0.id == id }?.name ?? id
            return "\(name) · \(AchievementCatalog.tierNames[min(max(0, tier), AchievementCatalog.tierNames.count - 1)])"
        }
    }
}
