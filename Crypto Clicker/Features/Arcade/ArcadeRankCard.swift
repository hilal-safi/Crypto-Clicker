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
                        .font(.footnote.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.arcade)
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isPaid ? Theme.gain : Theme.subtext)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                Spacer(minLength: 4)
                Text(MiniGame.allCases.filter(played.contains).map(\.icon).joined())
                    .font(.subheadline)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
        }
        .rowCard()
        .accessibilityElement(children: .combine)
        .sheet(isPresented: $showingStyle) { StyleView() }
    }
}

/// Looks for the games, two kinds for every game (the card games share their card backs), each
/// game's kinds together in the order the Arcade lists the games. Each kind is headed by its games'
/// icons. Locked looks say what unlocks them.
struct StyleView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Each game's kinds of look together, in the order the Arcade lists the games (a kind shared by
    /// two games goes with the first).
    static var slotsInArcadeOrder: [CosmeticSlot] {
        let games = MiniGame.byPrice
        func place(_ slot: CosmeticSlot) -> Int { slot.games.compactMap { games.firstIndex(of: $0) }.min() ?? games.count }
        return CosmeticSlot.allCases.enumerated()
            .sorted { (place($0.element), $0.offset) < (place($1.element), $1.offset) }
            .map(\.element)
    }

    var body: some View {
        let game = store.game
        NavigationStack {
            List {
                Section {
                    Text("Arcade Rank and game achievements unlock new looks. They change how the games look, nothing else.")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                ForEach(Self.slotsInArcadeOrder) { slot in
                    Section {
                        ForEach(Cosmetic.all(in: slot)) { cosmetic in
                            row(cosmetic, game: game)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Text(verbatim: slot.games.map(\.icon).joined())
                                .accessibilityHidden(true)
                            Text(slot.name)
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

    private func lockedText(_ cosmetic: Cosmetic, game: GameState) -> String {
        if let achievement = game.achievementUnlock(cosmetic) {
            return String(localized: "Locked: reach \(game.unlockText(cosmetic)), or earn the \(achievement.name) achievement at \(achievement.tier)")
        }
        return String(localized: "Locked: reach \(game.unlockText(cosmetic))")
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
                        UnlockLine(symbol: "lock.fill", text: "Reach \(game.unlockText(cosmetic))")
                        if let achievement = game.achievementUnlock(cosmetic) {
                            // The other way in: a game achievement, earned in Trophies.
                            UnlockLine(symbol: "trophy.fill",
                                       text: "Or earn the \(achievement.name) achievement (\(achievement.tier))")
                        }
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
        .accessibilityValue(isEquipped ? "In use" : isUnlocked ? "" : lockedText(cosmetic, game: game))
        .accessibilityAddTraits(isEquipped ? .isSelected : [])
    }
}

/// One way to unlock a look: a small symbol right beside its text, so the line reads as one.
private struct UnlockLine: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .font(.footnote)
                .frame(width: 16)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .foregroundStyle(.subtext)
    }
}
