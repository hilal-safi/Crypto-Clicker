import SwiftUI
import CryptoClickerKit

// The Statistics page's richer rows: a card for each game, the Arcade Rank, the wallet, tokens and
// miners. Plain figures stay as label-and-value rows in StatsView.

/// One figure: a value over its name.
struct StatItem {
    /// What the figure is: looked up in the String Catalog when written out, shown as it is
    /// when worked out in code.
    let title: Text
    let value: String

    init(_ title: LocalizedStringKey, _ value: String) {
        self.title = Text(title)
        self.value = value
    }

    @_disfavoredOverload
    init<Title: StringProtocol>(_ title: Title, _ value: String) {
        self.title = Text(title)
        self.value = value
    }
}

/// Figures as tiles, each a value over its name on a tinted backing: three to a row, or two when
/// there are two or four of them (so none sits alone) and at the largest text sizes.
struct StatGrid: View {
    let items: [StatItem]
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let perRow = typeSize.isAccessibilitySize || items.count == 2 || items.count == 4 ? 2 : 3
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .leading),
                                 count: max(1, min(perRow, items.count))),
                  alignment: .leading, spacing: 8) {
            // A grid's figures never move about, so their places are their identity.
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.value)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    item.title
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.subtext)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(tint.opacity(colorScheme == .dark ? 0.24 : 0.11), in: .rect(cornerRadius: 12))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.title)
                .accessibilityValue(item.value)
            }
        }
    }
}

/// An emoji on a tinted rounded square, for game and miner rows.
struct StatsIcon: View {
    let emoji: String
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(emoji)
            .font(.title2)
            .frame(width: 46, height: 46)
            .background(tint.opacity(colorScheme == .dark ? 0.32 : 0.16), in: .rect(cornerRadius: 13))
            .accessibilityHidden(true)
    }
}

/// One game: its name and how often it's been played, its headline record on the right, the rest
/// of its records as tiles, and an optional line under them (what was bet and paid out).
struct GameStatsCard: View {
    let game: MiniGame
    /// "42 games", "1,204 hands".
    let plays: String
    /// The record that leads: "Best" 12,345, or "Biggest win" 1.2M.
    let headline: StatItem
    let items: [StatItem]
    var note: String? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        VStack(alignment: .leading, spacing: 12) {
            layout {
                HStack(spacing: 12) {
                    StatsIcon(emoji: game.icon, tint: game.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.name)
                            .font(.headline)
                        Text(plays)
                            .font(.subheadline)
                            .foregroundStyle(.subtext)
                    }
                }
                .accessibilityElement(children: .combine)
                if !stacked {
                    Spacer(minLength: 8)
                }
                VStack(alignment: stacked ? .leading : .trailing, spacing: 1) {
                    headline.title
                        .font(.footnote.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(game.textColor(in: colorScheme))
                    Text(headline.value)
                        .font(.title3.bold().monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .accessibilityElement(children: .combine)
            }
            if !items.isEmpty {
                StatGrid(items: items, tint: game.color)
            }
            if let note {
                Label {
                    Text(note)
                } icon: {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .foregroundStyle(game.textColor(in: colorScheme))
                }
                .font(.subheadline)
                .foregroundStyle(.subtext)
            }
        }
        .padding(.vertical, 4)
    }
}

extension GameStatsCard {
    /// A game's card: a casino game's biggest win or an arcade game's best score up top, and the
    /// rest of its records as tiles. Statistics shows one for every game played, and the Arcade
    /// one game's in a sheet. Coin amounts are short, or every digit with `exactNumbers`.
    init(_ miniGame: MiniGame, in game: GameState, exactNumbers: Bool) {
        self = Self.make(miniGame, in: game, exactNumbers: exactNumbers)
    }

