import SwiftUI
import CryptoClickerKit

/// A guide to every system in the game, grouped by what it's for, then the full rules of each
/// mini-game. Each topic is one line saying what it is and a few short points, so the page reads
/// at a glance. Opened from Settings, so it's a page in Settings' navigation rather than a sheet.
struct HowToPlayView: View {
    @AppStorage(Preferences.howToPlaySeenKey) private var seen = false

    var body: some View {
        List {
            Section {
                Text("Mine coins, build a mining empire and keep it growing, even while you're away.")
                    .font(.headline)
            }
            ForEach(HowToChapter.all) { chapter in
                Section(chapter.title) {
                    ForEach(chapter.topics) { topic in
                        HowToTopicRow(topic: topic)
                    }
                }
            }
            Section {
                ForEach(MiniGame.byPrice) { game in
                    NavigationLink {
                        GameRulesPage(game: game)
                    } label: {
                        HStack(spacing: 12) {
                            Text(game.icon)
                                .font(.title3)
                                .frame(width: 30)
                                .accessibilityHidden(true)
                            Text(game.name)
                        }
                    }
                }
            } header: {
                Text("Game Rules")
            } footer: {
                SettingsNote("The full rules for every game, locked or not. Each game also has a How to Play button of its own.")
            }
        }
        .navigationTitle("How to Play")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { seen = true }
    }
}

/// One topic: its name, a line saying what it is, and the details as short points.
private struct HowToTopic: Identifiable {
    let icon: String
    let title: String
    let summary: String
    let points: [String]
    var id: String { title }

    init(_ icon: String, _ title: String, _ summary: String, _ points: [String] = []) {
        self.icon = icon
        self.title = title
        self.summary = summary
        self.points = points
    }
}

/// Topics under one heading.
private struct HowToChapter: Identifiable {
    let title: String
    let topics: [HowToTopic]
    var id: String { title }

    static let all = [mining, rewards, games, progress, beyondTheApp]

    private static let mining = HowToChapter(title: "Mining", topics: [
        HowToTopic("hand.tap.fill", "Tap to mine", "Tap the coin to earn coins.", [
            "Tapping upgrades add a share of a second's production to every tap, up to a whole second's worth.",
            "Tap your balance to switch between 12.3K and 12,345 (Settings and the Income page have the same switch).",
            "Tap the rates under it, or the balance bar on the other tabs, to see where every coin comes from.",
        ]),
        HowToTopic("flame.fill", "Combos", "Tap quickly and each tap earns more.", [
            "Every four or five quick taps add ×0.1, so about 45 make ×2.",
            "Pause for more than about half a second (longer with Combo Keeper) and the combo starts over.",
            "The flame under the coin shows your biggest combo.",
        ]),
        HowToTopic("bolt.fill", "Combo power-ups", "Bought in levels in Shop › Power-ups, and kept when you prestige.", [
            "Combo Booster: the biggest combo grows ×0.5 a level, up to ×5.",
            "Combo Overdrive: then ×1 a level, up to ×10.",
            "Quick Combos: each ×0.1 comes 50% faster a level, up to four times as fast.",
            "Combo Keeper: a combo waits 0.2 seconds longer for your next tap a level, from 0.6 up to 2.2 seconds.",
            "The Combo Master perk doubles that speed and lifts the biggest combo to at least ×3.",
        ]),
        HowToTopic("cpu", "Miners", "Miners earn coins every second while the app is open.", [
            "A Chromebook mines a coin every four seconds, and each tier after mines several times more.",
            "Each unit costs 15% more than the last, so the next tier soon becomes the better buy.",
            "In the Shop, each miner shows what one more adds, and Best value marks the best buy.",
        ]),
        HowToTopic("arrow.up.right.circle.fill", "Milestones and Mk upgrades", "The more of a miner you own, the more each one mines.", [
            "Owning 25, 50, 100, 200, then every 100 up to 1,000, doubles a miner's output each time.",
            "At 25, 50, 100, 200 and 400 owned, a Mk upgrade (Mk II to Mk VI) appears in the Shop.",
            "Each Mk upgrade doubles that miner again for the rest of the run.",
            "Legacy, late in the game: each miner you own 100 of makes every miner four or more tiers older earn ×5.",
        ]),
        HowToTopic("sparkles", "Upgrades", "One-time purchases in the Shop.", [
            "Multiply production and power up taps.",
            "Add automatic taps, each worth half a tap.",
            "Boost steps and mini-games.",
        ]),
        HowToTopic("moon.zzz.fill", "Offline Mining", "Keeps your miners earning while the app is closed.", [
            "Without it, miners stop a minute after you leave.",
            "The first level adds a minute (two in all), then each adds a minute up to 10 minutes, 5 minutes up to an hour, 15 minutes up to 3 hours, and half an hour up to three days. Every level costs more than the last.",
            "It's a power-up, so it stays when you prestige.",
        ]),
    ])

