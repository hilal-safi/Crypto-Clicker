import SwiftUI
import CryptoClickerKit

/// A quick guide to every system in the game.
struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    private let topics: [(icon: String, title: String, text: String)] = [
        ("hand.tap.fill", "Tap to mine",
         "Tap the coin to earn coins. Tapping upgrades add a share of your income to every tap."),
        ("cpu", "Buy miners",
         "Miners earn coins every second, even while the app is closed. Each one costs 15% more than the last."),
        ("arrow.up.right.circle.fill", "Hit milestones",
         "Owning 25, 50, 100, 200 (and every 100 up to 1,000) of a miner doubles its output each time."),
        ("sparkles", "Upgrades",
         "One-time purchases that multiply production, automate taps, boost steps and mini-games, or let miners work longer offline."),
        ("moon.zzz.fill", "Offline earnings",
         "Miners keep working while you're away, up to 2 hours at first. Offline upgrades extend this to a full day."),
        ("shippingbox.fill", "Airdrops",
         "Every few minutes an airdrop falls. Catch it for a pile of coins, or a Bull Run that multiplies production by 7 for a minute."),
        ("figure.walk", "Steps",
         "Connect Apple Health and every step you take, on iPhone or Apple Watch, is paid once. Steps grow more valuable as your income grows."),
        ("applewatch", "Apple Watch",
         "Tap to mine from your wrist and keep an eye on your balance. Taps are delivered to your iPhone and counted exactly once."),
        ("gamecontroller.fill", "Arcade",
         "Buy crypto tokens on the Exchange and bet them at Blackjack: bigger bets earn bigger coin bonuses, up to a limit set by your income. Tetris pays coins for every point."),
        ("trophy.fill", "Achievements",
         "Every bronze, silver and gold star permanently adds 1% to production."),
        ("arrow.triangle.branch", "Hard Fork",
         "Once you've mined 10 billion coins, start over for forks: each fork adds 2% production forever. Harder difficulties earn more forks."),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Mine coins, build a mining empire and keep it growing while you're away.")
                        .font(.headline)
                }
                ForEach(topics, id: \.title) { topic in
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title)
                                .font(.headline)
                            Text(topic.text)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: topic.icon)
                            .foregroundStyle(Theme.bitcoin)
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
