import Foundation

/// Something to buy in the Shop that adds production.
public enum Purchase: Hashable, Sendable {
    /// One more unit of a miner.
    case miner(MinerID)
    /// A miner's next Mk upgrade.
    case minerUpgrade(MinerID)
    case upgrade(UpgradeID)
}

/// A purchase worth making now, and what it adds to income.
public struct PurchaseSuggestion: Equatable, Sendable {
    public let purchase: Purchase
    public let name: String
    public let price: Double
    /// Coins per second it adds to idle income.
    public let incomeGain: Double

    /// Seconds the extra income takes to repay the price.
    public var payback: TimeInterval { incomeGain > 0 ? price / incomeGain : .infinity }
}

extension GameState {
    /// What `purchase` costs now, or `nil` while it isn't on sale (not revealed, owned, or not
    /// reached yet).
    public func price(of purchase: Purchase) -> Double? {
        switch purchase {
        case .miner(let miner):
            isRevealed(miner) ? price(of: miner, quantity: 1) : nil
        case .minerUpgrade(let miner):
            availableMinerUpgrade(miner)?.price
        case .upgrade(let upgrade):
            isRevealed(upgrade) && !upgrades.contains(upgrade) ? upgrade.cost : nil
        }
    }

    /// The name the Shop shows: "GPU Rig", "GPU Rig Mk III", "Overclocking".
    public func name(of purchase: Purchase) -> String {
        switch purchase {
        case .miner(let miner): miner.name
        case .minerUpgrade(let miner): miner.upgradeName(level: minerUpgradeLevel(miner))
        case .upgrade(let upgrade): upgrade.name
        }
    }

    @discardableResult
    public mutating func buy(_ purchase: Purchase) -> Bool {
        switch purchase {
        case .miner(let miner): buy(miner, quantity: 1)
        case .minerUpgrade(let miner): buyMinerUpgrade(miner)
        case .upgrade(let upgrade): buy(upgrade)
        }
    }

    /// Of everything affordable right now, the purchase whose extra idle income repays its price
    /// fastest. Each candidate is tried on a copy of the game, so milestones, Mk upgrades and
    /// multipliers all count. `nil` when nothing affordable adds income.
    public var bestPurchase: PurchaseSuggestion? {
        let candidates = MinerID.allCases.map(Purchase.miner) + MinerID.allCases.map(Purchase.minerUpgrade)
            + UpgradeID.allCases.map(Purchase.upgrade)
        let income = baseIdleIncome
        var best: PurchaseSuggestion?
        for purchase in candidates {
            guard let price = price(of: purchase), price <= coins else { continue }
            var after = self
            guard after.buy(purchase) else { continue }
            let gain = after.baseIdleIncome - income
            guard gain > 0, gain.isFinite else { continue }
            let suggestion = PurchaseSuggestion(purchase: purchase, name: name(of: purchase), price: price, incomeGain: gain)
            if best.map({ suggestion.payback < $0.payback }) ?? true { best = suggestion }
        }
        return best
    }
}
