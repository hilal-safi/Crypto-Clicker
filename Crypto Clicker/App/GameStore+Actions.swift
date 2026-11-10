import SwiftUI
import CryptoClickerKit

// The player's actions: tapping, buying, prestige and perks, tokens, airdrops and looks.
extension GameStore {
    // MARK: Actions

    /// Taps the coin. Taps in quick succession build a combo. Returns the coins this tap earned.
    @discardableResult
    func tap() -> Double {
        let now = Date.now
        comboStreak = now.timeIntervalSince(lastTapAt) <= state.comboWindow ? comboStreak + 1 : 1
        lastTapAt = now
        let streak = comboStreak
        return perform { game, now in game.tap(at: now, combo: streak) }
    }

    // Every Shop purchase shows the purchase popup (see `notePurchase`).

    @discardableResult
    func buy(_ miner: MinerID, quantity: Int) -> Bool {
        let before = purchaseBaseline
        let bought = perform { game, _ in game.buy(miner, quantity: quantity) }
        if bought { notePurchase(miner.name, count: quantity, before: before) }
        return bought
    }

    @discardableResult
    func buyMinerUpgrade(_ miner: MinerID) -> Bool {
        let before = purchaseBaseline
        let name = state.name(of: .minerUpgrade(miner))
        let bought = perform { game, _ in game.buyMinerUpgrade(miner) }
        if bought { notePurchase(name, before: before) }
        return bought
    }

    @discardableResult
    func buy(_ upgrade: UpgradeID) -> Bool {
        let before = purchaseBaseline
        let bought = perform { game, _ in game.buy(upgrade) }
        if bought { notePurchase(upgrade.name, effect: upgrade.addsCoins ? nil : upgrade.summary, before: before) }
        return bought
    }

    /// Buys a suggested purchase (from the welcome-back screen).
    @discardableResult
    func buy(_ purchase: Purchase) -> Bool {
        let before = purchaseBaseline
        let name = state.name(of: purchase)
        let bought = perform { game, _ in game.buy(purchase) }
        if bought { notePurchase(name, before: before) }
        return bought
    }

    /// Buys the next Offline Mining level. Saved at once, since it changes what time away pays.
    @discardableResult
    func buyOfflineMining() -> Bool {
        let before = purchaseBaseline
        let bought = perform { game, _ in game.buyOfflineMining() }
        if bought {
            notePurchase(String(localized: "Offline Mining"),
                         effect: String(localized: "Miners earn for up to \(CoinFormat.duration(state.offlineCap)) away"),
                         before: before)
            save()
            pushToWatch(force: true)
        }
        return bought
    }

    /// Buys a power-up's next level. Saved at once, like Offline Mining.
    @discardableResult
    func buyPowerUp(_ powerUp: PowerUpID) -> Bool {
        let before = purchaseBaseline
        let bought = perform { game, _ in game.buyPowerUp(powerUp) }
        if bought {
            notePurchase(powerUp.name, effect: powerUp.effect(atLevel: state.powerUpLevel(powerUp)), before: before)
            save()
        }
        return bought
    }

    @discardableResult
    func unlock(_ miniGame: MiniGame) -> Bool {
        perform { game, _ in game.unlock(miniGame) }
    }

    func setDifficulty(_ difficulty: Difficulty) {
        perform { game, _ in game.setDifficulty(difficulty) }
    }

    // MARK: Prestige

    @discardableResult
    func prestige() -> Int {
        let gained = perform { game, now in game.prestige(at: now) }
        guard gained > 0 else { return 0 }
        clearAirdrop()
        comboStreak = 0
        show(Toast(icon: "🌟", title: "Prestige complete",
                   message: "+\(CoinFormat.grouped(gained)) points · production +\(CoinFormat.percent(game.prestigeGain(gained)))"))
        save()
        pushToWatch(force: true)
        return gained
    }

    @discardableResult
    func buyPerk(_ perk: PerkID) -> Bool {
        let bought = perform { game, _ in game.buyPerk(perk) }
        if bought {
            show(Toast(icon: "🎖️", title: perk.name, message: perk.summary))
            save()
        }
        return bought
    }

    // MARK: Tokens

    @discardableResult
    func buyTokens(_ token: TokenID, quantity: Int) -> Bool {
        perform { game, now in game.buyTokens(token, quantity: quantity, at: now) }
    }

    /// Sells tokens at the market price. Returns the coins received.
    @discardableResult
    func sellTokens(_ token: TokenID, quantity: Int) -> Double? {
        let paid = perform { game, now in game.sellTokens(token, quantity: quantity, at: now) }
        if let paid {
            show(Toast(icon: "📈", title: "Sold \(CoinFormat.grouped(quantity)) \(token.ticker)",
                       message: "+\(CoinFormat.short(paid)) coins"))
        }
        return paid
    }

    // MARK: Airdrops

    /// Catches the airdrop on screen.
    func claimAirdrop() {
        guard let caught = airdrops.catchDrop(at: .now, game: state, roll: .random(in: 0...1)) else { return }
        airdrop = nil
        let reward = perform { game, now in game.claimAirdrop(caught.kind, at: now) }
        switch reward {
        case .coins(let amount):
            show(Toast(icon: "🪂", title: "Airdrop caught!", message: "+\(CoinFormat.short(amount)) coins"))
        case .bullRun(let multiplier, let duration):
            show(Toast(icon: "🐂", title: "Bull Run!",
                       message: "Production \(CoinFormat.multiplier(multiplier)) for \(CoinFormat.duration(duration))"))
        case .whale(let amount):
            show(Toast(icon: "🐋", title: "Whale airdrop!", message: "+\(CoinFormat.short(amount)) coins: an hour of mining"))
        }
    }

    func scheduleAirdrop(from now: Date) {
        airdrops.schedule(from: now, game: state, roll: .random(in: 0...1))
    }

    /// Moves the airdrops' clock: one falls, or the one on screen runs out (a miss, unless a game
    /// held it back).
    func updateAirdrop(at now: Date) {
        let event = airdrops.update(at: now, game: state, isInGame: isInGame,
                                    kindRoll: .random(in: 0..<1), delayRoll: .random(in: 0...1))
        switch event {
        case .appeared(let drop):
            airdrop = drop
        case .expired(let drop, let missed):
            airdrop = nil
            if missed { perform { game, now in game.missAirdrop(drop.kind, at: now) } }
        case nil:
            break
        }
    }

    /// Takes the airdrop off screen without a miss (the app going away, a prestige, a reset).
    func clearAirdrop() {
        airdrops.clear()
        airdrop = nil
    }

    func spawnAirdrop(_ kind: AirdropKind, at now: Date) {
        airdrop = airdrops.spawn(kind, at: now, game: state)
    }

    // MARK: Looks

    /// Picks a look for a game.
    func equip(_ cosmetic: Cosmetic) {
        perform { game, _ in game.equip(cosmetic) }
        save()
    }
}
