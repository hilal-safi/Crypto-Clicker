import Foundation
import CryptoClickerKit

// The Arcade tab: its hub ("arcade"), every game's records card ("gameCards", also used by
// Statistics), the games' How to Play ("guides") and the Style sheet's looks ("style"), as the iOS
// ArcadeView, ArcadeRankCard, StatsCards, GameHelp and StyleView work them out.

/// The Arcade's list (iOS: ArcadeView).
struct ArcadeView: Encodable {
    /// Arcade Rank, once a game is unlocked.
    let rank: RankView?
    let challenge: ChallengeView?
    /// Opens today's challenge's game, when it's unlocked and not done.
    let challengeGame: String?
    let casino: [MiniGameRowView]
    let arcade: [MiniGameRowView]
}

/// Arcade Rank at the top of the Arcade (iOS: ArcadeRankCard).
struct RankView: Encodable {
    let rank: Int
    let title: String
    /// "120 of 400 XP to rank 6"
    let progress: String
    let fraction: Double
    /// "This week: 3 of 5 games · +12K", or "Weekly variety goal met"
    let weekly: String
    let weeklyPaid: Bool
    /// The icons of the games played this week.
    let playedIcons: String
}

/// One mini-game: what it is, its record, and Play (with Stats) or Unlock (iOS: MiniGameRow).
struct MiniGameRowView: Encodable {
    let id: String
    let icon: String
    let name: String
    let pitch: String
    /// The game's colour ("#RRGGBB"), deep enough for white text, and lighter for text on dark cards.
    let color: String
    let textColorDark: String
    let isUnlocked: Bool
    let canAfford: Bool
    let unlockPrice: String
    let records: [RecordFactView]
}

struct RecordFactView: Encodable {
    let label: String
    let value: String
}

/// One game's records (iOS: GameStatsCard): a casino game's biggest win or an arcade game's best
/// score up top, the rest of its records as tiles.
struct GameCardView: Encodable {
    let id: String
    let icon: String
    let name: String
    let color: String
    let textColorDark: String
    /// "42 games", "1,204 hands"
    let plays: String
    let timesPlayed: Int
    let headlineTitle: String
    let headlineValue: String
    let items: [StatTileView]
    /// "1.2M bet · 1.1M paid out"
    let note: String?
}

struct StatTileView: Encodable {
    let title: String
    let value: String
}

/// A game's full rules (iOS: GameRulesPage, from `MiniGame.guide` in the kit).
struct GuideView: Encodable {
    let id: String
    let icon: String
    let name: String
    let color: String
    let objective: String
    let controls: [String]
    let scoring: [String]
    let items: [GuideItemView]
    let ending: String
    let tips: [String]
    let controlHint: String
}

struct GuideItemView: Encodable {
    let id: String
    let symbol: String
    let name: String
    let detail: String
}

/// Looks for the games (iOS: StyleView): two kinds for every game, each kind headed by its games'
/// icons; locked looks say what unlocks them.
struct StyleView: Encodable {
    let slots: [CosmeticSlotView]
}

struct CosmeticSlotView: Encodable {
    let id: String
    let name: String
    let icons: String
    let cosmetics: [CosmeticView]
}

struct CosmeticView: Encodable {
    let id: String
    let name: String
    let isUnlocked: Bool
    let isEquipped: Bool
    /// "Reach Arcade Rank 12", while locked.
    let rankLine: String?
    /// "Or earn the Card Shark achievement (Silver)", when an achievement can unlock it sooner.
    let achievementLine: String?
}

// MARK: - Building

extension GameSession {
    var arcadeView: ArcadeView {
        let game = state
        let challenge = game.dailyChallenge(today: today)
        let challengeGame = challenge.flatMap { challenge -> String? in
            guard let miniGame = challenge.kind.game, game.isUnlocked(miniGame), !challenge.isComplete else { return nil }
            return miniGame.rawValue
        }
        return ArcadeView(
            rank: game.unlockedGames.isEmpty ? nil : rankView,
            challenge: challengeView, challengeGame: challengeGame,
            casino: MiniGame.byPrice.filter(\.isCasino).map(miniGameRow),
            arcade: MiniGame.byPrice.filter { !$0.isCasino }.map(miniGameRow))
    }

