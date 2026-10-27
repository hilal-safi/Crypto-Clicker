import SwiftUI
import CryptoClickerKit

/// Daily rewards and quests, and the achievements that add production.
struct TrophiesView: View {
    /// Goes up by one each time another tab asks to show the Daily page.
    var dailyRequests = 0
    /// Opens today's challenge in the Arcade.
    let openChallenge: () -> Void
    @Environment(GameStore.self) private var store
    @State private var page = Page.daily
    @State private var handledDailyRequests = 0

    enum Page: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case achievements = "Achievements"

        var id: Self { self }
    }

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        let game = store.game
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Picker("Page", selection: $page) {
                        ForEach(Page.allCases) { page in
                            Text(page == .daily && store.dailyBadgeCount > 0
                                 ? "\(page.rawValue) (\(store.dailyBadgeCount))" : page.rawValue)
                                .tag(page)
                        }
                    }
                    .pickerStyle(.segmented)
                    switch page {
                    case .daily:
                        DailyPage(openChallenge: openChallenge)
                    case .achievements:
                        TrophySummary(earned: game.earnedAchievementTiers, total: AchievementCatalog.tierCount,
                                      bonus: game.achievementBonus - 1)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(AchievementCatalog.all) { achievement in
                                AchievementCard(achievement: achievement,
                                                tiers: game.tiersEarned(achievement),
                                                value: game.value(of: achievement.metric),
                                                next: game.nextThreshold(achievement))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background { AppBackground(tint: Theme.trophies) }
            .navigationTitle("Trophies")
            .balanceToolbar()
        }
        .onAppear(perform: showDailyIfAsked)
        .onChange(of: dailyRequests) { _, _ in showDailyIfAsked() }
    }

    private func showDailyIfAsked() {
        guard handledDailyRequests != dailyRequests else { return }
        handledDailyRequests = dailyRequests
        page = .daily
    }
}

// MARK: - Daily

/// The daily reward and its streak, the day's quests and the daily challenge.
private struct DailyPage: View {
    let openChallenge: () -> Void
    @Environment(GameStore.self) private var store

