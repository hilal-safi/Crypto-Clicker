import Foundation

/// Prestige: start over for permanent prestige points, then spend them on perks.
///
/// Lifetime coins build up prestige potential (the cube root of lifetime coins over
/// `Tuning.prestigeScale`). Prestiging turns new potential into points, times the run's
/// difficulty multiplier. Every point ever earned adds production; spending points on perks
/// never takes that bonus away.
extension GameState {
    // MARK: Points

    /// Prestige potential for `lifetimeCoins`: the largest whole p with p³ ≤ lifetime / scale.
    public static func prestigePotential(lifetimeCoins: Double) -> Int {
        let scaled = max(0, lifetimeCoins) / Tuning.prestigeScale
        let root = cbrt(scaled)
        guard root.isFinite else { return 0 }
        guard root < Double(Tuning.maxPrestigePoints) else { return Tuning.maxPrestigePoints }
        var points = Int(root.rounded(.down))
        // `cbrt` can land a hair either side of an exact cube: settle on the largest p with p³ <= scaled.
        while points > 0 && pow(Double(points), 3) > scaled { points -= 1 }
        while points < Tuning.maxPrestigePoints && pow(Double(points + 1), 3) <= scaled { points += 1 }
        return points
    }

    /// Prestige potential from every coin mined so far.
    public var prestigePotential: Int { Self.prestigePotential(lifetimeCoins: stats.lifetimeCoins) }

    /// Points a prestige would award right now.
    public var claimablePrestigePoints: Int {
        let potential = max(0, prestigePotential - prestigePotentialClaimed)
        let points = (Double(potential) * runPrestigeMultiplier).rounded(.down)
        return points.isFinite ? Int(min(max(0, points), Double(Tuning.maxPrestigePoints))) : 0
    }

    /// `points` plus `gained`, stopping at `Tuning.maxPrestigePoints` (no overflow on a 32-bit watch).
    static func addingPoints(_ points: Int, _ gained: Int) -> Int {
        points >= Tuning.maxPrestigePoints - gained ? Tuning.maxPrestigePoints : points + gained
    }

    /// Lifetime coins at which the next point of potential is earned.
    public var nextPrestigePointAt: Double {
        pow(Double(prestigePotential + 1), 3) * Tuning.prestigeScale
    }

    /// Production bonus that `points` prestige points add, as a share (0.5 = +50%).
    public func prestigeGain(_ points: Int) -> Double { Double(points) * Tuning.productionPerPrestigePoint }

    /// Points that can still be spent on perks.
    public var availablePrestigePoints: Int { max(0, prestigePoints - prestigePointsSpent) }

    /// How many times faster production would run after prestiging now, from the bonus alone.
    public var prestigeSpeedUp: Double {
        (1 + prestigeGain(prestigePoints + claimablePrestigePoints)) / prestigeBonus
    }

    /// Prestige is worth it once the new points would speed production up by at least half.
    public var isPrestigeRecommended: Bool {
        claimablePrestigePoints > 0 && prestigeSpeedUp >= Tuning.prestigeRecommendedSpeedUp
    }

    // MARK: Prestiging

    /// Starts a new run for prestige points. Coins, tokens, miners, Mk upgrades, upgrades and boosts
    /// reset, except what perks keep. (Tokens go too, or selling them would carry coins across.)
    /// Power-ups, perks, unlocked games, achievements, daily progress and lifetime statistics carry
    /// over. Returns the points gained (0 if none are ready).
    @discardableResult
    public mutating func prestige(at now: Date) -> Int {
        let gained = claimablePrestigePoints
        guard gained > 0 else { return 0 }
        prestigePoints = Self.addingPoints(prestigePoints, gained)
        prestigePotentialClaimed = prestigePotential
        stats.prestiges += 1
        stats.runCoins = 0
        coins = 0
        tokens = [:]
        blackjackStake = nil
        pokerRound = nil // A hand left waiting goes with the tokens it was bet with.
        miners = [:]
        if !hasPerk(.engineeringTeam) { minerUpgrades = [:] }
        let keepsProduction = hasPerk(.blueprints)
        let keepsTapping = hasPerk(.muscleMemory)
        upgrades = upgrades.filter { upgrade in
            switch upgrade.category {
            case .production: keepsProduction
            case .tapping: keepsTapping
            case .steps, .miniGames: false
            }
        }
        boost = nil
        runPrestigeMultiplier = difficulty.prestigeMultiplier
        runStart = now
        lastUpdate = now
        if hasPerk(.headStart) {
            for (miner, count) in Tuning.headStartMiners { give(miner, count: count) }
        }
        return gained
    }

    /// Adds miners without charging for them (Head Start).
    mutating func give(_ miner: MinerID, count: Int) {
        guard count > 0 else { return }
        let total = owned(miner) + count
        miners[miner] = total
        stats.maxOwned[miner] = max(stats.maxOwned[miner, default: 0], total)
        stats.maxTotalMiners = max(stats.maxTotalMiners, totalMiners)
    }

    // MARK: Perks

    /// The perk's prerequisite is owned (or it has none).
    public func isPerkAvailable(_ perk: PerkID) -> Bool {
        perk.requires.map(hasPerk) ?? true
    }

    public func canBuy(_ perk: PerkID) -> Bool {
        !hasPerk(perk) && isPerkAvailable(perk) && availablePrestigePoints >= perk.cost
    }

    /// Buys a perk with prestige points. It lasts forever.
    @discardableResult
    public mutating func buyPerk(_ perk: PerkID) -> Bool {
        guard canBuy(perk) else { return false }
        prestigePointsSpent += perk.cost
        perks.insert(perk)
        return true
    }
}