    private static func make(_ miniGame: MiniGame, in game: GameState, exactNumbers: Bool) -> GameStatsCard {
        func amount(_ value: Double) -> String {
            exactNumbers ? CoinFormat.exact(value) : CoinFormat.short(value)
        }
        /// "1.2M bet · 1.1M paid out", once anything's been bet.
        func betNote(_ bet: Double, paid: Double) -> String? {
            bet > 0 ? "\(amount(bet)) bet · \(amount(paid)) paid out" : nil
        }
        let s = game.stats
        let plays = game.timesPlayed(miniGame)
        let best = StatItem("Best", CoinFormat.grouped(game.bestScore(miniGame)))
        switch miniGame {
        case .blackjack:
            return GameStatsCard(game: miniGame, plays: counted(plays, "hand"),
                                 headline: StatItem("Biggest win", amount(s.blackjackBiggestWin)),
                                 items: [StatItem("Wins", CoinFormat.grouped(s.blackjackWins)),
                                         StatItem("Win rate", percentage(s.blackjackWins, of: s.blackjackHands)),
                                         StatItem("Naturals", CoinFormat.grouped(s.blackjackNaturals)),
                                         StatItem("Streak now", CoinFormat.grouped(s.blackjackStreak)),
                                         StatItem("Best streak", CoinFormat.grouped(s.blackjackBestStreak))])
        case .slots:
            return GameStatsCard(game: miniGame, plays: counted(plays, "spin"),
                                 headline: StatItem("Biggest win", amount(s.slotsBiggestWin)),
                                 items: [StatItem("Wins", CoinFormat.grouped(s.slotsWins)),
                                         StatItem("Win rate", percentage(s.slotsWins, of: s.slotsSpins)),
                                         StatItem("Jackpots", CoinFormat.grouped(s.slotsJackpots)),
                                         StatItem("Best spin", s.slotsBestMultiple >= 2 ? "×\(CoinFormat.grouped(s.slotsBestMultiple))" : "–"),
                                         StatItem("Free rounds", CoinFormat.grouped(s.slotsFreeSpinRounds)),
                                         StatItem("Free spins", CoinFormat.grouped(s.slotsFreeSpinsPlayed)),
                                         StatItem("Bitcoins", CoinFormat.grouped(s.slotsBitcoins)),
                                         StatItem("Bitcoin prizes", CoinFormat.grouped(s.slotsBitcoins / SlotMachine.bitcoinsPerPrize)),
                                         StatItem("Paid back", paidBack(s.slotsPaidOut, of: s.slotsWagered))],
                                 note: betNote(s.slotsWagered, paid: s.slotsPaidOut))
        case .moon:
            return GameStatsCard(game: miniGame, plays: counted(plays, "flight"),
                                 headline: StatItem("Biggest win", amount(s.moonBiggestWin)),
                                 items: [StatItem("Cash-outs", CoinFormat.grouped(s.moonCashOuts)),
                                         StatItem("Cashed out", percentage(s.moonCashOuts, of: s.moonFlights)),
                                         StatItem("Best cash-out", s.moonCashOuts > 0 ? CoinFormat.flight(s.moonBestMultiplier) : "–"),
                                         StatItem("Paid back", paidBack(s.moonPaidOut, of: s.moonWagered))],
                                 note: betNote(s.moonWagered, paid: s.moonPaidOut))
        case .videoPoker:
            return GameStatsCard(game: miniGame, plays: counted(plays, "hand"),
                                 headline: StatItem("Biggest win", amount(s.pokerBiggestWin)),
                                 items: [StatItem("Wins", CoinFormat.grouped(s.pokerWins)),
                                         StatItem("Win rate", percentage(s.pokerWins, of: s.pokerHands)),
                                         StatItem("Best hand", s.pokerHands > 0 ? (PokerHand(rawValue: s.pokerBestHand) ?? .nothing).name : "–"),
                                         StatItem("Royal flushes", CoinFormat.grouped(s.pokerRoyals)),
                                         StatItem("Paid back", paidBack(s.pokerPaidOut, of: s.pokerWagered))],
                                 note: betNote(s.pokerWagered, paid: s.pokerPaidOut))
        case .tetris:
            var items = [StatItem("Best level", CoinFormat.grouped(s.tetrisBestLevel)),
                         StatItem("Best combo", CoinFormat.grouped(s.tetrisBestCombo)),
                         StatItem("Full Blocks", CoinFormat.grouped(s.tetrisTetrises)),
                         StatItem("Rows", CoinFormat.grouped(s.tetrisLines))]
            if s.tetrisBestSprint > 0 {
                items.append(StatItem("Best Rush", CoinFormat.stopwatch(s.tetrisBestSprint)))
            }
            return GameStatsCard(game: miniGame, plays: counted(plays, "game"), headline: best, items: items)
        case .merge2048:
            return GameStatsCard(game: miniGame, plays: counted(plays, "game"), headline: best,
                                 items: [StatItem("Top miner", Merge2048Game.miner(for: s.merge2048BestTile).name),
                                         StatItem("Daily wins", CoinFormat.grouped(game.merge2048Daily.wins)),
                                         StatItem("Daily stars", CoinFormat.grouped(game.merge2048Daily.totalStars))])
        case .snake:
            return GameStatsCard(game: miniGame, plays: counted(plays, "game"), headline: best,
                                 items: [StatItem("Coin Rush", CoinFormat.grouped(s.snakeRushBestScore)),
                                         StatItem("Longest chain", CoinFormat.grouped(s.snakeLongest)),
                                         StatItem("Most coins", CoinFormat.grouped(s.snakeBestCoins)),
                                         StatItem("Longest game", CoinFormat.stopwatch(s.snakeLongestTime)),
                                         StatItem("Power-ups", CoinFormat.grouped(s.snakePowerUps))])
        case .brickBreaker:
            return GameStatsCard(game: miniGame, plays: counted(plays, "game"), headline: best,
                                 items: [StatItem("Best level", CoinFormat.grouped(s.brickBreakerBestLevel)),
                                         StatItem("Levels cleared", CoinFormat.grouped(s.brickBreakerLevelsCleared)),
                                         StatItem("Best streak", CoinFormat.grouped(s.brickBreakerBestStreak)),
                                         StatItem("Whales", CoinFormat.grouped(s.brickBreakerBosses)),
                                         StatItem("Power-ups", CoinFormat.grouped(s.brickBreakerPowerUps)),
                                         StatItem("Blocks", CoinFormat.grouped(s.bricksBroken))])
        case .bubbleBlaster:
            return GameStatsCard(game: miniGame, plays: counted(plays, "game"), headline: best,
                                 items: [StatItem("Best wave", CoinFormat.grouped(s.bubbleBestWave)),
                                         StatItem("Best shot", CoinFormat.grouped(s.bubbleBestShot)),
                                         StatItem("Best streak", CoinFormat.grouped(s.bubbleBestStreak)),
                                         StatItem("Popped", CoinFormat.grouped(s.bubblesPopped)),
                                         StatItem("Blue chips", CoinFormat.grouped(s.bubbleBonuses))])
        case .pumpDump:
            return GameStatsCard(game: miniGame, plays: counted(plays, "run"), headline: best,
                                 items: [StatItem("Best round", CoinFormat.grouped(s.pumpDumpBestRound)),
                                         StatItem("Best combo", CoinFormat.grouped(s.pumpDumpBestCombo)),
                                         StatItem("Coins hit", CoinFormat.grouped(s.pumpDumpCoinsHit)),
                                         StatItem("Scams hit", CoinFormat.grouped(s.pumpDumpScamsHit))])
        case .invaders:
            return GameStatsCard(game: miniGame, plays: counted(plays, "game"), headline: best,
                                 items: [StatItem("Best wave", CoinFormat.grouped(s.invadersBestWave)),
                                         StatItem("Invaders shot", CoinFormat.grouped(s.invadersDestroyed)),
                                         StatItem("Best streak", CoinFormat.grouped(s.invadersBestStreak)),
                                         StatItem("Accuracy", percentage(s.invadersVolleysHit, of: s.invadersVolleys)),
                                         StatItem("Whales", CoinFormat.grouped(s.invadersWhales)),
                                         StatItem("Bosses", CoinFormat.grouped(s.invadersBosses))])
        case .tokenSwap:
            let swap = game.tokenSwap
            return GameStatsCard(game: miniGame, plays: counted(plays, "game"),
                                 headline: StatItem("Classic best", CoinFormat.grouped(s.tokenSwapBestScore)),
                                 items: [StatItem("Levels won", "\(CoinFormat.grouped(swap.levelsWon)) of \(CoinFormat.grouped(TokenSwapLevel.all.count))"),
                                         StatItem("Stars", CoinFormat.grouped(swap.totalStars)),
                                         StatItem("Daily wins", CoinFormat.grouped(swap.dailyWins)),
                                         StatItem("Best chain", CoinFormat.grouped(s.tokenSwapBestChain)),
                                         StatItem("Specials", CoinFormat.grouped(s.tokenSwapBlasts)),
                                         StatItem("Tokens cleared", CoinFormat.grouped(s.tokenSwapTokens)),
                                         StatItem("Random wins", "\(CoinFormat.grouped(s.tokenSwapRandomWins)) of \(CoinFormat.grouped(s.tokenSwapRandomPlayed))"),
                                         StatItem("Classic games", CoinFormat.grouped(s.tokenSwapGames)),
                                         StatItem("Levels played", CoinFormat.grouped(s.tokenSwapLevelsPlayed))])
        }
    }