    private static var rewards: HowToChapter { HowToChapter(title: "Rewards", topics: [
        HowToTopic("shippingbox.fill", "Airdrops", "Once you've mined \(CoinFormat.grouped(Int(Tuning.airdropUnlockCoins))) coins, an airdrop falls every few minutes: tap it to catch it.", [
            "It holds a pile of coins, or a Bull Run that multiplies production by 7 for a minute.",
            "Now and then a whale swims by instead: up to an hour of income at once.",
            "Early in a run, a whale pays at most what the run has mined so far.",
        ]),
        HowToTopic("gift.fill", "Daily rewards and quests", "From your second day, in Trophies › Daily.", [
            "Claim a reward every day to build a streak: day 7 pays an hour of income.",
            "Three new quests arrive each day.",
            "Coin rewards grow with your income: up to three times over the day, and up to twice once a quest is finished but not yet claimed.",
        ]),
        HowToTopic("target", "Daily challenge", "From your second day, a challenge a day in one of your games.", [
            "A \(MiniGame.tetris.name) score, a \(MiniGame.merge2048.name) miner, a Pump and Dump run, a Token Swap score, invaders shot, good casino hands, or points in three arcade games.",
            "Each pays 15 minutes of income, and five in a week (Monday to Sunday) pay two hours more.",
            "On Block Day, \(MiniGame.tetris.name) deals everyone the same pieces.",
        ]),
        HowToTopic("figure.walk", "Steps", "After \(CoinFormat.grouped(Tuning.stepsUnlockTaps)) taps, your steps turn into coins.", [
            "Steps are paid as you walk, and count toward quests and achievements.",
            "Your first day's steps are paid the next day, so walking can't skip the opening.",
            "Every step, on iPhone or Apple Watch, is paid once, and steps grow more valuable as your income grows.",
        ]),
        HowToTopic("trophy.fill", "Achievements", "Bronze, silver, gold and mythic stars, in Trophies.", [
            "Every star adds 1% to production for good.",
            "Stars unlock finishes, rims and tap effects for the coin in Settings › Appearance.",
        ]),
    ]) }

