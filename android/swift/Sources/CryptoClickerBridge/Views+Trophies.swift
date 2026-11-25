import Foundation
import CryptoClickerKit

// The Trophies tab's three pages, as the iOS TrophiesView works them out: Goals ("goals"), Daily
// ("daily": the reward and its streak, the quests and the challenge) and Achievements
// ("achievements").

/// The next few things worth working toward (iOS: GoalsPage).
struct GoalsView: Encodable {
    /// The opening's starter milestones, until every one is claimed.
    let starters: [StarterView]
    let goals: [GoalView]
}

/// A starter milestone on the Goals page: what to do, what it pays, and Claim once it's done.
struct StarterView: Encodable {
    let id: String
    let title: String
    let symbol: String
    /// "1.2K coins", or the Bull Run it starts.
    let reward: String
    /// coins or bullRun, for the reward's symbol.
    let rewardKind: String
    let progress: Double
    let isReached: Bool
    let isClaimed: Bool
}

struct GoalView: Encodable {
    let id: String
    let title: String
    let detail: String
    let progress: Double
    /// "45%", or "Ready" once reached.
    let progressText: String
    let ready: Bool
    let symbol: String
    /// The goal kind's colour, by name or "#RRGGBB".
    let color: String
}

/// The daily reward and its streak, the day's quests and the daily challenge (iOS: DailyPage).
struct DailyView: Encodable {
    let reward: DailyRewardView
    /// Midnight, when the quests and the reward renew, in seconds since 1970.
    let resetsAt: Double
    let questsEmpty: String?
    let quests: [QuestView]
    let challenge: ChallengeView?
    let footnote: String
}

/// The login streak: a week of rewards building to day 7, and today's to claim (iOS: DailyRewardCard).
struct DailyRewardView: Encodable {
    /// "🔥 3-day streak"
    let streak: String?
    let days: [StreakDayView]
    let isReady: Bool
    /// "Claim Day 4" and what it pays.
    let claimTitle: String
    let claimDetail: String
    /// "First" on the game's first day, else "Next": "Next reward in 5 hr".
    let waitWord: String
    let note: String?
}

struct StreakDayView: Encodable {
    let day: Int
    /// The day's reward, a check once claimed, a star on day 7.
    let symbol: String
    let isClaimed: Bool
    let isToday: Bool
}

struct QuestView: Encodable {
    let id: String
    let symbol: String
    let title: String
    let fraction: Double
    /// "1.2K / 5K"
    let progressText: String
    let reward: String
    let rewardSymbol: String
    let isComplete: Bool
    let isClaimed: Bool
}

/// Today's challenge (iOS: ChallengeCard), on the Daily page and at the top of the Arcade.
struct ChallengeView: Encodable {
    /// The game it's played in ("snake"), nil for the arcade mix.
    let game: String?
    let icon: String
    /// The game's colour ("#RRGGBB"), deep enough for white text, and lighter for text on dark cards.
    let color: String
    let textColorDark: String
    /// "Survival Day · Daily Challenge"
    let title: String
    let goal: String
    let progressText: String
    let fraction: Double
    let isComplete: Bool
    /// The game is unlocked and the challenge not yet done: Play opens it.
    let canPlay: Bool
    /// "+12.3K coins", or "Reward collected"
    let reward: String
    /// "This week 2 of 5 · +50K at 5", or "Weekly bonus earned"
    let week: String
}

/// The achievements and the stars they add up to (iOS: TrophySummary and AchievementCard).
struct AchievementsView: Encodable {
    /// "12 of 120 stars"
    let title: String
    /// "+12% production from achievements"
    let bonus: String
    let fraction: Double
    /// "3 more for the Silver coin"
    let nextFinish: String?
    let cards: [AchievementView]
}

struct AchievementView: Encodable {
    let id: String
    let emoji: String
    let name: String
    let detail: String
    /// Tiers earned: 0 to 4 (bronze, silver, gold, mythic).
    let tiers: Int
    let fraction: Double
    /// "1.2K / 5K"
    let progressText: String
    /// Every tier is earned: a full mythic bar.
    let isMythic: Bool
    /// "Gold", or "Not earned yet", for TalkBack.
    let tierName: String
}

// MARK: - Building

