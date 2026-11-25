import SwiftUI
import CryptoClickerKit

// Progress and its announcements: dailies, quests, challenges, achievements, Arcade Rank, and
// the income chart's samples.
extension GameStore {
    // MARK: Dailies

    /// Issues the day's quests and challenge once the day changes (or the first game is unlocked),
    /// paying any finished quests left from before. Checked every few seconds, since midnight can
    /// pass while the app is open.
    func refreshDaily(at now: Date, force: Bool = false) {
        guard !isSaveLocked, force || now.timeIntervalSince(lastDayCheck) >= 5 else { return }
        lastDayCheck = now
        let today = StepDay.key(for: now)
        refreshDailyStatus(at: now) // The badge also changes at midnight and as quests finish.
        guard game.needsDailyRefresh(today: today) else { return }
        let canWalk = canTrackSteps
        let paid = perform { game, now in game.refreshDaily(today: today, canWalk: canWalk, at: now) }
        for payout in paid {
            show(toast(for: payout, title: "Yesterday's quest paid"))
        }
        save()
    }

    func claimQuest(_ quest: Quest) {
        guard let payout = perform({ game, now in game.claimQuest(quest.id, at: now) }) else { return }
        show(toast(for: payout, title: "Quest complete"))
        save()
    }

    /// Pays a starter milestone from the Goals page.
    func claimStarterMilestone(_ milestone: StarterMilestone) {
        guard let payout = perform({ game, now in game.claim(milestone, at: now) }) else { return }
        switch payout {
        case .coins(let amount):
            show(Toast(icon: "🎁", title: milestone.title, message: "+\(CoinFormat.short(amount)) coins"))
        case .bullRun(let seconds):
            show(Toast(icon: "🐂", title: milestone.title,
                       message: "Bull Run: production \(CoinFormat.multiplier(Tuning.bullRunMultiplier)) for \(CoinFormat.duration(seconds))"))
        }
        save()
    }

    func claimDailyReward() {
        let today = today, yesterday = yesterday
        guard let payout = perform({ game, now in game.claimDailyReward(today: today, yesterday: yesterday, at: now) })
        else { return }
        show(toast(for: payout, title: "Day \(game.daily.streak) reward"))
        save()
    }

    func toast(for payout: RewardPayout, title: String) -> Toast {
        switch payout {
        case .coins(let amount):
            Toast(icon: "🎁", title: title, message: "+\(CoinFormat.short(amount)) coins")
        case .tokens(let token, let count):
            Toast(icon: "🎁", title: title, message: "+\(CoinFormat.grouped(count)) \(token.name)")
        case .bullRun(let multiplier, let duration):
            Toast(icon: "🐂", title: title,
                  message: "Bull Run: production \(CoinFormat.multiplier(multiplier)) for \(CoinFormat.duration(duration))")
        }
    }

    /// Samples idle income for the Statistics chart every minute while the app is open.
    func recordIncomeIfDue(at now: Date) {
        let last = game.incomeHistory.last?.date ?? .distantPast
        guard now.timeIntervalSince(last) >= Tuning.incomeSampleInterval || last > now else { return }
        state.recordIncomeSample(at: now)
        publish(at: now, ticking: true)
        hasUnsavedChanges = true
    }

    /// Updates the daily badge, assigning only real changes so views don't redraw for nothing.
    func refreshDailyStatus(at now: Date) {
        let ready = game.isDailyRewardReady(today: StepDay.key(for: now))
        let count = game.claimableQuestCount + (ready ? 1 : 0)
        if ready != isDailyRewardReady { isDailyRewardReady = ready }
        if count != dailyBadgeCount { dailyBadgeCount = count }
    }

    /// Celebrates a completed daily challenge (and the week's bonus when it came with it).
    func announceChallenge() {
        let week = game.daily.challengesThisWeek
        let bonus = week == Tuning.weeklyChallengeGoal
            ? " · weekly bonus +\(CoinFormat.short(game.weeklyChallengeBonus))" : ""
        show(Toast(icon: "🎯", title: "Daily challenge complete!",
                   message: "+\(CoinFormat.short(game.challengeReward)) coins\(bonus)"))
    }

    // MARK: Announcements

    /// Celebrates the weekly variety goal and a new Arcade Rank, with what the rank unlocked.
    func announceArcade(_ award: ArcadeAward?, rankBefore: Int) {
        if let reward = award?.weeklyReward, reward > 0 {
            show(Toast(icon: "🎲", title: "Weekly variety goal!",
                       message: "\(Tuning.weeklyVarietyGames) different games this week · +\(CoinFormat.short(reward)) coins"))
        }
        let rank = game.arcadeRank
        guard rank > rankBefore else { return }
        let unlocked = game.cosmeticsUnlocked(sinceRank: rankBefore)
        show(Toast(icon: "🕹️", title: "Arcade Rank \(rank) · \(game.arcadeTitle)",
                   message: unlocked.isEmpty ? "Keep playing to rank up" : "New look: " + unlocked.map(\.name).joined(separator: ", ")))
    }

    func announceAchievements() {
        let before = (income: state.baseIdleIncome, tap: state.baseTapValue, step: state.stepValue)
        let tiers = state.refreshAchievements()
        guard !tiers.isEmpty else { return }
        publish()
        // The banner shows the numbers with the stars' boost in (the last one carries them, so
        // several at once don't repeat them).
        let gains = productionGains(since: before)
        for (index, earned) in tiers.enumerated() {
            let xp = AchievementCatalog.arcadeIDs.contains(earned.achievement.id)
                ? " · +\(Tuning.arcadeXPPerAchievementTier) Arcade XP" : ""
            show(Toast(icon: earned.achievement.emoji ?? "🏆",
                       title: "\(earned.achievement.name) · \(earned.tierName)",
                       message: "Achievement unlocked · +\(CoinFormat.percent(game.productionPerAchievementTier)) production\(xp)",
                       gains: index == tiers.count - 1 ? gains : []))
        }
    }

    /// Per second, per tap and per step as they are now, each with what it gained since `before`.
    private func productionGains(since before: (income: Double, tap: Double, step: Double)) -> [Toast.Gain] {
        func gain(_ title: String, was: Double, now: Double, format: (Double) -> String) -> Toast.Gain {
            let added = format(max(0, now - was))
            return Toast.Gain(title: title, added: now > was && added != "0" ? added : nil, total: format(now))
        }
        var gains = [
            gain("Per second", was: before.income, now: state.baseIdleIncome) { CoinFormat.rate($0) },
            gain("Per tap", was: before.tap, now: state.baseTapValue) { CoinFormat.short($0) },
        ]
        if state.steps.isConnected {
            gains.append(gain("Per step", was: before.step, now: state.stepValue) { CoinFormat.short($0) })
        }
        return gains
    }
}