    private static var games: HowToChapter { HowToChapter(title: "Tokens and Games", topics: [
        HowToTopic("chart.line.uptrend.xyaxis", "Tokens", "Buy and sell crypto in Shop › Tokens.", [
            "Prices drift every five minutes, usually a few percent a day, and news nudges them.",
            "Tether is a stablecoin: it barely moves, so it's a calm place to keep tokens.",
            "Bet tokens at the casino, or sell them later: selling costs a 10% fee.",
            "Pick ×1, ×10, ×100 or Max to buy and sell in bulk.",
            "Tokens reset when you prestige.",
        ]),
        HowToTopic("gamecontroller.fill", "Arcade", "Games unlock one at a time, from a few thousand coins up to about one and a half trillion.", [
            "Arcade games pay coins for every point, and half as much again for a new best.",
            "A minute of good play pays about two minutes of income.",
            "Playing earns XP for your Arcade Rank: each game shows what it earned, with more for a new best, the first game of each kind each day and the daily challenge. Casino rounds earn a little, up to a daily limit. Six different games in a week pay half an hour of income.",
            "Arcade Rank unlocks looks for every game in Style, on the Arcade's rank card. Some also come sooner with a game's achievement.",
            "Stats under a game's Play button shows its records before you start.",
            "Every game has a How to Play button with its full rules.",
        ]),
        HowToTopic("suit.spade.fill", "Casino", "\(MiniGame.blackjack.name), Crypto Slots, \(MiniGame.videoPoker.name) and To the Moon: bet your tokens.", [
            "Wins pay tokens, plus a coin bonus.",
            "Diamond Hands: HODL the cards you believe in and draw once. Hint HODLs what a strong player would.",
            "To the Moon: cash out before the market crashes, or set an automatic cash-out.",
        ]),
        HowToTopic("square.grid.3x3.fill", "More ways to play", "Every action game opens on a start screen of its ways to play and its settings.", [
            "\(MiniGame.tetris.name): Endless, Block Rush and today's pieces. \(MiniGame.snake.name): Classic in four arenas, and Coin Rush.",
            "\(MiniGame.merge2048.name): Classic and the Daily Puzzle. Building the Lunar Base pays ten minutes of income on top.",
            "Token Swap has levels whose stars each pay once, a daily puzzle and random levels.",
            "\(MiniGame.brickBreaker.name) and Scam Invaders have their levels or waves, random ones, and speed. Start at any level or wave you've reached; a later start pays a smaller share of its points.",
            "Pump and Dump plays on a 3×3, 4×4 or 5×5 board, at the speed you pick. Each board keeps its own best.",
            "\(MiniGame.bubbleBlaster.name): Waves, a two-minute Flash Market and today's market, with the shots' speed and a shorter aiming guide to pick.",
            "Swipe in from the left edge to leave a game.",
        ]),
    ]) }

    private static let progress = HowToChapter(title: "Progress", topics: [
        HowToTopic("flag.fill", "Goals", "Trophies › Goals shows what to aim for next.", [
            "The next miner, milestone, upgrade and game, the closest achievement star, and more.",
            "Each goal shows how close you are.",
        ]),
        HowToTopic("chart.bar.xaxis", "Statistics", "Settings › Statistics keeps every record.", [
            "Chart your income over the last day, week or month, or all time.",
            "Your Journey lists when each first happened, and how long after you started.",
        ]),
        HowToTopic("rosette", "Prestige and perks", "After 15 billion coins mined in all, start a new run for prestige points.", [
            "Every point adds 5% production for good, and points buy permanent perks.",
            "The Shop suggests prestiging once it would make you at least half as fast again.",
            "Your first prestige reveals three new miners.",
            "Hard earns half as many points again, and Easy half as many: pick in Settings.",
        ]),
    ])

    private static let beyondTheApp = HowToChapter(title: "Beyond the App", topics: [
        HowToTopic("applewatch", "Apple Watch", "Tap to mine from your wrist and keep an eye on your balance.", [
            "Taps reach your iPhone and count exactly once.",
        ]),
        HowToTopic("rectangle.stack.fill", "Widgets and the Lock Screen", "Watch your balance grow without opening the game.", [
            "Add the Balance widget to your Home Screen or Lock Screen: its number grows as your miners earn.",
            "A Live Activity shows your coin and balance on the Lock Screen and in the Dynamic Island, and how long your miners keep going.",
            "Turn the Live Activity off in Settings › Lock Screen and Widgets.",
        ]),
        HowToTopic("mic.fill", "Siri and Shortcuts", "Hear your balance without opening the game.", [
            "Ask Siri \u{201C}How many coins do I have in Crypto Clicker?\u{201D}",
            "Or add Check My Coins in the Shortcuts app.",
        ]),
    ])
}

/// A topic: its icon and name, the line saying what it is, then its points.
private struct HowToTopicRow: View {
    let topic: HowToTopic

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: topic.icon)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.headline)
                    Text(topic.summary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !topic.points.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(topic.points, id: \.self) { point in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(Theme.accent)
                                    .accessibilityHidden(true)
                                Text(point)
                                    .font(.subheadline)
                                    .foregroundStyle(.subtext)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