    var rankView: RankView {
        let game = state
        let rank = game.arcadeRank
        let progress = game.arcadeRankProgress
        let played = game.gamesPlayed(inWeekOf: today)
        let isPaid = game.isWeeklyGoalPaid(inWeekOf: today)
        return RankView(
            rank: rank, title: game.arcadeTitle,
            progress: "\(CoinFormat.grouped(progress.xp)) of \(CoinFormat.grouped(progress.needed)) XP to rank \(rank + 1)",
            fraction: clamped(Double(progress.xp) / Double(max(1, progress.needed))),
            weekly: isPaid ? "Weekly variety goal met"
                : "This week: \(min(played.count, Tuning.weeklyVarietyGames)) of \(Tuning.weeklyVarietyGames) games · +\(CoinFormat.short(game.weeklyVarietyReward))",
            weeklyPaid: isPaid,
            playedIcons: MiniGame.allCases.filter(played.contains).map(\.info.icon).joined())
    }

    func miniGameRow(_ miniGame: MiniGame) -> MiniGameRowView {
        let game = state
        return MiniGameRowView(
            id: miniGame.rawValue, icon: miniGame.info.icon, name: miniGame.name, pitch: miniGame.info.pitch,
            color: hex(miniGame.info.color), textColorDark: hex(miniGame.info.color, mixedWithWhite: 0.45),
            isUnlocked: game.isUnlocked(miniGame), canAfford: miniGame.unlockCost <= game.coins,
            unlockPrice: CoinFormat.cost(miniGame.unlockCost),
            records: game.record(for: miniGame).map { RecordFactView(label: $0.label, value: $0.value) })
    }

    var gameCardsView: [GameCardView] { MiniGame.allCases.map(gameCard) }