    var body: some View {
        let game = store.game
        let today = store.today
        let yesterday = store.yesterday
        let midnight = StepDay.calendar().startOfDay(for: .now).addingTimeInterval(86_400)
        let isFirstDay = game.isFirstDay(today)
        DailyRewardCard(streak: game.currentStreak(today: today, yesterday: yesterday),
                        nextStreak: game.streakIfClaimed(today: today, yesterday: yesterday),
                        isReady: game.isDailyRewardReady(today: today), isFirstDay: isFirstDay, resetsAt: midnight)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("Today's Quests", systemImage: "scroll.fill")
                    .font(.headline)
                Spacer()
                Text("New in \(Text(midnight, style: .relative))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.subtext)
            }
            if game.daily.quests.isEmpty {
                Text(isFirstDay ? "Your first quests and daily challenge arrive tomorrow." : "New quests are on their way.")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            ForEach(game.daily.quests) { quest in
                QuestRow(quest: quest, progress: game.progress(of: quest), reward: quest.reward.text(in: game))
                if quest.id != game.daily.quests.last?.id { Divider() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowCard()
        if let challenge = game.dailyChallenge(today: today) {
            let canPlay = !challenge.isComplete && challenge.kind.game.map(game.isUnlocked) == true
            ChallengeCard(challenge: challenge, weekCount: game.challengesCompleted(inWeekOf: today),
                          reward: game.challengeReward, weeklyBonus: game.weeklyChallengeBonus,
                          play: canPlay ? openChallenge : nil)
        }
        Text(game.hasPerk(.luckyStreak)
             ? "Lucky Streak doubles every daily reward. Coin rewards grow with your income."
             : "Coin rewards grow with your income. Quests finished but not claimed are paid at midnight.")
            .font(.footnote)
            .foregroundStyle(.subtext)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

extension QuestReward {
    /// What the reward pays if claimed now: coins track income, and Lucky Streak doubles it.
    func text(in game: GameState) -> String {
        let multiplier = game.dailyRewardMultiplier
        return switch self {
        case .coins(let seconds): "\(CoinFormat.short((seconds * game.rewardIncome * multiplier).rounded())) coins"
        case .tokens(let token, let count): "\(CoinFormat.grouped(Int(Double(count) * multiplier))) \(token.ticker)"
        case .bullRun: "Bull Run \(CoinFormat.multiplier(Tuning.bullRunMultiplier)) for \(CoinFormat.duration(game.bullRunDuration * multiplier))"
        }
    }

    var symbol: String {
        switch self {
        case .coins: "bitcoinsign.circle.fill"
        case .tokens: "circle.hexagongrid.fill"
        case .bullRun: "flame.fill"
        }
    }
}

/// The login streak: a week of rewards building to day 7, and today's to claim.
private struct DailyRewardCard: View {
    let streak: Int
    /// The streak that claiming today makes (or made).
    let nextStreak: Int
    let isReady: Bool
    /// The game's first day: rewards start tomorrow.
    var isFirstDay = false
    let resetsAt: Date
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var claims = 0

    var body: some View {
        let game = store.game
        let cycleDay = GameState.streakCycleDay(nextStreak)
        let reward = game.streakReward(day: nextStreak)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("Daily Reward", systemImage: "gift.fill")
                    .font(.title3.bold())
                Spacer()
                if streak > 0 {
                    Text("🔥 \(streak)-day streak")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.subtext)
                }
            }
            HStack(spacing: 6) {
                ForEach(1...Tuning.streakCycle, id: \.self) { day in
                    StreakDayChip(day: day, reward: game.streakReward(day: day),
                                  isClaimed: !isFirstDay && (day < cycleDay || (day == cycleDay && !isReady)),
                                  isToday: day == cycleDay)
                }
            }
            if isReady {
                Button {
                    store.claimDailyReward()
                    claims += 1
                } label: {
                    VStack(spacing: 2) {
                        Text("Claim Day \(nextStreak)")
                            .font(.headline)
                        Text(reward.text(in: game))
                            .font(.subheadline.monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            } else {
                Label("\(isFirstDay ? "First" : "Next") reward in \(Text(resetsAt, style: .relative))", systemImage: "clock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.subtext)
            }
            if !isReady || streak == 0 {
                Text(isFirstDay
                     ? "Daily rewards, quests and challenges start on your second day. Claim a reward every day to keep your streak: day 7 pays an hour of income."
                     : "Claim a reward every day to keep your streak. Day 7 pays an hour of income, then the week starts over.")
                    .font(.caption)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .glassCard(tint: Theme.trophies)
        .sensoryFeedback(.success, trigger: claims) { _, _ in haptics }
    }
}

private struct StreakDayChip: View {
    let day: Int
    let reward: QuestReward
    let isClaimed: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isClaimed ? "checkmark.circle.fill" : (day == Tuning.streakCycle ? "star.circle.fill" : reward.symbol))
                .font(.title3)
                .foregroundStyle(isClaimed ? Color.green : (isToday ? Theme.accent : Theme.subtext))
            Text("Day \(day)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? Color.primary : Theme.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isToday ? Theme.accent.opacity(0.16) : Color.secondary.opacity(0.08))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day \(day)\(isClaimed ? ", claimed" : "")\(isToday ? ", today" : "")")
    }
}

private struct QuestRow: View {
    let quest: Quest
    let progress: Double
    let reward: String
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var claims = 0

    var body: some View {
        let isComplete = progress >= quest.target
        HStack(spacing: 12) {
            Image(systemName: quest.kind.symbol)
                .font(.headline)
                .foregroundStyle(isComplete ? .white : Theme.accent)
                .frame(width: 38, height: 38)
                .background(isComplete ? Theme.accent : Theme.accent.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: min(progress, quest.target), total: max(quest.target, 1))
                    .tint(Theme.accent)
                HStack {
                    Text("\(CoinFormat.short(progress)) / \(CoinFormat.short(quest.target))")
                        .monospacedDigit()
                    Spacer()
                    Label(reward, systemImage: quest.reward.symbol)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.subtext)
            }
            if quest.isClaimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Claimed")
            } else if isComplete {
                Button("Claim") {
                    store.claimQuest(quest)
                    claims += 1
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .font(.subheadline.weight(.bold))
            }
        }
        .opacity(quest.isClaimed ? 0.7 : 1)
        .sensoryFeedback(.success, trigger: claims) { _, _ in haptics }
    }
}

// MARK: - Achievements

private struct TrophySummary: View {
    let earned: Int
    let total: Int
    let bonus: Double

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.trophies)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(earned) of \(total) stars")
                    .font(.title3.bold())
                Text("+\(CoinFormat.percent(bonus)) production from achievements")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                ProgressView(value: Double(earned), total: Double(max(1, total)))
                    .tint(Theme.trophies)
                if let next = CoinFinish.allCases.first(where: { !$0.isUnlocked(stars: earned) }) {
                    Text("\(next.starsNeeded - earned) more for the \(next.name) coin")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.subtext)
                }
            }
        }
        .glassCard(tint: Theme.trophies)
        .accessibilityElement(children: .combine)
    }
}