extension GameSession {
    var goalsView: GoalsView {
        let game = state
        var starters: [StarterView] = []
        if game.hasUnclaimedStarterMilestones {
            starters = StarterMilestone.allCases.map { milestone -> StarterView in
                let payout = game.payout(of: milestone)
                let kind = switch payout {
                case .coins: "coins"
                case .bullRun: "bullRun"
                }
                return StarterView(id: milestone.rawValue, title: milestone.title, symbol: milestone.symbol, reward: payout.text,
                                   rewardKind: kind, progress: clamped(game.progress(of: milestone)),
                                   isReached: game.isReached(milestone), isClaimed: game.isClaimed(milestone))
            }
        }
        return GoalsView(starters: starters, goals: game.nextGoals.map { goal in
            GoalView(
                id: goal.id, title: goal.title, detail: goal.detail, progress: clamped(goal.progress),
                progressText: goal.progress >= 1 ? "Ready" : CoinFormat.percent((goal.progress * 100).rounded(.down) / 100),
                ready: goal.progress >= 1, symbol: goalSymbol(goal.kind), color: goalColor(goal.kind))
        })
    }

    private func goalSymbol(_ kind: Goal.Kind) -> String {
        switch kind {
        case .miner: "cpu.fill"
        case .milestone: "arrow.up.right.circle.fill"
        case .upgrade: "sparkles"
        case .game: "gamecontroller.fill"
        case .achievement: "trophy.fill"
        case .arcadeRank: "star.circle.fill"
        case .tokenSwap: "square.grid.3x3.fill"
        case .prestige: "rosette"
        }
    }

    private func goalColor(_ kind: Goal.Kind) -> String {
        switch kind {
        case .miner: "blue"
        case .milestone: "orange"
        case .upgrade: "purple"
        case .game: "arcadeButton"
        case .achievement: "#D99900"
        case .arcadeRank: "pink"
        case .tokenSwap: hex(MiniGame.tokenSwap.info.color)
        case .prestige: "indigo"
        }
    }

    var dailyView: DailyView {
        let game = state
        let today = self.today
        let yesterday = self.yesterday
        let midnight = StepDay.calendar().startOfDay(for: now).addingTimeInterval(86_400)
        let isFirstDay = game.isFirstDay(today)
        let streak = game.currentStreak(today: today, yesterday: yesterday)
        let nextStreak = game.streakIfClaimed(today: today, yesterday: yesterday)
        let isReady = game.isDailyRewardReady(today: today)
        let cycleDay = GameState.streakCycleDay(nextStreak)
        let reward = DailyRewardView(
            streak: streak > 0 ? "🔥 \(streak)-day streak" : nil,
            days: (1...Tuning.streakCycle).map { day in
                let claimed = !isFirstDay && (day < cycleDay || (day == cycleDay && !isReady))
                return StreakDayView(
                    day: day,
                    symbol: claimed ? "checkmark.circle.fill"
                        : (day == Tuning.streakCycle ? "star.circle.fill" : rewardSymbol(game.streakReward(day: day))),
                    isClaimed: claimed, isToday: day == cycleDay)
            },
            isReady: isReady,
            claimTitle: "Claim Day \(nextStreak)",
            claimDetail: rewardText(game.streakReward(day: nextStreak), income: game.streakRewardIncome),
            waitWord: isFirstDay ? "First" : "Next",
            note: !isReady || streak == 0
                ? (isFirstDay
                    ? "Daily rewards, quests and challenges start on your second day. Claim a reward every day to keep your streak: day 7 pays an hour of income."
                    : "Claim a reward every day to keep your streak. Day 7 pays an hour of income, then the week starts over.")
                : nil)
        let quests = game.daily.quests.map { quest -> QuestView in
            let progress = game.progress(of: quest)
            return QuestView(
                id: quest.id, symbol: quest.kind.symbol, title: quest.title,
                fraction: clamped(min(progress, quest.target) / max(quest.target, 1)),
                progressText: "\(CoinFormat.short(progress)) / \(CoinFormat.short(quest.target))",
                reward: rewardText(quest.reward, income: game.rewardIncome(for: quest)),
                rewardSymbol: rewardSymbol(quest.reward),
                isComplete: progress >= quest.target, isClaimed: quest.isClaimed)
        }
        return DailyView(
            reward: reward, resetsAt: midnight.timeIntervalSince1970,
            questsEmpty: quests.isEmpty
                ? (isFirstDay ? "Your first quests and daily challenge arrive tomorrow." : "New quests are on their way.") : nil,
            quests: quests,
            challenge: challengeView,
            footnote: game.hasPerk(.luckyStreak)
                ? "Lucky Streak doubles every daily reward. Coin rewards grow with your income, up to three times over the day and twice once a quest is finished."
                : "Coin rewards grow with your income, up to three times over the day and twice once a quest is finished. Quests finished but not claimed are paid at midnight.")
    }