    /// A game's records card (iOS: GameStatsCard.make), with amounts in the form the player picked.
    func gameCard(_ miniGame: MiniGame) -> GameCardView {
        let game = state
        let s = game.stats
        let plays = game.timesPlayed(miniGame)
        func item(_ title: String, _ value: String) -> StatTileView { StatTileView(title: title, value: value) }
        func counted(_ count: Int, _ noun: String) -> String { "\(CoinFormat.grouped(count)) \(noun)\(count == 1 ? "" : "s")" }
        func share(_ value: Double) -> String {
            guard value.isFinite, value > 0 else { return "0%" }
            if value < 0.01 { return "<1%" }
            return "\(Int((min(value, 1e6) * 100).rounded()))%"
        }
        func percentage(_ part: Int, of whole: Int) -> String { whole > 0 ? share(Double(part) / Double(whole)) : "–" }
        func paidBack(_ paid: Double, of bet: Double) -> String { bet > 0 ? share(paid / bet) : "–" }
        func betNote(_ bet: Double, paid: Double) -> String? { bet > 0 ? "\(amount(bet)) bet · \(amount(paid)) paid out" : nil }
        func card(_ noun: String, _ headline: StatTileView, _ items: [StatTileView], note: String? = nil) -> GameCardView {
            GameCardView(id: miniGame.rawValue, icon: miniGame.info.icon, name: miniGame.name,
                         color: hex(miniGame.info.color), textColorDark: hex(miniGame.info.color, mixedWithWhite: 0.45),
                         plays: counted(plays, noun), timesPlayed: plays,
                         headlineTitle: headline.title, headlineValue: headline.value, items: items, note: note)
        }
        let best = item("Best", CoinFormat.grouped(game.bestScore(miniGame)))
        switch miniGame {
        case .blackjack:
            return card("hand", item("Biggest win", amount(s.blackjackBiggestWin)), [
                item("Wins", CoinFormat.grouped(s.blackjackWins)),
                item("Win rate", percentage(s.blackjackWins, of: s.blackjackHands)),
                item("Naturals", CoinFormat.grouped(s.blackjackNaturals)),
                item("Streak now", CoinFormat.grouped(s.blackjackStreak)),
                item("Best streak", CoinFormat.grouped(s.blackjackBestStreak)),
            ])
        case .slots:
            return card("spin", item("Biggest win", amount(s.slotsBiggestWin)), [
                item("Wins", CoinFormat.grouped(s.slotsWins)),
                item("Win rate", percentage(s.slotsWins, of: s.slotsSpins)),
                item("Jackpots", CoinFormat.grouped(s.slotsJackpots)),
                item("Best spin", s.slotsBestMultiple >= 2 ? "×\(CoinFormat.grouped(s.slotsBestMultiple))" : "–"),
                item("Free rounds", CoinFormat.grouped(s.slotsFreeSpinRounds)),
                item("Free spins", CoinFormat.grouped(s.slotsFreeSpinsPlayed)),
                item("Bitcoins", CoinFormat.grouped(s.slotsBitcoins)),
                item("Bitcoin prizes", CoinFormat.grouped(s.slotsBitcoins / SlotMachine.bitcoinsPerPrize)),
                item("Paid back", paidBack(s.slotsPaidOut, of: s.slotsWagered)),
            ], note: betNote(s.slotsWagered, paid: s.slotsPaidOut))
        case .moon:
            return card("flight", item("Biggest win", amount(s.moonBiggestWin)), [
                item("Cash-outs", CoinFormat.grouped(s.moonCashOuts)),
                item("Cashed out", percentage(s.moonCashOuts, of: s.moonFlights)),
                item("Best cash-out", s.moonCashOuts > 0 ? CoinFormat.flight(s.moonBestMultiplier) : "–"),
                item("Paid back", paidBack(s.moonPaidOut, of: s.moonWagered)),
            ], note: betNote(s.moonWagered, paid: s.moonPaidOut))
        case .videoPoker:
            return card("hand", item("Biggest win", amount(s.pokerBiggestWin)), [
                item("Wins", CoinFormat.grouped(s.pokerWins)),
                item("Win rate", percentage(s.pokerWins, of: s.pokerHands)),
                item("Best hand", s.pokerHands > 0 ? (PokerHand(rawValue: s.pokerBestHand) ?? .nothing).name : "–"),
                item("Royal flushes", CoinFormat.grouped(s.pokerRoyals)),
                item("Paid back", paidBack(s.pokerPaidOut, of: s.pokerWagered)),
            ], note: betNote(s.pokerWagered, paid: s.pokerPaidOut))
        case .tetris:
            var items = [item("Best level", CoinFormat.grouped(s.tetrisBestLevel)),
                         item("Best combo", CoinFormat.grouped(s.tetrisBestCombo)),
                         item("Full Blocks", CoinFormat.grouped(s.tetrisTetrises)),
                         item("Rows", CoinFormat.grouped(s.tetrisLines))]
            if s.tetrisBestSprint > 0 { items.append(item("Best Rush", CoinFormat.stopwatch(s.tetrisBestSprint))) }
            return card("game", best, items)
        case .merge2048:
            return card("game", best, [
                item("Top miner", Merge2048Game.miner(for: s.merge2048BestTile).name),
                item("Daily wins", CoinFormat.grouped(game.merge2048Daily.wins)),
                item("Daily stars", CoinFormat.grouped(game.merge2048Daily.totalStars)),
            ])
        case .snake:
            return card("game", best, [
                item("Coin Rush", CoinFormat.grouped(s.snakeRushBestScore)),
                item("Longest chain", CoinFormat.grouped(s.snakeLongest)),
                item("Most coins", CoinFormat.grouped(s.snakeBestCoins)),
                item("Longest game", CoinFormat.stopwatch(s.snakeLongestTime)),
                item("Power-ups", CoinFormat.grouped(s.snakePowerUps)),
            ])
        case .brickBreaker:
            return card("game", best, [
                item("Best level", CoinFormat.grouped(s.brickBreakerBestLevel)),
                item("Levels cleared", CoinFormat.grouped(s.brickBreakerLevelsCleared)),
                item("Best streak", CoinFormat.grouped(s.brickBreakerBestStreak)),
                item("Whales", CoinFormat.grouped(s.brickBreakerBosses)),
                item("Power-ups", CoinFormat.grouped(s.brickBreakerPowerUps)),
                item("Blocks", CoinFormat.grouped(s.bricksBroken)),
            ])
        case .bubbleBlaster:
            return card("game", best, [
                item("Best wave", CoinFormat.grouped(s.bubbleBestWave)),
                item("Flash Market", CoinFormat.grouped(s.bubbleFlashBestScore)),
                item("Best shot", CoinFormat.grouped(s.bubbleBestShot)),
                item("Best streak", CoinFormat.grouped(s.bubbleBestStreak)),
                item("Popped", CoinFormat.grouped(s.bubblesPopped)),
                item("Blue chips", CoinFormat.grouped(s.bubbleBonuses)),
            ])
        case .pumpDump:
            return card("run", best, [
                item("Best round", CoinFormat.grouped(s.pumpDumpBestRound)),
                item("Best combo", CoinFormat.grouped(s.pumpDumpBestCombo)),
                item("Coins hit", CoinFormat.grouped(s.pumpDumpCoinsHit)),
                item("Scams hit", CoinFormat.grouped(s.pumpDumpScamsHit)),
            ])
        case .invaders:
            return card("game", best, [
                item("Best wave", CoinFormat.grouped(s.invadersBestWave)),
                item("Invaders shot", CoinFormat.grouped(s.invadersDestroyed)),
                item("Best streak", CoinFormat.grouped(s.invadersBestStreak)),
                item("Accuracy", percentage(s.invadersVolleysHit, of: s.invadersVolleys)),
                item("Whales", CoinFormat.grouped(s.invadersWhales)),
                item("Bosses", CoinFormat.grouped(s.invadersBosses)),
            ])
        case .tokenSwap:
            let swap = game.tokenSwap
            return card("game", item("Classic best", CoinFormat.grouped(s.tokenSwapBestScore)), [
                item("Levels won", "\(CoinFormat.grouped(swap.levelsWon)) of \(CoinFormat.grouped(TokenSwapLevel.all.count))"),
                item("Stars", CoinFormat.grouped(swap.totalStars)),
                item("Daily wins", CoinFormat.grouped(swap.dailyWins)),
                item("Best chain", CoinFormat.grouped(s.tokenSwapBestChain)),
                item("Specials", CoinFormat.grouped(s.tokenSwapBlasts)),
                item("Tokens cleared", CoinFormat.grouped(s.tokenSwapTokens)),
                item("Random wins", "\(CoinFormat.grouped(s.tokenSwapRandomWins)) of \(CoinFormat.grouped(s.tokenSwapRandomPlayed))"),
                item("Classic games", CoinFormat.grouped(s.tokenSwapGames)),
                item("Levels played", CoinFormat.grouped(s.tokenSwapLevelsPlayed)),
            ])
        }
    }

