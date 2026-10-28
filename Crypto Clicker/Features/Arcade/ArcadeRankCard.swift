import SwiftUI
import CryptoClickerKit

/// Arcade Rank at the top of the Arcade: the rank and title, XP toward the next rank, the week's
/// variety goal, and the Style sheet where ranks and achievements unlock new looks.
struct ArcadeRankCard: View {
    let game: GameState
    let today: String
    @State private var showingStyle = false

    var body: some View {
        let rank = game.arcadeRank
        let progress = game.arcadeRankProgress
        let played = game.gamesPlayed(inWeekOf: today)
        let isPaid = game.isWeeklyGoalPaid(inWeekOf: today)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text("\(rank)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Theme.arcade.gradient, in: .rect(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Arcade Rank \(rank)")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.subtext)
                    Text(game.arcadeTitle)
                        .font(.headline)
                    Text("\(CoinFormat.grouped(progress.xp)) of \(CoinFormat.grouped(progress.needed)) XP to rank \(rank + 1)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.subtext)
                }
                Spacer(minLength: 8)
                Button("Style", systemImage: "paintpalette.fill") { showingStyle = true }
                    .buttonStyle(.bordered)
                    .font(.subheadline.weight(.bold))
                    .accessibilityHint("Pick looks for the games")
            }
            ProgressView(value: Double(progress.xp), total: Double(max(1, progress.needed)))
                .tint(Theme.arcade)
                .accessibilityHidden(true)
            HStack(alignment: .center, spacing: 8) {
                Label(isPaid ? "Weekly variety goal met" : "This week: \(min(played.count, Tuning.weeklyVarietyGames)) of \(Tuning.weeklyVarietyGames) games · +\(CoinFormat.short(game.weeklyVarietyReward))",
                      systemImage: isPaid ? "checkmark.seal.fill" : "dice.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPaid ? Theme.gain : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(MiniGame.allCases.filter(played.contains).map(\.icon).joined())
                    .font(.caption)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
        }
        .rowCard()
        .accessibilityElement(children: .combine)
        .sheet(isPresented: $showingStyle) { StyleView() }
    }
}

/// Looks for the games: card backs, the Blackjack felt, slot reels, Tetris blocks and the snake.
/// Locked looks say what unlocks them.
struct StyleView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let game = store.game
        NavigationStack {
            List {
                Section {
                    Text("Arcade Rank and game achievements unlock new looks. They change how the games look, nothing else.")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                ForEach(CosmeticSlot.allCases) { slot in
                    Section(slot.name) {
                        ForEach(Cosmetic.all(in: slot)) { cosmetic in
                            row(cosmetic, game: game)
                        }
                    }
                }
            }
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ cosmetic: Cosmetic, game: GameState) -> some View {
        let isUnlocked = game.isUnlocked(cosmetic)
        let isEquipped = game.equipped(cosmetic.slot) == cosmetic
        return Button {
            if isUnlocked { store.equip(cosmetic) }
        } label: {
            HStack(spacing: 14) {
                CosmeticPreview(cosmetic: cosmetic)
                    .frame(width: 56, height: 50)
                    .saturation(isUnlocked ? 1 : 0)
                    .opacity(isUnlocked ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cosmetic.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !isUnlocked {
                        Label(game.unlockText(cosmetic), systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.subtext)
                    }
                }
                Spacer()
                if isEquipped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.gain)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .accessibilityLabel(cosmetic.name)
        .accessibilityValue(isEquipped ? "In use" : isUnlocked ? "" : "Locked: \(game.unlockText(cosmetic))")
        .accessibilityAddTraits(isEquipped ? .isSelected : [])
    }
}
