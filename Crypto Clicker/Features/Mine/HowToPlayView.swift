import SwiftUI
import CryptoClickerKit

/// A quick guide to every system in the game.
struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    private let topics: [(icon: String, title: String, text: String)] = [
        ("hand.tap.fill", "Tap to mine",
         "Tap the coin to earn coins. Tapping upgrades make every tap also earn a share of a second's production, up to a whole second's worth, so tapping always pays. Tap the balance to switch between the short form (12.3K) and every digit (12,345); what each tap earns shows the same way. Tap the rates under your balance to see where every coin comes from."),
        ("flame.fill", "Combos",
         "Keep tapping quickly and a combo builds: after 40 quick taps every tap earns twice as much. Pause for more than about half a second and it starts over."),
        ("cpu", "Buy miners",
         "Miners earn coins every second while the app is open. Each one costs 15% more than the last. The miners you own show under the coin."),
        ("arrow.up.right.circle.fill", "Milestones and Mk upgrades",
         "Owning 25, 50, 100, 200 (and every 100 up to 1,000) of a miner doubles its output each time. At 25, 50, 100, 200 and 400 owned, a Mk upgrade (Mk II to Mk VI) appears in the Shop: each doubles that miner again for the rest of the run."),
        ("sparkles", "Upgrades",
         "One-time purchases that multiply production, power up taps, add automatic taps (each worth a quarter of a tap), and boost steps and mini-games."),
        ("moon.zzz.fill", "Offline Mining",
         "At first, miners stop a minute after you leave the app. The Offline Mining power-up keeps them earning while it's closed: 30 minutes more per level up to a day, then an hour more per level, up to three days. Power-ups stay when you prestige."),
        ("shippingbox.fill", "Airdrops",
         "Every few minutes an airdrop falls. Catch it for a pile of coins, or a Bull Run that multiplies production by 7 for a minute. Now and then a whale swims by instead: catch it for an hour of income at once."),
        ("gift.fill", "Daily rewards and quests",
         "Claim a reward every day in Trophies › Daily to build a streak: the week builds up to an hour of income on day 7. Three new quests arrive each day."),
        ("target", "Daily challenge",
         "Each day brings a challenge in one of your games: a score in Tetris, a tile in 2048, a round of Pump and Dump, wins at the casino, or points in three different arcade games. Complete it for 15 minutes of income, and complete five in a week (Monday to Sunday) for two hours more. On Block Day, Tetris deals everyone the same pieces."),
        ("chart.line.uptrend.xyaxis", "Coin Exchange",
         "In the Exchange tab, token prices drift every five minutes, usually by a few percent a day, and news nudges them up or down. Buy tokens to bet at the casino games, or to sell later: selling costs a 10% fee. Tokens reset when you prestige."),
        ("figure.walk", "Steps",
         "After 2,500 taps you can turn steps into coins. Every step you take, on iPhone or Apple Watch, is paid once, and steps grow more valuable as your income grows."),
        ("applewatch", "Apple Watch",
         "Tap to mine from your wrist and keep an eye on your balance. Taps are delivered to your iPhone and counted exactly once."),
        ("gamecontroller.fill", "Arcade",
         "Games unlock one at a time, each costing far more than the last, so a new one arrives about every hour of play. Blackjack, Crypto Slots and To the Moon pay tokens plus a coin bonus for every win. In To the Moon the multiplier climbs until the market crashes: cash out in time, or set an automatic cash-out. Tetris, 2048, Snake, Brick Breaker, Bubble Blaster and Pump and Dump pay coins for every point, and half as much again for a new best score; a minute of good play pays about two minutes of income. Making a 2048 tile pays ten minutes of income on top."),
        ("trophy.fill", "Achievements",
         "Every bronze, silver, gold and mythic star permanently adds 1% to production, and stars unlock new finishes for the coin in Settings (the gear at the top of this screen)."),
        ("rosette", "Prestige and perks",
         "Once you've mined 12.65 billion coins in all, you can prestige: start a new run for prestige points. Every point adds 5% production forever, and points also buy permanent perks. The Shop suggests prestiging once it would make you at least half as fast again. Your first prestige reveals three new miners. Harder difficulties earn more points."),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Mine coins, build a mining empire and keep it growing, even while you're away.")
                        .font(.headline)
                }
                ForEach(topics, id: \.title) { topic in
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title)
                                .font(.headline)
                            Text(topic.text)
                                .font(.subheadline)
                                .foregroundStyle(.subtext)
                        }
                    } icon: {
                        Image(systemName: topic.icon)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }
}