    /// "1 hand", "1,204 hands".
    static func counted(_ count: Int, _ noun: String) -> String {
        "\(CoinFormat.grouped(count)) \(noun)\(count == 1 ? "" : "s")"
    }

    /// A share as a whole percentage: "48%", or "<1%" for a sliver.
    static func percentage(_ share: Double) -> String {
        guard share.isFinite, share > 0 else { return "0%" }
        if share < 0.01 { return "<1%" }
        return "\(Int((min(share, 1e6) * 100).rounded()))%"
    }

    private static func percentage(_ part: Int, of whole: Int) -> String {
        whole > 0 ? percentage(Double(part) / Double(whole)) : "–"
    }

    /// What came back for what was bet: "95%".
    private static func paidBack(_ paid: Double, of bet: Double) -> String {
        bet > 0 ? percentage(paid / bet) : "–"
    }
}

/// The games with nothing to show yet, as a line of their icons.
struct UnplayedGamesRow: View {
    let games: [MiniGame]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not played yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.subtext)
            HStack(spacing: 8) {
                ForEach(games) { game in
                    Text(game.icon)
                        .font(.title3)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Not played yet: \(games.map(\.name).formatted(.list(type: .and)))")
    }
}

/// The Arcade Rank and the way to the next one, over the arcade's totals.
struct ArcadeRankStats: View {
    let rank: Int
    let title: String
    let progress: (xp: Int, needed: Int)
    let items: [StatItem]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let needed = max(progress.needed, 1)
        let xp = min(max(progress.xp, 0), needed)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text("\(rank)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(6)
                    .frame(width: 56, height: 56)
                    .background(Theme.arcadeButton.gradient, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arcade Rank \(rank)")
                        .font(.headline)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colorScheme == .dark ? Theme.arcade.mix(with: .white, by: 0.35) : Theme.arcadeButton)
                    ProgressView(value: Double(xp), total: Double(needed))
                        .tint(Theme.arcade)
                    Text("\(CoinFormat.grouped(needed - xp)) XP to Rank \(rank + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                .accessibilityElement(children: .combine)
            }
            StatGrid(items: items, tint: Theme.arcade)
        }
        .padding(.vertical, 4)
    }
}

