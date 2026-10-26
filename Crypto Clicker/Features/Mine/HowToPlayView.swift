import SwiftUI
import CryptoClickerKit

/// A quick guide to every system in the game.
struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    private let topics: [(icon: String, title: String, text: String)] = [
        ("hand.tap.fill", "Tap to mine",
         "Tap the coin to earn coins. Tapping upgrades make every tap also earn a share of a second's production, up to a whole second's worth, so tapping always pays. While you tap, the balance shows every digit; tap the balance to keep it that way."),
        ("cpu", "Buy miners",
         "Miners earn coins every second while the app is open. Each one costs 15% more than the last. The miners you own show under the coin."),
        ("arrow.up.right.circle.fill", "Hit milestones",
         "Owning 25, 50, 100, 200 (and every 100 up to 1,000) of a miner doubles its output each time."),
        ("sparkles", "Upgrades",
         "One-time purchases that multiply production, power up taps, add automatic taps (each worth a quarter of a tap), and boost steps and mini-games."),
        ("moon.zzz.fill", "Offline Mining",
         "At first, miners stop a minute after you leave the app. The Offline Mining power-up keeps them earning while it's closed: 30 minutes more per level up to a day, then an hour more per level, up to three days. Power-ups stay through Hard Forks."),
        ("shippingbox.fill", "Airdrops",
         "Every few minutes an airdrop falls. Catch it for a pile of coins, or a Bull Run that multiplies production by 7 for a minute."),
        ("figure.walk", "Steps",
         "After 2,500 taps you can turn steps into coins. Every step you take, on iPhone or Apple Watch, is paid once, and steps grow more valuable as your income grows."),
        ("applewatch", "Apple Watch",
         "Tap to mine from your wrist and keep an eye on your balance. Taps are delivered to your iPhone and counted exactly once."),
        ("gamecontroller.fill", "Arcade",
         "Buy crypto tokens on the Exchange and bet them at Blackjack or Crypto Slots: wins pay tokens plus a coin bonus. Tetris, Snake, Brick Breaker and Bubble Blaster pay coins for every point."),
        ("trophy.fill", "Achievements",
         "Every bronze, silver and gold star permanently adds 1% to production."),
        ("arrow.triangle.branch", "Hard Fork",
         "Once you've mined 10 billion coins, start over for forks: each fork adds 2% production forever. Harder difficulties earn more forks."),
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