    var guidesView: [GuideView] {
        MiniGame.allCases.map { miniGame in
            let guide = miniGame.guide
            return GuideView(
                id: miniGame.rawValue, icon: miniGame.info.icon, name: miniGame.name, color: hex(miniGame.info.color),
                objective: guide.objective, controls: guide.controls, scoring: guide.scoring,
                items: guide.items.map { GuideItemView(id: $0.id, symbol: $0.symbol, name: $0.name, detail: $0.detail) },
                ending: guide.ending, tips: guide.tips, controlHint: guide.controlHint)
        }
    }

    var styleView: StyleView {
        let game = state
        let order = MiniGame.byPrice
        func place(_ slot: CosmeticSlot) -> Int { slot.games.compactMap { order.firstIndex(of: $0) }.min() ?? order.count }
        let slots = CosmeticSlot.allCases.enumerated()
            .sorted { (place($0.element), $0.offset) < (place($1.element), $1.offset) }
            .map(\.element)
        return StyleView(slots: slots.map { slot in
            CosmeticSlotView(
                id: slot.rawValue, name: slot.name, icons: slot.games.map(\.info.icon).joined(),
                cosmetics: Cosmetic.all(in: slot).map { cosmetic in
                    let unlocked = game.isUnlocked(cosmetic)
                    let achievement = game.achievementUnlock(cosmetic)
                    return CosmeticView(
                        id: cosmetic.rawValue, name: cosmetic.name, isUnlocked: unlocked,
                        isEquipped: game.equipped(cosmetic.slot) == cosmetic,
                        rankLine: unlocked ? nil : "Reach \(game.unlockText(cosmetic))",
                        achievementLine: unlocked ? nil : achievement.map { "Or earn the \($0.name) achievement (\($0.tier))" })
                })
        })
    }

    /// The looks equipped for each kind (`CosmeticSlot` raw value to `Cosmetic` raw value), for the games to draw.
    var equippedLooks: [String] {
        CosmeticSlot.allCases.map { "\($0.rawValue)=\(state.equipped($0).rawValue)" }
    }
}