/// What the tokens held are worth now, over what's been bought and sold.
struct WalletCard: View {
    let value: String
    let detail: String
    let items: [StatItem]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.title)
                    .foregroundStyle(Theme.bitcoin)
                    .frame(width: 46, height: 46)
                    .background(Theme.bitcoin.opacity(colorScheme == .dark ? 0.24 : 0.14), in: .rect(cornerRadius: 13))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Wallet value")
                        .font(.footnote.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.accent)
                    Text(value)
                        .font(.title2.bold().monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                .accessibilityElement(children: .combine)
            }
            StatGrid(items: items, tint: Theme.bitcoin)
        }
        .padding(.vertical, 4)
    }
}

/// One token: how many are held and have been bought, and what they're worth now.
struct TokenStatRow: View {
    let token: TokenID
    let held: Int
    let bought: Int
    /// What the tokens held are worth.
    let worth: String
    /// One token's price.
    let price: String

    var body: some View {
        HStack(spacing: 12) {
            TokenImage(token: token, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(token.name)
                        .font(.headline)
                    Text(token.ticker)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }
                Text("\(CoinFormat.grouped(held)) held · \(CoinFormat.grouped(bought)) bought")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(worth)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(price) each")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One miner tier: how many are owned (and the most ever), its Mk upgrade, what it mines and its
/// share of the miners' income.
struct MinerStatRow: View {
    let miner: MinerID
    let owned: Int
    let mostEver: Int
    let mkLevel: Int
    /// Coins a second, already formatted.
    let rate: String
    /// Share of the miners' income, from 0 to 1.
    let share: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                StatsIcon(emoji: miner.emoji, tint: Theme.bitcoin)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(miner.name)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if mkLevel > 0 {
                            Text("Mk \(MinerID.markName(level: mkLevel - 1))")
                                .font(.footnote.weight(.heavy))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.accent.opacity(colorScheme == .dark ? 0.24 : 0.13), in: .capsule)
                        }
                    }
                    Text(mostEver > owned
                         ? "\(CoinFormat.grouped(owned)) owned · most \(CoinFormat.grouped(mostEver))"
                         : "\(CoinFormat.grouped(owned)) owned")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(rate)/s")
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(GameStatsCard.percentage(share))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            ShareBar(share: share)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// A slim bar filled to a share, from 0 to 1.
private struct ShareBar: View {
    let share: Double

    var body: some View {
        let share = share.isFinite ? min(max(share, 0), 1) : 0
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.bitcoin.opacity(0.18))
                if share > 0 {
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.gold, Theme.bitcoin], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, proxy.size.width * share))
                }
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Airdrops at a glance: how many were caught and missed and what they paid, over the counts of
/// each kind.
struct AirdropSummary: View {
    let caught: Int
    let missed: Int
    /// Coins from airdrops in all, already formatted.
    let earned: String
    let items: [StatItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                StatsIcon(emoji: "🪂", tint: Theme.shop)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Airdrops")
                        .font(.headline)
                    Text("\(CoinFormat.grouped(caught)) caught · \(CoinFormat.grouped(missed)) missed")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Earned")
                        .font(.footnote.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.accent)
                    Text(earned)
                        .font(.title3.bold().monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .accessibilityElement(children: .combine)
            }
            StatGrid(items: items, tint: Theme.shop)
        }
        .padding(.vertical, 4)
    }
}

/// One airdrop in the history: what it was, when, and what it paid (or that it got away).
struct AirdropLogRow: View {
    let log: AirdropLog
    /// The coins it paid, already formatted.
    let coins: String

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title3)
                .opacity(log.caught ? 1 : 0.45)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(log.date.formatted(.relative(presentation: .named)))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 8)
            Text(result)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(log.caught ? Theme.gain : Theme.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }

    private var emoji: String {
        switch log.kind {
        case .coins: "🪂"
        case .bullRun: "🐂"
        case .whale: "🐋"
        }
    }

    private var title: String {
        switch (log.kind, log.caught) {
        case (.coins, true): "Airdrop caught"
        case (.bullRun, true): "Bull Run"
        case (.whale, true): "Whale caught"
        case (.coins, false): "Airdrop missed"
        case (.bullRun, false): "Bull Run missed"
        case (.whale, false): "Whale missed"
        }
    }

    private var result: String {
        guard log.caught else { return "Missed" }
        return log.kind == .bullRun ? "\(CoinFormat.multiplier(Tuning.bullRunMultiplier)) boost" : "+\(coins)"
    }
}