/// One achievement: its stars, and progress toward the next tier. Unearned cards keep the plain
/// look; earned ones take on the metal of their highest tier, bronze, silver or gold, with a shine
/// sweeping across them. Mythic cards are iridescent.
private struct AchievementCard: View {
    let achievement: Achievement
    let tiers: Int
    let value: Double
    let next: Double?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let emoji = achievement.emoji {
                    Text(emoji)
                        .font(.system(size: 28))
                } else if let imageName = achievement.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
                Spacer()
                TierStars(earned: tiers)
            }
            Text(achievement.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(achievement.detail)
                .font(.caption)
                .foregroundStyle(.subtext)
                .lineLimit(2, reservesSpace: true)
            if let next {
                ProgressView(value: min(value, next), total: next)
                    .tint(Theme.tierColor(tiers))
                Text("\(CoinFormat.short(value)) / \(CoinFormat.short(next))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.subtext)
            } else {
                Label("Mythic", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.tierColor(3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background { background }
        .opacity(tiers == 0 ? 0.75 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(tiers == 0 ? "Not earned yet" : AchievementCatalog.tierNames[min(tiers, 4) - 1])
    }

    @ViewBuilder private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if tiers == 0 {
            CardSurface(cornerRadius: 20)
        } else {
            let tier = tiers - 1
            let isDark = colorScheme == .dark
            ZStack {
                CardSurface(cornerRadius: 20)
                Group {
                    if tier >= 3 {
                        MythicGradient()
                            .opacity(isDark ? 0.32 : 0.26)
                    } else {
                        LinearGradient(colors: TierStyle.metal(tier), startPoint: .topLeading, endPoint: .bottomTrailing)
                            .opacity(isDark ? 0.34 : 0.30)
                    }
                    MetalShine(period: TierStyle.shinePeriod(tier), delay: Self.delay(for: achievement.id),
                               intensity: TierStyle.shineIntensity(tier))
                }
                .clipShape(shape)
                Group {
                    if tier >= 3 {
                        MythicGradient()
                    } else {
                        LinearGradient(colors: TierStyle.metal(tier), startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .mask(shape.strokeBorder(lineWidth: tier >= 3 ? 3 : 2))
            }
            .shadow(color: (tier >= 3 ? Theme.tierColor(3) : TierStyle.metal(tier)[1]).opacity(isDark ? 0.45 : 0.35),
                    radius: tier >= 2 ? 10 : 6)
        }
    }

    /// A steady offset per achievement, so cards side by side shine at different moments.
    private static func delay(for id: String) -> Double {
        Double(id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 997 } % 40) / 10
    }
}
