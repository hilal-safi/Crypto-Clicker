import SwiftUI
import CryptoClickerKit

/// The screens inside Token Swap, opened from its hub (or straight from the daily challenge).
enum TokenSwapRoute: Hashable {
    case levels
    case level(Int)
    case daily(String)
    case classic
}

/// Where Token Swap opens: Levels, the daily puzzle and Classic, with the specials explained.
struct TokenSwapView: View {
    @Environment(GameStore.self) private var store
    @State private var showingHelp = false

    var body: some View {
        let progress = store.game.tokenSwap
        let today = store.today
        let next = TokenSwapLevel.number(progress.nextLevel) ?? TokenSwapLevel.all[0]
        let daily = TokenSwapLevel.daily(day: today)
        let allWon = progress.levelsWon == TokenSwapLevel.all.count
        ScrollView {
            VStack(spacing: 14) {
                ModeCard(icon: "square.grid.3x3.fill", title: "Levels",
                         status: "\(progress.levelsWon) of \(TokenSwapLevel.all.count) won · \(progress.totalStars) of \(TokenSwapLevel.all.count * 3) stars",
                         detail: allWon ? "Every level won. Replay any of them for three stars."
                                        : "Next: Level \(next.id), \(next.name). \(next.goals.map(\.description).joined(separator: ", ")) in \(next.moves) moves.",
                         note: "Stars pay coins the first time you earn them.") {
                    NavigationLink(value: TokenSwapRoute.level(next.id)) {
                        Label(allWon ? "Replay Level \(next.id)" : "Play Level \(next.id)", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    NavigationLink(value: TokenSwapRoute.levels) {
                        Label("All Levels", systemImage: "square.grid.2x2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
                ModeCard(icon: "calendar", title: "Daily Puzzle",
                         status: progress.hasWonDaily(day: today) ? "Solved today" : "Win for \(CoinFormat.short(store.game.tokenSwapDailyReward)) coins",
                         detail: "\(daily.name): \(daily.goals.map(\.description).joined(separator: ", ")) in \(daily.moves) moves. The same board for everyone today.",
                         note: progress.hasWonDaily(day: today) ? "Play again for fun; the reward is once a day." : nil) {
                    NavigationLink(value: TokenSwapRoute.daily(today)) {
                        Label(progress.hasWonDaily(day: today) ? "Play Again" : "Play Today's Puzzle", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                ModeCard(icon: "timer", title: "Classic",
                         status: store.game.stats.tokenSwapBestScore > 0 ? "Best \(CoinFormat.grouped(store.game.stats.tokenSwapBestScore))" : "A minute on the clock",
                         detail: "Score as much as you can in a minute. Every point pays coins.", note: nil) {
                    NavigationLink(value: TokenSwapRoute.classic) {
                        Label("Play Classic", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                SpecialsGuide()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background { AppBackground(tint: MiniGame.tokenSwap.color) }
        .navigationTitle("Token Swap")
        .navigationBarTitleDisplayMode(.inline)
        .gameHelp(.tokenSwap, isPresented: $showingHelp)
    }
}

/// One way to play, with its buttons.
private struct ModeCard<Buttons: View>: View {
    let icon: String
    let title: String
    let status: String
    let detail: String
    let note: String?
    @ViewBuilder let buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(MiniGame.tokenSwap.color.gradient, in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.bold())
                    Text(status)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.subtext)
                .fixedSize(horizontal: false, vertical: true)
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.subtext)
            }
            ViewThatFits {
                HStack(spacing: 10) { buttons }
                VStack(spacing: 8) { buttons }
            }
            .font(.headline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22)
        .accessibilityElement(children: .contain)
    }
}

/// The four specials, drawn as they look on the board.
struct SpecialsGuide: View {
    private static let rows: [(power: TokenSwapGame.Power, kind: Int, title: String, detail: String)] = [
        (.propeller, 2, "Propeller", "A 2×2 square. Clears beside it, then flies to what you need."),
        (.rocketAcross, 0, "Rocket", "Four in a row. Four across clears its row; four down its column."),
        (.bomb, 1, "Bomb", "Five in an L or T. Clears the 5×5 square around it."),
        (.colorClear, 0, "Color Clear", "Five in a row. Swap it with a token to clear that whole color."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Specials")
                .font(.headline)
            ForEach(Self.rows, id: \.title) { row in
                HStack(spacing: 12) {
                    TokenSwapTileView(tile: TokenSwapGame.Tile(id: 0, kind: row.power == .colorClear ? nil : row.kind, power: row.power),
                                      size: 46, reduceMotion: true)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.subheadline.weight(.bold))
                        Text(row.detail)
                            .font(.footnote)
                            .foregroundStyle(.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Text("A special goes off when it's matched, blasted, or swapped with any neighbor. Swap two specials together for a bigger combination.")
                .font(.footnote)
                .foregroundStyle(.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22)
    }
}

/// Every level, with its stars; levels open one at a time.
struct TokenSwapLevelsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let progress = store.game.tokenSwap
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(progress.totalStars) of \(TokenSwapLevel.all.count * 3) stars")
                    .font(.headline)
                    .foregroundStyle(.subtext)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(TokenSwapLevel.all) { level in
                        let isOpen = progress.isUnlocked(level.id)
                        NavigationLink(value: TokenSwapRoute.level(level.id)) {
                            LevelTile(level: level, stars: progress.stars(for: level.id), isOpen: isOpen)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isOpen)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background { AppBackground(tint: MiniGame.tokenSwap.color) }
        .navigationTitle("Levels")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LevelTile: View {
    let level: TokenSwapLevel
    let stars: Int
    let isOpen: Bool

    var body: some View {
        VStack(spacing: 4) {
            if isOpen {
                Text("\(level.id)")
                    .font(.title.bold().monospacedDigit())
            } else {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .frame(height: 34)
            }
            Text(level.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(height: 30)
            StarRow(stars: stars, size: 13)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(difficultyColor.opacity(isOpen ? 0.22 : 0.08), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(difficultyColor.opacity(isOpen ? 0.6 : 0.2), lineWidth: 1)
        }
        .opacity(isOpen ? 1 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level.id), \(level.name), \(level.difficulty.name)")
        .accessibilityValue(isOpen ? "\(stars) of 3 stars" : "Locked: win level \(level.id - 1) first")
    }

    private var difficultyColor: Color {
        switch level.difficulty {
        case .easy: Theme.gain
        case .medium: Theme.gold
        case .hard: Theme.loss
        }
    }
}

/// Three stars, filled up to `stars`.
struct StarRow: View {
    let stars: Int
    var size: CGFloat = 16
    /// Lights the stars one after another.
    var animated = false
    @State private var shown = 0

    var body: some View {
        HStack(spacing: size * 0.25) {
            ForEach(1...3, id: \.self) { star in
                let lit = star <= (animated ? shown : stars)
                Image(systemName: lit ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(lit ? Theme.gold : .secondary)
                    .scaleEffect(lit && animated ? 1.15 : 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) of 3 stars")
        .task(id: stars) {
            guard animated else { return }
            shown = 0
            for star in 0...stars {
                withAnimation(.spring(duration: 0.35, bounce: 0.5)) { shown = star }
                try? await Task.sleep(for: .milliseconds(320))
            }
        }
    }
}

/// A goal's picture: the token it asks for, or the obstacle or special.
struct GoalIcon: View {
    let goal: TokenSwapGame.Goal
    var size: CGFloat = 22

    var body: some View {
        switch goal {
        case .tokens(let kind, _):
            TokenImage(token: TokenSwapPalette.token(kind), size: size)
        case .gold:
            GoldBarView(size: size * 1.2)
                .frame(width: size, height: size)
        default:
            Image(systemName: symbol)
                .font(.system(size: size * 0.7, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
        }
    }

    private var symbol: String {
        switch goal {
        case .ice: "snowflake"
        case .chains: "link"
        case .crates: "shippingbox.fill"
        case .specials(let kind, _):
            switch kind {
            case .rocket: "arrow.left.and.right"
            case .bomb: "flame.fill"
            case .propeller: "fanblades.fill"
            case .colorClear: "sparkles"
            case .any: "star.fill"
            }
        case .score: "star.circle.fill"
        case .tokens, .gold: "circle"
        }
    }

    private var color: Color {
        switch goal {
        case .ice: Color(red: 0.55, green: 0.85, blue: 1)
        case .chains: Color(white: 0.8)
        case .crates: Color(red: 0.75, green: 0.5, blue: 0.25)
        default: Theme.gold
        }
    }
}
