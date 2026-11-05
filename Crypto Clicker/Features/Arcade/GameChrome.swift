import SwiftUI
import UIKit
import CryptoClickerKit

// Pieces shared by the mini-game screens.

extension View {
    /// Shared behavior for a game screen: toasts and airdrops wait until it closes, and games
    /// played with drags turn off iOS 26's swipe-back from anywhere, so a drag is never taken as
    /// "back". The swipe from the left edge still goes back.
    func gameScreen(blocksSwipeBack: Bool = false) -> some View {
        modifier(GameScreen(blocksSwipeBack: blocksSwipeBack))
    }
}

private struct GameScreen: ViewModifier {
    let blocksSwipeBack: Bool
    @Environment(GameStore.self) private var store

    func body(content: Content) -> some View {
        content
            .background {
                if blocksSwipeBack {
                    SwipeBackBlocker()
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                }
            }
            .onAppear { store.isInGame = true }
            .onDisappear { store.isInGame = false }
    }
}

extension View {
    /// What every action game does around a game in progress: it pauses when the app leaves the
    /// screen, holds the run as the app goes to the background (so it's paid even if iOS closes the
    /// app), lets go of it on the way back, and ends the game, paying what it scored, when the
    /// screen goes away. Swipe-back from anywhere is off, so drags on the board stay in the game.
    ///
    /// - Parameters:
    ///   - pause: Pauses the game (2048, with nothing running, doesn't need to).
    ///   - heldRun: The run to hold in the background, or `nil` when there's nothing to pay for
    ///     (a Token Swap level, say).
    ///   - leave: Ends the game as the screen goes away.
    func arcadeLifecycle(isPlaying: Bool, pause: @escaping () -> Void, heldRun: @escaping () -> ArcadeRun?,
                         leave: @escaping () -> Void) -> some View {
        modifier(ArcadeLifecycle(isPlaying: isPlaying, pause: pause, heldRun: heldRun, leave: leave))
    }
}

private struct ArcadeLifecycle: ViewModifier {
    let isPlaying: Bool
    let pause: () -> Void
    let heldRun: () -> ArcadeRun?
    let leave: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                guard isPlaying else { return }
                switch phase {
                case .active:
                    store.releaseArcadeRun()
                case .background:
                    pause()
                    if let run = heldRun() { store.holdArcadeRun(run) }
                default:
                    pause()
                }
            }
            .onDisappear {
                if isPlaying { leave() }
            }
            .gameScreen(blocksSwipeBack: true)
    }
}

/// Switches off iOS 26's swipe-back from anywhere while a game is on screen, so a drag across the
/// board is never taken as "back". The swipe from the left edge still goes back (the game ends
/// and pays what it scored, as with the back button), and everything is restored when the game
/// closes.
private struct SwipeBackBlocker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            setSwipeBack(enabled: false)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            setSwipeBack(enabled: true)
        }

        private func setSwipeBack(enabled: Bool) {
            guard let navigation = navigationController else { return }
            navigation.interactivePopGestureRecognizer?.isEnabled = true
            navigation.interactiveContentPopGestureRecognizer?.isEnabled = enabled
        }
    }
}

/// A labelled number in a game's score bar. A literal title is looked up in the String Catalog;
/// text worked out in code shows as it is.
struct GameStat: View {
    let title: Text
    let value: String

    init(title: LocalizedStringKey, value: String) {
        self.title = Text(title)
        self.value = value
    }

    @_disfavoredOverload
    init<Title: StringProtocol>(title: Title, value: String) {
        self.title = Text(title)
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            title
                .font(.footnote.weight(.heavy))
                .foregroundStyle(Theme.accent)
                .textCase(.uppercase)
            Text(value)
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// The compact glass strip that holds a game's score, backed so the board behind doesn't
    /// wash the numbers out.
    func scoreBar() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .background(.background.opacity(0.45), in: .rect(cornerRadius: 18))
    }
}

/// A round Liquid Glass game control.
struct ArcadeButton: View {
    let title: String
    let systemImage: String
    var size: CGFloat = 58
    var repeats = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .bold))
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
        // Plain style plus a glass circle keeps the button exactly `size` across, so it fits
        // the narrow columns beside a game board.
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .buttonRepeatBehavior(repeats ? .enabled : .disabled)
        .accessibilityLabel(title)
    }
}

/// The start and game-over card for arcade games: wide, over a dimmed screen. On a screen too
/// short for it (a small phone, or large text), the card scrolls.
struct GamePanel<Content: View>: View {
    let title: Text
    let buttonTitle: Text
    let action: () -> Void
    let content: Content

    init(title: LocalizedStringKey, buttonTitle: LocalizedStringKey, action: @escaping () -> Void,
         @ViewBuilder content: () -> Content) {
        self.title = Text(title)
        self.buttonTitle = Text(buttonTitle)
        self.action = action
        self.content = content()
    }

