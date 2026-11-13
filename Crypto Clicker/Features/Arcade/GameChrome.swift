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

/// A game's levels (or waves) ten at a time, those reached filled in and every boss marked. With a
/// `selection`, each level reached is a button that picks where the next game starts, the pick
/// ringed, and arrows page through the tens.
struct LevelTrack: View {
    let best: Int
    let bossEvery: Int
    let tint: Color
    let bossSymbol: String
    /// "level" or "wave", for VoiceOver.
    let noun: String
    /// When the bosses come, for VoiceOver: "A boss every fifth level."
    let bossNote: String
    /// The level the next game starts at.
    var selection: Binding<Int>? = nil
    /// The first number of the ten on show; `nil` until the player pages.
    @State private var shownFirst: Int?

    /// The furthest level that can be picked: 1 before any game.
    private var reachable: Int { max(1, best) }

    private static func first(ofTenWith number: Int) -> Int { max(0, number - 1) / 10 * 10 + 1 }

    var body: some View {
        let first = shownFirst ?? Self.first(ofTenWith: selection?.wrappedValue ?? best)
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(first..<(first + 10), id: \.self) { number in
                    if let selection, number <= reachable {
                        Button { selection.wrappedValue = number } label: { circle(number) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(label(for: number))
                            .accessibilityAddTraits(selection.wrappedValue == number ? .isSelected : [])
                    } else {
                        circle(number)
                            .accessibilityHidden(selection != nil)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            if selection != nil && reachable > 10 {
                pager(first: first)
            }
        }
        .accessibilityElement(children: selection == nil ? .ignore : .contain)
        .accessibilityLabel(selection == nil ? summary : "")
    }

    private func circle(_ number: Int) -> some View {
        let reached = number <= best
        let isPicked = selection?.wrappedValue == number
        return ZStack {
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
        .overlay {
            if isPicked {
                Circle().strokeBorder(.white, lineWidth: 2.5)
                Circle().strokeBorder(tint, lineWidth: 1).padding(-2)
            }
        }
        .frame(maxWidth: 34)
        .aspectRatio(1, contentMode: .fit)
        .contentShape(.circle)
    }

    /// "‹ 11–20 ›": the tens up to the furthest level reached.
    private func pager(first: Int) -> some View {
        HStack(spacing: 18) {
            Button { shownFirst = max(1, first - 10) } label: { Image(systemName: "chevron.left") }
                .disabled(first == 1)
                .accessibilityLabel("Earlier \(noun)s")
            Text("\(noun.capitalized)s \(first)–\(first + 9)")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(.subtext)
            Button { shownFirst = first + 10 } label: { Image(systemName: "chevron.right") }
                .disabled(first + 10 > reachable)
                .accessibilityLabel("Later \(noun)s")
        }
        .font(.subheadline.weight(.bold))
        .tint(tint)
    }

    private func label(for number: Int) -> String {
        "\(noun.capitalized) \(number)" + (number % bossEvery == 0 ? ", boss" : "")
    }

    private var summary: String {
        best > 0 ? "Best \(noun) reached: \(best). \(bossNote)" : "No \(noun)s reached yet. \(bossNote)"
    }
}

/// What a game started further in pays, under its level track: "From level 6, points pay 40%".
enum StartPay {
    static func percent(start: Int, slope: Double) -> Int {
        Int((Tuning.startPayShare(level: start, slope: slope) * 100).rounded())
    }

    /// The line itself, or nothing from level 1 (which pays in full); `separator` goes before it.
    static func note(start: Int, noun: String, slope: Double, separator: String = "") -> String {
        guard start > 1 else { return "" }
        return separator + "from \(noun) \(start), points pay \(percent(start: start, slope: slope))%"
    }

    @ViewBuilder
    static func label(start: Int, noun: String, slope: Double) -> some View {
        if start > 1 {
            Label("From \(noun) \(start), points pay \(percent(start: start, slope: slope))%. \(noun.capitalized) 1 pays them all.",
                  systemImage: "info.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.subtext)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    /// What the game earned toward Arcade Rank.
    var xp: ArcadeAward? = nil

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
            ArcadeXPEarned(award: xp)
        }
    }
}

/// The Arcade XP a game or round earned, with where it came from ("Game played +10 · First today
/// +15") and a new rank when it brought one. Casino rounds past the day's XP say so instead. A solid
/// purple pill with white text, so it reads on any table: dark glass, green felt or a bright board.
struct ArcadeXPEarned: View {
    let award: ArcadeAward?
    /// One line, for the casino's result banners.
    var compact = false

    static let fill = LinearGradient(colors: [Color(red: 0.55, green: 0.18, blue: 0.80), Color(red: 0.38, green: 0.10, blue: 0.62)],
                                     startPoint: .top, endPoint: .bottom)

    var body: some View {
        if let award, award.xp > 0 {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                    Text("+\(CoinFormat.grouped(award.xp)) Arcade XP")
                    if award.rankedUp {
                        Text("· Rank \(award.rankAfter)!")
                    }
                }
                .font(compact ? .subheadline.weight(.heavy) : .headline.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, compact ? 12 : 14)
                .padding(.vertical, compact ? 5 : 7)
                .background(Self.fill, in: .capsule)
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                if !compact, award.parts.count > 1 {
                    Text(award.parts.map { "\($0.name) +\(CoinFormat.grouped($0.xp))" }.joined(separator: " · "))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.subtext)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        } else if award?.isCasinoCapReached == true {
            Label("No Arcade XP: today's casino XP is used up", systemImage: "gamecontroller")
                .font(compact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.black.opacity(0.45), in: .capsule)
        }
    }
}

// MARK: - Side columns

/// The columns beside a game's field: lives down the left, timed effects down the right. Narrow,
/// so a tall field gives up little width to them.
enum SideColumn {
    static let width: CGFloat = 28
    static let gap: CGFloat = 4
    /// The screen edge's margin beside the columns (the bars above and below keep `barInset` more).
    static let edge: CGFloat = 4
    static let barInset: CGFloat = 8
}

extension View {
    /// Puts columns beside a field, each as tall as the field: `leading` from the top down,
    /// `trailing` filling the height (so a lone effect's bar runs the field's full height).
    func sideColumns<Leading: View, Trailing: View>(@ViewBuilder leading: () -> Leading,
                                                    @ViewBuilder trailing: () -> Trailing) -> some View {
        padding(.horizontal, SideColumn.width + SideColumn.gap)
            .overlay(alignment: .topLeading) {
                leading()
                    .frame(width: SideColumn.width)
            }
            .overlay(alignment: .topTrailing) {
                trailing()
                    .frame(width: SideColumn.width)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
    }
}

/// Lives, one above another.
struct LivesColumn: View {
    let lives: Int
    let total: Int
    let symbol: String
    let emptySymbol: String
    let color: Color
    /// "3 lives left", for VoiceOver.
    let label: String

    var body: some View {
        VStack(spacing: total > 3 ? 7 : 10) {
            ForEach(0..<total, id: \.self) { life in
                Image(systemName: life < lives ? symbol : emptySymbol)
                    .foregroundStyle(life < lives ? AnyShapeStyle(color) : AnyShapeStyle(.subtext))
            }
        }
        .font(.title3)
        .padding(.vertical, 10)
        .frame(width: SideColumn.width)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

/// A timed effect: its symbol over a bar that empties from the top down as time runs out. One
/// without a timer shows `label` (such as "×3" balls) instead of the bar.
struct EffectMeter: View {
    let symbol: String
    let color: Color
    /// The share of the time left, or `nil` for an effect without a timer.
    let fraction: Double?
    var label: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            if let fraction {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .overlay(alignment: .bottom) {
                            Capsule()
                                .fill(color.gradient)
                                .frame(height: proxy.size.height * min(max(fraction, 0), 1))
                        }
                }
                .frame(width: 8)
                .frame(minHeight: 30, maxHeight: .infinity)
            } else if let label {
                Text(label)
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.vertical, 8)
        .frame(width: SideColumn.width)
        .frame(maxHeight: fraction == nil ? nil : .infinity)
        .glassEffect(.regular, in: .capsule)
    }
}

/// The timed effects running, in one column: their symbols at the top, then a bar each, side by
/// side and as tall as the column, emptying from the top as their time runs out. The bars share a
/// scale (the longest of the effects' full times), so it reads at a glance which ends first and
/// how far apart they are.
struct EffectBars: View {
    struct Effect: Identifiable {
        let id: String
        let symbol: String
        let color: Color
        let name: String
        /// Seconds left, and the effect's full time.
        let secondsLeft: Double
        let duration: Double
    }

    let effects: [Effect]

    var body: some View {
        let scale = max(effects.map(\.duration).max() ?? 1, 0.001)
        let count = CGFloat(max(1, effects.count))
        let spacing: CGFloat = effects.count > 2 ? 2 : 4
        let barWidth = min(8, (SideColumn.width - 10 - spacing * (count - 1)) / count)
        VStack(spacing: 6) {
            ForEach(effects) { effect in
                Image(systemName: effect.symbol)
                    .font(effects.count > 2 ? .caption.weight(.bold) : .subheadline.weight(.bold))
                    .foregroundStyle(effect.color)
            }
            HStack(spacing: spacing) {
                ForEach(effects) { effect in
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .overlay(alignment: .bottom) {
                                Capsule()
                                    .fill(effect.color.gradient)
                                    .frame(height: proxy.size.height * min(max(effect.secondsLeft / scale, 0), 1))
                            }
                    }
                    .frame(width: barWidth)
                }
            }
            .frame(minHeight: 30, maxHeight: .infinity)
        }
        .padding(.vertical, 8)
        .frame(width: SideColumn.width)
        .frame(maxHeight: .infinity)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(effects.map { "\($0.name), \(Int($0.secondsLeft.rounded(.up))) seconds left" }.joined(separator: "; "))
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
    /// The backdrop picked in Style: purple velvet, a ruby or an emerald lounge.
    var look = Cosmetic.slotsVelvet

    var body: some View {
        let colors = look.slotsBackdropColors
        RadialGradient(colors: [colors.center, colors.edge], center: .top, startRadius: 40, endRadius: 760)
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

/// The casino's bet: the token (picked from a sheet showing every token's artwork) and how many.
struct TokenBetControls: View {
    @Binding var token: TokenID
    /// The bet per line.
    @Binding var bet: Int
    let counts: [TokenID: Int]
    /// Lines the bet is placed on: the stake is the bet times this.
    var lines = 1
    /// Disabled while a spin is revealed: the counts shown then are only for display.
    @Environment(\.isEnabled) private var isEnabled
    @State private var showsPicker = false

    var body: some View {
        let owned = counts[token, default: 0]
        HStack(spacing: 12) {
            Button {
                showsPicker = true
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
            .accessibilityHint("Choose another token")
            Spacer(minLength: 0)
            Stepper(value: $bet, in: 1...max(1, owned / lines)) {
                Text(lines == 1 ? "Bet \(CoinFormat.grouped(bet))" : "Bet \(CoinFormat.grouped(bet)) × \(lines)")
                    .font(.headline.monospacedDigit())
            }
            .accessibilityValue(lines == 1 ? "\(bet)" : "\(bet) a line, \(bet * lines) in all")
            .fixedSize()
        }
        .sheet(isPresented: $showsPicker) {
            TokenPickerSheet(token: $token, counts: counts)
        }
        .onAppear(perform: fitBetToWallet)
        .onChange(of: owned) { _, _ in fitBetToWallet() }
        .onChange(of: token) { _, _ in fitBetToWallet() }
        .onChange(of: isEnabled) { _, _ in fitBetToWallet() }
        .onChange(of: lines) { _, _ in fitBetToWallet() }
    }

    /// Lowers the bet to what the wallet holds, but never while the controls are disabled.
    private func fitBetToWallet() {
        guard isEnabled else { return }
        bet = min(bet, max(1, counts[token, default: 0] / lines))
    }
}

/// Every token to bet with, as tiles with its artwork, how many you hold and what one is worth.
/// Tokens you hold none of are dimmed (the Shop sells them); the one in use is ringed.
private struct TokenPickerSheet: View {
    @Binding var token: TokenID
    let counts: [TokenID: Int]
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(TokenID.allCases) { option in
                        Button {
                            token = option
                            dismiss()
                        } label: {
                            TokenTile(token: option, owned: counts[option, default: 0],
                                      price: store.market.quote(option).price, isSelected: option == token)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                if TokenID.allCases.contains(where: { counts[$0, default: 0] == 0 }) {
                    Label("Buy more kinds in the Shop's Tokens page.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.subtext)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Choose a Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// One token in the picker.
private struct TokenTile: View {
    let token: TokenID
    let owned: Int
    let price: Double
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            TokenImage(token: token, size: 48)
            Text(token.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(owned > 0 ? "\(CoinFormat.grouped(owned)) \(token.ticker)" : "None yet")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(owned > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.subtext))
            Text("\(CoinFormat.short(price)) coins each")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(.fill.tertiary, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .padding(8)
            }
        }
        .opacity(owned > 0 || isSelected ? 1 : 0.5)
        .contentShape(.rect(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(token.name), \(owned) owned, \(CoinFormat.short(price)) coins each")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
