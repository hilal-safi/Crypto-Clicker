import SwiftUI
import CryptoClickerKit

/// Every first in this game, oldest first: the first of each miner, Offline Mining, each game
/// unlocked, every thousandfold of coins mined and the first prestige, with how long after the
/// start each one came. A record of how the game was actually paced.
struct JourneyView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let game = store.game
        let entries = game.journeyEntries
        List {
            Section {
                ForEach(entries) { entry in
                    JourneyRow(entry: entry, start: game.created)
                }
            } footer: {
                SettingsNote(footer(game))
            }
        }
        .navigationTitle("Your Journey")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func footer(_ game: GameState) -> String {
        var text = "When each first happened, and how long after you started. Firsts stay when you prestige."
        if let since = game.journey.since, since.timeIntervalSince(game.created) > 60 {
            text += " Recording began on \(since.formatted(date: .abbreviated, time: .omitted)); firsts from before then weren't kept."
        }
        return text
    }
}

private struct JourneyRow: View {
    let entry: JourneyEntry
    let start: Date

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.icon)
                .font(.title3)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 8)
            if entry.kind != .started {
                Text("after \(CoinFormat.duration(max(0, entry.date.timeIntervalSince(start))))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.subtext)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