    /// A title worked out in code, shown as it is.
    @_disfavoredOverload
    init<Title: StringProtocol>(title: Title, buttonTitle: LocalizedStringKey, action: @escaping () -> Void,
                                @ViewBuilder content: () -> Content) {
        self.title = Text(title)
        self.buttonTitle = Text(buttonTitle)
        self.action = action
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            ViewThatFits(in: .vertical) {
                card
                ScrollView {
                    card
                        .padding(.vertical, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var card: some View {
        VStack(spacing: 16) {
            title
                .font(.largeTitle.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            content
            Button(action: action) {
                Label { buttonTitle } icon: { Image(systemName: "play.fill") }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: 440)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
        // A backing behind the glass, so text on the card stays crisp over a busy board.
        .background(.background.opacity(0.6), in: .rect(cornerRadius: 30))
        .padding(.horizontal, 16)
    }
}

/// One way to play on a game's start screen (every action game has one): an icon, a title with a
/// status line, what it is, an optional note, and its buttons.
struct ModeCard<Buttons: View>: View {
    let tint: Color
    let icon: String
    let title: Text
    let status: String
    let detail: Text
    let note: String?
    let buttons: Buttons

    /// A title and detail written out, looked up in the String Catalog.
    init(tint: Color, icon: String, title: LocalizedStringKey, status: String, detail: LocalizedStringKey, note: String?,
         @ViewBuilder buttons: () -> Buttons) {
        self.tint = tint
        self.icon = icon
        self.title = Text(title)
        self.status = status
        self.detail = Text(detail)
        self.note = note
        self.buttons = buttons()
    }

    /// A title and detail worked out in code, shown as they are.
    @_disfavoredOverload
    init<Title: StringProtocol, Detail: StringProtocol>(tint: Color, icon: String, title: Title, status: String, detail: Detail,
                                                        note: String?, @ViewBuilder buttons: () -> Buttons) {
        self.tint = tint
        self.icon = icon
        self.title = Text(title)
        self.status = status
        self.detail = Text(detail)
        self.note = note
        self.buttons = buttons()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(tint.gradient, in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(.title3.bold())
                    Text(status)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            detail
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            if let note {
                Label(note, systemImage: "info.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
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

/// Ten levels (or waves) at a time on a game's start screen: the ones reached so far lit in the
/// game's color, and every boss marked with its symbol.
struct LevelTrack: View {
    let best: Int
    let bossEvery: Int
    let tint: Color
    let bossSymbol: String
    /// "level" or "wave", for VoiceOver.
    let noun: String
    /// When the bosses come, for VoiceOver: "A boss every fifth level."
    let bossNote: String

    var body: some View {
        let first = max(0, best - 1) / 10 * 10 + 1
        HStack(spacing: 4) {
            ForEach(first..<(first + 10), id: \.self) { number in
                let reached = number <= best
                ZStack {
                    Circle()
                        .fill(reached ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
                    if number % bossEvery == 0 {
                        Image(systemName: bossSymbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(reached ? .white : Theme.gold)
                    } else {
                        Text("\(number)")
                            .font(.footnote.weight(.bold).monospacedDigit())
                            .foregroundStyle(reached ? .white : .primary)
                            .minimumScaleFactor(0.6)
                    }
                }
                .frame(maxWidth: 34)
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(best > 0 ? "Best \(noun) reached: \(best). \(bossNote)" : "No \(noun)s reached yet. \(bossNote)")
    }
}

/// What a finished arcade game earned. Everything is large enough to read at a glance: the
/// panel has room to spare.
struct GameOverSummary: View {
    let score: Int
    let isNewBest: Bool
    let best: Int
    let reward: Double
    var details: [String] = []
    /// Set when this game completed the daily challenge.
    var challenge: ChallengeReward? = nil

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                Text(CoinFormat.grouped(score))
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("points")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.subtext)
            }
            if isNewBest {
                Label("New best! +\(CoinFormat.percent(Tuning.newBestBonus)) coins", systemImage: "star.fill")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.accent)
            } else {
                Text("Best \(CoinFormat.grouped(best))")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.subtext)
            }
            ForEach(details, id: \.self) { detail in
                Text(detail)
                    .font(.headline)
                    .foregroundStyle(.subtext)
            }
            if let challenge {
                ChallengeCompleteBadge(reward: challenge)
            }
            HStack(spacing: 8) {
                Text("You earned")
                    .font(.title3.weight(.semibold))
                CoinAmount(amount: reward, font: .title.bold(), iconSize: 30)
            }
            .padding(.top, 6)
        }
    }
}

/// "Daily challenge complete", with what it paid (and the week's bonus when it came too).
struct ChallengeCompleteBadge: View {
    let reward: ChallengeReward

    var body: some View {
        VStack(spacing: 4) {
            Label("Daily challenge complete!", systemImage: "target")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            Text(reward.weeklyBonus > 0
                 ? "+\(CoinFormat.short(reward.coins)) coins, and +\(CoinFormat.short(reward.weeklyBonus)) for the week's \(Tuning.weeklyChallengeGoal)th"
                 : "+\(CoinFormat.short(reward.coins)) coins")
                .font(.body.weight(.semibold))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Theme.accent.opacity(0.16), in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// The intro on a game's start card: the best score and anything particular to this round. The
/// rules themselves are a tap away (the ? in the navigation bar, and the pause card), so they
/// aren't repeated here.
struct GameIntro: View {
    let best: Int
    /// Another line under the best score: a record.
    var note: String? = nil
    /// What's particular to this mode or day (today's pieces, a Sprint's target, a bonus).
    var detail: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            if best > 0 {
                Label("Best \(CoinFormat.grouped(best))", systemImage: "trophy.fill")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.accent)
            }
            if let note {
                Text(note)
                    .font(.headline)
            }
            if let detail {
                Text(detail)
                    .font(.body.weight(.medium))
            }
        }
    }
}

// MARK: - Casino

/// Green baize for the card table.
struct FeltBackground: View {
    /// The felt picked in Style.
    var look: Cosmetic = .feltGreen

    var body: some View {
        RadialGradient(colors: [look.feltColors.center, look.feltColors.edge],
                       center: .center, startRadius: 30, endRadius: 560)
            .overlay {
                // A faint weave, so the felt doesn't look like flat plastic.
                Canvas { context, size in
                    var path = Path()
                    stride(from: 0.0, through: size.width + size.height, by: 6).forEach { offset in
                        path.move(to: CGPoint(x: offset, y: 0))
                        path.addLine(to: CGPoint(x: offset - size.height, y: size.height))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 1)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// Deep velvet for the slot machine.
struct VelvetBackground: View {
    var body: some View {
        RadialGradient(colors: [Color(red: 0.36, green: 0.12, blue: 0.48), Color(red: 0.09, green: 0.03, blue: 0.16)],
                       center: .top, startRadius: 40, endRadius: 760)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// Picks the token to bet and how many. Token counts come from the caller, so a game can hold
/// them steady while an animation plays out.
/// Real bets or practice chips, for the casino games. Hidden mid-round.
struct CasinoModePicker: View {
    @Binding var isPracticing: Bool

    var body: some View {
        Picker("Mode", selection: $isPracticing) {
            Text("Play for Tokens").tag(false)
            Text("Practice").tag(true)
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Practice plays with chips: no tokens, coins or statistics change")
    }
}

/// Practice chips: the stack, and the bet to play.
struct PracticeBetControls: View {
    let chips: PracticeChips
    @Binding var bet: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Label("\(CoinFormat.grouped(chips.balance)) chips", systemImage: "circle.hexagongrid.circle.fill")
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
                Text("No tokens, coins or stats change")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 0)
            Picker("Bet", selection: $bet) {
                ForEach(PracticeChips.bets, id: \.self) { amount in
                    Text("\(amount)").tag(amount)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityLabel("Practice bet")
        }
    }
}

struct TokenBetControls: View {
    @Binding var token: TokenID
    @Binding var bet: Int
    let counts: [TokenID: Int]
    /// Disabled while a spin is revealed: the counts shown then are only for display.
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let owned = counts[token, default: 0]
        HStack(spacing: 12) {
            Menu {
                Picker("Token", selection: $token) {
                    ForEach(TokenID.allCases) { token in
                        Text("\(token.name) · \(CoinFormat.grouped(counts[token, default: 0]))").tag(token)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    TokenImage(token: token, size: 28)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(token.ticker)
                            .font(.headline)
                        Text("\(CoinFormat.grouped(owned)) owned")
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundStyle(.subtext)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Token: \(token.name), \(owned) owned")
            Spacer(minLength: 0)
            Stepper(value: $bet, in: 1...max(1, owned)) {
                Text("Bet \(CoinFormat.grouped(bet))")
                    .font(.headline.monospacedDigit())
            }
            .fixedSize()
        }
        .onAppear(perform: fitBetToWallet)
        .onChange(of: owned) { _, _ in fitBetToWallet() }
        .onChange(of: token) { _, _ in fitBetToWallet() }
        .onChange(of: isEnabled) { _, _ in fitBetToWallet() }
    }

    /// Lowers the bet to what the wallet holds, but never while the controls are disabled.
    private func fitBetToWallet() {
        guard isEnabled else { return }
        bet = min(bet, max(1, counts[token, default: 0]))
    }
}
