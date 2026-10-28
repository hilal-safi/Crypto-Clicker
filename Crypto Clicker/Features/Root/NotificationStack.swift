import SwiftUI
import CryptoClickerKit

/// Airdrops and toasts, floating over every tab.
struct NotificationStack: View {
    @Environment(GameStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 8) {
            if let airdrop = store.airdrop, !store.isInGame {
                AirdropButton(airdrop: airdrop) { store.claimAirdrop() }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let toast = store.toasts.first, !store.isInGame {
                ToastView(toast: toast)
                    .id(toast.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { store.dismiss(toast) }
                    .task(id: toast.id) {
                        do {
                            try await Task.sleep(for: .seconds(2.5))
                            store.dismiss(toast)
                        } catch {}
                    }
            }
        }
        .padding(.horizontal, 16)
        // Below the navigation bar (and the iPad tab bar), so toasts never cover toolbar buttons.
        .padding(.top, sizeClass == .regular ? 110 : 52)
        .animation(.spring(duration: 0.4), value: store.toasts.first?.id)
        .animation(.spring(duration: 0.4), value: store.airdrop?.id)
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.icon)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.headline)
                Text(toast.message)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 440)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// A falling airdrop: catch it before it goes for coins or a Bull Run. A rare whale is bigger,
/// bluer and worth up to an hour of income.
struct AirdropButton: View {
    let airdrop: Airdrop
    let action: () -> Void
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var appeared = false

    var body: some View {
        let isWhale = airdrop.kind == .whale
        Button(action: action) {
            HStack(spacing: 12) {
                Text(isWhale ? "🐋" : "🪂")
                    .font(isWhale ? .largeTitle : .title)
                    .rotationEffect(.degrees(appeared ? 8 : -8))
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: appeared)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isWhale ? "Whale airdrop!" : "Airdrop incoming!")
                        .font(.headline)
                    Text(isWhale ? "Catch it for an hour of mining" : "Tap to catch it")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let remaining = max(0, airdrop.expiresAt.timeIntervalSince(context.date))
                    CountdownRing(fraction: remaining / max(1, airdrop.lifetime), color: isWhale ? .cyan : Theme.bitcoin)
                }
                .padding(.leading, 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isWhale ? 14 : 10)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint((isWhale ? Color.cyan : Theme.bitcoin).opacity(0.35)).interactive(), in: .capsule)
        .sensoryFeedback(isWhale ? .impact(weight: .heavy) : .impact(weight: .medium), trigger: appeared) { _, new in
            haptics && new
        }
        .onAppear { appeared = true }
        .accessibilityLabel(isWhale ? "Whale airdrop, worth an hour of mining. Tap to catch it before it disappears."
                                    : "Airdrop. Tap to catch it before it disappears.")
    }
}

struct CountdownRing: View {
    let fraction: Double
    var color = Theme.bitcoin

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: fraction)
        }
        .frame(width: 26, height: 26)
    }
}
