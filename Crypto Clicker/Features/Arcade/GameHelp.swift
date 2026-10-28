import SwiftUI
import CryptoClickerKit

// How to Play for every mini-game: a sheet with the full rules (from `MiniGame.guide` in the kit),
// a button for it in each game's navigation bar, the sheet opening by itself the first time a game
// is opened, and a pause card that keeps the rules a tap away.

extension View {
    /// Adds the How to Play button and sheet. The sheet also opens by itself the first time the
    /// game is opened, before any round starts. `onOpen` runs as it opens, so a game in progress
    /// can pause (nothing is reset). `isEnabled` turns the button off, for moments a game can't stop.
    func gameHelp(_ game: MiniGame, isPresented: Binding<Bool>, isEnabled: Bool = true,
                  onOpen: @escaping () -> Void = {}) -> some View {
        modifier(GameHelp(game: game, isPresented: isPresented, isEnabled: isEnabled, onOpen: onOpen))
    }
}

private struct GameHelp: ViewModifier {
    let game: MiniGame
    @Binding var isPresented: Bool
    let isEnabled: Bool
    let onOpen: () -> Void
    @AppStorage private var hasSeenHelp: Bool

    init(game: MiniGame, isPresented: Binding<Bool>, isEnabled: Bool, onOpen: @escaping () -> Void) {
        self.game = game
        _isPresented = isPresented
        self.isEnabled = isEnabled
        self.onOpen = onOpen
        _hasSeenHelp = AppStorage(wrappedValue: false, Preferences.helpSeenKey(game))
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("How to Play", systemImage: "questionmark.circle") {
                        onOpen()
                        isPresented = true
                    }
                    .disabled(!isEnabled)
                }
            }
            .sheet(isPresented: $isPresented, onDismiss: { hasSeenHelp = true }) {
                GameHelpView(game: game)
            }
            .task {
                guard !hasSeenHelp else { return }
                // After the screen has slid in.
                try? await Task.sleep(for: .milliseconds(450))
                if !hasSeenHelp && isEnabled {
                    onOpen()
                    isPresented = true
                }
            }
    }
}

/// The full rules for one game.
struct GameHelpView: View {
    let game: MiniGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let guide = game.guide
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        Text(game.icon)
                            .font(.system(size: 38))
                            .accessibilityHidden(true)
                        Text(guide.objective)
                            .font(.body.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
                Section("Controls") {
                    ForEach(guide.controls, id: \.self) { line in
                        Label(line, systemImage: "hand.point.up.left.fill")
                    }
                }
                Section("Scoring") {
                    ForEach(guide.scoring, id: \.self) { line in
                        Label(line, systemImage: "star.fill")
                    }
                }
                if !guide.items.isEmpty {
                    Section("Specials and Hazards") {
                        ForEach(guide.items) { item in
                            HStack(spacing: 14) {
                                GuideItemIcon(item: item, tint: game.color)
                                    .frame(width: 48, height: 48)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.headline)
                                    Text(item.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.subtext)
                                }
                            }
                            .padding(.vertical, 2)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                Section("How It Ends") {
                    Label(guide.ending, systemImage: "flag.checkered")
                }
                Section("Tips") {
                    ForEach(guide.tips, id: \.self) { tip in
                        Label(tip, systemImage: "lightbulb.fill")
                    }
                }
            }
            .labelStyle(HelpLabelStyle(tint: game.color))
            .navigationTitle("How to Play \(game.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// A list line with its symbol at the top, so long lines wrap neatly beside it.
private struct HelpLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            configuration.icon
                .font(.footnote)
                .foregroundStyle(tint.mix(with: .white, by: 0.2))
                .frame(width: 20)
                .accessibilityHidden(true)
            configuration.title
        }
    }
}

/// The picture for a special piece or hazard: the real piece where the game draws one.
struct GuideItemIcon: View {
    let item: MiniGameGuide.Item
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            Group {
                if let look = PumpPiece.Look(guideID: item.id) {
                    PumpPiece(look: look, size: size * 1.35)
                } else if let special = TokenSwapSpecialIcon(guideID: item.id) {
                    special
                } else if let bubble = BubbleSpecialBadge(guideID: item.id) {
                    bubble
                        .padding(size * 0.08)
                } else {
                    Image(systemName: item.symbol)
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: size, height: size)
                        .background(tint.gradient, in: .circle)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// "Paused", with the game's goal and controls, and the full rules a tap away.
struct PausedCard: View {
    let game: MiniGame
    let resume: () -> Void
    let showHelp: () -> Void

    var body: some View {
        let guide = game.guide
        VStack(spacing: 12) {
            Label("Paused", systemImage: "pause.circle.fill")
                .font(.title2.bold())
            Text(guide.objective)
                .font(.subheadline)
                .foregroundStyle(.subtext)
            Text(guide.controlHint)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.subtext)
            ViewThatFits {
                HStack(spacing: 10) { buttons }
                VStack(spacing: 8) { buttons }
            }
            .font(.headline)
            .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
        .padding(20)
        .frame(maxWidth: 360)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .padding(16)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var buttons: some View {
        Button("Rules", systemImage: "questionmark.circle", action: showHelp)
            .buttonStyle(.glass)
        Button("Resume", systemImage: "play.fill", action: resume)
            .buttonStyle(.glassProminent)
    }
}

/// The controls in a few words, under a board whose gestures aren't on screen.
struct ControlHint: View {
    let game: MiniGame

    var body: some View {
        Label(game.guide.controlHint, systemImage: "hand.point.up.left")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.subtext)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .accessibilityLabel("Controls: \(game.guide.controlHint)")
    }
}