    /// What a reward pays if claimed now (iOS: QuestReward.text).
    func rewardText(_ reward: QuestReward, income: Double) -> String {
        switch state.payout(of: reward, income: income) {
        case .coins(let amount): "\(CoinFormat.short(amount)) coins"
        case .tokens(let token, let count): "\(CoinFormat.grouped(count)) \(token.ticker)"
        case .bullRun(let multiplier, let duration): "Bull Run \(CoinFormat.multiplier(multiplier)) for \(CoinFormat.duration(duration))"
        }
    }

    func rewardSymbol(_ reward: QuestReward) -> String {
        switch reward {
        case .coins: "bitcoinsign.circle.fill"
        case .tokens: "circle.hexagongrid.fill"
        case .bullRun: "flame.fill"
        }
    }

    var challengeView: ChallengeView? {
        let game = state
        guard let challenge = game.dailyChallenge(today: today) else { return nil }
        let miniGame = challenge.kind.game
        let color = miniGame.map { hex($0.info.color) } ?? "bitcoin"
        let weekCount = game.challengesCompleted(inWeekOf: today)
        let goal = Tuning.weeklyChallengeGoal
        let fraction = challenge.isComplete ? 1 : min(1, Double(challenge.progress) / Double(max(1, challenge.target)))
        let progressText: String
        if challenge.isComplete {
            progressText = "Done for today. A new challenge comes at midnight."
        } else {
            switch challenge.kind {
            case .merge2048:
                progressText = challenge.progress > 0 ? "Best tile today: \(challenge.progress)" : "No tile yet today"
            case .arcadeMix:
                let icons = challenge.gamesScored.sorted { $0.rawValue < $1.rawValue }.map(\.info.icon).joined(separator: " ")
                progressText = "\(challenge.gamesScored.count) of \(challenge.target) so far" + (icons.isEmpty ? "" : ": \(icons)")
            default:
                progressText = challenge.kind.isBestOfOneGame
                    ? "Best today: \(CoinFormat.grouped(challenge.progress))"
                    : "\(CoinFormat.grouped(challenge.progress)) of \(CoinFormat.grouped(challenge.target)) so far"
            }
        }
        return ChallengeView(
            game: miniGame?.rawValue, icon: miniGame?.info.icon ?? "🎯",
            color: color, textColorDark: miniGame.map { hex($0.info.color, mixedWithWhite: 0.45) } ?? "bitcoin",
            title: "\(challenge.kind.dayName) · Daily Challenge", goal: challenge.goal,
            progressText: progressText, fraction: fraction, isComplete: challenge.isComplete,
            canPlay: !challenge.isComplete && miniGame.map(game.isUnlocked) == true,
            reward: challenge.isComplete ? "Reward collected" : "+\(CoinFormat.short(game.challengeReward)) coins",
            week: weekCount >= goal ? "Weekly bonus earned"
                : "This week \(weekCount) of \(goal) · +\(CoinFormat.short(game.weeklyChallengeBonus)) at \(goal)")
    }

    var achievementsView: AchievementsView {
        let game = state
        let earned = game.earnedAchievementTiers
        let total = AchievementCatalog.tierCount
        let next = CoinFinish.allCases.first { !$0.isUnlocked(stars: earned) }
        return AchievementsView(
            title: "\(earned) of \(total) stars",
            bonus: "+\(CoinFormat.percent(game.achievementBonus - 1)) production from achievements",
            fraction: clamped(Double(earned) / Double(max(1, total))),
            nextFinish: next.map { "\($0.starsNeeded - earned) more for the \($0.name) coin" },
            cards: AchievementCatalog.all.map { achievement in
                let tiers = game.tiersEarned(achievement)
                let value = game.value(of: achievement.metric)
                let next = game.nextThreshold(achievement)
                let needed = next ?? achievement.thresholds.last ?? value
                return AchievementView(
                    id: achievement.id, emoji: achievement.emoji ?? "🏆", name: achievement.name, detail: achievement.detail,
                    tiers: tiers, fraction: next.map { clamped(min(value, $0) / max($0, 1)) } ?? 1,
                    progressText: "\(CoinFormat.short(value)) / \(CoinFormat.short(needed))",
                    isMythic: next == nil,
                    tierName: tiers == 0 ? "Not earned yet" : AchievementCatalog.tierNames[min(tiers, 4) - 1])
            })
    }
}

/// A kit colour as "#RRGGBB", mixed toward white by `share` (the iOS textColor in dark mode).
func hex(_ color: MiniGameInfo.RGB, mixedWithWhite share: Double = 0) -> String {
    func channel(_ value: Double) -> Int { Int((min(max(value + (1 - value) * share, 0), 1) * 255).rounded()) }
    return String(format: "#%02X%02X%02X", channel(color.red), channel(color.green), channel(color.blue))
}
