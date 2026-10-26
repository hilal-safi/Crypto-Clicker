import SwiftUI
import UIKit
import CryptoClickerKit

// Pieces shared by the mini-game screens.

extension View {
    /// Shared behavior for a game screen: toasts and airdrops wait until it closes, and games
    /// played with drags turn off swipe-to-go-back so a drag is never taken as "back".
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

/// Switches off the navigation swipe-back gestures (from the edge, and iOS 26's swipe from
/// anywhere) while a game is on screen. The back button still works, and the gestures come
/// back as soon as the game closes.
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
            navigation.interactivePopGestureRecognizer?.isEnabled = enabled
            navigation.interactiveContentPopGestureRecognizer?.isEnabled = enabled
        }
    }
}

/// A labelled number in a game's score bar.
struct GameStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.subtext)
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
    /// The compact glass strip that holds a game's score.
    func scoreBar() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
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

/// The start and game-over card for arcade games: wide, over a dimmed screen.
struct GamePanel<Content: View>: View {
    let title: String
    let buttonTitle: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text(title)
                    .font(.largeTitle.bold())
                content
                Button(action: action) {
                    Label(buttonTitle, systemImage: "play.fill")
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
            .padding(.horizontal, 16)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

/// What a finished arcade game earned.
struct GameOverSummary: View {
    let score: Int
    let isNewBest: Bool
    let best: Int
    let reward: Double
    var details: [String] = []

    var body: some View {
        VStack(spacing: 8) {
            Text(CoinFormat.grouped(score))
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text("points")
                .font(.headline)
                .foregroundStyle(.subtext)
            if isNewBest {
                Label("New best!", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
            } else {
                Text("Best \(CoinFormat.grouped(best))")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            ForEach(details, id: \.self) { detail in
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            HStack(spacing: 6) {
                Text("You earned")
                    .font(.headline)
                CoinAmount(amount: reward, font: .title2.bold(), iconSize: 26)
            }
            .padding(.top, 6)
        }
    }
}

/// The intro on a game's start card.
struct GameIntro: View {
    let best: Int
    let howTo: String

    var body: some View {
        VStack(spacing: 8) {
            if best > 0 {
                Text("Best \(CoinFormat.grouped(best))")
                    .font(.headline)
                    .foregroundStyle(.subtext)
            }
            Text(howTo)
                .font(.subheadline)
                .foregroundStyle(.subtext)
        }
    }
}

// MARK: - Casino

/// Green baize for the card table.
struct FeltBackground: View {
    var body: some View {
        RadialGradient(colors: [Color(red: 0.07, green: 0.47, blue: 0.27), Color(red: 0.02, green: 0.20, blue: 0.11)],
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
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.subtext)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.subtext)
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
