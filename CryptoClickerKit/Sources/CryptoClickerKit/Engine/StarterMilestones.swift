import Foundation

/// The opening's short goals: reached by playing, claimed once on the Goals page.
extension GameState {
    /// Whether `milestone` has been reached. Lifetime records keep a milestone reached after a
    /// prestige has reset the miners and upgrades, so it can still be claimed.
    public func isReached(_ milestone: StarterMilestone) -> Bool {
        switch milestone {
        case .firstChromebook:
            owned(.chromebook) > 0 || journey.miners[.chromebook] != nil || stats.maxOwned[.chromebook, default: 0] > 0
        case .threeMiners:
            totalMiners >= 3 || stats.maxTotalMiners >= 3 || stats.minersBought >= 3
        case .firstUpgrade:
            !upgrades.isEmpty || stats.maxUpgrades > 0
        case .firstGameUnlocked:
            !unlockedGames.isEmpty
        case .firstGamePlayed:
            MiniGame.allCases.contains { timesPlayed($0) > 0 }
        }
    }

    public func isClaimed(_ milestone: StarterMilestone) -> Bool { starterMilestonesClaimed.contains(milestone) }

    /// How far along `milestone` is, from 0 to 1.
    public func progress(of milestone: StarterMilestone) -> Double {
        if isReached(milestone) { return 1 }
        switch milestone {
        case .firstChromebook:
            let chromebookPrice = price(of: .chromebook, quantity: 1)
            return chromebookPrice > 0 ? min(1, coins / chromebookPrice) : 0
        case .threeMiners:
            return Double(min(3, max(totalMiners, 0))) / 3
        case .firstUpgrade, .firstGameUnlocked, .firstGamePlayed:
            return 0
        }
    }

    /// What claiming `milestone` pays now: coins worth its seconds of the reward income (the same
    /// one the daily rewards use, with its floor on day one), or its Bull Run.
    public func payout(of milestone: StarterMilestone) -> StarterPayout {
        switch milestone.reward {
        case .coins(let seconds): .coins(Self.wholeCoins(seconds * rewardIncome, minimum: 1))
        case .bullRun(let seconds): .bullRun(seconds: seconds)
        }
    }

    /// The milestones reached and not yet claimed.
    public var claimableStarterMilestones: [StarterMilestone] {
        StarterMilestone.allCases.filter { isReached($0) && !isClaimed($0) }
    }

    /// Whether any milestone is still unclaimed (the Goals page hides the section once all are).
    public var hasUnclaimedStarterMilestones: Bool {
        StarterMilestone.allCases.contains { !isClaimed($0) }
    }

    /// Pays a reached milestone once. Returns what it paid, or `nil` when it isn't reached yet or
    /// was claimed already.
    @discardableResult
    public mutating func claim(_ milestone: StarterMilestone, at now: Date) -> StarterPayout? {
        guard isReached(milestone), !isClaimed(milestone) else { return nil }
        let paid = payout(of: milestone)
        starterMilestonesClaimed.insert(milestone)
        switch paid {
        case .coins(let amount): credit(amount, source: .daily)
        case .bullRun(let seconds): startBullRun(duration: seconds, at: now)
        }
        return paid
    }
}
